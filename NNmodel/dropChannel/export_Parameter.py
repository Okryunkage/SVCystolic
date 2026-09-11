from __future__ import annotations

import argparse
from pathlib import Path

import torch

weightWidth =8
weightFrac =7

conv1Tile =8
conv2Tile =8
classifierTile =5

@torch.no_grad()
def quantize_signed_to_int(
	x: torch.Tensor, num_bits: int, fractional_bits: int,)-> torch.Tensor:
	qmin =-(1<<(num_bits-1))
	qmax =(1<<(num_bits-1))-1
	scale =1<<fractional_bits
	q =torch.round(x*scale)
	q =torch.clamp(q, qmin, qmax)
	return q.to(torch.int64)

def pack_word_lsb_first(values: list[torch.Tensor], element_bits: int,)-> str:
	#values[0] occupies the least-significant segment of the packed word.
	word =0
	mask =(1<<element_bits)-1
	for index, value in enumerate(values):
		word |=(int(value)&mask)<<(index*element_bits)
	total_bits =len(values)*element_bits
	hex_digits =(total_bits+3)//4
	return f"{word:0{hex_digits}X}"

def export_conv_weight_tile_mem(
	quantized_weight: torch.Tensor, tile: int,
	element_bits: int, path: Path,)-> None:
	#Shape: [OUT_CHANNELS, IN_CHANNELS, KERNEL_HEIGHT, KERNEL_WIDTH]
	#Line order: output tile, input channel, kernel row, kernel column.
	out_channels, in_channels, kernel_height, kernel_width =quantized_weight.shape
	if out_channels%tile !=0:
		raise ValueError(f"OUT_CHANNELS={out_channels} must be divisible by tile={tile}")
	with path.open("w", encoding="ascii") as file:
		for tile_base in range(0, out_channels, tile):
			for input_channel in range(in_channels):
				for kernel_row in range(kernel_height):
					for kernel_column in range(kernel_width):
						values =[
							quantized_weight[tile_base+offset, input_channel, kernel_row, kernel_column]
							for offset in range(tile)]
						file.write(pack_word_lsb_first(values, element_bits)+"\n")

def export_linear_weight_tile_mem(
	quantized_weight: torch.Tensor, tile: int,
	element_bits: int, path: Path,)-> None:
	#Shape: [OUT_FEATURES, IN_FEATURES]
	#Line order: output tile, input feature.
	out_features, in_features =quantized_weight.shape
	if out_features%tile !=0:
		raise ValueError(f"OUT_FEATURES={out_features} must be divisible by tile={tile}")
	with path.open("w", encoding="ascii") as file:
		for tile_base in range(0, out_features, tile):
			for input_feature in range(in_features):
				values =[
					quantized_weight[tile_base+offset, input_feature]
					for offset in range(tile)]
				file.write(pack_word_lsb_first(values, element_bits)+"\n")

def load_checkpoint(path: Path)-> tuple[dict[str, torch.Tensor], dict]:
	try:
		checkpoint =torch.load(path, map_location="cpu", weights_only=True)
	except TypeError:
		checkpoint =torch.load(path, map_location="cpu")
	if isinstance(checkpoint, dict) and "model_state_dict" in checkpoint:
		state_dict =checkpoint["model_state_dict"]
	elif isinstance(checkpoint, dict) and "state_dict" in checkpoint:
		state_dict =checkpoint["state_dict"]
	else:
		state_dict =checkpoint
	cleaned_state_dict ={}
	for name, value in state_dict.items():
		clean_name =name[len("module."):] if name.startswith("module.") else name
		cleaned_state_dict[clean_name] =value
	metadata =checkpoint if isinstance(checkpoint, dict) else {}
	return cleaned_state_dict, metadata

def require_weight(
	state_dict: dict[str, torch.Tensor], name: str,
	expected_dimensions: int,)-> torch.Tensor:
	if name not in state_dict:
		raise KeyError(f"Checkpoint does not contain '{name}'")
	weight =state_dict[name].detach().cpu()
	if weight.ndim !=expected_dimensions:
		raise ValueError(
			f"{name} must have {expected_dimensions} dimensions, but shape is {tuple(weight.shape)}")
	return weight

