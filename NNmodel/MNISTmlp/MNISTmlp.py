import torch
import torch.nn as nn
import torch.nn.functional as F
import torch.optim as optim
from torchvision import datasets, transforms

# ============================================================
# 0) config
# ============================================================
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
SEED = 0
torch.manual_seed(SEED)

INPUT_DIM  = 784
HIDDEN_DIM = 128
OUTPUT_DIM = 10

BATCH_SIZE = 128
EPOCHS     = 10
LR         = 1e-3

# -----------------------------
# Fixed-point format
# -----------------------------
# Input image x in [0,1]
X_BITS = 8              # unsigned
X_FRAC = 8              # step = 1/256

# Layer1 params
W1_BITS = 8             # signed
W1_FRAC = 6
B1_BITS = 32            # signed, accumulator-aligned
B1_FRAC = X_FRAC + W1_FRAC   # important

# Hidden activation after ReLU
A1_BITS = 12            # unsigned
A1_FRAC = 4

# Layer2 params
W2_BITS = 8             # signed
W2_FRAC = 6
B2_BITS = 32            # signed, accumulator-aligned
B2_FRAC = A1_FRAC + W2_FRAC  # important

MODEL_PATH = "mnist_fixed_mlp.pth"
TXT_PATH   = "mnist_fixed_mlp_params.txt"
VH_PATH    = "mnist_fixed_mlp_params.vh"

# ============================================================
# 1) quantization helpers
# ============================================================
class RoundSTE(torch.autograd.Function):
    @staticmethod
    def forward(ctx, x):
        return torch.round(x)

    @staticmethod
    def backward(ctx, grad_output):
        return grad_output

def fake_quant_signed(x, num_bits, frac_bits):
    """
    symmetric signed fake quant
    q = round(x * 2^frac_bits), clipped to signed range
    dq = q / 2^frac_bits
    """
    qmin = -(1 << (num_bits - 1))
    qmax =  (1 << (num_bits - 1)) - 1
    scale = 1 << frac_bits

    q = RoundSTE.apply(x * scale)
    q = torch.clamp(q, qmin, qmax)
    dq = q / scale
    return dq

def fake_quant_unsigned(x, num_bits, frac_bits):
    """
    unsigned fake quant
    q = round(x * 2^frac_bits), clipped to unsigned range
    dq = q / 2^frac_bits
    """
    qmin = 0
    qmax = (1 << num_bits) - 1
    scale = 1 << frac_bits

    q = RoundSTE.apply(x * scale)
    q = torch.clamp(q, qmin, qmax)
    dq = q / scale
    return dq

@torch.no_grad()
def quantize_signed_to_int(x, num_bits, frac_bits):
    qmin = -(1 << (num_bits - 1))
    qmax =  (1 << (num_bits - 1)) - 1
    scale = 1 << frac_bits
    q = torch.round(x * scale)
    q = torch.clamp(q, qmin, qmax)
    return q.to(torch.int64)

@torch.no_grad()
def quantize_unsigned_to_int(x, num_bits, frac_bits):
    qmin = 0
    qmax = (1 << num_bits) - 1
    scale = 1 << frac_bits
    q = torch.round(x * scale)
    q = torch.clamp(q, qmin, qmax)
    return q.to(torch.int64)

def round_shift_right_signed(x, shift):
    """
    signed rounding right shift for int tensors
    round(x / 2^shift)
    """
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

