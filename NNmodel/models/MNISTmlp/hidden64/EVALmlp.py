import argparse
import torch
import torch.nn as nn
import torch.nn.functional as F
from torchvision import datasets, transforms

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

##############################
##     Function Prepare     ##
##############################
class RoundSTE(torch.autograd.Function):
	@staticmethod
	def forward(ctx, x):
		return torch.round(x)
	@staticmethod
	def backward(ctx, grad_output):
		return grad_output

def fake_quant_signed(x,num_bits,frac_bits):
	#symmetric signed fake quant
	#q =round(x*2^frac_bits), clipped to signed range
	#dq =q/2^frac_bits
	qmin = -(1<<(num_bits-1))
	qmax = (1<<(num_bits-1))-1
	scale = 1<<frac_bits
	q =RoundSTE.apply(x*scale)
	q =torch.clamp(q,qmin,qmax)
	dq =(q/scale)
	return dq

def fake_quant_unsigned(x,num_bits,frac_bits):
	#unsigned fake quant
	#q =round(x*2^frac_bits), clipped to unsigned range
	#dq =q/2^frac_bits
	qmin =0
	qmax = (1<<num_bits)-1
	scale = 1<<frac_bits
	q =RoundSTE.apply(x*scale)
	q =torch.clamp(q,qmin,qmax)
	dq =(q/scale)
	return dq

@torch.no_grad()
def quantize_signed_to_int(x,num_bits,frac_bits):
	qmin =-(1<<(num_bits-1))
	qmax = (1<<(num_bits-1))-1
	scale = 1<<frac_bits
	q =torch.round(x*scale)
	q =torch.clamp(q,qmin,qmax)
	return q.to(torch.int64)

@torch.no_grad()
def quantize_unsigned_to_int(x,num_bits,frac_bits):
	qmin =0
	qmax =(1<<num_bits)-1
	scale =1<<frac_bits
	q =torch.round(x*scale)
	q =torch.clamp(q,qmin,qmax)
	return q.to(torch.int64)

def round_shift_right_signed(x,shift):
	#signed rounding right shift for int tensors
	#round(x/2^shift)
	if shift ==0:
		return x
	if shift <0:
		return x<<(-shift)
	offset = 1<<(shift - 1)
	return torch.where(
		x >=0,
		(x+offset)>>shift,
		-(((-x)+offset)>>shift))

##############################
## Fixed-Point Aware Model  ##
##############################
class FixedPointMNISTMLP(nn.Module):
	def __init__(self):
		super().__init__()
		self.fc1 =nn.Linear(inNum,hidNum,bias=True)
		self.fc2 =nn.Linear(hidNum,outNum,bias=True)
	def forward(self, x):
		x_q =fake_quant_unsigned(x,inWidth,inFrac)
		w1_q =fake_quant_signed(self.fc1.weight,w1Width,w1Frac)
		b1_q =fake_quant_signed(self.fc1.bias,  b1Width,b1Frac)
		z1   =F.linear(x_q,w1_q,b1_q)
		h1   =F.relu(z1)
		h1_q =fake_quant_unsigned(h1,a1Width,a1Frac)
		w2_q =fake_quant_signed(self.fc2.weight,w2Width,w2Frac)
		b2_q =fake_quant_signed(self.fc2.bias,  b2Width,b2Frac)
		z2   =F.linear(h1_q,w2_q,b2_q)
		return z2
	
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

def load_model(model_path,device):
	model =FixedPointMNISTMLP().to(device)
	state_dict =load_state_dict_from_pth(model_path)
	model.load_state_dict(state_dict, strict=True)
	model.eval()
	return model

##############################
##          Dataset         ##
##############################
def make_test_loader(data_dir,batch_size):
	transform =transforms.Compose([transforms.ToTensor(), transforms.Lambda(lambda x: x.view(-1)),])
	test_dataset =datasets.MNIST(root=data_dir, train=False, download=True, transform=transform,)
	test_loader =torch.utils.data.DataLoader(test_dataset, batch_size=batch_size, shuffle=False,)
	return test_loader

##############################
##     float-path eval      ##
##############################
@torch.no_grad()
def evaluate_fake_quant(model,loader,device):
	model.eval()
	criterion =nn.CrossEntropyLoss()

	total =0
	correct =0
	loss_sum =0.0

	for x,y in loader:
		x =x.to(device)
		y =y.to(device)

		logits =model(x)
		loss =criterion(logits,y)
		pred =logits.argmax(dim=1)

		total +=y.size(0)
		correct +=(pred ==y).sum().item()
		loss_sum +=loss.item()*y.size(0)
	return (loss_sum/total),(correct/total)

