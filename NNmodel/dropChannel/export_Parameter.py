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
	if num_bits !=8:
		raise ValueError(f"Only int8 export is supported, but num_bits={num_bits}")
	qmin =-(1<<(num_bits-1))
	qmax =(1<<(num_bits-1))-1
	scale =1<<fractional_bits
	q =torch.round(x*scale)
	q =torch.clamp(q, qmin, qmax)
	return q.to(torch.int8)

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

def export_bias_tile_mem(
	quantized_bias: torch.Tensor, tile: int,
	element_bits: int, path: Path,)-> None:
	#Shape: [OUT_CHANNELS] or [OUT_FEATURES]
	#Line order: output tile.
	output_count =quantized_bias.shape[0]
	if output_count%tile !=0:
		raise ValueError(f"OUTPUT_COUNT={output_count} must be divisible by tile={tile}")
	with path.open("w", encoding="ascii") as file:
		for tile_base in range(0, output_count, tile):
			values =[
				quantized_bias[tile_base+offset]
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

def require_parameter(
	state_dict: dict[str, torch.Tensor], name: str,
	expected_dimensions: int,)-> torch.Tensor:
	if name not in state_dict:
		raise KeyError(f"Checkpoint does not contain '{name}'")
	parameter =state_dict[name].detach().cpu()
	if parameter.ndim !=expected_dimensions:
		raise ValueError(
			f"{name} must have {expected_dimensions} dimensions, but shape is {tuple(parameter.shape)}")
	return parameter

def export_txt(
	parameters: dict[str, torch.Tensor], quantized: dict[str, torch.Tensor],
	path: Path, checkpoint_path: Path,)-> None:
	with path.open("w", encoding="utf-8") as file:
		file.write("=== Fixed-point MNIST CNN parameters ===\n\n")
		file.write(f"checkpoint={checkpoint_path.resolve()}\n")
		file.write(f"parameterWidth={weightWidth}, parameterFrac={weightFrac}\n")
		file.write("format=signed int8 Q1.7, two's complement\n")
		file.write("packing=output-channel tile, values[0] in LSB\n\n")
		for name in (
			"conv1.weight", "conv1.bias",
			"conv2.weight", "conv2.bias",
			"classifier.weight", "classifier.bias",):
			file.write(f"{name} shape={tuple(parameters[name].shape)}\n")
			file.write(f"dtype={quantized[name].dtype}\n")
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

	parameters ={
		"conv1.weight": require_parameter(state_dict, "conv1.weight", 4),
		"conv1.bias": require_parameter(state_dict, "conv1.bias", 1),
		"conv2.weight": require_parameter(state_dict, "conv2.weight", 4),
		"conv2.bias": require_parameter(state_dict, "conv2.bias", 1),
		"classifier.weight": require_parameter(state_dict, "classifier.weight", 2),
		"classifier.bias": require_parameter(state_dict, "classifier.bias", 1),}
	quantized ={
		name: quantize_signed_to_int(parameter, weightWidth, weightFrac)
		for name, parameter in parameters.items()}

	output_dir.mkdir(parents=True, exist_ok=True)
	conv1_weight_path =output_dir/"conv1_w_tile.mem"
	conv1_bias_path =output_dir/"conv1_b_tile.mem"
	conv2_weight_path =output_dir/"conv2_w_tile.mem"
	conv2_bias_path =output_dir/"conv2_b_tile.mem"
	classifier_weight_path =output_dir/"classifier_w_tile.mem"
	classifier_bias_path =output_dir/"classifier_b_tile.mem"
	txt_path =output_dir/txt_name

	export_conv_weight_tile_mem(
		quantized["conv1.weight"], conv1Tile, weightWidth, conv1_weight_path)
	export_bias_tile_mem(
		quantized["conv1.bias"], conv1Tile, weightWidth, conv1_bias_path)
	export_conv_weight_tile_mem(
		quantized["conv2.weight"], conv2Tile, weightWidth, conv2_weight_path)
	export_bias_tile_mem(
		quantized["conv2.bias"], conv2Tile, weightWidth, conv2_bias_path)
	export_linear_weight_tile_mem(
		quantized["classifier.weight"], classifierTile, weightWidth, classifier_weight_path)
	export_bias_tile_mem(
		quantized["classifier.bias"], classifierTile, weightWidth, classifier_bias_path)
	export_txt(parameters, quantized, txt_path, checkpoint_path)

	conv1_weight_lines =(parameters["conv1.weight"].shape[0]//conv1Tile)*parameters["conv1.weight"].shape[1]*parameters["conv1.weight"].shape[2]*parameters["conv1.weight"].shape[3]
	conv1_bias_lines =parameters["conv1.bias"].shape[0]//conv1Tile
	conv2_weight_lines =(parameters["conv2.weight"].shape[0]//conv2Tile)*parameters["conv2.weight"].shape[1]*parameters["conv2.weight"].shape[2]*parameters["conv2.weight"].shape[3]
	conv2_bias_lines =parameters["conv2.bias"].shape[0]//conv2Tile
	classifier_weight_lines =(parameters["classifier.weight"].shape[0]//classifierTile)*parameters["classifier.weight"].shape[1]
	classifier_bias_lines =parameters["classifier.bias"].shape[0]//classifierTile

	print("Export done.")
	print(f"TXT : {txt_path.resolve()}")
	print(f"MEM : {conv1_weight_path.resolve()} ({conv1_weight_lines} lines)")
	print(f"MEM : {conv1_bias_path.resolve()} ({conv1_bias_lines} lines)")
	print(f"MEM : {conv2_weight_path.resolve()} ({conv2_weight_lines} lines)")
	print(f"MEM : {conv2_bias_path.resolve()} ({conv2_bias_lines} lines)")
	print(f"MEM : {classifier_weight_path.resolve()} ({classifier_weight_lines} lines)")
	print(f"MEM : {classifier_bias_path.resolve()} ({classifier_bias_lines} lines)")

def main()-> None:
	parser =argparse.ArgumentParser(
		description="Export fixed-point MNIST CNN parameters to tile-packed .mem files.")
	parser.add_argument("--model", default="MCDC_int8_Fixed.pt", help="Input checkpoint path")
	parser.add_argument("--out-dir", default="hex_weights", help="Output directory")
	parser.add_argument("--txt", default="MCDC_int8_Fixed.txt", help="Output text filename")
	args =parser.parse_args()
	export_from_checkpoint(Path(args.model), Path(args.out_dir), args.txt)

if __name__ == "__main__":
	main()