# ============================================================
# 2) dataset
# ============================================================
transform = transforms.Compose([
    transforms.ToTensor(),               # float32 in [0,1]
    transforms.Lambda(lambda x: x.view(-1))
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

train_loader = torch.utils.data.DataLoader(
    train_dataset,
    batch_size=BATCH_SIZE,
    shuffle=True
)

test_loader = torch.utils.data.DataLoader(
    test_dataset,
    batch_size=BATCH_SIZE,
    shuffle=False
)

# ============================================================
# 3) fixed-point aware model
# ============================================================
class FixedPointMNISTMLP(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(INPUT_DIM, HIDDEN_DIM, bias=True)
        self.fc2 = nn.Linear(HIDDEN_DIM, OUTPUT_DIM, bias=True)

    def forward(self, x):
        # input quant
        x_q = fake_quant_unsigned(x, X_BITS, X_FRAC)

        # layer1 params
        w1_q = fake_quant_signed(self.fc1.weight, W1_BITS, W1_FRAC)
        b1_q = fake_quant_signed(self.fc1.bias,   B1_BITS, B1_FRAC)

        z1 = F.linear(x_q, w1_q, b1_q)
        h1 = F.relu(z1)

        # hidden activation quant
        h1_q = fake_quant_unsigned(h1, A1_BITS, A1_FRAC)

        # layer2 params
        w2_q = fake_quant_signed(self.fc2.weight, W2_BITS, W2_FRAC)
        b2_q = fake_quant_signed(self.fc2.bias,   B2_BITS, B2_FRAC)

        z2 = F.linear(h1_q, w2_q, b2_q)
        return z2

# ============================================================
# 4) float-path eval (fake-quant forward)
# ============================================================
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

    return loss_sum / total, correct / total

# ============================================================
# 5) integer export
# ============================================================
@torch.no_grad()
def export_integer_params(model):
    qW1 = quantize_signed_to_int(model.fc1.weight.cpu(), W1_BITS, W1_FRAC)
    qB1 = quantize_signed_to_int(model.fc1.bias.cpu(),   B1_BITS, B1_FRAC)

    qW2 = quantize_signed_to_int(model.fc2.weight.cpu(), W2_BITS, W2_FRAC)
    qB2 = quantize_signed_to_int(model.fc2.bias.cpu(),   B2_BITS, B2_FRAC)

    return qW1, qB1, qW2, qB2

# ============================================================
# 6) integer-like inference
# ============================================================
@torch.no_grad()
def integer_like_forward_batch(x_float, qW1, qB1, qW2, qB2):
    """
    x_float : [N,784] float in [0,1]
    qW1     : [128,784] int
    qB1     : [128] int, scale = 2^-(X_FRAC + W1_FRAC)
    qW2     : [10,128] int
    qB2     : [10] int, scale = 2^-(A1_FRAC + W2_FRAC)

    Returns:
      pred        : [N]
      x_int       : [N,784]
      acc1        : [N,128]  (before relu, scale=B1_FRAC)
      act1_int    : [N,128]  (requantized hidden activation, scale=A1_FRAC)
      acc2        : [N,10]   (final logits integer domain, scale=B2_FRAC)
    """
    # input quantization
    x_int = quantize_unsigned_to_int(x_float.cpu(), X_BITS, X_FRAC)

    # layer1 integer MAC
    acc1 = x_int @ qW1.transpose(0, 1) + qB1

    # relu in integer domain
    acc1_relu = torch.clamp(acc1, min=0)

    # requantize acc1_relu from scale 2^-B1_FRAC to 2^-A1_FRAC
    # act1_int ~= round(acc1_relu / 2^(B1_FRAC - A1_FRAC))
    shift1 = B1_FRAC - A1_FRAC
    act1_int = round_shift_right_signed(acc1_relu, shift1)

    # clamp hidden activation to unsigned activation format
    a1_qmax = (1 << A1_BITS) - 1
    act1_int = torch.clamp(act1_int, 0, a1_qmax)

    # layer2 integer MAC
    acc2 = act1_int @ qW2.transpose(0, 1) + qB2

    # argmax on integer logits
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

# ============================================================
# 7) train
# ============================================================
def train():
    model = FixedPointMNISTMLP().to(DEVICE)
    optimizer = optim.Adam(model.parameters(), lr=LR)
    criterion = nn.CrossEntropyLoss()

    for epoch in range(1, EPOCHS + 1):
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

    torch.save(model.state_dict(), MODEL_PATH)
    print(f"Saved model to: {MODEL_PATH}")
    return model

# ============================================================
# 8) debug one sample
# ============================================================
@torch.no_grad()
def debug_one_sample(model, dataset, idx=0):
    qW1, qB1, qW2, qB2 = export_integer_params(model)

    x, y = dataset[idx]
    x_batch = x.unsqueeze(0)

    pred, x_int, acc1, act1_int, acc2 = integer_like_forward_batch(x_batch, qW1, qB1, qW2, qB2)

    print(f"\n[DEBUG sample index={idx}]")
    print(f"label     = {y}")
    print(f"pred      = {pred.item()}")
    print(f"x_int[:32]= {x_int[0, :32].tolist()}")
    print(f"acc1[:16] = {acc1[0, :16].tolist()}")
    print(f"act1[:16] = {act1_int[0, :16].tolist()}")
    print(f"acc2      = {acc2[0].tolist()}")

# ============================================================
# 9) export txt / vh
# ============================================================
def twos_hex(v, width):
    mask = (1 << width) - 1
    x = int(v) & mask
    hex_digits = (width + 3) // 4
    return f"{width}'h{x:0{hex_digits}X}"

def flatten_row_major(mat_2d):
    out = []
    for row in mat_2d:
        out.extend(row)
    return out

@torch.no_grad()
def export_files(model):
    qW1, qB1, qW2, qB2 = export_integer_params(model)

    # text
    with open(TXT_PATH, "w", encoding="utf-8") as f:
        f.write("=== Fixed-point MNIST MLP parameters ===\n\n")

        f.write(f"INPUT_DIM={INPUT_DIM}\n")
        f.write(f"HIDDEN_DIM={HIDDEN_DIM}\n")
        f.write(f"OUTPUT_DIM={OUTPUT_DIM}\n\n")

        f.write(f"X_BITS={X_BITS}, X_FRAC={X_FRAC}\n")
        f.write(f"W1_BITS={W1_BITS}, W1_FRAC={W1_FRAC}\n")
        f.write(f"B1_BITS={B1_BITS}, B1_FRAC={B1_FRAC}\n")
        f.write(f"A1_BITS={A1_BITS}, A1_FRAC={A1_FRAC}\n")
        f.write(f"W2_BITS={W2_BITS}, W2_FRAC={W2_FRAC}\n")
        f.write(f"B2_BITS={B2_BITS}, B2_FRAC={B2_FRAC}\n\n")

        f.write(f"fc1.weight_int shape = {tuple(qW1.shape)}\n")
        f.write(f"{qW1.tolist()}\n\n")

        f.write(f"fc1.bias_int shape = {tuple(qB1.shape)}\n")
        f.write(f"{qB1.tolist()}\n\n")

        f.write(f"fc2.weight_int shape = {tuple(qW2.shape)}\n")
        f.write(f"{qW2.tolist()}\n\n")

        f.write(f"fc2.bias_int shape = {tuple(qB2.shape)}\n")
        f.write(f"{qB2.tolist()}\n\n")

    print(f"Saved text params to: {TXT_PATH}")

    # vh
    fc1_w = flatten_row_major(qW1.tolist())
    fc1_b = qB1.tolist()
    fc2_w = flatten_row_major(qW2.tolist())
    fc2_b = qB2.tolist()

    fc1_ww = len(fc1_w) * W1_BITS
    fc1_bw = len(fc1_b) * B1_BITS
    fc2_ww = len(fc2_w) * W2_BITS
    fc2_bw = len(fc2_b) * B2_BITS

    elems_fc1_w = ", ".join(twos_hex(v, W1_BITS) for v in reversed(fc1_w))
    elems_fc1_b = ", ".join(twos_hex(v, B1_BITS) for v in reversed(fc1_b))
    elems_fc2_w = ", ".join(twos_hex(v, W2_BITS) for v in reversed(fc2_w))
    elems_fc2_b = ", ".join(twos_hex(v, B2_BITS) for v in reversed(fc2_b))

    lines = []
    lines.append("// Auto-generated fixed-point parameters for Verilog")
    lines.append("// 784 -> 128 -> 10")
    lines.append("")
    lines.append(f"localparam integer IN_N_FILE   = {INPUT_DIM};")
    lines.append(f"localparam integer HID_N_FILE  = {HIDDEN_DIM};")
    lines.append(f"localparam integer OUT_N_FILE  = {OUTPUT_DIM};")
    lines.append("")
    lines.append(f"localparam integer X_BITS_FILE  = {X_BITS};")
    lines.append(f"localparam integer X_FRAC_FILE  = {X_FRAC};")
    lines.append(f"localparam integer W1_W_FILE    = {W1_BITS};")
    lines.append(f"localparam integer W1_FRAC_FILE = {W1_FRAC};")
    lines.append(f"localparam integer B1_W_FILE    = {B1_BITS};")
    lines.append(f"localparam integer B1_FRAC_FILE = {B1_FRAC};")
    lines.append(f"localparam integer A1_BITS_FILE = {A1_BITS};")
    lines.append(f"localparam integer A1_FRAC_FILE = {A1_FRAC};")
    lines.append(f"localparam integer W2_W_FILE    = {W2_BITS};")
    lines.append(f"localparam integer W2_FRAC_FILE = {W2_FRAC};")
    lines.append(f"localparam integer B2_W_FILE    = {B2_BITS};")
    lines.append(f"localparam integer B2_FRAC_FILE = {B2_FRAC};")
    lines.append("")
    lines.append(f"localparam integer FC1_WW = {fc1_ww};")
    lines.append(f"localparam integer FC1_BW = {fc1_bw};")
    lines.append(f"localparam integer FC2_WW = {fc2_ww};")
    lines.append(f"localparam integer FC2_BW = {fc2_bw};")
    lines.append("")
    lines.append(f"localparam [FC1_WW-1:0] fc1_w_flat = {{ {elems_fc1_w} }};")
    lines.append(f"localparam [FC1_BW-1:0] fc1_b_flat = {{ {elems_fc1_b} }};")
    lines.append(f"localparam [FC2_WW-1:0] fc2_w_flat = {{ {elems_fc2_w} }};")
    lines.append(f"localparam [FC2_BW-1:0] fc2_b_flat = {{ {elems_fc2_b} }};")
    lines.append("")

    with open(VH_PATH, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"Saved Verilog header to: {VH_PATH}")

# ============================================================
# 10) main
# ============================================================
if __name__ == "__main__":
    model = train()

    test_loss, test_acc_fake = evaluate_fake_quant(model, test_loader)
    test_acc_int = evaluate_integer_like(model, test_loader)

    print("\nFinal Results")
    print(f"Fake-quant test accuracy   : {test_acc_fake*100:.2f}%")
    print(f"Integer-like test accuracy : {test_acc_int*100:.2f}%")

    debug_one_sample(model, test_dataset, idx=0)
    export_files(model)