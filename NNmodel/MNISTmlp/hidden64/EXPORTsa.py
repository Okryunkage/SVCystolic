import argparse
from pathlib import Path
from typing import Iterable, List, Optional, Sequence, Tuple

import torch
import torch.nn as nn

# -----------------------------------------------------------------------------
# Design parameters: AXKU062 / 32x32 SA version
# -----------------------------------------------------------------------------
IN_NUM = 784
HID_NUM = 64
OUT_NUM = 10
SA_SIZE = 32

IN_WIDTH = 8
IN_FRAC = 8
W1_WIDTH = 8
W1_FRAC = 6
B1_WIDTH = 32
B1_FRAC = IN_FRAC + W1_FRAC
A1_WIDTH = 8
A1_FRAC = 4
W2_WIDTH = 8
W2_FRAC = 6
B2_WIDTH = 32
B2_FRAC = A1_FRAC + W2_FRAC

FC1_IN_TILES = (IN_NUM + SA_SIZE - 1) // SA_SIZE   # 25
FC1_OUT_TILES = (HID_NUM + SA_SIZE - 1) // SA_SIZE # 2
FC2_IN_TILES = (HID_NUM + SA_SIZE - 1) // SA_SIZE  # 2
FC2_OUT_PAD = SA_SIZE                              # class 0~9 valid, 10~31 zero padding

RQ_SHIFT = B1_FRAC - A1_FRAC                       # 10


class FixedPointMNISTMLP(nn.Module):
	def __init__(self):
		super().__init__()
		self.fc1 = nn.Linear(IN_NUM, HID_NUM, bias=True)
		self.fc2 = nn.Linear(HID_NUM, OUT_NUM, bias=True)

	def forward(self, x):
		raise RuntimeError("This export script does not use forward().")


@torch.no_grad()
def quantize_signed_to_int(x: torch.Tensor, num_bits: int, frac_bits: int) -> torch.Tensor:
	qmin = -(1 << (num_bits - 1))
	qmax = (1 << (num_bits - 1)) - 1
	scale = 1 << frac_bits
	q = torch.round(x * scale)
	q = torch.clamp(q, qmin, qmax)
	return q.to(torch.int64)


@torch.no_grad()
def export_integer_params(model: FixedPointMNISTMLP):
	qW1 = quantize_signed_to_int(model.fc1.weight.cpu(), W1_WIDTH, W1_FRAC)
	qB1 = quantize_signed_to_int(model.fc1.bias.cpu(), B1_WIDTH, B1_FRAC)
	qW2 = quantize_signed_to_int(model.fc2.weight.cpu(), W2_WIDTH, W2_FRAC)
	qB2 = quantize_signed_to_int(model.fc2.bias.cpu(), B2_WIDTH, B2_FRAC)
	return qW1, qB1, qW2, qB2


def pack_word_lsb_first(values: Sequence[int], elem_bits: int) -> str:
	"""
	Pack integer values into one hex word.
	values[0] goes to the least-significant elem_bits segment.

	Example for 8-bit values:
	  values[0] -> word[7:0]
	  values[1] -> word[15:8]
	  ...
	"""
	word = 0
	mask = (1 << elem_bits) - 1
	for i, v in enumerate(values):
		word |= ((int(v) & mask) << (i * elem_bits))

	total_bits = len(values) * elem_bits
	hex_digits = (total_bits + 3) // 4
	return f"{word:0{hex_digits}x}"


def write_lines(path: Path, lines: Iterable[str]) -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	with open(path, "w", encoding="utf-8") as f:
		for line in lines:
			f.write(line.rstrip() + "\n")


