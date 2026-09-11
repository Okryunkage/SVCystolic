from __future__ import annotations

import random
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader, random_split
from torchvision import datasets, transforms

#Value of "Config" can't be changed after the initilization by "@dataclass(frozen=True)"
@dataclass(frozen=True)
class Config:
	data_dir: str ="./data"
	batch_size: int =128
	epochs: int =30
	learning_rate: float =1e-3
	weight_decay: float =1e-4
	seed: int =42
	validation_size: int =5_000
	#Split Validation Data from the training set to tune and select the model
	#Without leaking information from the final test set.
	mc_samples: int =30
	channel_drop_probs: tuple[float,float] =(0.1,0.2)
	weight_fractional_bits: int =7
	checkpoint: str ="MCDC_int8.pt"

CFG =Config()

def load_checkpoint_compat(path: Path | str, device: torch.device)-> dict:
	try:
		return torch.load(path, map_location=device, weights_only=True)
	except TypeError:
		return torch.load(path, map_location=device)

def set_seed(seed: int)-> None:
	random.seed(seed)
	np.random.seed(seed)
	torch.manual_seed(seed)
	if torch.cuda.is_available():
		torch.cuda.manual_seed_all(seed)

def fixed_point_weight(
	weight: torch.Tensor,
	fractional_bits: int,)-> torch.Tensor:
	factor =float(2**fractional_bits)
	weight_q =torch.round(weight*factor).clamp(-128,127)/factor
	return weight +(weight_q-weight).detach()

class FixedPointConv2d(nn.Conv2d):
	def forward(self, x: torch.Tensor)-> torch.Tensor:
		weight_q =fixed_point_weight(self.weight, CFG.weight_fractional_bits)
		return F.conv2d(x, weight_q, self.bias, self.stride, self.padding, self.dilation, self.groups,)

class FixedPointLinear(nn.Linear):
	def forward(self, x:torch.Tensor)-> torch.Tensor:
		weight_q =fixed_point_weight(self.weight, CFG.weight_fractional_bits)
		return F.linear(x, weight_q, self.bias)

class BayesianInt8ChannelCNN(nn.Module):
	def __init__(self, channel_drop_probs: tuple[float, float])-> None:
		super().__init__()
		if len(channel_drop_probs) !=2:
			raise ValueError("Two dropout probabilities are required: conv1 and conv2")
		if any(not 0.0 <= p < 1.0 for p in channel_drop_probs):
			raise ValueError("Every dropout probability must satisfy 0 <= p < 1")
		p1, p2 =channel_drop_probs
		self.conv1 =FixedPointConv2d(1, 32, kernel_size=3, padding=1)
		self.drop_channel1 =nn.Dropout2d(p=p1)
		self.conv2 =FixedPointConv2d(32, 64, kernel_size=3, padding=1)
		self.drop_channel2 =nn.Dropout2d(p=p2)
		self.classifier =FixedPointLinear(64*7*7, 10)
	def forward(self, x:torch.Tensor)-> torch.Tensor:
		x =F.relu(self.conv1(x))
		x =self.drop_channel1(x)
		x =F.max_pool2d(x, kernel_size=2)
		x =F.relu(self.conv2(x))
		x =self.drop_channel2(x)
		x =F.max_pool2d(x, kernel_size=2)
		x =torch.flatten(x, start_dim=1)
		return self.classifier(x)

def make_loaders(cfg: Config)-> tuple[DataLoader, DataLoader, DataLoader]:
	transform  =transforms.Compose([transforms.ToTensor(), transforms.Normalize((0.1307,),(0.3081)),])
	full_train =datasets.MNIST(root=cfg.data_dir, train=True,  download=True, transform=transform,)
	test_set   =datasets.MNIST(root=cfg.data_dir, train=False, download=True, transform=transform,)
	train_size =len(full_train) -cfg.validation_size
	split_generator =torch.Generator().manual_seed(cfg.seed)
	train_set, validation_set =random_split(full_train, [train_size, cfg.validation_size], generator=split_generator,)
	loader_args ={"batch_size": cfg.batch_size, "num_workers": 0, "pin_memory": torch.cuda.is_available(),}
	train_loader =DataLoader(train_set, shuffle=True, **loader_args)
	validation_loader = DataLoader(validation_set, shuffle=False, **loader_args)
	test_loader = DataLoader(test_set, shuffle=False, **loader_args)
	return train_loader, validation_loader, test_loader

