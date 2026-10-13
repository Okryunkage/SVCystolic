"""Evaluate all 10,000 MNIST test images with 50 FPGA inferences per image."""
import argparse
import csv
from datetime import datetime
import hashlib
import json
from pathlib import Path
import sys
import time

import numpy as np
from board_client import Board, MODEL, ROOT, Reference, load_mnist, ports
from mc_metrics import uncertainty


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', help='FPGA USB-UART port, e.g. COM6')
    parser.add_argument('--download', action='store_true', help='Download MNIST if missing')
    parser.add_argument('--download-only', action='store_true')
    parser.add_argument('--list-ports', action='store_true')
    parser.add_argument('--verify-scores', action='store_true', help='Also compare all FPGA scores with the CPU integer model')
    parser.add_argument('--every', type=int, default=100, help='Print progress every N images (default100;1 for each image)')
    parser.add_argument('--output', type=Path, help='Empty output directory')
    args = parser.parse_args(argv)
    if args.list_ports:
        print(json.dumps(ports(), ensure_ascii=False, indent=2))
        return 0
    if args.every < 1:
        parser.error('--every must be positive')
    if not args.download_only and not args.port:
        parser.error('--port is required')
    images, labels = load_mnist(args.download or args.download_only)
    if images.shape != (10000, 28, 28) or labels.shape != (10000,):
        raise ValueError('Expected the complete MNIST test split:10,000 images and labels')
    if args.download_only:
        print('MNIST test split ready:10,000 images')
        return 0
    reference = Reference() if args.verify_scores else None
    out = args.output or ROOT / 'output/mnist_mc50_runs' / datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        parser.error('Use an empty output directory')

    # ~22MB for all scores/masks. Only completed samples are saved after interruption.
    scores = np.empty((10000, 50, 10), dtype=np.int32)
    masks = np.empty((10000, 50, 2), dtype=np.uint16)
    confusion = np.zeros((10, 10), dtype=np.int64)
    completed = correct = mismatches = 0
    error = None
    started = time.perf_counter()
    fields = ['index', 'label', 'prediction', 'correct', 'confidence',
              'predictive_entropy', 'expected_entropy', 'mutual_information',
              'unique_masks', 'elapsed_ms', 'reference_match', 'running_accuracy']
    print('MNIST test:10,000 images x50 iterations =500,000 FPGA inferences; UART8Mbps', flush=True)
    with (out / 'results.csv').open('w', newline='', encoding='utf-8') as file:
        writer = csv.DictWriter(file, fieldnames=fields)
        writer.writeheader()
        try:
            with Board(args.port) as board:
                for index in range(10000):
                    result = board.infer_mc(images[index])
                    if result['scores'].shape != (50, 10) or result['masks'].shape != (50, 2):
                        raise ValueError(f'Invalid MC sample shape at image{index}')
                    metrics = uncertainty(result['scores'])
                    match = None
                    if reference is not None:
                        checks = [reference.infer(images[index], int(mask[0]), int(mask[1])) == score.tolist()
                                  for mask, score in zip(result['masks'], result['scores'])]
                        match = all(checks)
                        mismatches += not match
                    prediction = metrics['prediction']
                    label = int(labels[index])
                    hit = prediction == label
                    scores[index] = result['scores']
                    masks[index] = result['masks']
                    completed += 1
                    correct += int(hit)
                    confusion[label, prediction] += 1
                    row = {key: metrics[key] for key in fields if key in metrics}
                    row.update(index=index, label=label, correct=int(hit),
                               unique_masks=len(np.unique(result['masks'], axis=0)),
                               elapsed_ms=result['elapsed_ms'], reference_match=match,
                               running_accuracy=correct / completed)
                    writer.writerow(row)
                    file.flush()
                    if completed % args.every == 0 or completed == 10000:
                        print(f'[{completed}/10000] label={label} pred={prediction} '
                              f'{"OK" if hit else "WRONG"} masks={row["unique_masks"]}/50 '
                              f'accuracy={correct}/{completed} ({correct/completed:.2%}) '
                              f'ref={match}', flush=True)
        except (Exception, KeyboardInterrupt) as exc:
            error = f'{type(exc).__name__}: {exc}'

    np.savez_compressed(out / 'samples.npz', scores=scores[:completed], masks=masks[:completed],
                        indices=np.arange(completed), labels=labels[:completed])
    complete = completed == 10000 and error is None
    summary = {
        'dataset': 'MNIST', 'split': 'test', 'requested_images': 10000,
        'completed_images': completed, 'iterations_per_image': 50,
        'completed_inferences': completed * 50, 'complete': complete, 'error': error,
        'correct': correct, 'accuracy': correct / completed if completed else None,
        'accuracy_scope': 'full_test_split' if complete else 'completed_subset_only',
        'aggregation': 'argmax(mean(softmax(scores/2048),axis=iteration))',
        'port': args.port, 'baud': 8000000, 'command': 4,
        'input_format': 'PC-normalized int8, scale32',
        'reference_checked': reference is not None, 'score_mismatch_images': mismatches,
        'confusion_matrix_label_by_prediction': confusion.tolist(),
        'wall_seconds': time.perf_counter() - started,
        'model_mem_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest()
                             for p in sorted(MODEL.glob('*.mem')) if not p.name.startswith('test_')},
    }
    (out / 'summary.json').write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    print(f'\nCompleted {completed}/10000; FPGA inferences={completed*50}; '
          f'score mismatch images={mismatches if reference is not None else "not checked"}')
    if completed:
        scope = 'MNIST test accuracy' if complete else 'Partial accuracy (not the full test set)'
        print(f'{scope}: {correct}/{completed} = {correct/completed:.4%}')
    print(f'Results: {out}')
    if error:
        print(error, file=sys.stderr)
    return int(not complete or mismatches > 0)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        sys.exit(1)