# -----------------------------------------------------------------------------
# Weight/Bias .mem export for 32x32 SA
# -----------------------------------------------------------------------------
def export_fc1_weight_sa32_mem(qW1: torch.Tensor, path: Path) -> None:
	"""
	fc1WeightBRAM format:
	  - word width = 256 bit = 32 x int8
	  - depth      = 64 output channels x 25 input tiles = 1600
	  - address    = output_channel * 25 + input_tile

	Each line stores 32 input-direction weights for one output channel.
	  line = pack(qW1[output_channel, input_tile*32 + 0 : +32])
	Last tile is zero-padded from input index 784 to 799.
	"""
	assert tuple(qW1.shape) == (HID_NUM, IN_NUM)
	lines: List[str] = []
	for out_ch in range(HID_NUM):
		for in_tile in range(FC1_IN_TILES):
			base = in_tile * SA_SIZE
			vals = []
			for k in range(SA_SIZE):
				in_idx = base + k
				vals.append(int(qW1[out_ch, in_idx]) if in_idx < IN_NUM else 0)
			lines.append(pack_word_lsb_first(vals, W1_WIDTH))
	write_lines(path, lines)


def export_fc2_weight_sa32_mem(qW2: torch.Tensor, path: Path) -> None:
	"""
	fc2WeightBRAM format:
	  - word width = 256 bit = 32 x int8
	  - depth      = 32 padded output columns x 2 input tiles = 64
	  - address    = output_column * 2 + input_tile

	output_column 0~9  : real class weights
	output_column 10~31: zero padding
	"""
	assert tuple(qW2.shape) == (OUT_NUM, HID_NUM)
	lines: List[str] = []
	for out_col in range(FC2_OUT_PAD):
		for in_tile in range(FC2_IN_TILES):
			base = in_tile * SA_SIZE
			vals = []
			for k in range(SA_SIZE):
				in_idx = base + k
				if out_col < OUT_NUM and in_idx < HID_NUM:
					vals.append(int(qW2[out_col, in_idx]))
				else:
					vals.append(0)
			lines.append(pack_word_lsb_first(vals, W2_WIDTH))
	write_lines(path, lines)


def export_bias_32bit_mem(qB: torch.Tensor, path: Path, depth: int, pad_value: int = 0) -> None:
	"""
	Bias memory format:
	  - word width = 32 bit
	  - one signed int32 bias per line, written as two's-complement hex.
	"""
	lines: List[str] = []
	for i in range(depth):
		v = int(qB[i]) if i < qB.numel() else pad_value
		lines.append(pack_word_lsb_first([v], 32))
	write_lines(path, lines)


# -----------------------------------------------------------------------------
# Optional inputBatchBRAM .mem export
# -----------------------------------------------------------------------------
def parse_indices(indices: Optional[str]) -> Optional[List[int]]:
	if indices is None or indices.strip() == "":
		return None
	return [int(x.strip()) for x in indices.split(",") if x.strip()]


def load_mnist_images(
	data_dir: Path,
	batch_size: int,
	indices: Optional[Sequence[int]],
	download: bool,
	random_select: bool,
) -> Tuple[List[int], List[int], torch.Tensor]:
	"""
	Returns:
	  used_indices: list[int]
	  labels      : list[int]
	  images_u8   : torch.uint8 tensor [batch_size, 784]
	"""
	try:
		from torchvision import datasets
		import numpy as np
	except ImportError as e:
		raise RuntimeError("torchvision and numpy are required only when --export-input is used.") from e

	testset = datasets.MNIST(root=str(data_dir), train=False, download=download, transform=None)

	if indices is None:
		if random_select:
			import random
			used_indices = random.sample(range(len(testset)), batch_size)
		else:
			used_indices = list(range(batch_size))
	else:
		used_indices = list(indices)
		if len(used_indices) != batch_size:
			raise ValueError(f"--indices length ({len(used_indices)}) must match --batch-size ({batch_size}).")

	labels: List[int] = []
	flat_images: List[torch.Tensor] = []
	for idx in used_indices:
		img, label = testset[idx]
		img_np = np.array(img, dtype=np.uint8)
		if img_np.shape != (28, 28):
			raise ValueError(f"Unexpected MNIST image shape at index {idx}: {img_np.shape}")
		labels.append(int(label))
		flat_images.append(torch.from_numpy(img_np.reshape(-1).copy()).to(torch.uint8))

	images_u8 = torch.stack(flat_images, dim=0)
	return used_indices, labels, images_u8


