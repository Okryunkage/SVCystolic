import argparse
import struct
import time
import torch
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
import serial

SOF =b"\xAA\x55"
#Start Of Frame
#if UART reciever receive 0xAA then 0x55, it can recognize packet start
VERSION =1
FLAG_INCLUDE_LABEL =0x01
#if 0x01, label is sent.
HEADER_STRUCT =struct.Struct("<BBIHHI")
# Packet header, little-endian:
# version      : uint8
# flags        : uint8
# batch_id     : uint32
# batch_size   : uint16
# vector_len   : uint16
# payload_len  : uint32

def quantize_mnist_u8(images:torch.Tensor)->torch.Tensor:
	#input : torch.Tensor type
	#output: torch.Tensor type
	#output type written after arrow is just a hint, not forced.
	q =torch.round(images*255.0)
	q =torch.clamp(q,0,255).to(torch.uint8)
	return q.view(q.size(0),-1).contiguous()

def make_packet(
		image_matrix_u8: torch.Tensor,
		labels: torch.Tensor,
		batch_id: int,
		include_label: bool,)->bytes:
	if image_matrix_u8.dtype != torch.uint8:
		raise ValueError("image_matrix_u8 must be torch.uint8")
	batch_size,vector_len = image_matrix_u8.shape
	image_payload =image_matrix_u8.cpu().numpy().tobytes(order="C")
	flags =0
	payload =image_payload
	if include_label:
		flag |=FLAG_INCLUDE_LABEL
		label_payload =labels.to(torch.uint8).cpu().numpy().tobytes(order="C")
		payload +=label_payload
	header =HEADER_STRUCT.pack(VERSION,flags,batch_id,batch_size,vector_len,len(payload))

	checksum =(sum(header)+sum(payload))&0xFF
	packet =SOF+header+payload+bytes([checksum])
	return packet

def wait_ack(ser:serial.Serial, timeout_msg:str="ACLK timeout"):
	ack =ser.read(1)
	if ack !=b"\x06":
		if len(ack)==0:
			raise TimeoutError(timeout_msg)
		raise RuntimeError(f"Expected ACK 0x06, got 0x{ack.hex()}")
	
def main():
	parser =argparse.ArgumentParser(description="send quantized MNIST batches to FPGA through UART")
    parser.add_argument("--port", required=True, help="UART port, e.g. COM4 or /dev/ttyUSB0")
    parser.add_argument("--baud", type=int, default=1_000_000, help="UART baud rate")
    parser.add_argument("--batch-size", type=int, default=16, help="Number of images per packet")
    parser.add_argument("--num-batches", type=int, default=1, help="Number of batches to send")
    parser.add_argument("--split", choices=["train", "test"], default="test")
    parser.add_argument("--data-dir", default="./data")
    parser.add_argument("--include-label", action="store_true", help="Append labels after image payload")
    parser.add_argument("--drop-last", action="store_true", help="Only send full batches")
    parser.add_argument("--shuffle", action="store_true")
    parser.add_argument("--ack", action="store_true", help="Wait for 0x06 ACK after each packet")
    parser.add_argument("--timeout", type=float, default=2.0, help="UART read timeout in seconds")
    parser.add_argument("--delay-ms", type=float, default=0.0, help="Delay after each packet")
    parser.add_argument("--rtscts", action="store_true", help="Enable RTS/CTS hardware flow control")

	args =parser.parse_args()
	tramsform = tramsform.ToTensor()
