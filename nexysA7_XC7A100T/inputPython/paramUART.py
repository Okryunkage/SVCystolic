import argparse
import re
#The re library is used for regular expressioin matching
#It helps find, check, split, or replace strings based on patterns
import struct
import time
import serial

SOF =b"\xAA\x55"
VERSION =1
PACKET_TYPE_PARAM =0x02
PARAM_TYPE_WEIGHT =0x00
PARAM_TYPE_BIAS   =0x01
FLAG_SIGNED =0x01
#Parameter packet header, little-endian:
#version     : uint8
#packet_type : uint8
#flags       : uint8
#layer_id    : uint8
#param_type  : uint8
#bit_width   : uint16
#elem_count  : uint32
#payload_len : uint32
PARAM_HEADER_STRUCT =struct.Struct("<BBBBBHII")


def parse_int_token(token:str)->int:
	#got potential issue recognizing HEX if there's no alphabet digit in line.
	"""
	Parse one value from a .mem file.
	Supported examples:
		FF
		0xFF
		8'hFF
		32'hFFFF_FFFF
		-3
		127
	"""
	token =token.strip()
	#remove space
	token =token.replace("_","")
	#remove underscore
	if not token:
		raise ValueError("empty token")
	# Verilog-style literal, e.g. 8'hFF or 32'd123
	m =re.match(r"^\d+'([hHdDbB])([0-9a-fA-FxXzZ]+)$", token)
	if m:
		base_char =m.group(1).lower()
		value_str =m.group(2)
		# For memory files, x/z are not valid real values.
		if "x" in value_str.lower() or "z" in value_str.lower():
			raise ValueError(f"Unsupported x/z value in token: {token}")
		if base_char =="h":
			return int(value_str,16)
		if base_char =="d":
			return int(value_str,10)
		if base_char =="b":
			return int(value_str,2)
	# 0x-prefixed hex
	if token.lower().startswith("0x"):
		return int(token,16)
	# Negative or positive decimal
	if re.match(r"^[+-]?\d+$", token):
		return int(token,10)
	# Bare hex, e.g. FF, 7A, fffffffe
	if re.match(r"^[0-9a-fA-F]+$", token):
		return int(token, 16)
	raise ValueError(f"Cannot parse token: {token}")
'''
def read_mem_values(mem_path: str)->list[int]:
	"""
	Read a .mem file and return integer values.
	Supported format:
		- one value per line
		- multiple values per line
		- comments using // or #
		- @address tokens are ignored
	"""
	values =[]
	with open(mem_path, "r", encoding="utf-8") as f:
		for line_no, line in enumerate(f, start=1):
			# Remove comments
			line =line.split("//",1)[0]
			line =line.split("#",1)[0]
			line =line.strip()
			if not line:
				continue
			tokens =line.split()
			for token in tokens:
				# Ignore Verilog memory address markers, e.g. @0000
				if token.startswith("@"):
					continue
				try:
					values.append(parse_int_token(token))
				except ValueError as e:
					raise ValueError(f"{mem_path}:{line_no}: {e}") from e
	return values
'''
def read_mem_values_fixed_hex(mem_path: str, bit_width: int)->list[int]:
	values = []
	hex_digits_per_elem = (bit_width+3)//4
	with open(mem_path, "r", encoding="utf-8") as f:
		for line_no, line in enumerate(f, start=1):
			line = line.split("//", 1)[0]
			line = line.split("#", 1)[0]
			line = line.strip().replace("_", "")
			if not line:
				continue
			tokens = line.split()
			for token in tokens:
				if token.startswith("@"):
					continue
				#If this is a long bare-hex token, split it into fixed-width chunks.
				'''
				if re.fullmatch(r"[0-9a-fA-F]+", token) and (len(token)>hex_digits_per_elem):
					if (len(token)%hex_digits_per_elem) !=0:
						raise ValueError(f"{mem_path}:{line_no}: hex string length is not aligned to {bit_width}-bit elements")
					for i in range(0, len(token), hex_digits_per_elem):
						chunk = token[i:i+hex_digits_per_elem]
						values.append(int(chunk, 16))
				else:
					values.append(parse_int_token(token))
				'''
				if re.fullmatch(r"[0-9a-fA-F]+", token):
					if (len(token)%hex_digits_per_elem) !=0:
						raise ValueError(
							f"{mem_path}:{line_no}: hex string length is not aligned to "
							f"{bit_width}-bit elements")
					for i in range(0, len(token), hex_digits_per_elem):
						chunk =token[i:i+hex_digits_per_elem]
						values.append(int(chunk, 16))
				else:
					values.append(parse_int_token(token))
	return values

