# Model 1: Vietnamese transaction classification

The adapter inherits `ITransactionClassifier` and preserves
`classify(text) -> ClassificationResult` for existing application use cases.
`predict(text)` additionally returns `(category, confidence, source)`;
`source` is `LOCAL` at confidence >= 0.8 and `CLOUD_FALLBACK` otherwise.
The latter is a routing signal for an application orchestrator to enqueue Gemini.

For the five-source Model 1 dataset prepared on 2026-10-18, use the frozen
bundle and `--dataset-dir` rather than regenerating synthetic data. See
[merged dataset handoff](../../../../../docs/MODEL1_MERGED_DATASET.md).
From the repository root:

```powershell
python backend/scripts/train_classifier.py --dataset-dir data/prepared/model1_merged_1000_per_label_20261018/bundle_v2
```

From the repository root, install the optional NLP dependencies and train:

```powershell
python -m pip install -r backend/requirements-classifier.txt
python backend/scripts/generate_synthetic_data.py --transactions-only
python backend/scripts/train_classifier.py
```

Provide `data/processed/data_transactions.csv` as UTF-8, with exactly `text` and
`category` columns. All six labels must be represented: Ăn uống, Đi lại, Mua sắm,
Hóa đơn/Nhà ở, Y tế, Khác. Each class needs at least two samples and the dataset
must be large enough to represent six classes in both portions of the 80/20 split.
The generator overwrites `data_transactions.csv` with 1,500 balanced synthetic
transactions: 250 per category, with 175 clear and 75 abbreviated, mistyped, or
slang texts in each category. Seed 42 makes generation reproducible. The legacy
`transactions.csv` is not used by the default training command.

The script uses lowercase text, normalized whitespace, and
`underthesea.word_tokenize(text, format="text")` in both training and inference.
PhoBERT runs in evaluation mode, on CPU, under `torch.no_grad()`. The first token
of the final hidden state is the 768-dimensional CLS feature. Sequences are
truncated to 256 tokens; training uses dynamically padded batches.

Training prints the classification report, Macro F1, local handling rate, and
mean/p95 warmed single-sentence CPU latency including segmentation, PhoBERT, and
LightGBM. The <15ms, F1 >=88%, and local rate >=75% specification targets require
measurement on representative data and hardware; the implementation does not
guarantee those results. Latency measurements exclude initial model loading.

Three artifacts are saved to `weights/checkpoints/`:

- `lgbm_classifier.pkl`: fitted LightGBM model.
- `label_encoder.pkl`: sorted mapping of the six Vietnamese labels.
- `classifier_config.json`: versioned preprocessing, model revision, token limit,
  CLS pooling, feature size, and routing threshold.

PhoBERT downloads are cached in `weights/cache/phobert/`; its resolved revision is
saved in the JSON file. Inference only reads cached model files. Copy that cache
and all three artifacts to the inference host. `--cache-dir PATH` changes the
training cache location; pass the same path to the inference embedder when using
a custom location. `--local-files-only` trains without network access when the
cache is already populated. Pickle artifacts must come from a trusted training run.

Run inference from `backend/`:

```python
from app.infrastructure.ai.classifier.lgbm_inference import (
    LightGBMTransactionClassifier,
)

classifier = LightGBMTransactionClassifier()  # Reuse for subsequent requests.
category, confidence, source = classifier.predict("ăn trưa 40k")
```

Contract tests use real LightGBM with deterministic PhoBERT doubles, without model
downloads. From the repository root:

```powershell
python -m pytest -c backend/pyproject.toml --confcutdir=backend/tests/classifier backend/tests/classifier -q
```
