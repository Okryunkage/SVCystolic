import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
from torchvision import datasets, transforms

##############################
##          Config          ##
##############################
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
SEED = 0
torch.manual_seed(SEED)
if torch.cuda.is_available():
	torch.cuda.manual_seed_all(SEED)

batchSize = 128
epochNum  = 10
learnRate = 1e-3

inNum   = 784
hidNum  = 64
outNum  = 10

# All MAC inputs to SA are signed int8.
# MNIST pixel is exported/trained as:
#   x_s8 = pixel_u8 - 128       -> [-128, 127]
#   x_real = x_s8 / 2^inFrac
inWidth = 8
inFrac  = 8

w1Width = 8
w1Frac  = 6
b1Width = 32
b1Frac  = inFrac + w1Frac

# Hidden activation is ReLU, but stored in signed int8-safe range 0~127.
# This makes fc2 input compatible with signed int8 SA.
a1Width = 8
a1Frac  = 4

w2Width = 8
w2Frac  = 6
b2Width = 32
b2Frac  = a1Frac + w2Frac

modelPath = "mnistMLP64.pth"

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


def fake_quant_signed(x, num_bits, frac_bits):
	# Symmetric signed fake quant.
	# q  = round(x * 2^frac_bits), clipped to signed range
	# dq = q / 2^frac_bits
	qmin = -(1 << (num_bits - 1))
	qmax =  (1 << (num_bits - 1)) - 1
	scale = 1 << frac_bits
	q = RoundSTE.apply(x * scale)
	q = torch.clamp(q, qmin, qmax)
	dq = q / scale
	return dq


def fake_quant_mnist_input_signed_s8(x):
	"""
	Quantize MNIST input exactly as the hardware input memory should store it.

	Input x is torchvision ToTensor output in [0,1].
	First recover pixel_u8 approximately by round(x*255), then convert to signed:
	  pixel_s8 = pixel_u8 - 128
	The real value used during QAT is pixel_s8 / 2^inFrac.
	"""
	q_u8 = RoundSTE.apply(x * 255.0)
	q_u8 = torch.clamp(q_u8, 0, 255)
	q_s8 = q_u8 - 128
	q_s8 = torch.clamp(q_s8, -128, 127)
	return q_s8 / float(1 << inFrac)


def fake_quant_relu_signed_s8(x, num_bits, frac_bits):
	"""
	ReLU activation quantized into signed-int8-safe positive range.
	For num_bits=8, output integer range is 0~127, not 0~255.
	"""
	qmin = 0
	qmax = (1 << (num_bits - 1)) - 1
	scale = 1 << frac_bits
	x_relu = F.relu(x)
	q = RoundSTE.apply(x_relu * scale)
	q = torch.clamp(q, qmin, qmax)
	return q / scale


@torch.no_grad()
def quantize_signed_to_int(x, num_bits, frac_bits):
	qmin = -(1 << (num_bits - 1))
	qmax =  (1 << (num_bits - 1)) - 1
	scale = 1 << frac_bits
	q = torch.round(x * scale)
	q = torch.clamp(q, qmin, qmax)
	return q.to(torch.int64)


@torch.no_grad()
def quantize_mnist_input_signed_s8_to_int(x_float):
	"""
	x_float: [N,784] in [0,1]
	return : signed int8 integer tensor in [-128,127]
			 exact hardware byte should be int_value & 0xff.
	"""
	q_u8 = torch.round(x_float.cpu() * 255.0)
	q_u8 = torch.clamp(q_u8, 0, 255)
	q_s8 = q_u8.to(torch.int64) - 128
	q_s8 = torch.clamp(q_s8, -128, 127)
	return q_s8.to(torch.int64)


def round_shift_right_signed(x, shift):
	# Signed rounding right shift for int tensors.
	# round(x / 2^shift), symmetric around zero.
	if shift == 0:
		return x
	if shift < 0:
		return x << (-shift)
	offset = 1 << (shift - 1)
	return torch.where(
		x >= 0,
		(x + offset) >> shift,
		-(((-x) + offset) >> shift)
	)

