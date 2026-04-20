import torch
import torch.nn as nn
import torch.optim as optim

# -----------------------------
# 1) 유틸 함수
# -----------------------------
def int_to_bits(n, width):
    # LSB -> MSB
    return [(n >> i) & 1 for i in range(width)]

def bits_to_int(bits):
    # bits: [b0, b1, b2, ...] (LSB -> MSB)
    value = 0
    for i, b in enumerate(bits):
        value |= (int(b) << i)
    return value

# -----------------------------
# 2) 데이터셋 생성
#    모든 4bit 조합: 16 x 16 = 256개
# -----------------------------
def build_dataset():
    X = []
    Y = []

    for a in range(16):
        for b in range(16):
            x_bits = int_to_bits(a, 4) + int_to_bits(b, 4)   # 8-bit input
            y_bits = int_to_bits(a + b, 5)                   # 5-bit output
            X.append(x_bits)
            Y.append(y_bits)

    X = torch.tensor(X, dtype=torch.float32)
    Y = torch.tensor(Y, dtype=torch.float32)
    return X, Y

# -----------------------------
# 3) MLP 모델
# -----------------------------
class AddMLP(nn.Module):
    def __init__(self):
        super().__init__()
        self.fc1 = nn.Linear(8, 16)
        self.act = nn.ReLU()
        self.fc2 = nn.Linear(16, 5)

    def forward(self, x):
        x = self.fc1(x)
        x = self.act(x)
        x = self.fc2(x)   # sigmoid는 loss에서 처리
        return x

# -----------------------------
# 4) 파라미터를 txt로 저장
# -----------------------------
def dump_params_to_text(model, path="mlp_params.txt"):
    with open(path, "w", encoding="utf-8") as f:
        for name, param in model.named_parameters():
            arr = param.detach().cpu().numpy()
            f.write(f"{name}  shape={arr.shape}\n")

            if arr.ndim == 1:
                for i in range(arr.shape[0]):
                    f.write(f"{name}[{i}] = {arr[i]:.8f}\n")

            elif arr.ndim == 2:
                for i in range(arr.shape[0]):
                    for j in range(arr.shape[1]):
                        f.write(f"{name}[{i}][{j}] = {arr[i, j]:.8f}\n")

            f.write("\n")

    print(f"Saved parameters to: {path}")

# -----------------------------
# 5) 정확도 확인
# -----------------------------
@torch.no_grad()
def evaluate(model, X, Y):
    logits = model(X)
    probs = torch.sigmoid(logits)
    pred_bits = (probs >= 0.5).float()

    bit_acc = (pred_bits == Y).float().mean().item()
    sample_acc = (pred_bits == Y).all(dim=1).float().mean().item()

    return bit_acc, sample_acc, pred_bits

# -----------------------------
# 6) 학습
# -----------------------------
def train():
    torch.manual_seed(0)

    X, Y = build_dataset()
    model = AddMLP()

    criterion = nn.BCEWithLogitsLoss()
    optimizer = optim.Adam(model.parameters(), lr=0.01)

    epochs = 5000

    for epoch in range(1, epochs + 1):
        model.train()

        logits = model(X)
        loss = criterion(logits, Y)

        optimizer.zero_grad()
        loss.backward()
        optimizer.step()

        if epoch % 200 == 0 or epoch == 1:
            bit_acc, sample_acc, _ = evaluate(model, X, Y)
            print(
                f"Epoch {epoch:4d} | "
                f"Loss: {loss.item():.6f} | "
                f"Bit Acc: {bit_acc*100:.2f}% | "
                f"Sample Acc: {sample_acc*100:.2f}%"
            )

        # 모든 샘플의 5비트가 전부 맞으면 조기 종료
        bit_acc, sample_acc, _ = evaluate(model, X, Y)
        if sample_acc == 1.0:
            print(f"\nReached 100% sample accuracy at epoch {epoch}.")
            break

    return model, X, Y

# -----------------------------
# 7) 예시 추론
# -----------------------------
@torch.no_grad()
def test_examples(model):
    tests = [(0, 0), (3, 5), (7, 8), (9, 6), (15, 15)]

    print("\nExample predictions:")
    for a, b in tests:
        x = torch.tensor([int_to_bits(a, 4) + int_to_bits(b, 4)], dtype=torch.float32)
        logits = model(x)
        probs = torch.sigmoid(logits)
        pred_bits = (probs >= 0.5).int().squeeze(0).tolist()
        pred_value = bits_to_int(pred_bits)

        print(
            f"{a:2d} + {b:2d} = pred {pred_value:2d}, "
            f"bits {pred_bits}, gt {a+b:2d}"
        )

# -----------------------------
# 8) 실행
# -----------------------------
if __name__ == "__main__":
    model, X, Y = train()

    bit_acc, sample_acc, _ = evaluate(model, X, Y)
    print(f"\nFinal Bit Accuracy   : {bit_acc*100:.2f}%")
    print(f"Final Sample Accuracy: {sample_acc*100:.2f}%")

    test_examples(model)

    # 텍스트로 파라미터 저장
    dump_params_to_text(model, "mlp_params.txt")