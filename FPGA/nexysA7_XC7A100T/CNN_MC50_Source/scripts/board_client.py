"""Nexys CNN: real UART client, MNIST test data and integer reference."""
from pathlib import Path
import gzip
import hashlib
import struct
import time
import urllib.request
import numpy as np
import serial
from serial.tools import list_ports

ROOT = Path(__file__).resolve().parents[1]
MODEL = ROOT / 'data/mcdc_int8_fixed'
DATA = ROOT / 'data/mnist_test'
RESOURCES = {
    't10k-images-idx3-ubyte.gz': '9fb629c4189551a2d022fa330f9573f3',
    't10k-labels-idx1-ubyte.gz': 'ec29112dd5afa0611ce80d1b7f02629c',
}
MIRROR = 'https://ossci-datasets.s3.amazonaws.com/mnist/'


def ports():
    return [{'port': p.device, 'description': p.description} for p in list_ports.comports()]


def load_mnist(download=False):
    DATA.mkdir(parents=True, exist_ok=True)
    contents = []
    for name, md5 in RESOURCES.items():
        path = DATA / name
        if not path.exists():
            if not download:
                raise FileNotFoundError('MNIST test data missing. Run: board_mc_cli.py --download-only')
            with urllib.request.urlopen(MIRROR + name, timeout=60) as response:
                data = response.read()
            if hashlib.md5(data).hexdigest() != md5:
                raise ValueError(f'MNIST checksum mismatch: {name}')
            path.write_bytes(data)
        data = path.read_bytes()
        if hashlib.md5(data).hexdigest() != md5:
            raise ValueError(f'Corrupt dataset: {path}; remove this file and download again')
        contents.append(gzip.decompress(data))
    image_bytes, label_bytes = contents
    magic, count, height, width = struct.unpack('>4I', image_bytes[:16])
    label_magic, label_count = struct.unpack('>2I', label_bytes[:8])
    if (magic, height, width, label_magic, count) != (2051, 28, 28, 2049, label_count):
        raise ValueError('Invalid MNIST IDX headers')
    images = np.frombuffer(image_bytes[16:], dtype=np.uint8).reshape(count, 28, 28)
    labels = np.frombuffer(label_bytes[8:], dtype=np.uint8)
    if len(labels) != count or np.any(labels > 9):
        raise ValueError('Invalid MNIST labels')
    return images, labels


def normalize_image(image):
    """Raw uint8 -> model int8, matching export_mcdc's float32 round-to-even LUT."""
    a = np.asarray(image)
    if a.dtype != np.uint8:
        raise ValueError('normalize_image expects raw uint8 values')
    x = a.astype(np.float32) / np.float32(255)
    x = (x - np.float32(.1307)) / np.float32(.3081)
    return np.clip(np.rint(x * np.float32(32)), -128, 127).astype(np.int8)


def make_packet(image, command=3):
    """789 bytes: normalize raw uint8, or send already normalized int8 unchanged."""
    a = np.asarray(image)
    if a.shape != (28, 28) or a.dtype not in (np.dtype('uint8'), np.dtype('int8')):
        raise ValueError('Expected (28,28) raw uint8 or normalized int8 image')
    if command not in (3, 4):
        raise ValueError('Use command03/04 for normalized int8 firmware')
    if a.dtype == np.uint8:
        a = normalize_image(a)
    pixels = a.tobytes(order='C')
    return b'\xa5\x5a' + bytes([command]) + pixels + struct.pack('<H', (command + sum(pixels)) & 65535)


def decode_reply(reply):
    if len(reply) != 46 or reply[:2] != b'\x5a\xa5':
        raise ValueError('Invalid UART reply length/header; reconnect before retrying')
    if (sum(reply[2:44]) & 65535) != struct.unpack('<H', reply[44:])[0]:
        raise ValueError('UART reply checksum mismatch')
    status, prediction = reply[2:4]
    if status:
        meaning = {0xe1: 'request checksum', 0xe2: 'framing', 0xe3: 'inter-byte timeout', 0xe4: 'command'}
        raise ValueError(f'FPGA error 0x{status:02x}: {meaning.get(status, "unknown")}')
    scores = list(struct.unpack('<10i', reply[4:44]))
    if prediction > 9 or prediction != max(range(10), key=scores.__getitem__):
        raise ValueError('Prediction is inconsistent with returned scores')
    return prediction, scores