def value_to_bytes(value: int, bit_width: int, signed_value: bool) -> bytes:
	"""
	Convert one parameter value into little-endian bytes.
	Each element is byte-aligned:
		bit_width <=8   -> 1 byte
		bit_width <=16  -> 2 bytes
		bit_width <=32  -> 4 bytes
	Negative signed values are converted to two's complement.
	"""
	if bit_width <=0:
		raise ValueError("bit_width must be positive")
	bytes_per_elem =(bit_width+7)//8
	mask =(1<<bit_width) -1

	if signed_value and (value<0):
		value =(1<<bit_width) +value

	if (value<0) or (value>mask):
		raise ValueError(f"value {value} does not fit in {bit_width} bits")
	
	raw_value =value&mask
	return raw_value.to_bytes(bytes_per_elem, byteorder="little", signed=False)

def make_param_payload(values: list[int], bit_width: int, signed_value: bool)->bytes:
	payload =bytearray()
	for v in values:
		payload +=value_to_bytes(v,bit_width,signed_value)
	return bytes(payload)

def make_param_packet(
	values: list[int],
	layer_id: int,
	param_type: int,
	bit_width: int,
	signed_value: bool,)->bytes:

	flags =0

	if signed_value:
		flags |=FLAG_SIGNED

	payload =make_param_payload(
		values=values,
		bit_width=bit_width,
		signed_value=signed_value,)

	elem_count =len(values)
	payload_len =len(payload)

	header =PARAM_HEADER_STRUCT.pack(
		VERSION,
		PACKET_TYPE_PARAM,
		flags,
		layer_id,
		param_type,
		bit_width,
		elem_count,
		payload_len,)
	#Checksum is calculated over HEADER + PAYLOAD only.
	#SOF and checksum byte itself are not included.
	checksum =(sum(header) + sum(payload)) & 0xFF
	packet =SOF+header+payload+bytes([checksum])
	return packet

def wait_ack(ser: serial.Serial, timeout_msg: str ="ACK timeout"):
	ack =ser.read(1)
	if ack !=b"\x06":
		if len(ack) ==0:
			raise TimeoutError(timeout_msg)
		raise RuntimeError(f"Expected ACK 0x06, got 0x{ack.hex()}")

def parse_param_type(name: str) -> int:
	name =name.lower()
	if name =="weight":
		return PARAM_TYPE_WEIGHT
	if name =="bias":
		return PARAM_TYPE_BIAS
	raise ValueError(f"Unknown param type: {name}")

def main():
	parser =argparse.ArgumentParser(description="Send neural-network parameters from a .mem file to FPGA through UART")
	parser.add_argument("--port", required=True, help="UART port, e.g. COM4 or /dev/ttyUSB0")
	parser.add_argument("--baud", type=int, default=1_000_000, help="UART baud rate")
	parser.add_argument("--timeout", type=float, default=2.0, help="UART read timeout in seconds")
	parser.add_argument("--rtscts", action="store_true", help="Enable RTS/CTS hardware flow control")
	parser.add_argument("--mem", required=True, help="Input .mem file")
	parser.add_argument("--layer-id", type=int, required=True, help="Layer ID, e.g. 1 for fc1, 2 for fc2")
	parser.add_argument("--param-type", choices=["weight", "bias"], required=True)
	parser.add_argument("--bit-width", type=int, required=True, help="Bit width of each parameter element")
	parser.add_argument("--signed", action="store_true", help="Treat values as signed two's-complement parameters")
	parser.add_argument("--ack", action="store_true", help="Wait for 0x06 ACK after sending the packet")
	parser.add_argument("--delay-ms", type=float, default=0.0, help="Delay after sending packet")

	args =parser.parse_args()

	if not (0 <=args.layer_id <=255):
		raise ValueError("layer_id must fit in uint8")

	param_type =parse_param_type(args.param_type)

	#values =read_mem_values(args.mem)
	values =read_mem_values_fixed_hex(args.mem,args.bit_width)

	packet =make_param_packet(
		values=values,
		layer_id=args.layer_id,
		param_type=param_type,
		bit_width=args.bit_width,
		signed_value=args.signed,
	)

	bytes_per_elem =(args.bit_width+7)//8
	payload_len =len(values)*bytes_per_elem

	print("Parameter packet info:")
	print(f"  mem file       : {args.mem}")
	print(f"  layer_id       : {args.layer_id}")
	print(f"  param_type     : {args.param_type}")
	print(f"  bit_width      : {args.bit_width}")
	print(f"  signed         : {args.signed}")
	print(f"  elem_count     : {len(values)}")
	print(f"  bytes_per_elem : {bytes_per_elem}")
	print(f"  payload_len    : {payload_len}")
	print(f"  packet_len     : {len(packet)}")

	ser =serial.Serial(
		port=args.port,
		baudrate=args.baud,
		timeout=args.timeout,
		rtscts=args.rtscts,
	)

	try:
		ser.write(packet)
		ser.flush()
		if args.ack:
			wait_ack(ser)
		if args.delay_ms>0:
			time.sleep(args.delay_ms/1000.0)
		print("Parameter packet sent successfully.")
	finally:
		ser.close()

if __name__ =="__main__":
	main()