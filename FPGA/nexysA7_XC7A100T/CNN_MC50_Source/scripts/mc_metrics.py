"""Host-side mean softmax and uncertainty. Entropies are in nats."""
import numpy as np


def uncertainty(scores):
    scores = np.asarray(scores, dtype=np.float64)
    if scores.ndim != 2 or scores.shape[1] != 10 or len(scores) < 2 or not np.isfinite(scores).all():
        raise ValueError('Expected finite [iterations,10] scores')
    logits = scores / 2048.
    logits -= logits.max(axis=1, keepdims=True)
    exp = np.exp(logits)
    probabilities = exp / exp.sum(axis=1, keepdims=True)
    mean = probabilities.mean(axis=0)
    predictive = float(-(mean * np.log(np.maximum(mean, 1e-300))).sum())
    expected = float(-(probabilities * np.log(np.maximum(probabilities, 1e-300))).sum(axis=1).mean())
    return {'prediction': int(mean.argmax()), 'confidence': float(mean.max()),
            'predictive_entropy': predictive, 'expected_entropy': expected,
            'mutual_information': max(0., predictive - expected), 'mean_probabilities': mean.tolist()}


def auroc(id_values, ood_values):
    # OOD is positive; higher scores mean more uncertain. Exact tie handling.
    a, b = np.asarray(id_values), np.asarray(ood_values)
    if not len(a) or not len(b):
        return None
    return float(((b[:, None] > a).sum() + .5*(b[:, None] == a).sum()) / (len(a)*len(b)))
