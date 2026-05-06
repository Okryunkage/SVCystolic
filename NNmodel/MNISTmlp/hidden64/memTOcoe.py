'''
def mem_to_coe(mem_path, coe_path):
	with open(mem_path, "r", encoding="utf-8") as f:
		lines = [line.strip() for line in f if line.strip()]

	with open(coe_path, "w", encoding="utf-8") as f:
		f.write("memory_initialization_radix=16;\n")
		f.write("memory_initialization_vector=\n")

		for i, line in enumerate(lines):
			if i == len(lines) - 1:
				f.write(line + ";\n")
			else:
				f.write(line + ",\n")

mem_to_coe("fc1_w_tile.mem", "fc1_w_tile.coe")
mem_to_coe("fc1_b_tile.mem", "fc1_b_tile.coe")
mem_to_coe("fc2_w_tile.mem", "fc2_w_tile.coe")
mem_to_coe("fc2_b_tile.mem", "fc2_b_tile.coe")
'''
from pathlib import Path
def memTOcoe(memPath,coePath):
	memPath =Path(memPath)
	coePath =Path(coePath)
	with open(memPath,"r",encoding="utf-8") as f:
		lines =[line.strip() for line in f if line.strip()]
	with open(coePath,"w",encoding="utf-8") as f:
		f.write("memory_initialization_radix=16;\n")
		f.write("memory_initialization_vector=\n")
		for i,line in enumerate(lines):
			if i==len(lines)-1:
				f.write(line+";\n")
			else:
				f.write(line+",\n")
memTOcoe("fc1_w_tile.mem","fc1_w_tile.coe")
memTOcoe("fc2_w_tile.mem","fc2_w_tile.coe")
memTOcoe("fc1_b_tile.mem","fc1_b_tile.coe")
memTOcoe("fc2_b_tile.mem","fc2_b_tile.coe")