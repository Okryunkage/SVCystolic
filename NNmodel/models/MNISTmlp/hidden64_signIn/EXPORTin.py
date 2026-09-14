import argparse
import random
from pathlib import Path
from typing import Iterable, List, Optional, Sequence, Tuple

import numpy as np
import torch
from torchvision import datasets

# -----------------------------------------------------------------------------
# Design parameters
# -----------------------------------------------------------------------------
IN_NUM = 784
SA_SIZE = 32
IN_WIDTH = 8
FC1_IN_TILES = (IN_NUM + SA_SIZE - 1) // SA_SIZE  # 25


def parse_indices(indices: Optional[str]) -> Optional[List[int]]:
    if indices is None or indices.strip() == "":
        return None
    return [int(x.strip()) for x in indices.split(",") if x.strip()]


def pack_word_lsb_first(values: Sequence[int], elem_bits: int) -> str:
    """
    Pack integer values into one hex word.

    values[0] goes to the least-significant elem_bits segment.
    Signed values are written as two's-complement by masking.

    Example for 8-bit values:
      values[0] -> word[7:0]
      values[1] -> word[15:8]
      ...
    """
    word = 0
    mask = (1 << elem_bits) - 1

    for i, v in enumerate(values):
        word |= ((int(v) & mask) << (i * elem_bits))

    total_bits = len(values) * elem_bits
    hex_digits = (total_bits + 3) // 4
    return f"{word:0{hex_digits}x}"


