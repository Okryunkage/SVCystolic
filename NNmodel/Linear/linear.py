#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Train and export a 784->10 MNIST linear classifier for the current Verilog design.

Hardware equation:
    acc[out] = bias_int32[out] + sum_{i=0}^{783} input_int8[i] * weight_int8[out][i]
    pred     = argmax(acc[0..9])

Quantization:
    input_int8  = uint8_pixel - 128        # range [-128, 127]
    weight_int8 = signed int8              # range [-128, 127], normally clipped to [-127, 127]
    bias_int32  = signed int32

Exported memory layouts matched to current SA_btr / linear10Engine_regacc:

1) input_batch_tile10_lsb.mem
    width = 80-bit
    addr  = image * 79 + tile
    word[8*k +: 8] = input_int8[image][tile*10 + k]
    line hex prints byte9 ... byte0 so $readmemh loads byte0 into [7:0].

2) mnist_linear_w_outmajor_for_sabtr.mem
    width = 80-bit
    addr  = out * 79 + tile
    word[8*k +: 8] = weight_int8[out][tile*10 + k]
    This matches SA_btr:
        weightAddr = out * inputTileNum + inputTile
    SA_btr requests out9 -> out0 during preload, but the memory itself is still
    stored as out0 block, out1 block, ..., out9 block.

3) mnist_linear_b_int32.mem
    width = 32-bit
    addr  = out

Also exports:
    label_batch.mem
    ref_acc_10x32_lsb.mem
    ref_pred.mem
    metadata.json
