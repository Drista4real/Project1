# Streamlit AI demo

This demo connects directly to the four adapters under `backend/app/infrastructure/ai/`.
The existing Flutter frontend can continue to run separately.

From the repository root, using the project's Python environment:

```powershell
python -m pip install -r frontend/requirements-demo.txt
python -m streamlit run frontend/app.py
```

The demo is available at `http://localhost:8501`. Paths are resolved relative to
the source file, so starting Streamlit from another working directory is supported.
Backend imports are lazy and do not load the FastAPI application. Cached local
adapters reuse CPU models across requests; the initial load can take longer.

The first screen supports text normalization/classification, uploaded PCM16 WAV
voice, and JPEG/PNG receipts. The classification source is `LOCAL` at P >=0.8 or
`CLOUD_FALLBACK` below that threshold. The latter is a routing hint; this demo
does not perform an additional cloud text classification call. Latency is shown.
Text/voice timings exclude initial model loading. Receipt timings include the
async extraction request and local arithmetic check.

Missing PhoWhisper ONNX files enable the adapter's visibly marked Mock mode.
Uploaded WAV analysis is blocked in that mode with an explicit missing-model
message, so uploaded audio never receives a fabricated transcription. After
installing weights, use the ASR reload button to clear the cached recognizer.
The quick voice button explicitly selects mock mode even when real weights are
loaded; uploaded WAV analysis uses the genuine model. The receipt sample button always
uses a deterministic Mock receipt and does not send data to a cloud provider.
Qwen2.5-VL handles receipt images; Gemini 2.5 Flash handles financial advice.
Missing `GEMINI_API_KEY` enables local advisor templates. Uploaded receipts are
blocked without a real Qwen client; they never produce a mock receipt.
Configure `OPENROUTER_API_KEY`, `QWEN_BASE_URL`, and `QWEN_MODEL` in ignored
`backend/.env`, or enter the key in the password field under `K?t n?i Qwen`.
The default route is `qwen/qwen-2.5-vl-7b-instruct`; the `:free` route can also be
selected if a provider is available. For DashScope, use its compatible-mode URL,
`DASHSCOPE_API_KEY`, and native model ID `qwen2.5-vl-7b-instruct`.
The Gemini password field is separate. Sidebar keys are session-only and are
not written to disk. Default test mode stays offline even when keys are present.
FPT Cloud uses `FPT_API_KEY`, `QWEN_BASE_URL=https://mkp-api.fptcloud.com/v1`,
and `QWEN_MODEL=Qwen2.5-VL-7B-Instruct` in the same ignored configuration file.
Every cloud client is opened, awaited with adapter timeouts, and closed within
the same task's event loop.

The dashboard lets you set a current balance, profile, and historical as-of date.
Date choices come from `balance_fixed.csv` or `balance_flexible.csv`; the default
is the last available observation. Fixed-income forecasting needs eight historical
balances and the delta checkpoint. The input balance shifts the history without
altering observed deltas. A selected payday changes the payday covariate,
countdown, and mismatch alert; the training data assumes day 5, so accuracy on
other payday schedules requires independent measurement. The chart shows 30
future days; a payday 31 days away has no balance estimate inside that horizon.

Flexible-income forecasts use either a constant user-entered daily expense or
recorded expenses through the selected date. Calculations are delegated to EWMA
Model 2; a zero burn rate displays unbounded runway. Persona advice consumes the
existing metrics and risk flags and never calculates numerical forecasts.
Charts show the initial balance, 30 future balances, and a horizontal zero line.
Changing the scenario hides old dashboard results until recalculation.

If data/checkpoints are missing, prepare them from the repository root:

```powershell
python backend/scripts/generate_synthetic_data.py
python backend/scripts/train_classifier.py
python backend/scripts/train_forecaster.py
```

To prepare the actual PhoWhisper-tiny INT8 model once:

```powershell
python -m pip install -r backend/requirements-asr-export.txt
python backend/scripts/prepare_asr_model.py
```

This downloads the official VinAI checkpoint, remaps its tensors with strict
shape/key checks, and uses a pinned, checksum-verified sherpa-onnx exporter.
The three runtime files are installed under `weights/onnx/phowhisper-tiny/`.
`manifest.json` records provenance and artifact hashes. Afterwards, click
`Nạp lại model ASR` in the Voice tab; inference runs without downloads.

Missing files/dependencies and malformed uploads produce friendly messages.
This page is a local model demo; results are not written to financial accounts.
