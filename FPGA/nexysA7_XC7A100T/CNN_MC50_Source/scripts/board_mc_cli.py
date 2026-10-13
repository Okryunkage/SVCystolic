"""MC50 UART evaluation: default 900 MNIST + 50 KMNIST + 50 Fashion-MNIST."""
import argparse
import csv
from datetime import datetime
import hashlib
import json
from pathlib import Path
import sys
import time
import numpy as np
from board_client import Board, Reference, ROOT, MODEL, ports
from ood_data import load_dataset, mixed_indices
from mc_metrics import uncertainty, auroc


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port')
    parser.add_argument('--id-count', type=int, default=900)
    parser.add_argument('--kmnist-count', type=int, default=50)
    parser.add_argument('--fashion-count', type=int, default=50)
    parser.add_argument('--seed', type=int, default=42)
    parser.add_argument('--download', action='store_true')
    parser.add_argument('--download-only', action='store_true')
    parser.add_argument('--list-ports', action='store_true')
    parser.add_argument('--verify-scores', action='store_true', help='Check every iteration using its returned masks')
    parser.add_argument('--quiet', action='store_true')
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    if args.list_ports:
        print(json.dumps(ports(), ensure_ascii=False, indent=2)); return 0
    counts = {'mnist': args.id_count, 'kmnist': args.kmnist_count, 'fashion': args.fashion_count}
    selection = mixed_indices(counts, args.seed)
    datasets = {name: load_dataset(name, args.download or args.download_only) for name, n in counts.items() if n}
    if args.download_only:
        print('Test datasets ready'); return 0
    if not args.port or not selection:
        parser.error('--port and at least one image are required')
    out = args.output or ROOT / 'output/mc50_runs' / datetime.now().strftime('%Y%m%d_%H%M%S_%f')
    out.mkdir(parents=True, exist_ok=True)
    if any(out.iterdir()):
        parser.error('Use an empty output directory')
    ref = Reference() if args.verify_scores else None
    rows, samples, masks = [], [], []
    error = None; mismatch_count = 0
    fields = ['dataset','index','is_ood','source_label','prediction','id_correct','confidence',
              'predictive_entropy','expected_entropy','mutual_information','elapsed_ms','unique_masks','reference_match']
    started = time.perf_counter()
    with (out/'results.csv').open('w', newline='', encoding='utf-8') as file:
        writer = csv.DictWriter(file, fieldnames=fields); writer.writeheader()
        try:
            with Board(args.port) as board:
                for name, index in selection:
                    images, labels = datasets[name]
                    result = board.infer_mc(images[index])
                    metrics = uncertainty(result['scores'])
                    match = None
                    if ref:
                        checks = [ref.infer(images[index], int(mask[0]), int(mask[1])) == score.tolist()
                                  for mask, score in zip(result['masks'], result['scores'])]
                        match = all(checks)
                        mismatch_count += not match
                    row = {k:metrics[k] for k in fields if k in metrics}
                    row.update(dataset=name,index=index,is_ood=int(name!='mnist'),source_label=int(labels[index]),
                               id_correct=int(metrics['prediction']==labels[index]) if name=='mnist' else '',
                               elapsed_ms=result['elapsed_ms'],unique_masks=len(np.unique(result['masks'],axis=0)),reference_match=match)
                    rows.append(row); samples.append(result['scores']); masks.append(result['masks'])
                    writer.writerow(row); file.flush()
                    if not args.quiet or len(rows)%25==0 or len(rows)==len(selection):
                        print(f"[{len(rows)}/{len(selection)}] {name}[{index}] {'OOD' if name!='mnist' else 'ID'} "
                              f"pred={row['prediction']} confidence={row['confidence']:.4f} "
                              f"H={row['predictive_entropy']:.4f} MI={row['mutual_information']:.4f} "
                              f"masks={row['unique_masks']}/50 ref={match}",flush=True)
        except (Exception, KeyboardInterrupt) as exc:
            error=f'{type(exc).__name__}: {exc}'
    score_array=np.asarray(samples,dtype=np.int32).reshape(-1,50,10)
    mask_array=np.asarray(masks,dtype=np.uint16).reshape(-1,50,2)
    np.savez_compressed(out/'samples.npz',scores=score_array,masks=mask_array,
                        datasets=np.array([r['dataset'] for r in rows]),indices=np.array([r['index'] for r in rows]))
    id_rows=[r for r in rows if not r['is_ood']]; ood_rows=[r for r in rows if r['is_ood']]
    metric_names=['predictive_entropy','expected_entropy','mutual_information','confidence']
    summary={'date':datetime.now().isoformat(),'requested_counts':counts,'completed':len(rows),
             'input_format':'normalized int8, scale32, host float32 rint','command':4,
             'iterations':50,'seed':args.seed,'port':args.port,'baud':8000000,'error':error,
             'complete':len(rows)==len(selection) and error is None,'id_correct':sum(r['id_correct'] for r in id_rows),
             'id_accuracy':sum(r['id_correct'] for r in id_rows)/len(id_rows) if id_rows else None,
             'score_mismatch_images':mismatch_count,'reference_checked':bool(ref),'wall_seconds':time.perf_counter()-started,
             'nominal_drop_probabilities':[.125,.1875], 'uncertainty_units':'nats',
             'model_mem_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in MODEL.glob('*.mem') if not p.name.startswith('test_')},
             'groups':{name:{'count':len(group),**{metric:float(np.mean([r[metric] for r in group])) if group else None for metric in metric_names}}
                       for name,group in [(n,[r for r in rows if r['dataset']==n]) for n in counts]},
             'ood_auroc':{metric:auroc([r[metric] for r in id_rows],[r[metric] for r in ood_rows])
                          for metric in ['predictive_entropy','mutual_information']},
             'notes':['OOD labels are not digit ground truth; accuracy is ID-only.',
                      'Higher uncertainty is not a guaranteed OOD decision; no rejection threshold is fitted.',
                      'Seed controls dataset selection, not the physical RNG.']}
    if len(mask_array):
        summary['observed_drop_probabilities']=[float(np.mean([1-int(v).bit_count()/width for v in mask_array[:,:,i].ravel()]))
                                               for i,width in enumerate((8,16))]
    (out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    print(f"\nCompleted {len(rows)}/{len(selection)}; ID accuracy={summary['id_accuracy']}; score mismatch images={mismatch_count}")
    print(f"OOD AUROC: {summary['ood_auroc']}\nResults: {out}")
    if error: print(error,file=sys.stderr)
    return int(error is not None or mismatch_count>0)


if __name__=='__main__':
    try: sys.exit(main())
    except Exception as exc:
        print(f'ERROR: {exc}',file=sys.stderr); sys.exit(1)
