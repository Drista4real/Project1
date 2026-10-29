# Model 1: Vietnamese transaction classification

## LoRA backend for the October 2026 demo

The standalone Streamlit demo (`frontend/app.py`) also honors this configuration
and loads the classifier directly. It does not need an API server. From the
repository root, using the prepared Python environment:

```powershell
python -m pip install -r frontend/requirements-demo.txt
python -m streamlit run frontend/app.py
```

The backend can select the trained LoRA adapter through `backend/.env`:

```dotenv
CLASSIFIER_BACKEND=lora
CLASSIFIER_DEVICE=cpu
```

Default paths are `weights/checkpoints/classifier_lora/` for the full adapter
folder and `weights/cache/phobert-lora/` for the base-model cache. Override with
absolute `CLASSIFIER_LORA_DIR` and `CLASSIFIER_LORA_CACHE_DIR` if needed.
The approved run is `20261018T090941Z_baf75057`, best epoch 9 of 10,
dataset `dataset_02f0e7a1e54a4973ef079e01`. Its test Macro F1 is 0.898825;
the 200-example synthetic development evaluation has 193 correct predictions.
These measurements do not establish real-world accuracy.

Using the Python environment that will run the API, from the repository root:

```powershell
python -m pip install -r backend/requirements.txt -r backend/requirements-lora-inference.txt
python backend/scripts/prepare_lora_model.py
python backend/scripts/prepare_lora_model.py --local-files-only
python -m uvicorn app.main:app --app-dir backend --host 127.0.0.1 --port 8000
```

Preparation downloads the exact base revision pinned in `lora_config.json`,
then reloads the adapter and verifies a prediction offline. It does not train.
It prints the configured device, revision, category, confidence and one warmed
prediction timing. API inference always uses `local_files_only=True` and loads
one classifier lazily per process. The first request can take longer because
it loads the model; send a demo transaction before the presentation.

LoRA implements the same `classify()` contract as LightGBM. Amount extraction,
income/transfer handling, confidence routing and editable drafts retain their
existing flow. Low-confidence predictions may call Gemini when configured;
review is still required for inaccurate high-confidence suggestions.

Set `CLASSIFIER_BACKEND=lightgbm` and restart the API to switch back. If the
selected classifier cannot load, the parser logs the error and follows its
existing cloud/rule/manual-review flow; it does not silently switch models.

The trained `adapter_model.safetensors` alone is insufficient: preserve the
adapter configuration, saved tokenizer, `lora_config.json` and pinned base cache.
Keep `metrics.json`, `training_config.json` and the data manifest for provenance.

The adapter inherits `ITransactionClassifier` and preserves
`classify(text) -> ClassificationResult` for existing application use cases.
`predict(text)` additionally returns `(category, confidence, source)`;
`source` is `LOCAL` at confidence >= 0.8 and `CLOUD_FALLBACK` otherwise.
The latter is a routing signal for an application orchestrator to enqueue Gemini.

## Setup after cloning (no training)

From the repository root, using the Python environment that runs the backend:

```powershell
python -m pip install -r backend/requirements-classifier.txt
python backend/scripts/download_classifier_model.py
```

The three classifier checkpoint files are already tracked in Git. This script
reads `weights/checkpoints/classifier_config.json`, downloads missing PhoBERT
files into `weights/cache/phobert/`, then reloads with downloads disabled and
verifies a real 768-dimensional embedding. It reuses cached files and does not
train or modify checkpoints/configuration. Internet is needed only for missing
files; no teammate account or API key is required for the public model.

To verify an existing cache without downloading:

```powershell
python backend/scripts/download_classifier_model.py --local-files-only
```

`--config PATH` selects another compatible classifier configuration.
`--cache-dir PATH` is optional; application inference must use that same cache
path if you change it. The script honors the revision in the configuration;
`main` uses a cached branch reference when available and is not an immutable
version pin. Share a configuration with a fixed model commit for reproducibility.
This prepares the PhoBERT + LightGBM pipeline; separately trained LoRA adapters
must be distributed with their own inference artifacts.

## Training

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
saved in the JSON file. Inference only reads cached model files. Use the setup
script above on the inference host, or copy the cache and all three artifacts.
`--cache-dir PATH` changes the
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