def write_lines(path: Path, lines: Iterable[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for line in lines:
            f.write(line.rstrip() + "\n")


def load_mnist_images(
    data_dir: Path,
    batch_size: int,
    indices: Optional[Sequence[int]],
    download: bool,
    random_select: bool,
    seed: int,
) -> Tuple[List[int], List[int], torch.Tensor]:
    """
    Returns:
      used_indices : list[int]
      labels       : list[int]
      images_u8    : torch.uint8 tensor [batch_size, 784], raw MNIST pixels 0~255
    """
    testset = datasets.MNIST(root=str(data_dir), train=False, download=download, transform=None)

    if indices is None:
        if random_select:
            rng = random.Random(seed)
            used_indices = rng.sample(range(len(testset)), batch_size)
        else:
            used_indices = list(range(batch_size))
    else:
        used_indices = list(indices)
        if len(used_indices) != batch_size:
            raise ValueError(
                f"--indices length ({len(used_indices)}) must match --batch-size ({batch_size})."
            )

    labels: List[int] = []
    flat_images: List[torch.Tensor] = []

    for idx in used_indices:
        img, label = testset[idx]
        img_np = np.array(img, dtype=np.uint8)

        if img_np.shape != (28, 28):
            raise ValueError(f"Unexpected MNIST image shape at index {idx}: {img_np.shape}")

        labels.append(int(label))
        flat_images.append(torch.from_numpy(img_np.reshape(-1).copy()).to(torch.uint8))

    images_u8 = torch.stack(flat_images, dim=0)
    return used_indices, labels, images_u8


def mnist_u8_to_signed_int8(images_u8: torch.Tensor) -> torch.Tensor:
    """
    Convert raw MNIST pixel 0~255 into signed int8 domain used by the SA.

      pixel_s8 = pixel_u8 - 128

    Examples:
      0   -> -128 -> 0x80
      128 ->    0 -> 0x00
      255 ->  127 -> 0x7f
    """
    if images_u8.dtype != torch.uint8:
        raise TypeError("images_u8 must be torch.uint8")
    if images_u8.ndim != 2 or images_u8.shape[1] != IN_NUM:
        raise ValueError(f"images_u8 must have shape [batch_size, {IN_NUM}]")

    return images_u8.to(torch.int16) - 128


def export_input_batch_sa32_mem(images_s8: torch.Tensor, path: Path) -> None:
    """
    inputBatchBRAM format:
      - word width = 256 bit = 32 x signed int8
      - depth      = batch_size x 25
      - address    = image_index * 25 + input_tile

    Each image:
      tile 0  = pixel[0:31]
      ...
      tile 23 = pixel[736:767]
      tile 24 = pixel[768:783] + 16-byte zero padding

    Padding is signed zero, not -128.
    """
    if images_s8.ndim != 2 or images_s8.shape[1] != IN_NUM:
        raise ValueError(f"images_s8 must have shape [batch_size, {IN_NUM}]")

    lines: List[str] = []
    batch_size = images_s8.shape[0]

    for img_idx in range(batch_size):
        pixels = images_s8[img_idx]
        for in_tile in range(FC1_IN_TILES):
            base = in_tile * SA_SIZE
            vals = []
            for k in range(SA_SIZE):
                pidx = base + k
                vals.append(int(pixels[pidx]) if pidx < IN_NUM else 0)
            lines.append(pack_word_lsb_first(vals, IN_WIDTH))

    write_lines(path, lines)


def export_label_file(path: Path, used_indices: Sequence[int], labels: Sequence[int]) -> None:
    with open(path, "w", encoding="utf-8") as f:
        f.write("image_order index label\n")
        for image_order, (idx, label) in enumerate(zip(used_indices, labels)):
            f.write(f"{image_order} {idx} {label}\n")


def export_debug_signed_pixels(path: Path, images_s8: torch.Tensor) -> None:
    """
    Optional human-readable debug file.
    One line per image: image_order followed by 784 signed pixel integers.
    """
    with open(path, "w", encoding="utf-8") as f:
        f.write("image_order signed_pixel_0 ... signed_pixel_783\n")
        for image_order in range(images_s8.shape[0]):
            vals = " ".join(str(int(v)) for v in images_s8[image_order].tolist())
            f.write(f"{image_order} {vals}\n")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Export signed-int8 MNIST input_batch_sa32.mem for 32x32 SA design."
    )
    parser.add_argument("--out-dir", default=".", help="Output directory.")
    parser.add_argument("--input-mem", default="input_batch_sa32.mem", help="Output input .mem filename.")
    parser.add_argument("--label-txt", default="input_labels.txt", help="Output label text filename.")
    parser.add_argument("--batch-size", type=int, default=1, help="Number of MNIST test images to export.")
    parser.add_argument("--indices", default=None, help="Comma-separated MNIST test indices. Length must match --batch-size.")
    parser.add_argument("--random", action="store_true", help="Randomly choose MNIST test images when --indices is not given.")
    parser.add_argument("--seed", type=int, default=0, help="Random seed used with --random.")
    parser.add_argument("--data-dir", default="./data", help="MNIST data directory.")
    parser.add_argument("--download", action="store_true", help="Allow torchvision to download MNIST if not found.")
    parser.add_argument("--debug-pixels", action="store_true", help="Also export signed_input_pixels.txt for human-readable debug.")

    args = parser.parse_args()

    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)

    indices = parse_indices(args.indices)
    used_indices, labels, images_u8 = load_mnist_images(
        data_dir=Path(args.data_dir),
        batch_size=args.batch_size,
        indices=indices,
        download=args.download,
        random_select=args.random,
        seed=args.seed,
    )

    images_s8 = mnist_u8_to_signed_int8(images_u8)

    input_mem_path = out_dir / args.input_mem
    label_txt_path = out_dir / args.label_txt

    export_input_batch_sa32_mem(images_s8, input_mem_path)
    export_label_file(label_txt_path, used_indices, labels)

    print("Exported signed-int8 input files:")
    print(f"  MEM : {input_mem_path}  lines={args.batch_size * FC1_IN_TILES}, width=256b")
    print(f"  TXT : {label_txt_path}")

    if args.debug_pixels:
        debug_path = out_dir / "signed_input_pixels.txt"
        export_debug_signed_pixels(debug_path, images_s8)
        print(f"  TXT : {debug_path}")

    print("\nConversion:")
    print("  pixel_s8 = pixel_u8 - 128")
    print("  0 -> 0x80, 128 -> 0x00, 255 -> 0x7f")
    print("  Padding bytes in the last tile are signed zero: 0x00")

    if args.batch_size > 0:
        print("\nFirst image debug:")
        print(f"  image_order=0, mnist_index={used_indices[0]}, label={labels[0]}")
        print(f"  first 32 signed pixels = {images_s8[0, :32].tolist()}")
        print(f"  first .mem line         = {input_mem_path.read_text(encoding='utf-8').splitlines()[0]}")


if __name__ == "__main__":
    main()
