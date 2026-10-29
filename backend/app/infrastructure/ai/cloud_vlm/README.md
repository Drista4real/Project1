# Model 4: receipt VLM and persona advice

Architecture note (2026-10-18): Model 4 owns receipt extraction, including its
receipt-level category; a Model 1 pass is optional for category-only ambiguity.
The Advisor belongs to Model 2 even though its adapter lives in this directory.
[ADR 0003](../../../../../docs/adr/0003-three-tier-ai-and-modality-fallback.md)
and [the target specification](../../../../../docs/SPECIFICATION.md#55-ma-trận-fallback-theo-công-đoạn)
define Gemini multimodal fallback that rereads the original image when Qwen
extraction fails. The prototype is implemented only in the standalone Streamlit
demo (`frontend/demo_pipeline.py`). Flutter, FastAPI and these shared model
adapters remain unchanged; app integration is a later phase.
Configure compatible `GEMINI_AUDIO_MODEL` and `GEMINI_RECEIPT_MODEL` endpoints
for demo fallback. Fallback runs automatically in the background, without a Gemini
button or per-request approval dialog. User review before saving is separate
from fallback execution; manual correction is recovery if automation fails.
The target Tier 2 fallback orchestrator chooses text/audio/image by the failing
operation. Qwen extraction fallback triggers on errors/timeouts, truncated output,
schema/required-field failures or arithmetic inconsistency after accounting for
documented tax, fees and discounts. A self-reported confidence field is not a
calibrated probability. Category-only ambiguity uses Model 1, not image rereading.
After task-specific evaluation, a single Gemini media request may return both
extracted data and an allowed category. A complete validated result goes straight
to review; do not reclassify it in another cloud call. If the category is unresolved,
try the local classifier and retain a needs-review draft once the shared cloud
budget is exhausted. Demo orchestration is implemented; app orchestration and
combined semantic media extraction/category output await evaluation/integration.

Schemas use Pydantic v2 with forbidden extra fields, strict integer VND amounts,
positive item quantities, six Vietnamese categories, finite confidence in [0,1],
and valid ISO dates or null. Qwen2.5-VL extracts receipt documents only using
async `httpx` and the OpenAI-compatible chat completions API. Requests include
Base64 images and a JSON schema prompt. FPT Cloud requests send
`response_format=json_schema` with `strict=true`; other routes use JSON mode.
Every response is strictly validated by Pydantic before use; JSON mode alone
does not guarantee schema compliance. Gemini uses the asynchronous Google Gen AI
SDK with `response_json_schema`; Advisor behavior remains unchanged.
The receipt parser strips a complete JSON Markdown fence and converts Vietnamese
day/month/year dates (with `/`, `-`, or `.` separators and a four-digit year) to
ISO dates before validation. Invalid dates, two-digit years, incorrect money
types, extra fields, and unsupported categories remain rejected.
Gemini also categorizes text in the authenticated `/api/v1/ingestion/text`
endpoint when the local classifier is unavailable or below its confidence
threshold. Money normalization remains deterministic and local. The Streamlit
demo now performs actual text category fallback through its separate pipeline.

Configure `OPENROUTER_API_KEY`, `QWEN_BASE_URL` (default
`https://openrouter.ai/api/v1`) and `QWEN_MODEL` (default
`qwen/qwen-2.5-vl-7b-instruct`). The optional `:free` route requires an available
provider. Route availability must be checked independently of key validity.
DashScope uses its compatible-mode base URL, `DASHSCOPE_API_KEY`, and native
`qwen2.5-vl-7b-instruct` model ID. No automatic provider/model substitution occurs.
Advisor credentials remain separate: `GEMINI_API_KEY`, with
`GEMINI_MODEL=gemini-3.8-flash` in the current environment template. The original
specification used 2.5 Flash; newer accounts may receive a model-unavailable
response for that version. The demo uses `GEMINI_INPUT_MODEL` for text and
separate `GEMINI_AUDIO_MODEL`/`GEMINI_RECEIPT_MODEL` overrides for media
(otherwise `GEMINI_INPUT_MODEL`). Model access must be checked for the account.

The demo's Gemini client allows one logical request/one transport attempt with
a 20-second timeout; Qwen uses 15 seconds. It sends original media inline, then
validates output independently. Transcript recovery and unresolved image categories
use local classification once that budget is spent. Its extended receipt schema
supports separately printed tax/fee/discount adjustments without changing the
shared adapter schema. The low-level Qwen adapter still has its original line/total
check; disagreement triggers a fresh image read in the demo. See the
[Streamlit guide](../../../../../frontend/STREAMLIT_DEMO.md) for formats, limits,
configuration, memory retention, testing and remaining quality evaluation.

FPT Cloud is also supported: set `FPT_API_KEY`,
`QWEN_BASE_URL=https://mkp-api.fptcloud.com/v1`, and
`QWEN_MODEL=Qwen2.5-VL-7B-Instruct`. Requests explicitly disable streaming.
The adapter accepts both standard completions and FPT's documented
`{code, message, data}` response envelope. See the
[FPT model API example](https://marketplace.fptcloud.com/en/models/qwen2.5-vl-7b-instruct).
Validation errors expose only known field paths and locally generated messages,
never rejected values, response contents, or credentials. Completions cut off
by the token limit produce a separate `truncated` error.

Install from the repository root:

```powershell
python -m pip install -r backend/requirements-cloud-vlm.txt
```

Supply the appropriate provider key through the environment, or pass `api_key=` (a string or
Pydantic SecretStr) from your configuration. No key enables mock mode. Adapters
also read local `backend/.env` or repository-root `.env` when no environment
key is set; these files are ignored by Git. An explicitly set environment
variable, including an empty value, takes precedence over local dotenv files.
Tests automatically enable mock mode even if a key is present, unless the constructor
explicitly uses `test_mode=False`. The latter is used with HTTP/SDK doubles in tests;
it enables real cloud mode outside tests. `is_mock` exposes the current mode.
An explicit empty key disables cloud calls regardless of the environment.

All public extraction and advisor operations are asynchronous. Each request has
both a provider HTTP timeout and an outer asyncio deadline. Defaults
are 15 seconds for receipt extraction and 10 seconds for advice. Call `aclose()`
when the adapter is no longer needed to release client resources.

From `backend/`:

```python
from pathlib import Path
from app.infrastructure.ai.cloud_vlm.schemas import ReceiptExtractionResult
from app.infrastructure.ai.cloud_vlm.client import QwenVLMReceiptExtractor


async def inspect_receipt() -> ReceiptExtractionResult:
    extractor = QwenVLMReceiptExtractor()
    try:
        result = await extractor.extract_receipt(Path("receipt.jpg").read_bytes())
        return result
    finally:
        await extractor.aclose()
```

`extract_receipt` returns `ReceiptExtractionResult`. The protocol method
`await extract(image, mime_type)` returns vendor-neutral `ReceiptData`, retaining
items, category, confidence, and arithmetic validity so the application can
request confirmation. The domain protocol, `IngestReceipt.execute`, and the
legacy receipt hook use async/await. Domain/application layers do not import SDKs
or Pydantic schemas. Accepted images are nonempty bytes with JPEG, PNG, or WebP
MIME types.

Arithmetic is computed only in Python:

```text
items_sum = sum(quantity * price)
valid = nonempty items and abs(items_sum - total_amount) * 20 <= total_amount
```

The denominator is the printed total. A difference exactly equal to 5% is valid.
Nonempty zero-price items with a zero total are valid; no items is always invalid.
Valid extractions receive confidence 0.95; all other arithmetic results receive
0.60. Model-provided confidence and arithmetic flags are overwritten. A total
is not altered to force agreement. The mock receipt is visibly labeled MOCK.
Live transport failures, rate limits, malformed JSON, or schema violations raise
`CloudVLMError`; they never produce a fabricated receipt. Application workers may
enqueue/retry those failures according to their task policy.

`PersonaFinancialAdvisor` inherits the domain `IFinancialAdvisor`. Its methods
consume already computed Model 2 metrics and flags. They never calculate a new
balance, runway, burn rate, or safe spending limit. `alert_flag=False` returns
`SAFE` locally without a Gemini request. True flags select `CASHFLOW_MISMATCH`
for fixed income and `WINDFALL_DEPLETION` for flexible income. Model 2's
unbounded runway representation (`None`) is accepted.

Gemini receives the persona and metrics but is asked to produce qualitative
Vietnamese prose without numbers. A changed risk type, numeric prose, timeout,
or invalid response uses a deterministic local warning. Messages are capped at
two sentences. For flexible income, Python formats and inserts the supplied
`safe_to_spend` into the message; the LLM cannot invent a different daily limit.
Mock advice uses the same warning templates.

Run unit tests and lint from the repository root:

```powershell
python -m pytest -c tests/pytest.ini tests/test_cloud_vlm.py tests/test_qwen_vlm.py -q
python -m ruff check --config backend/pyproject.toml backend/app/infrastructure/ai/cloud_vlm tests/test_cloud_vlm.py
```

Tests use AsyncMock clients and synthetic responses. No live provider requests or
real API credentials are required. They validate the HTTP and SDK call contracts and local
logic; actual receipt extraction quality requires real images and a live model.
