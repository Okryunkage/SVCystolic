from __future__ import annotations

import random
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.utils.data import DataLoader
from torchvision import datasets, transforms

@dataclass(frozen=True)
class Config:
	data_dir: str ="./data"
	batch_size: int =256
	mc_samples: int =30
	ece_bins: int =15
	seed: int =42
	channel_drop_probs: tuple[float, float] =(0.1, 0.2)
	#Must match the value used during training for checkpoints without metadata.
	weight_fractional_bits: int =7
	checkpoint: str ="MCDC_int8_Fixed.pt"
	cpu: bool =False

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
		bias_q   =fixed_point_weight(self.bias, CFG.weight_fractional_bits)
		return F.conv2d(x, weight_q, bias_q, self.stride, self.padding, self.dilation, self.groups,)

class FixedPointLinear(nn.Linear):
	def forward(self, x:torch.Tensor)-> torch.Tensor:
		weight_q =fixed_point_weight(self.weight, CFG.weight_fractional_bits)
		bias_q   =fixed_point_weight(self.bias, CFG.weight_fractional_bits)
		return F.linear(x, weight_q, bias_q)

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


def make_loaders(cfg: Config, device: torch.device)-> dict[str, DataLoader]:
	#Use the training normalization for both MNIST and OOD images.
	transform =transforms.Compose([transforms.ToTensor(), transforms.Normalize((0.1307,), (0.3081,)),])
	dataset_args ={"root": cfg.data_dir, "train": False, "download": True, "transform": transform,}
	loader_args ={"batch_size": cfg.batch_size, "shuffle": False, "num_workers": 0, "pin_memory": device.type =="cuda",}
	return {
		"MNIST": DataLoader(datasets.MNIST(**dataset_args), **loader_args),
		"FashionMNIST": DataLoader(datasets.FashionMNIST(**dataset_args), **loader_args),
		"KMNIST": DataLoader(datasets.KMNIST(**dataset_args), **loader_args),}

@torch.no_grad()
def deterministic_evaluate(model: nn.Module, loader: DataLoader, device: torch.device,)-> tuple[float, float]:
	model.eval()
	loss_sum, correct, count =0.0, 0, 0
	for images, labels in loader:
		images =images.to(device, non_blocking=True)
		labels =labels.to(device, non_blocking=True)
		logits =model(images)
		loss_sum +=F.cross_entropy(logits, labels, reduction="sum").item()
		correct +=(logits.argmax(dim=1)==labels).sum().item()
		count +=labels.size(0)
	return loss_sum/count, correct/count

@torch.no_grad()
def collect_mc_outputs(
	model: nn.Module, loader: DataLoader,
	device: torch.device, mc_samples: int,)-> dict[str, torch.Tensor]:
	all_probabilities =[]
	all_labels =[]
	all_entropies =[]
	all_mutual_information =[]
	for images, labels in loader:
		images =images.to(device, non_blocking=True)
		result =mc_predict(model, images, mc_samples)
		all_probabilities.append(result["mean_probability"].cpu())
		all_labels.append(labels.cpu())
		all_entropies.append(result["predictive_entropy"].cpu())
		all_mutual_information.append(result["mutual_information"].cpu())
	return {
		"probabilities": torch.cat(all_probabilities),
		"labels": torch.cat(all_labels),
		"predictive_entropy": torch.cat(all_entropies),
		"mutual_information": torch.cat(all_mutual_information),}

def classification_metrics(outputs: dict[str, torch.Tensor], ece_bins: int,)-> dict[str, float]:
	probabilities =outputs["probabilities"]
	labels =outputs["labels"]
	return {
		"nll": F.nll_loss(probabilities.clamp_min(1e-8).log(), labels).item(),
		"accuracy": probabilities.argmax(dim=1).eq(labels).float().mean().item(),
		"predictive_entropy": outputs["predictive_entropy"].mean().item(),
		"mutual_information": outputs["mutual_information"].mean().item(),
		"ece": expected_calibration_error(probabilities, labels, ece_bins),
		"brier": multiclass_brier_score(probabilities, labels),}

