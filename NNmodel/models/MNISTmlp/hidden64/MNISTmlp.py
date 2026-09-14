import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
from torchvision import datasets, transforms

##############################
##          Config          ##
##############################
DEVICE ="cuda" if torch.cuda.is_available() else "cpu"
SEED = 0
torch.manual_seed(SEED)

batchSize =128
epochNum  =10
learnRate =1e-3

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

modelPath  ="mnistMLP64.pth"
txtPath   ="mnistMLP64.txt"
vhPath    ="../mnistMLP64.vh"

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
##          Dataset         ##
##############################
transform =transforms.Compose([
	transforms.ToTensor(),
	transforms.Lambda(lambda x: x.view(-1))])
train_dataset =datasets.MNIST(root="../data", train=True, download=True, transform=transform)
test_dataset =datasets.MNIST(root="../data", train=False, download=True, transform=transform)
train_loader =torch.utils.data.DataLoader(train_dataset, batch_size=batchSize, shuffle=True)
test_loader =torch.utils.data.DataLoader(test_dataset, batch_size=batchSize, shuffle=False)

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

##############################
##     float-path eval      ##
##############################
@torch.no_grad()
def evaluate_fake_quant(model,loader):
	model.eval()
	criterion =nn.CrossEntropyLoss()

	total =0
	correct =0
	loss_sum =0.0

	for x,y in loader:
		x =x.to(DEVICE)
		y =y.to(DEVICE)

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

##############################
##           Train          ##
##############################
def train():
	model =FixedPointMNISTMLP().to(DEVICE)
	optimizer =optim.Adam(model.parameters(),lr=learnRate)
	criterion =nn.CrossEntropyLoss()

	for epoch in range(0,epochNum):
		model.train()

		total =0
		correct =0
		loss_sum =0.0

		for x,y in train_loader:
			x =x.to(DEVICE)
			y =y.to(DEVICE)

			logits =model(x)
			loss =criterion(logits,y)

			optimizer.zero_grad()
			loss.backward()
			optimizer.step()

			pred =logits.argmax(dim=1)
			total +=y.size(0)
			correct +=(pred==y).sum().item()
			loss_sum +=loss.item()*y.size(0)

		train_loss =loss_sum/total
		train_acc =correct/total

		test_loss,test_acc_fake =evaluate_fake_quant(model,test_loader)
		test_acc_int =evaluate_integer_like(model,test_loader)

		print(
			f"Epoch {epoch:2d} | "
			f"train_loss={train_loss:.4f}, train_acc={train_acc*100:.2f}% | "
			f"test_loss={test_loss:.4f}, "
			f"fakeQ_acc={test_acc_fake*100:.2f}% | "
			f"intLike_acc={test_acc_int*100:.2f}%")

	torch.save(model.state_dict(),modelPath)
	print(f"Saved model to: {modelPath}")
	return model

##############################
##     debug one sample     ##
##############################
@torch.no_grad()
def debug_one_sample(model,dataset,idx=0):
	qW1,qB1,qW2,qB2 =export_integer_params(model)

	x,y =dataset[idx]
	#unsqueeze to make a batch size of 1
	x_batch =x.unsqueeze(0)

	pred,x_int,acc1,act1_int,acc2 =integer_like_forward_batch(x_batch, qW1, qB1, qW2, qB2)

	print(f"\n[DEBUG sample index={idx}]")
	print(f"label     = {y}")
	print(f"pred      = {pred.item()}")
	print(f"x_int[:32]= {x_int[0, :32].tolist()}")
	print(f"acc1[:16] = {acc1[0, :16].tolist()}")
	print(f"act1[:16] = {act1_int[0, :16].tolist()}")
	print(f"acc2      = {acc2[0].tolist()}")

##############################
##     output Parameters    ##
##############################
def twos_hex(v,width):
	#function to convert integer v to verilog format hexadecimal literal char
	mask =(1<<width)-1
	x =int(v)&mask
	hex_digits=(width+3)//4
	return f"{width}'h{x:0{hex_digits}X}"

def flatten_row_major(mat_2d):
	#function to convert 2d array/list into row-major order 1d list
	out =[]
	for row in mat_2d:
		out.extend(row)
	return out

	##############################
	##         MEM OUT          ##
	##############################
FC1_W_TILE_MEM = "fc1_w_tile.mem"
FC1_B_TILE_MEM = "fc1_b_tile.mem"
FC2_W_TILE_MEM = "fc2_w_tile.mem"
FC2_B_TILE_MEM = "fc2_b_tile.mem"

FC1_TILE = 8
FC2_TILE = 5

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