##############################
##     integer  export      ##
##############################
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

##############################
##  integer-like inference  ##
##############################
@torch.no_grad()
def integer_like_forward_batch(x_float,qW1,qB1,qW2,qB2):
	"""
	x_float : [N,784] float in [0,1]
	qW1     : [128,784] int
	qB1     : [128] int, scale =2^-(inFrac+w1Frac)
	qW2     : [10,128] int
	qB2     : [10] int, scale =2^-(a1Frac+w2Frac)

	Returns:
		pred        : [N]
		x_int       : [N,784]
		acc1        : [N,128]  (before relu, scale=b1Frac)
		act1_int    : [N,128]  (requantized hidden activation, scale=a1Frac)
		acc2        : [N,10]   (final logits integer domain, scale=b2Frac)
	"""
	# input quantization
	x_int =quantize_unsigned_to_int(x_float.cpu(),inWidth,inFrac)
	# layer1 integer MAC
	acc1 =x_int@qW1.transpose(0,1)+qB1
	# relu in integer domain
	acc1_relu =torch.clamp(acc1,min=0)
	# requantize acc1_relu from scale 2^-b1Frac to 2^-a1Frac
	# act1_int ~= round(acc1_relu / 2^(b1Frac - a1Frac))
	shift1 =b1Frac-a1Frac
	act1_int =round_shift_right_signed(acc1_relu,shift1)
	# clamp hidden activation to unsigned activation format
	a1_qmax =(1<<a1Width)-1
	act1_int =torch.clamp(act1_int,0,a1_qmax)
	# layer2 integer MAC
	acc2 =act1_int@qW2.transpose(0,1)+qB2
	# argmax on integer logits
	pred =acc2.argmax(dim=1)
	return pred, x_int, acc1, act1_int, acc2

@torch.no_grad()
def evaluate_integer_like(model, loader):
	model.eval()
	qW1,qB1,qW2,qB2 =export_integer_params(model)
	total =0
	correct =0
	for x,y in loader:
		pred,_,_,_,_ =integer_like_forward_batch(x,qW1,qB1,qW2,qB2)
		total +=y.size(0)
		correct +=(pred ==y.cpu()).sum().item()
	return (correct/total)

def main():
	parser = argparse.ArgumentParser(description="Measure MNIST MLP inference accuracy from a trained .pth file.") #-help
	parser.add_argument("--model", default="mnistMLP64.pth", help="Input .pth model file. Default: mnistMLP64.pth",)
	parser.add_argument("--data-dir", default="../data", help="MNIST dataset directory. Default: ../data",)
	parser.add_argument("--batch-size", type=int, default=128, help="Test batch size. Default: 128",)
	parser.add_argument("--mode", choices=["both", "fakeq", "int"], default="both", help="Evaluation mode. Default: both",)
	parser.add_argument("--device", choices=["auto", "cpu", "cuda"], default="auto", help="Device for fake-quant evaluation. Integer-like evaluation uses CPU. Default: auto",)
	
	args = parser.parse_args()
	
	if args.device =="auto":
		device = "cuda" if torch.cuda.is_available() else "cpu"
	else:
		device =args.device
	if device == "cuda" and not torch.cuda.is_available():
		raise RuntimeError("CUDA was requested, but torch.cuda.is_available() is False.")

	print("========================================")
	print("MNIST MLP inference accuracy evaluation")
	print("========================================")
	print(f"model      : {args.model}")
	print(f"data_dir   : {args.data_dir}")
	print(f"batch_size : {args.batch_size}")
	print(f"mode       : {args.mode}")
	print(f"device     : {device}")
	print("")

	test_loader =make_test_loader(args.data_dir,args.batch_size)
	model =load_model(args.model,device)

	if args.mode in ["both", "fakeq"]:
		fakeq_loss,fakeq_acc =evaluate_fake_quant(model,test_loader,device)
		print("[Fake-quant floating-path]")
		print(f"  loss     : {fakeq_loss:.6f}")
		print(f"  accuracy : {fakeq_acc * 100:.2f}%")
		print("")

	if args.mode in ["both", "int"]:
		# Move model to CPU before integer-like evaluation.
		model_cpu =model.to("cpu")
		int_acc =evaluate_integer_like(model_cpu,test_loader)
		print("[Integer-like inference]")
		print(f"  accuracy : {int_acc * 100:.2f}%")
		print("")

if __name__ == "__main__":
	main()