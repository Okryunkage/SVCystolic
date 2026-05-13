import argparse
from pathlib import Path
import torch
import torch.nn as nn

inNum   =784
hidNum  =64
outNum  =10
inWidth =8
inFrac  =8
w1Width =8
w1Frac  =6
b1Width =32
b1Frac  =inFrac+w1Frac
a1Width =8
a1Frac  =4
w2Width =8
w2Frac  =6
b2Width =32
b2Frac  =a1Frac+w2Frac

fc1Tile =8
fc2Tile =5

class FixedPointMNISTMLP(nn.Module):
	def __init__(self):
		super().__init__()
		self.fc1 =nn.Linear(inNum, hidNum, bias=True)
		self.fc2 =nn.Linear(hidNum, outNum, bias=True)
	def forward(self, x):
		raise RuntimeError("This export script does not use forward().")
	
@torch.no_grad()
def quantize_signed_to_int(x,num_bits,frac_bits):
	qmin =-(1<<(num_bits-1))
	qmax = (1<<(num_bits-1))-1
	scale = 1<<frac_bits
	q =torch.round(x*scale)
	q =torch.clamp(q,qmin,qmax)
	return q.to(torch.int64)

@torch.no_grad()
def export_integer_params(model):
	#Move the trained parameters to CPU before export so that
	#they can be handled easily for saving, printing, or converting
	#to formats such as NumPy arrays or text files.
	qW1 =quantize_signed_to_int(model.fc1.weight.cpu(), w1Width,w1Frac)
	qB1 =quantize_signed_to_int(model.fc1.bias.cpu(),   b1Width,b1Frac)
	qW2 =quantize_signed_to_int(model.fc2.weight.cpu(), w2Width,w2Frac)
	qB2 =quantize_signed_to_int(model.fc2.bias.cpu(),   b2Width,b2Frac)
	return qW1,qB1,qW2,qB2

def pack_word_lsb_first(values, elem_bits):
	#Pack multiple integer values into one hex word string.
	#values[0] goes to the least-significant segment,
	#values[1] goes to the next segment, ...
	word =0
	mask =(1<<elem_bits)-1
	for i,v in enumerate(values):
		word |=((int(v)&mask)<<(i*elem_bits))

	total_bits =len(values)*elem_bits
	hex_digits =(total_bits+3)//4
	return f"{word:0{hex_digits}x}"

def export_fc_weight_tile_mem(qW,tile,elem_bits,path):
	#qW shape: [OUT_NUM, IN_NUM]
	#line order: tile-major, then input-major
	#For each line, TILE weights are packed into one word:
	#	values[0] -> LSB segment
	#	values[1] -> next segment
	#	...
	out_num,in_num =qW.shape
	assert out_num%tile ==0,f"OUT_NUM={out_num} must be divisible by tile={tile}"

	with open(path,"w",encoding="utf-8") as f:
		for tile_base in range(0,out_num,tile):
			for i in range(in_num):
				vals =[qW[tile_base+k,i] for k in range(tile)]
				f.write(pack_word_lsb_first(vals,elem_bits)+"\n")

def export_fc_bias_tile_mem(qB,tile,elem_bits,path):
	#qB shape: [OUT_NUM]
	#line order: tile-major
	#Each line packs TILE bias values into one word.
	out_num =qB.shape[0]
	assert out_num%tile ==0, f"OUT_NUM={out_num} must be divisible by tile={tile}"

	with open(path,"w",encoding="utf-8") as f:
		for tile_base in range(0,out_num,tile):
			vals = [qB[tile_base + k] for k in range(tile)]
			f.write(pack_word_lsb_first(vals,elem_bits)+"\n")

