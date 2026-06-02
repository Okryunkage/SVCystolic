import argparse
import subprocess
import sys
import time

def run_cmd(cmd):
	print("\n[RUN]", " ".join(cmd))
	result =subprocess.run(cmd)
	if result.returncode !=0:
		print("[ERROR] Command failed.")
		sys.exit(result.returncode)
	print("[DONE]")

def main():
	parser =argparse.ArgumentParser()
	parser.add_argument("--port", default="COM7")
	parser.add_argument("--baud", type=int, default=1000000)
	parser.add_argument("--delay-ms", type=int, default=100)
	parser.add_argument("--batch-size", type=int, default=1000)
	parser.add_argument("--num-batches", type=int, default=1)
	parser.add_argument("--split", default="test")
	parser.add_argument("--no-shuffle", action="store_true")
	parser.add_argument("--no-label", action="store_true")
	
	args = parser.parse_args()
	python = sys.executable

	common_uart =[
		"--port", args.port,
		"--baud", str(args.baud),
		"--delay-ms", str(args.delay_ms),]

	param_commands =[
		[
			python, "paramUART.py",
			*common_uart,
			"--mem", "fc1_w_tile.mem",
			"--layer-id", "1",
			"--param-type", "weight",
			"--bit-width", "8",
			"--signed",],
		[
			python, "paramUART.py",
			*common_uart,
			"--mem", "fc1_b_tile.mem",
			"--layer-id", "1",
			"--param-type", "bias",
			"--bit-width", "32",
			"--signed",],
		[
			python, "paramUART.py",
			*common_uart,
			"--mem", "fc2_w_tile.mem",
			"--layer-id", "2",
			"--param-type", "weight",
			"--bit-width", "8",
			"--signed",],
		[
			python, "paramUART.py",
			*common_uart,
			"--mem", "fc2_b_tile.mem",
			"--layer-id", "2",
			"--param-type", "bias",
			"--bit-width", "32",
			"--signed",],]
	
	input_command =[
		python, "inputUARTmatrix.py",
		*common_uart,
		"--batch-size", str(args.batch_size),
		"--num-batches", str(args.num_batches),
		"--split", args.split,
		"--drop-last",]

	if not args.no_label:
		input_command.append("--include-label")

	if not args.no_shuffle:
		input_command.append("--shuffle")

	print("===================================")
	print("UART full transmission start")
	print("===================================")

	for cmd in param_commands:
		run_cmd(cmd)
		time.sleep(args.delay_ms / 1000.0)

	run_cmd(input_command)

	print("\n===================================")
	print("All transmissions completed")
	print("===================================")

if __name__ == "__main__":
	main()