##############################
##          Dataset         ##
##############################
transform = transforms.Compose([
	transforms.ToTensor(),
	transforms.Lambda(lambda x: x.view(-1))
])
train_dataset = datasets.MNIST(root="../data", train=True,  download=True, transform=transform)
test_dataset  = datasets.MNIST(root="../data", train=False, download=True, transform=transform)
train_loader = torch.utils.data.DataLoader(train_dataset, batch_size=batchSize, shuffle=True)
test_loader  = torch.utils.data.DataLoader(test_dataset,  batch_size=batchSize, shuffle=False)

##############################
## Fixed-Point Aware Model  ##
##############################
class FixedPointMNISTMLP(nn.Module):
	def __init__(self):
		super().__init__()
		self.fc1 = nn.Linear(inNum, hidNum, bias=True)
		self.fc2 = nn.Linear(hidNum, outNum, bias=True)

	def forward(self, x):
		# signed int8 input: pixel_s8 = pixel_u8 - 128
		x_q = fake_quant_mnist_input_signed_s8(x)

		w1_q = fake_quant_signed(self.fc1.weight, w1Width, w1Frac)
		b1_q = fake_quant_signed(self.fc1.bias,   b1Width, b1Frac)
		z1   = F.linear(x_q, w1_q, b1_q)

		# ReLU activation, then signed-int8-safe positive quantization: 0~127
		h1_q = fake_quant_relu_signed_s8(z1, a1Width, a1Frac)

		w2_q = fake_quant_signed(self.fc2.weight, w2Width, w2Frac)
		b2_q = fake_quant_signed(self.fc2.bias,   b2Width, b2Frac)
		z2   = F.linear(h1_q, w2_q, b2_q)
		return z2

##############################
##     float-path eval      ##
##############################
@torch.no_grad()
def evaluate_fake_quant(model, loader):
	model.eval()
	criterion = nn.CrossEntropyLoss()

	total = 0
	correct = 0
	loss_sum = 0.0

	for x, y in loader:
		x = x.to(DEVICE)
		y = y.to(DEVICE)

		logits = model(x)
		loss = criterion(logits, y)
		pred = logits.argmax(dim=1)

		total += y.size(0)
		correct += (pred == y).sum().item()
		loss_sum += loss.item() * y.size(0)

	return (loss_sum / total), (correct / total)

##############################
##     integer  export      ##
##############################
@torch.no_grad()
def export_integer_params(model):
	qW1 = quantize_signed_to_int(model.fc1.weight.cpu(), w1Width, w1Frac)
	qB1 = quantize_signed_to_int(model.fc1.bias.cpu(),   b1Width, b1Frac)
	qW2 = quantize_signed_to_int(model.fc2.weight.cpu(), w2Width, w2Frac)
	qB2 = quantize_signed_to_int(model.fc2.bias.cpu(),   b2Width, b2Frac)
	return qW1, qB1, qW2, qB2

##############################
##  integer-like inference  ##
##############################
@torch.no_grad()
def integer_like_forward_batch(x_float, qW1, qB1, qW2, qB2):
	"""
	x_float : [N,784] float in [0,1]
	qW1     : [64,784] signed int8, scale=2^-w1Frac
	qB1     : [64] signed int32, scale=2^-(inFrac+w1Frac)
	qW2     : [10,64] signed int8, scale=2^-w2Frac
	qB2     : [10] signed int32, scale=2^-(a1Frac+w2Frac)

	Returns:
		pred        : [N]
		x_int       : [N,784], signed int8 integer [-128,127]
		acc1        : [N,64],  scale=b1Frac
		act1_int    : [N,64],  signed-int8-safe ReLU activation integer [0,127]
		acc2        : [N,10],  scale=b2Frac
	"""
	# input quantization: pixel_s8 = pixel_u8 - 128
	x_int = quantize_mnist_input_signed_s8_to_int(x_float)

	# layer1 integer MAC: signed int8 input * signed int8 weight
	acc1 = x_int @ qW1.transpose(0, 1) + qB1

	# ReLU in integer domain
	acc1_relu = torch.clamp(acc1, min=0)

	# requantize acc1_relu from scale 2^-b1Frac to 2^-a1Frac
	shift1 = b1Frac - a1Frac
	act1_int = round_shift_right_signed(acc1_relu, shift1)

	# fc2 input must be signed int8-safe, so positive range is 0~127.
	a1_qmax = (1 << (a1Width - 1)) - 1
	act1_int = torch.clamp(act1_int, 0, a1_qmax)

	# layer2 integer MAC: signed int8 activation * signed int8 weight
	acc2 = act1_int @ qW2.transpose(0, 1) + qB2
	pred = acc2.argmax(dim=1)
	return pred, x_int, acc1, act1_int, acc2