@torch.no_grad()
def export_files(model):
	qW1,qB1,qW2,qB2 =export_integer_params(model)

	# text
	with open(txtPath, "w", encoding="utf-8") as f:
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

	print(f"Saved text params to: {txtPath}")

	# vh
	fc1_w = flatten_row_major(qW1.tolist())
	fc1_b = qB1.tolist()
	fc2_w = flatten_row_major(qW2.tolist())
	fc2_b = qB2.tolist()

	fc1_ww = len(fc1_w) * w1Width
	fc1_bw = len(fc1_b) * b1Width
	fc2_ww = len(fc2_w) * w2Width
	fc2_bw = len(fc2_b) * b2Width

	elems_fc1_w = ", ".join(twos_hex(v, w1Width) for v in reversed(fc1_w))
	elems_fc1_b = ", ".join(twos_hex(v, b1Width) for v in reversed(fc1_b))
	elems_fc2_w = ", ".join(twos_hex(v, w2Width) for v in reversed(fc2_w))
	elems_fc2_b = ", ".join(twos_hex(v, b2Width) for v in reversed(fc2_b))

	lines = []
	lines.append("// Auto-generated fixed-point parameters for Verilog")
	lines.append("")
	lines.append(f"localparam integer inNum_file  ={inNum};")
	lines.append(f"localparam integer hidNum_file ={hidNum};")
	lines.append(f"localparam integer outNum_file ={outNum};")
	lines.append("")
	lines.append(f"localparam integer inWidth_file ={inWidth};")
	lines.append(f"localparam integer inFrac_file  ={inFrac};")
	lines.append(f"localparam integer w1Width_file ={w1Width};")
	lines.append(f"localparam integer w1Frac_file  ={w1Frac};")
	lines.append(f"localparam integer b1Width_file ={b1Width};")
	lines.append(f"localparam integer b1Frac_file  ={b1Frac};")
	lines.append(f"localparam integer a1Width_file ={a1Width};")
	lines.append(f"localparam integer a1Frac_file  ={a1Frac};")
	lines.append(f"localparam integer w2Width_file ={w2Width};")
	lines.append(f"localparam integer w2Frac_file  ={w2Frac};")
	lines.append(f"localparam integer b2Width_file ={b2Width};")
	lines.append(f"localparam integer b2Frac_file  ={b2Frac};")
	lines.append("")
	lines.append(f"localparam integer FC1_WW ={fc1_ww};")
	lines.append(f"localparam integer FC1_BW ={fc1_bw};")
	lines.append(f"localparam integer FC2_WW ={fc2_ww};")
	lines.append(f"localparam integer FC2_BW ={fc2_bw};")
	lines.append("")
	lines.append(f"localparam [FC1_WW-1:0] fc1_w_flat ={{ {elems_fc1_w} }};")
	lines.append(f"localparam [FC1_BW-1:0] fc1_b_flat ={{ {elems_fc1_b} }};")
	lines.append(f"localparam [FC2_WW-1:0] fc2_w_flat ={{ {elems_fc2_w} }};")
	lines.append(f"localparam [FC2_BW-1:0] fc2_b_flat ={{ {elems_fc2_b} }};")
	lines.append("")

	with open(vhPath, "w", encoding="utf-8") as f:
		f.write("\n".join(lines))

	print(f"Saved Verilog header to: {vhPath}")
	# tile-packed mem export for BRAM-based sequential FC
	export_fc_weight_tile_mem(qW1, tile=FC1_TILE, elem_bits=w1Width, path=FC1_W_TILE_MEM)
	export_fc_bias_tile_mem  (qB1, tile=FC1_TILE, elem_bits=b1Width, path=FC1_B_TILE_MEM)

	export_fc_weight_tile_mem(qW2, tile=FC2_TILE, elem_bits=w2Width, path=FC2_W_TILE_MEM)
	export_fc_bias_tile_mem  (qB2, tile=FC2_TILE, elem_bits=b2Width, path=FC2_B_TILE_MEM)

	print(f"Saved tile mem files: {FC1_W_TILE_MEM}, {FC1_B_TILE_MEM}, {FC2_W_TILE_MEM}, {FC2_B_TILE_MEM}")

##############################
##           Main           ##
##############################
if __name__ == "__main__":
	model = train()

	test_loss,test_acc_fake =evaluate_fake_quant(model,test_loader)
	test_acc_int =evaluate_integer_like(model,test_loader)

	print("\nFinal Results")
	print(f"Fake-quant test accuracy   : {test_acc_fake*100:.2f}%")
	print(f"Integer-like test accuracy : {test_acc_int*100:.2f}%")

	debug_one_sample(model, test_dataset, idx=0)
	#export_files(model)