def binary_ood_metrics(id_scores: torch.Tensor, ood_scores: torch.Tensor,)-> dict[str, float]:
	#OOD is positive; larger uncertainty scores indicate OOD samples.
	scores =torch.cat([id_scores, ood_scores]).detach().cpu().double().numpy()
	labels =np.concatenate([np.zeros(len(id_scores), dtype=np.int64), np.ones(len(ood_scores), dtype=np.int64),])
	order =np.argsort(-scores, kind="mergesort")
	scores, labels =scores[order], labels[order]
	true_positives =np.cumsum(labels)
	false_positives =np.cumsum(1-labels)
	#Group equal scores so tied samples share the same threshold.
	indices =np.r_[np.where(np.diff(scores)!=0)[0], labels.size-1]
	true_positives =true_positives[indices]
	false_positives =false_positives[indices]
	recall =true_positives/float(len(ood_scores))
	fpr =false_positives/float(len(id_scores))
	roc_tpr =np.r_[0.0, recall]
	roc_fpr =np.r_[0.0, fpr]
	auroc =float(np.sum(np.diff(roc_fpr)*(roc_tpr[1:]+roc_tpr[:-1])/2))
	precision =true_positives/np.maximum(true_positives+false_positives, 1)
	aupr_out =float(np.sum((recall-np.r_[0.0, recall[:-1]])*precision))
	candidates =np.flatnonzero(recall >=0.95)
	fpr95 =float(fpr[candidates[0]]) if len(candidates) else 1.0
	return {"auroc": auroc, "aupr_out": aupr_out, "fpr95": fpr95,}

def main()-> None:
	set_seed(CFG.seed)
	device =torch.device("cuda" if torch.cuda.is_available() and not CFG.cpu else "cpu")
	checkpoint_path =Path(CFG.checkpoint)
	checkpoint =load_checkpoint_compat(checkpoint_path, device)
	#The supplied training script does not save fractional bits in its checkpoint.
	saved_bits =checkpoint.get("weight_fractional_bits")
	if saved_bits is not None and saved_bits !=CFG.weight_fractional_bits:
		raise ValueError(f"Checkpoint uses {saved_bits} fractional bits, but Config uses {CFG.weight_fractional_bits}")
	if saved_bits is None:
		print(f"Checkpoint has no fractional-bit metadata; using Config value: {CFG.weight_fractional_bits}")
	channel_drop_probs =tuple(checkpoint.get("channel_drop_probs", CFG.channel_drop_probs))
	model =BayesianInt8ChannelCNN(channel_drop_probs).to(device)
	model.load_state_dict(checkpoint["model_state_dict"])
	loaders =make_loaders(CFG, device)

	deterministic_nll, deterministic_accuracy =deterministic_evaluate(model, loaders["MNIST"], device)
	id_outputs =collect_mc_outputs(model, loaders["MNIST"], device, CFG.mc_samples)
	mc =classification_metrics(id_outputs, CFG.ece_bins)
	print(f"device: {device}")
	print(f"checkpoint: {checkpoint_path.resolve()}")
	print(f"drop probabilities: {channel_drop_probs}")
	print(f"fractional bits: {CFG.weight_fractional_bits}, MC samples: {CFG.mc_samples}")
	print(f"deterministic: nll={deterministic_nll:.4f}, accuracy={deterministic_accuracy:.4f}")
	print(
		f"MC DropChannel: nll={mc['nll']:.4f}, accuracy={mc['accuracy']:.4f}, "
		f"mean_entropy={mc['predictive_entropy']:.4f}, mean_mi={mc['mutual_information']:.4f}, "
		f"ece={mc['ece']:.4f}, brier={mc['brier']:.4f}")

	print("\nOOD: AUROC/AUPR-Out higher is better; FPR@95TPR lower is better")
	for name in ("FashionMNIST", "KMNIST"):
		ood_outputs =collect_mc_outputs(model, loaders[name], device, CFG.mc_samples)
		print(f"{name}:")
		for score_name in ("predictive_entropy", "mutual_information"):
			metrics =binary_ood_metrics(id_outputs[score_name], ood_outputs[score_name])
			print(
				f"  {score_name:20s} AUROC={metrics['auroc']:.4f}, "
				f"AUPR-Out={metrics['aupr_out']:.4f}, FPR@95TPR={metrics['fpr95']:.4f}, "
				f"ID_mean={id_outputs[score_name].mean().item():.4f}, "
				f"OOD_mean={ood_outputs[score_name].mean().item():.4f}")

if __name__ == "__main__":
	main()