def train_one_epoch(
	model: nn.Module, loader: DataLoader,
	optimizer: torch.optim.Optimizer, device: torch.device,)-> tuple[float, float]:
	model.train()
	loss_sum, correct, count =0.0, 0, 0
	for images, labels in loader:
		images =images.to(device, non_blocking=True)
		labels =labels.to(device, non_blocking=True)
		optimizer.zero_grad(set_to_none=True)
		logits =model(images)
		loss =F.cross_entropy(logits, labels)
		loss.backward()
		optimizer.step()
		loss_sum +=loss.item()*labels.size(0)
		correct  +=(logits.argmax(dim=1)==labels).sum().item()
		count    +=labels.size(0)
	return loss_sum/count, correct/count

@torch.no_grad()
def deterministic_evaluate(model: nn.Module, loader: DataLoader, device: torch.device,)-> tuple[float, float]:
	model.eval()
	loss_sum, correct, count =0.0, 0, 0
	for images, labels in loader:
		images =images.to(device, non_blocking=True)
		labels =labels.to(device, non_blocking=True)
		logits =model(images)
		loss =F.cross_entropy(logits, labels)
		loss_sum +=loss.item()*labels.size(0)
		correct  +=(logits.argmax(dim=1)==labels).sum().item()
		count    +=labels.size(0)
	return loss_sum/count, correct/count

def enable_mc_dropchannel(model: nn.Module)-> None:
	model.eval()
	for module in model.modules():
		if isinstance(module, nn.Dropout2d):
			module.train()

def expected_calibration_error(probabilities: torch.Tensor,	labels: torch.Tensor, num_bins: int=15)-> float:
	confidences, predictions =probabilities.max(dim=1)
	correctness              =predictions.eq(labels).float()
	boundaries               =torch.linspace(0.0, 1.0, num_bins+1, device=probabilities.device)
	ece                      =torch.zeros((), device=probabilities.device)
	for index in range(num_bins):
		lower,upper =boundaries[index], boundaries[index+1]
		in_bin =(confidences >lower)&(confidences <=upper)
		if index ==0:
			in_bin =(confidences >=lower)&(confidences <=upper)
		if in_bin.any():
			ece +=in_bin.float().mean()*(correctness[in_bin].mean()-confidences[in_bin].mean()).abs()
	return ece.item()

def multiclass_brier_score(probabilties: torch.Tensor, labels: torch.Tensor,)-> float:
	targets =F.one_hot(labels, num_classes=probabilties.size(1)).float()
	return ((probabilties-targets)**2).sum(dim=1).mean().item()

@torch.no_grad()
def mc_predict(model: nn.Module, images: torch.Tensor, mc_samples: int,)-> dict[str, torch.Tensor]:
	if mc_samples <2:
		raise ValueError("mc_samples must be at least 2")
	enable_mc_dropchannel(model)
	samples = torch.stack([torch.softmax(model(images), dim=-1) for _ in range(mc_samples)], dim=0,)
	mean_probability   =samples.mean(dim=0)
	predictive_entropy =-(mean_probability*mean_probability.clamp_min(1e-8).log()).sum(dim=-1)
	expected_entropy   =-(samples*samples.clamp_min(1e-8).log()).sum(dim=-1).mean(dim=0)
	mutual_information = predictive_entropy - expected_entropy
	return {
		"samples": samples,
		"mean_probability": mean_probability,
		"prediction": mean_probability.argmax(dim=-1),
		"predictive_entropy": predictive_entropy,
		"mutual_information": mutual_information,}