def export_txt(
	weights: dict[str, torch.Tensor], quantized: dict[str, torch.Tensor],
	path: Path, checkpoint_path: Path,)-> None:
	with path.open("w", encoding="utf-8") as file:
		file.write("=== Fixed-point MNIST CNN weights ===\n\n")
		file.write(f"checkpoint={checkpoint_path.resolve()}\n")
		file.write(f"weightWidth={weightWidth}, weightFrac={weightFrac}\n")
		file.write("packing=output-channel tile, values[0] in LSB\n\n")
		for name in ("conv1.weight", "conv2.weight", "classifier.weight"):
			file.write(f"{name} shape={tuple(weights[name].shape)}\n")
			file.write(f"quantized_min={quantized[name].min().item()}\n")
			file.write(f"quantized_max={quantized[name].max().item()}\n")
			file.write(f"quantized_values={quantized[name].tolist()}\n\n")

def export_from_checkpoint(
	checkpoint_path: Path, output_dir: Path, txt_name: str,)-> None:
	state_dict, metadata =load_checkpoint(checkpoint_path)
	saved_bits =metadata.get("weight_fractional_bits")
	if saved_bits is not None and saved_bits !=weightFrac:
		raise ValueError(
			f"Checkpoint uses {saved_bits} fractional bits, but exporter uses {weightFrac}")

	weights ={
		"conv1.weight": require_weight(state_dict, "conv1.weight", 4),
		"conv2.weight": require_weight(state_dict, "conv2.weight", 4),
		"classifier.weight": require_weight(state_dict, "classifier.weight", 2),}
	quantized ={
		name: quantize_signed_to_int(weight, weightWidth, weightFrac)
		for name, weight in weights.items()}

	output_dir.mkdir(parents=True, exist_ok=True)
	conv1_path =output_dir/"conv1_w_tile.mem"
	conv2_path =output_dir/"conv2_w_tile.mem"
	classifier_path =output_dir/"classifier_w_tile.mem"
	txt_path =output_dir/txt_name

	export_conv_weight_tile_mem(quantized["conv1.weight"], conv1Tile, weightWidth, conv1_path)
	export_conv_weight_tile_mem(quantized["conv2.weight"], conv2Tile, weightWidth, conv2_path)
	export_linear_weight_tile_mem(
		quantized["classifier.weight"], classifierTile, weightWidth, classifier_path)
	export_txt(weights, quantized, txt_path, checkpoint_path)

	conv1_lines =(weights["conv1.weight"].shape[0]//conv1Tile)*weights["conv1.weight"].shape[1]*weights["conv1.weight"].shape[2]*weights["conv1.weight"].shape[3]
	conv2_lines =(weights["conv2.weight"].shape[0]//conv2Tile)*weights["conv2.weight"].shape[1]*weights["conv2.weight"].shape[2]*weights["conv2.weight"].shape[3]
	classifier_lines =(weights["classifier.weight"].shape[0]//classifierTile)*weights["classifier.weight"].shape[1]
	print("Export done.")
	print(f"TXT : {txt_path.resolve()}")
	print(f"MEM : {conv1_path.resolve()} ({conv1_lines} lines)")
	print(f"MEM : {conv2_path.resolve()} ({conv2_lines} lines)")
	print(f"MEM : {classifier_path.resolve()} ({classifier_lines} lines)")

def main()-> None:
	parser =argparse.ArgumentParser(
		description="Export fixed-point MNIST CNN weights to tile-packed .mem files.")
	parser.add_argument("--model", default="MCDC_int8_Fixed.pt", help="Input checkpoint path")
	parser.add_argument("--out-dir", default="hex_weights", help="Output directory")
	parser.add_argument("--txt", default="MCDC_int8_Fixed.txt", help="Output text filename")
	args =parser.parse_args()
	export_from_checkpoint(Path(args.model), Path(args.out_dir), args.txt)

if __name__ == "__main__":
	main()