def export_input_batch_sa32_mem(images_u8: torch.Tensor, path: Path) -> None:
	"""
	inputBatchBRAM format:
	  - word width = 256 bit = 32 x uint8
	  - depth      = batch_size x 25
	  - address    = image_index * 25 + input_tile

	Each image:
	  tile 0  = pixel[0:31]
	  ...
	  tile 23 = pixel[736:767]
	  tile 24 = pixel[768:783] + 16-byte zero padding
	"""
	if images_u8.dtype != torch.uint8:
		raise TypeError("images_u8 must be torch.uint8")
	if images_u8.ndim != 2 or images_u8.shape[1] != IN_NUM:
		raise ValueError(f"images_u8 must have shape [batch_size, {IN_NUM}]")

	lines: List[str] = []
	batch_size = images_u8.shape[0]
	for img_idx in range(batch_size):
		pixels = images_u8[img_idx]
		for in_tile in range(FC1_IN_TILES):
			base = in_tile * SA_SIZE
			vals = []
			for k in range(SA_SIZE):
				pidx = base + k
				vals.append(int(pixels[pidx]) if pidx < IN_NUM else 0)
			lines.append(pack_word_lsb_first(vals, IN_WIDTH))
	write_lines(path, lines)


# -----------------------------------------------------------------------------
# Integer golden model for debug
# -----------------------------------------------------------------------------
def requant_u8_from_fc1_acc(fc1_acc: torch.Tensor) -> torch.Tensor:
	relu = torch.clamp(fc1_acc, min=0)
	shifted = torch.div(relu, 1 << RQ_SHIFT, rounding_mode="floor")
	clipped = torch.clamp(shifted, 0, (1 << A1_WIDTH) - 1)
	return clipped.to(torch.int64)


@torch.no_grad()
def run_integer_golden(images_u8: torch.Tensor, qW1: torch.Tensor, qB1: torch.Tensor, qW2: torch.Tensor, qB2: torch.Tensor):
	x = images_u8.to(torch.int64)
	fc1_acc = x @ qW1.t() + qB1.view(1, -1)
	a1_u8 = requant_u8_from_fc1_acc(fc1_acc)
	fc2_acc = a1_u8 @ qW2.t() + qB2.view(1, -1)
	pred = torch.argmax(fc2_acc, dim=1).to(torch.int64)
	return fc1_acc, a1_u8, fc2_acc, pred


def export_golden_files(out_dir: Path, used_indices: Sequence[int], labels: Sequence[int], fc1_acc, a1_u8, fc2_acc, pred) -> None:
	with open(out_dir / "input_labels.txt", "w", encoding="utf-8") as f:
		f.write("image_order index label\n")
		for i, (idx, lab) in enumerate(zip(used_indices, labels)):
			f.write(f"{i} {idx} {lab}\n")

	with open(out_dir / "golden_predictions.txt", "w", encoding="utf-8") as f:
		f.write("image_order index label pred correct\n")
		for i, (idx, lab, p) in enumerate(zip(used_indices, labels, pred.tolist())):
			f.write(f"{i} {idx} {lab} {p} {int(lab == p)}\n")

	with open(out_dir / "golden_fc2_scores.txt", "w", encoding="utf-8") as f:
		f.write("image_order fc2_score_0 ... fc2_score_9\n")
		for i in range(fc2_acc.shape[0]):
			scores = " ".join(str(int(v)) for v in fc2_acc[i].tolist())
			f.write(f"{i} {scores}\n")

	with open(out_dir / "golden_fc1_activation_u8.txt", "w", encoding="utf-8") as f:
		f.write("image_order a1_0 ... a1_63\n")
		for i in range(a1_u8.shape[0]):
			vals = " ".join(str(int(v)) for v in a1_u8[i].tolist())
			f.write(f"{i} {vals}\n")