@torch.no_grad()
def mc_evaluate(
	model: nn.Module,
	loader: DataLoader,
	device: torch.device,
	mc_samples: int,
	ece_bins: int = 15,)-> dict[str, float]:
	all_probabilities =[]
	all_labels =[]
	all_entropies =[]
	all_mutual_information =[]

	for images, labels in loader:
		images =images.to(device, non_blocking=True)
		labels =labels.to(device, non_blocking=True)
		result =mc_predict(model, images, mc_samples)
		probabilities =result["mean_probability"]
		all_probabilities.append(probabilities.cpu())
		all_labels.append(labels.cpu())
		all_entropies.append(result["predictive_entropy"].cpu())
		all_mutual_information.append(result["mutual_information"].cpu())

	probabilities      =torch.cat(all_probabilities)
	labels             =torch.cat(all_labels)
	entropies          =torch.cat(all_entropies)
	mutual_information =torch.cat(all_mutual_information)
	return {
		"nll": F.nll_loss(probabilities.clamp_min(1e-8).log(), labels).item(),
		"accuracy": probabilities.argmax(dim=1).eq(labels).float().mean().item(),
		"predictive_entropy": entropies.mean().item(),
		"mutual_information": mutual_information.mean().item(),
		"ece": expected_calibration_error(probabilities, labels, ece_bins),
		"brier": multiclass_brier_score(probabilities, labels),}

def main()-> None:
	set_seed(CFG.seed)
	device =torch.device("cuda" if torch.cuda.is_available() else "cpu")
	train_loader, validation_loader, test_loader =make_loaders(CFG)

	model =BayesianInt8ChannelCNN(CFG.channel_drop_probs).to(device)
	optimizer =torch.optim.Adam(model.parameters(), lr=CFG.learning_rate, weight_decay=CFG.weight_decay,)
	best_validation_nll =float("inf")
	checkpoint_path =Path(CFG.checkpoint)

	for epoch in range(1, CFG.epochs+1):
		train_loss, train_accuracy =train_one_epoch(model, train_loader, optimizer, device)
		validation = mc_evaluate(model,	validation_loader, device, CFG.mc_samples,)

		if validation["nll"] <best_validation_nll:
			best_validation_nll =validation["nll"]
			torch.save(
				{
					"model_state_dict": model.state_dict(),
					"channel_drop_probs": CFG.channel_drop_probs,
					"validation_nll": validation["nll"],
					"epoch": epoch,},
				checkpoint_path,
			)
		print(
			f"epoch={epoch:02d} "
			f"train_loss={train_loss:.4f} "
			f"train_acc={train_accuracy:.4f} "
			f"val_mc_nll={validation['nll']:.4f} "
			f"val_mc_acc={validation['accuracy']:.4f} "
			f"val_entropy={validation['predictive_entropy']:.4f} "
			f"val_mi={validation['mutual_information']:.4f} "
			f"val_ece={validation['ece']:.4f} "
			f"val_brier={validation['brier']:.4f}")

	checkpoint =load_checkpoint_compat(checkpoint_path, device)
	model.load_state_dict(checkpoint["model_state_dict"])

	deterministic_nll, deterministic_accuracy =deterministic_evaluate(model, test_loader, device)
	mc =mc_evaluate(model, test_loader, device, CFG.mc_samples)

	print("\nBest model")
	print(f"best epoch: {checkpoint.get('epoch', 'not stored')}")
	print(f"drop probabilities: {CFG.channel_drop_probs}")
	print(
		f"deterministic: nll={deterministic_nll:.4f}, "
		f"accuracy={deterministic_accuracy:.4f}"	)
	print(
		f"MC DropChannel: nll={mc['nll']:.4f}, "
		f"accuracy={mc['accuracy']:.4f}, "
		f"mean_entropy={mc['predictive_entropy']:.4f}, "
		f"mean_mi={mc['mutual_information']:.4f}, "
		f"ece={mc['ece']:.4f}, brier={mc['brier']:.4f}")
	print(f"checkpoint: {checkpoint_path.resolve()}")

if __name__ == "__main__":
	main()
