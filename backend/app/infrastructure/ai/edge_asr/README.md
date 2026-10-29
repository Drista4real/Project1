# Model 3: offline Vietnamese financial speech

`SherpaOnnxRecognizer` inherits the pure-domain `IAudioTranscriber`. It uses
`sherpa_onnx.OfflineRecognizer.from_whisper` with CPU, Vietnamese (`vi`), and
the `transcribe` task. Each call creates a separate decoding stream and reuses
the loaded model. The adapter never downloads models or contacts a cloud service.
The SDK method follows the [official sherpa-onnx implementation](https://github.com/k2-fsa/sherpa-onnx/blob/master/sherpa-onnx/python/sherpa_onnx/offline_recognizer.py).

Install the optional runtime from the repository root:

```powershell
python -m pip install -r backend/requirements-asr.txt
```

Download the pinned, pre-exported model from the repository root:

```powershell
python backend/scripts/download_asr_model.py
```

For private repositories, run `gh auth login` and add `--github-cli`.
Downloads are verified against the tracked manifest. See
[team setup and release publication](../../../../../docs/MODEL3_SETUP.md).

To generate compatible INT8 exports from the official `vinai/PhoWhisper-tiny`
checkpoint, run once from the repository root:

```powershell
python -m pip install -r backend/requirements-asr-export.txt
python backend/scripts/prepare_asr_model.py
```

Preparation downloads happen only in this setup script. The pinned sherpa-onnx
exporter is verified by SHA256 before execution, mapped tensor keys/shapes must
match exactly, and quantized ONNX graphs are checked before installation.
Runtime inference stays offline. A provenance manifest includes source/exporter
revisions and SHA256 hashes. Model download/export cache is separate from runtime
files, under `weights/cache/asr-export/`.

Place compatible PhoWhisper-tiny INT8 exports in
`weights/onnx/phowhisper-tiny/`:

- `encoder.int8.onnx` and `decoder.int8.onnx` (preferred), or `encoder.onnx` and
  `decoder.onnx` containing the exported quantized models.
- `tokens.txt` from the same export.

The SDK loads supplied weights; filenames alone do not verify quantization.
Model-present load or decoding failures raise contextual errors. Missing or
zero-byte model files automatically enable a deterministic mock, logged as a
warning and exposed as `is_mock=True`. Default mock text is `cơm sườn ba lăm k`.
Use `allow_mock=False` to require real models in a deployment. Mock mode does
not need missing artifacts if explicitly requested with `mock_mode=True`. It
not read, decode, or validate audio contents: its output is a synthetic fixture.

From `backend/`:

```python
from app.infrastructure.ai.edge_asr.recognizer import SherpaOnnxRecognizer

recognizer = SherpaOnnxRecognizer()
text, amount = recognizer.transcribe_and_normalize("recording.wav")
```

Inputs are WAV paths (`str`/`Path`), WAV bytes, or headerless mono PCM16
little-endian bytes. WAV supports uncompressed 16-bit mono or stereo; stereo
is averaged to mono. The WAV header supplies its sample rate. Raw PCM buffers
use the `sample_rate` argument, default 16,000 Hz. Samples passed to sherpa-onnx
are mono float32 in [-1, 1]. MP3/other compressed formats are unsupported.

`VietnameseFinancialSlangNormalizer.normalize(text)` returns normalized text
and its first monetary amount (or `None`). It normalizes Unicode to NFC,
lowercases, collapses whitespace, and replaces all recognized amounts with
`<integer> đồng`. Multiple amounts are not added together.

Deterministic conventions:

| Input convention | VND multiplier / interpretation |
|---|---|
| `k`, `cành`, `nghìn`, `ngàn` | 1,000 |
| `lít`, `loét`, `xị` | 100,000 (Northern `lít`, Southern `xị`) |
| `củ`, `triệu`, `tr` | 1,000,000 |
| `tỷ`, `tỉ` | 1,000,000,000 |
| `rưỡi` after a unit | Add half of that unit |
| `1tr5`, `3tr5` | 1,500,000 and 3,500,000 |
| `1 triệu 2`, `một củ hai` at a clause end | 1,200,000 (units ≥ 100,000 only) |
| `2 triệu 500 nghìn`, `1 tỷ 200 triệu` | One amount when units descend |
| `50k đồng`, `50 nghìn vnđ` | 50,000 (trailing currency word is absorbed) |
| `năm chục`, `ba chục` without another unit | 50,000 and 30,000 |
| `ba lăm k`, `ba mươi lăm k` | 35,000 |

Spoken numbers support single digits, tens, and hundreds. Bare numbers with
no currency unit are not interpreted as money. Signed or unsupported phrases
remain unchanged. `3 triệu một tháng` stays 3,000,000 because the remainder is
not at a clause end; `50k 20k` stays two amounts because the units do not
descend. Dots or commas in groups of three indicate thousands (`50.000 đồng`,
`1,500,000đ`);
decimal commas/dots support forms such as `12,5k` and `1.5 triệu`. `lít` is
interpreted as a money unit in this financial normalizer, not as a volume unit.

Run tests and lint from the repository root:

```powershell
python -m pytest tests/test_edge_asr.py -q
python -m ruff check --config backend/pyproject.toml backend/app/infrastructure/ai/edge_asr tests/test_edge_asr.py
```

Tests use local SDK doubles for the model-present branch, without network access
or ONNX downloads. Actual WER and device latency require real exported weights
and representative Vietnamese audio.
