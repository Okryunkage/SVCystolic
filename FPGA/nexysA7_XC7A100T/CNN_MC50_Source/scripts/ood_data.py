"""Verified official test splits, all 28x28 uint8, no resizing or label remapping."""
import gzip
import hashlib
import struct
import urllib.request
import numpy as np
from board_client import ROOT, load_mnist

# Resource checksums match torchvision.datasets.mnist.
DATASETS = {
    'kmnist': ('https://codh.rois.ac.jp/kmnist/dataset/kmnist/',
               '5c965bf0a639b31b8f53240b1b52f4d7', '7320c461ea6c1c855c0b718fb2a4b134'),
    'fashion': ('https://raw.githubusercontent.com/zalandoresearch/fashion-mnist/master/data/fashion/',
                'bef4ecab320f06d8554ea6380940ec79', 'bb300cfdad3c16e7a12a480ee83cd310')}


def load_dataset(name, download=False):
    if name == 'mnist':
        return load_mnist(download)
    base, image_hash, label_hash = DATASETS[name]
    directory = ROOT / 'data' / (name + '_test')
    directory.mkdir(parents=True, exist_ok=True)
    data = []
    for filename, expected in [('t10k-images-idx3-ubyte.gz', image_hash), ('t10k-labels-idx1-ubyte.gz', label_hash)]:
        path = directory / filename
        if not path.exists():
            if not download:
                raise FileNotFoundError(f'{name} data missing. Use --download or --download-only')
            print(f'Download {name}/{filename}', flush=True)
            with urllib.request.urlopen(base + filename, timeout=45) as response:
                blob = response.read()
            if hashlib.md5(blob).hexdigest() != expected:
                raise ValueError(f'{name} download checksum mismatch')
            path.write_bytes(blob)
        blob = path.read_bytes()
        if hashlib.md5(blob).hexdigest() != expected:
            raise ValueError(f'{path} checksum mismatch')
        data.append(gzip.decompress(blob))
    if struct.unpack('>4I', data[0][:16]) != (2051, 10000, 28, 28) or struct.unpack('>2I', data[1][:8]) != (2049, 10000):
        raise ValueError(f'{name} IDX header mismatch')
    images = np.frombuffer(data[0][16:], dtype=np.uint8).reshape(10000, 28, 28)
    labels = np.frombuffer(data[1][8:], dtype=np.uint8)
    if labels.shape != (10000,) or np.any(labels > 9):
        raise ValueError(f'{name} invalid labels')
    return images, labels


def mixed_indices(counts, seed):
    rng = np.random.default_rng(seed)
    selection = []
    for name, count in counts.items():
        if not 0 <= count <= 10000:
            raise ValueError('Each dataset count must be 0..10000')
        selection.extend((name, int(i)) for i in rng.permutation(10000)[:count])
    rng.shuffle(selection)
    return selection