# -----------------------------------------------------------------------------
# Text report
# -----------------------------------------------------------------------------
def export_txt(qW1, qB1, qW2, qB2, path: Path) -> None:
	with open(path, "w", encoding="utf-8") as f:
		f.write("=== AXKU062 / 32x32 SA fixed-point MNIST MLP export ===\n\n")
		f.write(f"IN_NUM={IN_NUM}\n")
		f.write(f"HID_NUM={HID_NUM}\n")
		f.write(f"OUT_NUM={OUT_NUM}\n")
		f.write(f"SA_SIZE={SA_SIZE}\n")
		f.write(f"FC1_IN_TILES={FC1_IN_TILES}\n")
		f.write(f"FC1_OUT_TILES={FC1_OUT_TILES}\n")
		f.write(f"FC2_IN_TILES={FC2_IN_TILES}\n\n")

		f.write(f"IN_WIDTH={IN_WIDTH}, IN_FRAC={IN_FRAC}\n")
		f.write(f"W1_WIDTH={W1_WIDTH}, W1_FRAC={W1_FRAC}\n")
		f.write(f"B1_WIDTH={B1_WIDTH}, B1_FRAC={B1_FRAC}\n")
		f.write(f"A1_WIDTH={A1_WIDTH}, A1_FRAC={A1_FRAC}\n")
		f.write(f"W2_WIDTH={W2_WIDTH}, W2_FRAC={W2_FRAC}\n")
		f.write(f"B2_WIDTH={B2_WIDTH}, B2_FRAC={B2_FRAC}\n")
		f.write(f"RQ_SHIFT={RQ_SHIFT}\n\n")

		f.write("Memory format:\n")
		f.write("  input_batch_sa32.mem : 256-bit, depth=batch_size*25, addr=image_index*25+input_tile\n")
		f.write("  fc1_w_sa32.mem       : 256-bit, depth=64*25=1600, addr=out_ch*25+input_tile\n")
		f.write("  fc1_b_32bit.mem      : 32-bit,  depth=64\n")
		f.write("  fc2_w_sa32.mem       : 256-bit, depth=32*2=64, addr=out_col*2+input_tile, out_col 10~31 padded zero\n")
		f.write("  fc2_b_32bit_pad.mem  : 32-bit,  depth=32, class 10~31 padded zero\n\n")

		f.write(f"fc1.weight_int shape = {tuple(qW1.shape)}\n")
		f.write(f"fc1.bias_int   shape = {tuple(qB1.shape)}\n")
		f.write(f"fc2.weight_int shape = {tuple(qW2.shape)}\n")
		f.write(f"fc2.bias_int   shape = {tuple(qB2.shape)}\n")


# -----------------------------------------------------------------------------
# Model loading / main export
# -----------------------------------------------------------------------------
def load_state_dict_from_pth(model_path: Path):
	"""
	Supports:
	  - torch.save(model.state_dict(), path)
	  - torch.save({"state_dict": model.state_dict()}, path)
	  - torch.save({"model_state_dict": model.state_dict()}, path)
	"""
	try:
		obj = torch.load(model_path, map_location="cpu", weights_only=True)
	except TypeError:
		obj = torch.load(model_path, map_location="cpu")

	if isinstance(obj, dict) and "state_dict" in obj:
		state_dict = obj["state_dict"]
	elif isinstance(obj, dict) and "model_state_dict" in obj:
		state_dict = obj["model_state_dict"]
	else:
		state_dict = obj

	cleaned = {}
	for k, v in state_dict.items():
		if k.startswith("module."):
			cleaned[k[len("module."):]] = v
		else:
			cleaned[k] = v
	return cleaned


