"""Export Q7 weight/bias memories and the CPU normalization reference from the checkpoint.

Requires NumPy. Never executes the training file or arbitrary pickle globals.
The restricted reader supports only the float32 tensor format in this checkpoint.
"""
import collections
import hashlib
import io
import json
import pickle
from pathlib import Path
import zipfile
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'models/mcdc_int8_fixed/MCDC_int8_Fixed.pt'
OUT = ROOT / 'data/mcdc_int8_fixed'


def load_checkpoint(path):
    with zipfile.ZipFile(path) as archive:
        prefix = next(n[:-8] for n in archive.namelist() if n.endswith('data.pkl'))

        def rebuild(storage, offset, shape, stride, requires_grad, hooks):
            expected = tuple(np.cumprod((1,) + tuple(shape[:0:-1]))[::-1])
            if tuple(stride) != expected:
                raise ValueError('Only contiguous tensors are supported')
            size = int(np.prod(shape))
            return storage[offset:offset + size].reshape(shape).copy()

        class Reader(pickle.Unpickler):
            def find_class(self, module, name):
                allowed = {('collections', 'OrderedDict'): collections.OrderedDict,
                           ('torch._utils', '_rebuild_tensor_v2'): rebuild,
                           ('torch', 'FloatStorage'): 'float32'}
                if (module, name) not in allowed:
                    raise ValueError(f'Unsupported checkpoint global: {module}.{name}')
                return allowed[module, name]

            def persistent_load(self, pid):
                kind, dtype, key, location, count = pid
                if kind != 'storage' or dtype != 'float32':
                    raise ValueError('Unsupported storage')
                data = np.frombuffer(archive.read(prefix + 'data/' + key), dtype='<f4')
                if data.size != count:
                    raise ValueError('Storage length mismatch')
                return data

        return Reader(io.BytesIO(archive.read(prefix + 'data.pkl'))).load()


def write_mem(name, words, bits):
    (OUT / (name + '.mem')).write_text(''.join(
        f'{int(v) & ((1 << bits) - 1):0{(bits + 3) // 4}x}\n' for v in words), encoding='ascii')


def packed(array, lanes):
    rows = np.asarray(array).reshape(array.shape[0], -1)
    return [sum((int(rows[t + lane, k]) & 255) << (8 * lane) for lane in range(lanes))
            for t in range(0, rows.shape[0], lanes) for k in range(rows.shape[1])]


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    checkpoint = load_checkpoint(SOURCE)
    shapes = {'conv1.weight': (8, 1, 3, 3), 'conv1.bias': (8,),
              'conv2.weight': (16, 8, 3, 3), 'conv2.bias': (16,),
              'classifier.weight': (10, 784), 'classifier.bias': (10,)}
    quantized = {}
    stats = {}
    for name, shape in shapes.items():
        tensor = checkpoint['model_state_dict'][name]
        assert tensor.shape == shape and np.isfinite(tensor).all()
        rounded = np.rint(tensor * np.float32(128))  # PyTorch round: ties to even
        quantized[name] = np.clip(rounded, -128, 127).astype(np.int64)
        stats[name] = {'shape': list(shape), 'clipped': int(((rounded < -128) | (rounded > 127)).sum())}
    for layer, lanes in [('conv1', 8), ('conv2', 8), ('classifier', 5)]:
        for kind, suffix in [('weight', 'w'), ('bias', 'b')]:
            values = quantized[layer + '.' + kind]
            words = packed(values, lanes)
            if kind == 'bias' and len(words) == 1:
                words.append(0)  # XPM minimum two words
            write_mem(layer + '_' + suffix, words, lanes * 8)
            # Decode each generated word to independently check lane/address order.
            decoded = np.empty_like(values.reshape(values.shape[0], -1))
            for t in range(values.shape[0] // lanes):
                for k in range(decoded.shape[1]):
                    for lane in range(lanes):
                        byte = (words[t * decoded.shape[1] + k] >> (lane * 8)) & 255
                        decoded[t * lanes + lane, k] = byte if byte < 128 else byte - 256
            np.testing.assert_array_equal(decoded.reshape(values.shape), values)
    pixel = np.arange(256, dtype=np.float32) / np.float32(255)
    normalized = (pixel - np.float32(.1307)) / np.float32(.3081)
    lut = np.clip(np.rint(normalized * 32), -128, 127).astype(np.int64)
    write_mem('normalize', lut, 8)
    report = {'checkpoint_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'source_epoch': checkpoint['epoch'], 'channel_drop_probs': checkpoint['channel_drop_probs'],
              'weight_bias_scale': 128, 'input_scale': 32, 'activation_scales': [32, 16],
              'bias_shifts': [5, 5, 4], 'requant_shifts': [7, 8], 'score_scale': 2048,
              'rounding': 'weights/bias/input: ties-to-even; positive activation: half-up',
              'parameters': stats,
              'validation_note': 'Packed parameters decoded and compared with quantized checkpoint; no simulation fixtures are required or generated.',
              'mem_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.glob('*.mem'))}}
    (OUT / 'validation.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