"""

import argparse
import json
import random
from pathlib import Path

import numpy as np
import torch
import torch.nn as nn
from torch.utils.data import DataLoader
from torchvision import datasets


INPUT_DIM = 784
OUT_DIM = 10
TILE_SIZE = 10
PADDED_INPUT_DIM = ((INPUT_DIM + TILE_SIZE - 1) // TILE_SIZE) * TILE_SIZE
NUM_TILES = PADDED_INPUT_DIM // TILE_SIZE


# -----------------------------------------------------------------------------
# Small utilities
# -----------------------------------------------------------------------------

def set_seed(seed: int) -> None:
    random.seed(seed)
    np.random.seed(seed)
    torch.manual_seed(seed)
    torch.cuda.manual_seed_all(seed)


def to_twos_hex(value: int, bits: int) -> str:
    mask = (1 << bits) - 1
    width = (bits + 3) // 4
    return f"{value & mask:0{width}X}"


def pack_bytes_lsb(byte_values) -> str:
    """
    byte_values[0] should become Verilog word[7:0].
    readmemh writes the leftmost hex digits into the MSB side, so print reversed.
    """
    bs = [int(v) & 0xFF for v in byte_values]
    return "".join(f"{b:02X}" for b in reversed(bs))


def pack_int32_lsb(values_10) -> str:
    """
    values_10[0] should become word[31:0].
    Therefore print acc9 ... acc0.
    """
    vals = [int(v) for v in values_10]
    return "".join(to_twos_hex(v, 32) for v in reversed(vals))


# -----------------------------------------------------------------------------
# Dataset
# -----------------------------------------------------------------------------

class MNISTSignedInt8(torch.utils.data.Dataset):
    def __init__(self, root: str, train: bool, download: bool):
        self.ds = datasets.MNIST(root=root, train=train, download=download, transform=None)

    def __len__(self):
        return len(self.ds)

    def __getitem__(self, idx):
        img, label = self.ds[idx]
        arr_u8 = np.array(img, dtype=np.uint8).reshape(-1)
        arr_s16 = arr_u8.astype(np.int16) - 128
        # Keep training input in integer units. The model forward handles scaling.
        x = torch.from_numpy(arr_s16.astype(np.float32))
        return x, int(label)


# -----------------------------------------------------------------------------
# Integer-like linear model using STE quantization
# -----------------------------------------------------------------------------

def ste_round_clamp(x: torch.Tensor, qmin: int, qmax: int) -> torch.Tensor:
    q = torch.round(torch.clamp(x, qmin, qmax))
    return x + (q - x).detach()


class IntLinearMNIST(nn.Module):
    def __init__(self):
        super().__init__()

        # These parameters live in "integer units".
        # During forward, they are rounded/clipped through STE.
        self.weight_raw = nn.Parameter(torch.empty(OUT_DIM, INPUT_DIM))
        self.bias_raw = nn.Parameter(torch.zeros(OUT_DIM))

        # Random integer-ish initialization.
        nn.init.normal_(self.weight_raw, mean=0.0, std=1.0)

    def quantized_weight(self) -> torch.Tensor:
        # int8 signed. Avoid -128 by default to keep symmetric range.
        return ste_round_clamp(self.weight_raw, -127, 127)

    def quantized_bias(self) -> torch.Tensor:
        # Bias is int32. Clipping range is huge; practically this only rounds.
        return ste_round_clamp(self.bias_raw, -(2**31), 2**31 - 1)

    def forward_int_logits(self, x_s8_float: torch.Tensor) -> torch.Tensor:
        w_q = self.quantized_weight()
        b_q = self.quantized_bias()
        return x_s8_float.matmul(w_q.t()) + b_q

    def forward(self, x_s8_float: torch.Tensor, logit_div: float) -> torch.Tensor:
        # Dividing logits stabilizes cross-entropy.
        # Argmax is unchanged for positive logit_div.
        return self.forward_int_logits(x_s8_float) / logit_div

    @torch.no_grad()
    def export_int_params(self):
        w = torch.round(torch.clamp(self.weight_raw, -127, 127)).to(torch.int16).cpu().numpy()
        b = torch.round(torch.clamp(self.bias_raw, -(2**31), 2**31 - 1)).to(torch.int64).cpu().numpy()
        return w.astype(np.int16), b.astype(np.int64)


# -----------------------------------------------------------------------------
# Training / evaluation
# -----------------------------------------------------------------------------

def train_one_epoch(model, loader, optimizer, device, logit_div: float):
    model.train()
    ce = nn.CrossEntropyLoss()

    total_loss = 0.0
    total = 0
    correct = 0

    for x, y in loader:
        x = x.to(device)
        y = y.to(device)

        optimizer.zero_grad(set_to_none=True)
        logits = model(x, logit_div=logit_div)
        loss = ce(logits, y)
        loss.backward()
        optimizer.step()

        total_loss += float(loss.item()) * x.size(0)
        total += x.size(0)
        pred = logits.argmax(dim=1)
        correct += int((pred == y).sum().item())

    return total_loss / total, correct / total


@torch.no_grad()
def evaluate(model, loader, device, logit_div: float):
    model.eval()
    ce = nn.CrossEntropyLoss()

    total_loss = 0.0
    total = 0
    correct_scaled = 0
    correct_int = 0

    for x, y in loader:
        x = x.to(device)
        y = y.to(device)

        logits_scaled = model(x, logit_div=logit_div)
        logits_int = model.forward_int_logits(x)

        loss = ce(logits_scaled, y)
        total_loss += float(loss.item()) * x.size(0)
        total += x.size(0)

        correct_scaled += int((logits_scaled.argmax(dim=1) == y).sum().item())
        correct_int += int((logits_int.argmax(dim=1) == y).sum().item())

    return total_loss / total, correct_scaled / total, correct_int / total


# -----------------------------------------------------------------------------
# Export functions
# -----------------------------------------------------------------------------

def export_weight_mem_outmajor_for_sabtr(w_int8: np.ndarray, outdir: Path) -> Path:
    """
    w_int8 shape = [10, 784]
    Output:
        addr = out * 79 + tile
        line = 80-bit hex, byte0 in [7:0]
    """
    if w_int8.shape != (OUT_DIM, INPUT_DIM):
        raise ValueError(f"weight shape must be {(OUT_DIM, INPUT_DIM)}, got {w_int8.shape}")

    padded = np.zeros((OUT_DIM, PADDED_INPUT_DIM), dtype=np.int16)
    padded[:, :INPUT_DIM] = w_int8.astype(np.int16)

    path = outdir / "mnist_linear_w_outmajor_for_sabtr.mem"
    with path.open("w", encoding="utf-8") as f:
        for out in range(OUT_DIM):
            for tile in range(NUM_TILES):
                start = tile * TILE_SIZE
                vals = padded[out, start:start + TILE_SIZE]
                f.write(pack_bytes_lsb(vals) + "\n")

    return path


def export_weight_mem_tilemajor_debug(w_int8: np.ndarray, outdir: Path) -> Path:
    """
    Optional debug layout:
        addr = tile * 10 + out
    Do NOT use this with the current SA_btr unless SA_btr address logic is changed.
    """
    padded = np.zeros((OUT_DIM, PADDED_INPUT_DIM), dtype=np.int16)
    padded[:, :INPUT_DIM] = w_int8.astype(np.int16)

    path = outdir / "mnist_linear_w_tilemajor_debug_do_not_use_with_sabtr.mem"
    with path.open("w", encoding="utf-8") as f:
        for tile in range(NUM_TILES):
            for out in range(OUT_DIM):
                start = tile * TILE_SIZE
                vals = padded[out, start:start + TILE_SIZE]
                f.write(pack_bytes_lsb(vals) + "\n")

    return path


def export_bias_mem(b_int32: np.ndarray, outdir: Path) -> Path:
    if b_int32.shape != (OUT_DIM,):
        raise ValueError(f"bias shape must be {(OUT_DIM,)}, got {b_int32.shape}")

    path = outdir / "mnist_linear_b_int32.mem"
    with path.open("w", encoding="utf-8") as f:
        for out in range(OUT_DIM):
            f.write(to_twos_hex(int(b_int32[out]), 32) + "\n")

    return path


def get_test_batch_s8(data_dir: str, batch_size: int, start_index: int, download: bool):
    ds = datasets.MNIST(root=data_dir, train=False, download=download, transform=None)

    if start_index < 0:
        raise ValueError("start_index must be >= 0")
    if start_index + batch_size > len(ds):
        raise ValueError(f"Requested test indices [{start_index}, {start_index + batch_size}) exceed dataset length {len(ds)}")

    xs = np.zeros((batch_size, INPUT_DIM), dtype=np.int16)
    ys = np.zeros((batch_size,), dtype=np.int64)

    for n in range(batch_size):
        img, label = ds[start_index + n]
        arr_u8 = np.array(img, dtype=np.uint8).reshape(-1)
        xs[n] = arr_u8.astype(np.int16) - 128
        ys[n] = int(label)

    return xs, ys


def export_input_batch_mem(x_s8: np.ndarray, outdir: Path) -> Path:
    """
    x_s8 shape = [batch, 784]
    Output:
        addr = image * 79 + tile
        line = 80-bit hex, byte0 in [7:0]
    """
    batch_size = x_s8.shape[0]
    padded = np.zeros((batch_size, PADDED_INPUT_DIM), dtype=np.int16)
    padded[:, :INPUT_DIM] = x_s8.astype(np.int16)

    path = outdir / "input_batch_tile10_lsb.mem"
    with path.open("w", encoding="utf-8") as f:
        for image in range(batch_size):
            for tile in range(NUM_TILES):
                start = tile * TILE_SIZE
                vals = padded[image, start:start + TILE_SIZE]
                f.write(pack_bytes_lsb(vals) + "\n")

    return path


def export_label_mem(labels: np.ndarray, outdir: Path) -> Path:
    path = outdir / "label_batch.mem"
    with path.open("w", encoding="utf-8") as f:
        for y in labels:
            f.write(to_twos_hex(int(y), 8) + "\n")
    return path


def integer_reference(x_s8: np.ndarray, w_int8: np.ndarray, b_int32: np.ndarray):
    """
    Returns:
        acc  shape [batch, 10], int64
        pred shape [batch]
    """
    acc = x_s8.astype(np.int64).dot(w_int8.astype(np.int64).T) + b_int32.astype(np.int64)[None, :]
    pred = np.argmax(acc, axis=1).astype(np.int64)
    return acc, pred


def export_reference(acc: np.ndarray, pred: np.ndarray, outdir: Path):
    acc_path = outdir / "ref_acc_10x32_lsb.mem"
    pred_path = outdir / "ref_pred.mem"

    with acc_path.open("w", encoding="utf-8") as f:
        for row in acc:
            f.write(pack_int32_lsb(row.tolist()) + "\n")

    with pred_path.open("w", encoding="utf-8") as f:
        for p in pred:
            f.write(to_twos_hex(int(p), 4) + "\n")

    return acc_path, pred_path


def export_metadata(args, outdir: Path, files: dict, test_acc: float, export_ref_acc: float):
    meta = {
        "model": "MNIST linear classifier 784->10",
        "input_quantization": "input_int8 = uint8_pixel - 128",
        "weight_quantization": "signed int8, clipped to [-127, 127]",
        "bias_quantization": "signed int32",
        "input_dim": INPUT_DIM,
        "out_dim": OUT_DIM,
        "tile_size": TILE_SIZE,
        "padded_input_dim": PADDED_INPUT_DIM,
        "input_tile_num": NUM_TILES,
        "sa_size": 10,
        "verilog_expected_layout": {
            "inputAddr": "image * 79 + tile",
            "weightAddr": "out * 79 + tile",
            "biasAddr": "out",
            "input_word": "word[8*k +: 8] = input_int8[tile*10+k]",
            "weight_word": "word[8*k +: 8] = weight_int8[out][tile*10+k]",
            "acc_word": "word[32*out +: 32] = acc[out]",
        },
        "training": {
            "epochs": args.epochs,
            "train_batch_size": args.train_batch_size,
            "lr": args.lr,
            "weight_decay": args.weight_decay,
            "logit_div": args.logit_div,
            "seed": args.seed,
        },
        "export_batch": {
            "batch_size": args.export_batch_size,
            "test_start_index": args.export_start_index,
            "integer_reference_accuracy_on_export_batch": export_ref_acc,
        },
        "test_integer_accuracy": test_acc,
        "files": {k: str(v.name) for k, v in files.items()},
    }

    path = outdir / "metadata.json"
    path.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    return path


# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data-dir", default="./data")
    ap.add_argument("--outdir", default="./mnist_linear10_export")
    ap.add_argument("--epochs", type=int, default=15)
    ap.add_argument("--train-batch-size", type=int, default=256)
    ap.add_argument("--test-batch-size", type=int, default=512)
    ap.add_argument("--export-batch-size", type=int, default=100)
    ap.add_argument("--export-start-index", type=int, default=0)
    ap.add_argument("--lr", type=float, default=0.05)
    ap.add_argument("--weight-decay", type=float, default=1e-5)
    ap.add_argument("--logit-div", type=float, default=256.0)
    ap.add_argument("--seed", type=int, default=1)
    ap.add_argument("--download", action="store_true", default=True)
    ap.add_argument("--no-download", dest="download", action="store_false")
    args = ap.parse_args()

    if args.export_batch_size <= 0:
        raise ValueError("--export-batch-size must be positive")

    set_seed(args.seed)

    outdir = Path(args.outdir)
    outdir.mkdir(parents=True, exist_ok=True)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"[INFO] device = {device}")
    print(f"[INFO] inputTileNum = {NUM_TILES}, paddedInputDim = {PADDED_INPUT_DIM}")

    train_ds = MNISTSignedInt8(args.data_dir, train=True, download=args.download)
    test_ds = MNISTSignedInt8(args.data_dir, train=False, download=args.download)

    train_loader = DataLoader(
        train_ds,
        batch_size=args.train_batch_size,
        shuffle=True,
        num_workers=2,
        pin_memory=(device.type == "cuda"),
    )

    test_loader = DataLoader(
        test_ds,
        batch_size=args.test_batch_size,
        shuffle=False,
        num_workers=2,
        pin_memory=(device.type == "cuda"),
    )

    model = IntLinearMNIST().to(device)
    optimizer = torch.optim.AdamW(
        model.parameters(),
        lr=args.lr,
        weight_decay=args.weight_decay,
    )

    best_state = None
    best_int_acc = -1.0

    for epoch in range(1, args.epochs + 1):
        tr_loss, tr_acc = train_one_epoch(model, train_loader, optimizer, device, args.logit_div)
        te_loss, te_acc_scaled, te_acc_int = evaluate(model, test_loader, device, args.logit_div)

        print(
            f"[EPOCH {epoch:02d}] "
            f"train_loss={tr_loss:.4f} train_acc={tr_acc*100:.2f}% | "
            f"test_loss={te_loss:.4f} test_acc_int={te_acc_int*100:.2f}%"
        )

        if te_acc_int > best_int_acc:
            best_int_acc = te_acc_int
            best_state = {k: v.detach().cpu().clone() for k, v in model.state_dict().items()}

    if best_state is not None:
        model.load_state_dict(best_state)

    _, _, test_int_acc = evaluate(model, test_loader, device, args.logit_div)

    w_int8, b_int32 = model.export_int_params()

    # Export parameter memories.
    w_path = export_weight_mem_outmajor_for_sabtr(w_int8, outdir)
    w_dbg_path = export_weight_mem_tilemajor_debug(w_int8, outdir)
    b_path = export_bias_mem(b_int32, outdir)

    # Export one test batch and integer reference.
    x_batch, y_batch = get_test_batch_s8(
        args.data_dir,
        batch_size=args.export_batch_size,
        start_index=args.export_start_index,
        download=args.download,
    )

    input_path = export_input_batch_mem(x_batch, outdir)
    label_path = export_label_mem(y_batch, outdir)

    ref_acc, ref_pred = integer_reference(x_batch, w_int8, b_int32)
    ref_acc_path, ref_pred_path = export_reference(ref_acc, ref_pred, outdir)

    export_ref_acc = float((ref_pred == y_batch).mean())

    files = {
        "weight_outmajor_for_sabtr": w_path,
        "weight_tilemajor_debug_do_not_use_with_sabtr": w_dbg_path,
        "bias_int32": b_path,
        "input_batch_tile10_lsb": input_path,
        "label_batch": label_path,
        "ref_acc_10x32_lsb": ref_acc_path,
        "ref_pred": ref_pred_path,
    }

    meta_path = export_metadata(args, outdir, files, test_int_acc, export_ref_acc)

    print("\n[EXPORT DONE]")
    print(f"outdir = {outdir.resolve()}")
    for name, path in files.items():
        print(f"{name:38s}: {path.name}")
    print(f"{'metadata':38s}: {meta_path.name}")

    print("\n[IMPORTANT ADDRESS LAYOUT]")
    print("inputAddr  = image * 79 + tile")
    print("weightAddr = out * 79 + tile")
    print("biasAddr   = out")

    print("\n[ACCURACY]")
    print(f"test integer accuracy       = {test_int_acc*100:.2f}%")
    print(f"export batch ref accuracy   = {export_ref_acc*100:.2f}%")
    print("\nUse this weight file with current SA_btr:")
    print("  mnist_linear_w_outmajor_for_sabtr.mem")


if __name__ == "__main__":
    main()