def export_from_pth(args) -> None:
	out_dir = Path(args.out_dir)
	out_dir.mkdir(parents=True, exist_ok=True)

	model = FixedPointMNISTMLP()
	state_dict = load_state_dict_from_pth(Path(args.model))
	model.load_state_dict(state_dict, strict=True)
	model.eval()

	qW1, qB1, qW2, qB2 = export_integer_params(model)

	txt_path = out_dir / args.txt
	fc1_w_mem = out_dir / "fc1_w_sa32.mem"
	fc1_b_mem = out_dir / "fc1_b_32bit.mem"
	fc2_w_mem = out_dir / "fc2_w_sa32.mem"
	fc2_b_mem = out_dir / "fc2_b_32bit_pad.mem"

	export_txt(qW1, qB1, qW2, qB2, txt_path)
	export_fc1_weight_sa32_mem(qW1, fc1_w_mem)
	export_bias_32bit_mem(qB1, fc1_b_mem, depth=HID_NUM)
	export_fc2_weight_sa32_mem(qW2, fc2_w_mem)
	export_bias_32bit_mem(qB2, fc2_b_mem, depth=FC2_OUT_PAD)

	print("Exported parameter .mem files:")
	print(f"  TXT : {txt_path}")
	print(f"  MEM : {fc1_w_mem}        lines={HID_NUM * FC1_IN_TILES}, width=256b")
	print(f"  MEM : {fc1_b_mem}        lines={HID_NUM}, width=32b")
	print(f"  MEM : {fc2_w_mem}        lines={FC2_OUT_PAD * FC2_IN_TILES}, width=256b")
	print(f"  MEM : {fc2_b_mem}        lines={FC2_OUT_PAD}, width=32b")

	if args.export_input:
		indices = parse_indices(args.indices)
		used_indices, labels, images_u8 = load_mnist_images(
			data_dir=Path(args.data_dir),
			batch_size=args.batch_size,
			indices=indices,
			download=args.download,
			random_select=args.random,
		)
		input_mem = out_dir / "input_batch_sa32.mem"
		export_input_batch_sa32_mem(images_u8, input_mem)
		print(f"  MEM : {input_mem}        lines={args.batch_size * FC1_IN_TILES}, width=256b")

		fc1_acc, a1_u8, fc2_acc, pred = run_integer_golden(images_u8, qW1, qB1, qW2, qB2)
		export_golden_files(out_dir, used_indices, labels, fc1_acc, a1_u8, fc2_acc, pred)
		print("Exported golden debug files:")
		print(f"  TXT : {out_dir / 'input_labels.txt'}")
		print(f"  TXT : {out_dir / 'golden_predictions.txt'}")
		print(f"  TXT : {out_dir / 'golden_fc2_scores.txt'}")
		print(f"  TXT : {out_dir / 'golden_fc1_activation_u8.txt'}")


def main() -> None:
	parser = argparse.ArgumentParser(
		description="Export MNIST MLP parameters and optional input batch for AXKU062 32x32 SA design."
	)
	parser.add_argument("--model", default="mnistMLP64.pth", help="Input .pth file path.")
	parser.add_argument("--out-dir", default=".", help="Output directory for .mem/.txt files.")
	parser.add_argument("--txt", default="mnistMLP64_sa32_export.txt", help="Output text report filename.")

	parser.add_argument("--export-input", action="store_true", help="Also export input_batch_sa32.mem from MNIST test images.")
	parser.add_argument("--batch-size", type=int, default=1, help="Number of MNIST test images to export when --export-input is used.")
	parser.add_argument("--indices", default=None, help="Comma-separated MNIST test indices. Length must match --batch-size.")
	parser.add_argument("--random", action="store_true", help="Randomly choose MNIST test images when --indices is not given.")
	parser.add_argument("--data-dir", default="./data", help="MNIST data directory.")
	parser.add_argument("--download", action="store_true", help="Allow torchvision to download MNIST if not found.")

	args = parser.parse_args()
	export_from_pth(args)


if __name__ == "__main__":
	main()
