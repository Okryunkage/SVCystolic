import os
import copy
import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torchvision import datasets, transforms
from torch.ao.quantization import QuantStub, DeQuantStub

##############################
#      Model Definition      #
##############################
class MnistLinearQAT(nn.Module):
	def __init__(self):
		super().__init__()
		self.quant = QuantStub()
		#QuantStub() converts float activations to quantized values.
		self.fc = nn.Linear(784, 10)
		#fully-connected layer with input dimension of 784, output dimension of 10.
		self.dequant = DeQuantStub()
		#DeQuanStub converts quantized values back to float.

	def forward(self, x):
		x = x.view(x.size(0), -1)
		#stratch the image from [batch,1,28,28] to [batch,784]
		x = self.quant(x)
		x = self.fc(x)
		x = self.dequant(x)
		return x

##############################
#    Evaluation Function     #
##############################
def evaluate(model, loader, device):
	model.eval()
	#switch model to evaluation mode.
	correct = 0
	total = 0

	with torch.no_grad():
	#No gradient calculation in this block.
		for images, labels in loader:
			images = images.to(device)
			labels = labels.to(device)

			logits = model(images)
			preds = torch.argmax(logits, dim=1)

			correct += (preds == labels).sum().item()
			total += labels.size(0)

	return correct / total

##############################
#      Data Preparation      #
##############################
batch_size = 128
epochs = 5
lr = 0.01

transform = transforms.Compose([
#composing multiple procedure into one transforms
	transforms.ToTensor(),
	transforms.Normalize((0.1307,), (0.3081,))
])

train_dataset = datasets.MNIST(
	root="./data",
	train=True,
	download=True,
	transform=transform
)

test_dataset = datasets.MNIST(
	root="./data",
	train=False,
	download=True,
	transform=transform
)

train_loader = DataLoader(train_dataset, batch_size=batch_size, shuffle=True, num_workers=0)
#num_workers: The number of seperate processes to load data. If 0, the main process loads it.
test_loader = DataLoader(test_dataset, batch_size=batch_size, shuffle=False, num_workers=0)

##############################
#   fp Model instantiation   #
##############################
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
print("Train device:", device)

model_fp32 = MnistLinearQAT().to(device)

criterion = nn.CrossEntropyLoss()
optimizer = torch.optim.SGD(model_fp32.parameters(), lr=lr)

##############################
#      QAT Preparation       #
##############################
backend = "x86"
torch.backends.quantized.engine = backend

model_fp32.qconfig = torch.ao.quantization.get_default_qat_qconfig(backend)

# prepare_qat는 fake-quant / observer를 삽입한 학습용 모델을 만든다
model_qat = torch.ao.quantization.prepare_qat(model_fp32.train(), inplace=False).to(device)

print(model_qat)


# --------------------------------------------------
# 6) QAT 학습
# --------------------------------------------------
for epoch in range(epochs):
	model_qat.train()
	running_loss = 0.0

	for images, labels in train_loader:
		images = images.to(device)
		labels = labels.to(device)

		optimizer.zero_grad()
		logits = model_qat(images)
		loss = criterion(logits, labels)
		loss.backward()
		optimizer.step()

		running_loss += loss.item() * labels.size(0)

	epoch_loss = running_loss / len(train_loader.dataset)
	qat_acc = evaluate(model_qat, test_loader, device)

	print(f"Epoch [{epoch+1}/{epochs}] Loss: {epoch_loss:.4f} QAT Acc: {qat_acc*100:.2f}%")


# --------------------------------------------------
# 7) QAT 학습된 float checkpoint 저장
#	- 이건 아직 convert 전이라 학습용 checkpoint
# --------------------------------------------------
qat_ckpt_path = "mnist_linear_qat_preconvert.pth"
torch.save(model_qat.state_dict(), qat_ckpt_path)
print(f"Saved QAT training checkpoint: {qat_ckpt_path}")


# --------------------------------------------------
# 8) convert 전에 평가
# --------------------------------------------------
model_qat.eval()
qat_eval_acc = evaluate(model_qat, test_loader, device)
print(f"QAT prepared-model accuracy: {qat_eval_acc*100:.2f}%")


# --------------------------------------------------
# 9) INT8 모델로 변환
#	- convert는 CPU 모델에서 수행
# --------------------------------------------------
model_qat_cpu = copy.deepcopy(model_qat).to("cpu")
model_qat_cpu.eval()

model_int8 = torch.ao.quantization.convert(model_qat_cpu, inplace=False)
print(model_int8)


# --------------------------------------------------
# 10) INT8 평가
# --------------------------------------------------
int8_acc = evaluate(model_int8, test_loader, torch.device("cpu"))
print(f"INT8 converted-model accuracy: {int8_acc*100:.2f}%")


# --------------------------------------------------
# 11) INT8 모델 저장
# --------------------------------------------------
int8_path = "mnist_linear_qat_int8.pth"
torch.save(model_int8.state_dict(), int8_path)
print(f"Saved INT8 model state_dict: {int8_path}")

if os.path.exists(qat_ckpt_path):
	print(f"QAT checkpoint size: {os.path.getsize(qat_ckpt_path)} bytes")

if os.path.exists(int8_path):
	print(f"INT8 model size: {os.path.getsize(int8_path)} bytes")


# --------------------------------------------------
# 12) 파라미터 수
# --------------------------------------------------
num_params = sum(p.numel() for p in MnistLinearQAT().fc.parameters())
print(f"Number of trainable parameters in linear layer: {num_params}")