@torch.no_grad()
def evaluate_integer_like(model, loader):
	model.eval()
	qW1, qB1, qW2, qB2 = export_integer_params(model)
	total = 0
	correct = 0
	for x, y in loader:
		pred, _, _, _, _ = integer_like_forward_batch(x, qW1, qB1, qW2, qB2)
		total += y.size(0)
		correct += (pred == y.cpu()).sum().item()
	return correct / total

##############################
##           Train          ##
##############################
def train():
	model = FixedPointMNISTMLP().to(DEVICE)
	optimizer = optim.Adam(model.parameters(), lr=learnRate)
	criterion = nn.CrossEntropyLoss()

	for epoch in range(0, epochNum):
		model.train()

		total = 0
		correct = 0
		loss_sum = 0.0

		for x, y in train_loader:
			x = x.to(DEVICE)
			y = y.to(DEVICE)

			logits = model(x)
			loss = criterion(logits, y)

			optimizer.zero_grad()
			loss.backward()
			optimizer.step()

			pred = logits.argmax(dim=1)
			total += y.size(0)
			correct += (pred == y).sum().item()
			loss_sum += loss.item() * y.size(0)

		train_loss = loss_sum / total
		train_acc = correct / total

		test_loss, test_acc_fake = evaluate_fake_quant(model, test_loader)
		test_acc_int = evaluate_integer_like(model, test_loader)

		print(
			f"Epoch {epoch:2d} | "
			f"train_loss={train_loss:.4f}, train_acc={train_acc*100:.2f}% | "
			f"test_loss={test_loss:.4f}, "
			f"fakeQ_acc={test_acc_fake*100:.2f}% | "
			f"intLike_acc={test_acc_int*100:.2f}%"
		)

	torch.save(model.state_dict(), modelPath)
	print(f"Saved model to: {modelPath}")
	return model

##############################
##     debug one sample     ##
##############################
@torch.no_grad()
def debug_one_sample(model, dataset, idx=0):
	qW1, qB1, qW2, qB2 = export_integer_params(model)

	x, y = dataset[idx]
	x_batch = x.unsqueeze(0)

	pred, x_int, acc1, act1_int, acc2 = integer_like_forward_batch(x_batch, qW1, qB1, qW2, qB2)

	print(f"\n[DEBUG sample index={idx}]")
	print(f"label       = {y}")
	print(f"pred        = {pred.item()}")
	print(f"x_int min/max = {int(x_int.min())}/{int(x_int.max())}")
	print(f"x_int[:32]  = {x_int[0, :32].tolist()}")
	print(f"acc1[:16]   = {acc1[0, :16].tolist()}")
	print(f"act1[:16]   = {act1_int[0, :16].tolist()}")
	print(f"act1 min/max= {int(act1_int.min())}/{int(act1_int.max())}")
	print(f"acc2        = {acc2[0].tolist()}")

##############################
##           Main           ##
##############################
if __name__ == "__main__":
	model = train()

	test_loss, test_acc_fake = evaluate_fake_quant(model, test_loader)
	test_acc_int = evaluate_integer_like(model, test_loader)

	print("\nFinal Results")
	print(f"Fake-quant test accuracy   : {test_acc_fake*100:.2f}%")
	print(f"Integer-like test accuracy : {test_acc_int*100:.2f}%")

	debug_one_sample(model, test_dataset, idx=0)