class Board:
    def __init__(self, port, baud=8_000_000):
        self.port = port
        self.serial = serial.Serial(port=None, baudrate=baud, timeout=.1, write_timeout=2,
                                    rtscts=False, dsrdtr=False, xonxoff=False)
        self.serial.dtr = False
        self.serial.rts = False
        self.serial.port = port
        try:
            self.serial.open()
            # Allow an interrupted previous request to time out before clearing stale replies.
            time.sleep(.6)
            self.serial.reset_input_buffer()
        except Exception:
            self.serial.close()
            raise

    def infer(self, image):
        packet = make_packet(image)
        start = time.perf_counter()
        if self.serial.write(packet) != len(packet):
            raise IOError('Incomplete UART request write')
        reply = bytearray()
        deadline = start + 3
        while len(reply) < 46 and time.perf_counter() < deadline:
            reply.extend(self.serial.read(46 - len(reply)))
        elapsed = (time.perf_counter() - start) * 1000
        prediction, scores = decode_reply(reply)
        return {'prediction': prediction, 'scores': scores, 'elapsed_ms': elapsed}

    def close(self):
        self.serial.close()

    def infer_mc(self, image):
        packet = make_packet(image, command=4)
        start = time.perf_counter()
        if self.serial.write(packet) != len(packet):
            raise IOError('Incomplete MC request')
        samples, masks, predictions = [], [], []
        def read_exact(count):
            data = bytearray()
            deadline = time.perf_counter() + 3
            while len(data) < count and time.perf_counter() < deadline:
                data.extend(self.serial.read(count - len(data)))
            if len(data) != count:
                raise TimeoutError(f'MC response timeout: got {len(data)}/{count} bytes')
            return bytes(data)
        for iteration in range(50):
            header = read_exact(2)
            if header == b'\x5a\xa5':
                decode_reply(header + read_exact(44))
                raise ValueError('MC50 firmware required: received a single-inference response')
            frame = header + read_exact(48)
            decoded = decode_mc_reply(frame, iteration)
            samples.append(decoded['scores']); masks.append(decoded['masks'])
            predictions.append(decoded['prediction'])
        return {'scores': np.array(samples, dtype=np.int32), 'masks': np.array(masks, dtype=np.uint16),
                'predictions': predictions, 'elapsed_ms': (time.perf_counter()-start)*1000}

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()


class Reference:
    """Integer model decoded from BRAM .mem files; optional per-layer channel masks."""
    def __init__(self):
        def unpack(name, channels, terms, lanes):
            words = [int(v, 16) for v in (MODEL / name).read_text().split()]
            result = np.empty((channels, terms), dtype=np.int64)
            for c in range(channels):
                for k in range(terms):
                    v = (words[(c // lanes) * terms + k] >> (8 * (c % lanes))) & 255
                    result[c, k] = v - 256 if v >= 128 else v
            return result
        self.w1 = unpack('conv1_w.mem', 8, 9, 8).reshape(8, 1, 3, 3)
        self.b1 = unpack('conv1_b.mem', 8, 1, 8).ravel()
        self.w2 = unpack('conv2_w.mem', 16, 72, 8).reshape(16, 8, 3, 3)
        self.b2 = unpack('conv2_b.mem', 16, 1, 8).ravel()
        self.w3 = unpack('classifier_w.mem', 10, 784, 5)
        self.b3 = unpack('classifier_b.mem', 10, 1, 5).ravel()
        values = np.array([int(v, 16) for v in (MODEL / 'normalize.mem').read_text().split()], dtype=np.int64)
        self.lut = np.where(values >= 128, values - 256, values)

    def infer(self, image, mask1=255, mask2=65535):
        x = (image.astype(np.int64) if image.dtype == np.int8 else self.lut[image])[None]
        for w, b, shift, mask in [(self.w1, self.b1, 7, mask1), (self.w2, self.b2, 8, mask2)]:
            padded = np.pad(x, ((0, 0), (1, 1), (1, 1)))
            windows = np.lib.stride_tricks.sliding_window_view(padded, (3, 3), axis=(1, 2))
            acc = np.einsum('cijxy,ocxy->oij', windows, w, optimize=True) + b[:, None, None] * 32
            x = np.clip((np.maximum(acc, 0) + (1 << (shift - 1))) >> shift, 0, 255)
            x *= np.array([(int(mask) >> c) & 1 for c in range(len(b))])[:, None, None]
            c, h, width = x.shape
            x = x.reshape(c, h // 2, 2, width // 2, 2).max(axis=(2, 4))
        return (self.w3 @ x.ravel() + self.b3 * 16).tolist()


def decode_mc_reply(frame, iteration):
    if len(frame) != 50 or frame[:2] != b'\x5a\xa6':
        raise ValueError('Invalid MC frame length/header')
    if sum(frame[2:48]) & 65535 != struct.unpack('<H', frame[48:])[0]:
        raise ValueError('MC checksum mismatch')
    if frame[2]:
        raise ValueError(f'FPGA MC error 0x{frame[2]:02x}')
    if frame[3] != iteration:
        raise ValueError(f'MC sequence mismatch: got {frame[3]}, expected {iteration}')
    scores = list(struct.unpack('<10i', frame[8:48]))
    if frame[4] != max(range(10), key=scores.__getitem__):
        raise ValueError('MC prediction/score mismatch')
    return {'prediction': frame[4], 'masks': (frame[5], int.from_bytes(frame[6:8], 'little')), 'scores': scores}