def export_txt(qW1,qB1,qW2,qB2,path):
	with open(path, "w", encoding="utf-8") as f:
		f.write("=== Fixed-point MNIST MLP parameters ===\n\n")

		f.write(f"inNum={inNum}\n")
		f.write(f"hidNum={hidNum}\n")
		f.write(f"outNum={outNum}\n\n")

		f.write(f"inWidth={inWidth}, inFrac={inFrac}\n")
		f.write(f"w1Width={w1Width}, w1Frac={w1Frac}\n")
		f.write(f"b1Width={b1Width}, b1Frac={b1Frac}\n")
		f.write(f"a1Width={a1Width}, a1Frac={a1Frac}\n")
		f.write(f"w2Width={w2Width}, w2Frac={w2Frac}\n")
		f.write(f"b2Width={b2Width}, b2Frac={b2Frac}\n\n")

		f.write(f"fc1.weight_int shape = {tuple(qW1.shape)}\n")
		f.write(f"{qW1.tolist()}\n\n")

		f.write(f"fc1.bias_int shape = {tuple(qB1.shape)}\n")
		f.write(f"{qB1.tolist()}\n\n")

		f.write(f"fc2.weight_int shape = {tuple(qW2.shape)}\n")
		f.write(f"{qW2.tolist()}\n\n")

		f.write(f"fc2.bias_int shape = {tuple(qB2.shape)}\n")
		f.write(f"{qB2.tolist()}\n\n")

def load_state_dict_from_pth(model_path):
	"""
	Supports:
	  - torch.save(model.state_dict(), path)
	  - torch.save({"state_dict": model.state_dict()}, path)
	  - torch.save({"model_state_dict": model.state_dict()}, path)
	"""
	try:
		obj =torch.load(model_path, map_location="cpu", weights_only=True)
	except TypeError:
		# For older PyTorch versions that do not support weights_only.
		obj =torch.load(model_path, map_location="cpu")

	if isinstance(obj,dict) and "state_dict" in obj:
		state_dict =obj["state_dict"]
	elif isinstance(obj,dict) and "model_state_dict" in obj:
		state_dict =obj["model_state_dict"]
	else:
		state_dict =obj

	# If the model was saved from DataParallel, keys may start with "module."
	cleaned ={}
	for k, v in state_dict.items():
		if k.startswith("module."):
			cleaned[k[len("module."):]] =v
		else:
			cleaned[k] =v
	return cleaned

def export_from_pth(model_path,out_dir,txt_name):
	out_dir = Path(out_dir)
	out_dir.mkdir(parents=True, exist_ok=True)

	model =FixedPointMNISTMLP()
	state_dict =load_state_dict_from_pth(model_path)
	model.load_state_dict(state_dict, strict=True)
	model.eval()

	qW1,qB1,qW2,qB2 =export_integer_params(model)

	txt_path =out_dir/txt_name
	fc1_w_mem =out_dir/"fc1_w_tile.mem"
	fc1_b_mem = out_dir/"fc1_b_tile.mem"
	fc2_w_mem = out_dir/"fc2_w_tile.mem"
	fc2_b_mem = out_dir/"fc2_b_tile.mem"

	export_txt(qW1, qB1, qW2, qB2, txt_path)

	export_fc_weight_tile_mem(qW1, tile=fc1Tile, elem_bits=w1Width, path=fc1_w_mem)
	export_fc_bias_tile_mem  (qB1, tile=fc1Tile, elem_bits=b1Width, path=fc1_b_mem)

	export_fc_weight_tile_mem(qW2, tile=fc2Tile, elem_bits=w2Width, path=fc2_w_mem)
	export_fc_bias_tile_mem  (qB2, tile=fc2Tile, elem_bits=b2Width, path=fc2_b_mem)

	print("Export done.")
	print(f"TXT : {txt_path}")
	print(f"MEM : {fc1_w_mem}")
	print(f"MEM : {fc1_b_mem}")
	print(f"MEM : {fc2_w_mem}")
	print(f"MEM : {fc2_b_mem}")

	print("\nExpected .mem line counts:")
	print(f"  fc1_w_tile.mem : {(hidNum // fc1Tile) * inNum}")
	print(f"  fc1_b_tile.mem : {hidNum // fc1Tile}")
	print(f"  fc2_w_tile.mem : {(outNum // fc2Tile) * hidNum}")
	print(f"  fc2_b_tile.mem : {outNum // fc2Tile}")

def main():
	parser =argparse.ArgumentParser(description="Export fixed-point MNIST MLP .pth parameters to .txt and tile-packed .mem files.")
	parser.add_argument("--model", default="mnistMLP64.pth", help="Input .pth file path. Default: mnistMLP64.pth",)
	parser.add_argument("--out-dir", default=".", help="Output directory for .txt and .mem files. Default: current directory",)
	parser.add_argument("--txt", default="mnistMLP64.txt", help="Output text filename. Default: mnistMLP64.txt",)

	args = parser.parse_args()
	export_from_pth(args.model, args.out_dir, args.txt)

if __name__ == "__main__":
	main()