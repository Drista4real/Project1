# Three physical AI tiers and modality-specific fallback

Date: 2026-10-18. Status: accepted target architecture; Streamlit prototype only.
Implementation ticket: [#59](https://github.com/Drista4real/Project1/issues/59).
Specification and documentation ticket: [#52](https://github.com/Drista4real/Project1/issues/52).
Automatic background fallback clarification: [#53](https://github.com/Drista4real/Project1/issues/53).
Shared orchestration and combined media request decision: [#56](https://github.com/Drista4real/Project1/issues/56).

The user's updated architecture has three physical tiers, independent of the
four logical Model 1–4 subsystems. Tier 1 is the Flutter device with PhoWhisper
INT8/sherpa-onnx ASR, basic normalization and review. SQLCipher and offline drafts
are target requirements, not established by the app lock in ADR 0001. Tier 2 is
the FastAPI application CPU server with Model 1 PhoBERT/LightGBM classification,
Model 2 LightGBM/EWMA quantitative forecasting and Redis/Celery orchestration.
Tier 3 provides Qwen document inference and task-specific Foundation API calls.
Provider-hosted APIs do not imply a self-managed GPU/vLLM deployment exists.

Model 3 transcribes audio, then sends validated/corrected text through Model 1.
Model 4 directly extracts receipt JSON including a receipt-level category. It
does not require a second classification pass through Model 1. Only readable
receipt descriptions whose categories remain unresolved use that shared path.
An item-level category extension needs its own schema change.

All model fallbacks run automatically in the background when a failure or quality
gate triggers. There is no Gemini button, per-request approval dialog or manual
correction prerequisite. Cloud-processing permissions are established before
using the feature. Manual editing/rerecording is recovery after automatic
processing cannot resolve the draft, including offline/unavailable-cloud cases.
This clarifies the earlier suggestion to rerecord/edit before invoking fallback.

Fallback follows the failing operation:

- Model 1: text classification to Gemini when `P_class < 0.8`, invalid labels or
  unavailable classifier; retain deterministic amount extraction.
- Model 3: automatically send original audio to a compatible Gemini audio endpoint
  initially when the local runtime fails or the transcript is empty. Additional
  ASR quality gates are enabled only after runtime signals are verified and
  calibrated. Retain audio temporarily until the automatic pipeline finishes.
  Transcript-only fallback output returns to Model 1. Offline ASR does not imply offline
  classification. ASR quality signals and thresholds still require design and
  validation; do not invent confidence values or use WER as a per-request score.
- Model 4: original image to a compatible Gemini multimodal endpoint if Qwen
  fails/times out, output is truncated or required-field/schema/arithmetic checks
  fail. Account for taxes, fees and discounts before rejecting arithmetic. Reapply
  schema, arithmetic and category validation. Category-only ambiguity uses Model 1.

A shared Tier 2 fallback orchestrator selects the smallest relevant input for
the failed operation. Usable Model 3 transcripts follow Model 1's normal path;
low classification confidence alone sends text, not original audio, to Gemini.
Keep ASR and receipt checks separate from classifier probability. Do not trigger
receipt rereading solely from an uncalibrated model-reported confidence value.

After task-specific quality evaluation, enable a combined media request: when
Gemini already receives audio or an image, request both extracted transaction
data and an allowed category in the same call. A complete validated result goes
directly to review, bypassing redundant Model 1/cloud classification. This
refines the earlier mandatory post-ASR Model 1 path, only for the combined media
fallback branch. Transcript-only output still uses the normal local classifier.
If the category remains unresolved, try Model 1 locally; if no cloud budget is
left, retain a needs-review draft instead of issuing another semantic cloud call.
The default budget permits one logical Gemini fallback request per input job,
with bounded transport retries, shared by extraction and classification. For a
multi-transaction input, use a batch rather than separate calls for each item.
Advisor is a separate job and budget, not a second ingestion fallback call.

Text category fallback cannot change amounts. Combined media extraction may
propose source-grounded amounts for previously unconfirmed drafts; normalize
and validate them in the backend, retain provenance and require user review.
Missing or conflicting amounts stay unresolved; never invent an amount or
override a user-confirmed value. Model 2 still owns balance/forecast arithmetic.

These share infrastructure, not one confidence score or input contract. ASR
quality and receipt validation must not reuse classifier probability. The
adapter's arithmetic-based 0.95/0.60 receipt scores are rule signals, not
calibrated probabilities. Correct schema/arithmetic cannot prove factual accuracy.

Gemini Advisor belongs to Model 2, even though its code currently lives beside
the receipt adapter. It explains quantitative outputs without recalculating or
overriding amounts, balances, runway, safe-to-spend or risk flags. Its local
template fallback also runs automatically, independently of the media fallback design.
Model versions and timeout/schema settings are task-specific; the user's 2.5
Flash proposal is not a guarantee that an endpoint/version is available.

Media fallback expands the earlier documented adapter rule that Qwen alone reads
receipts and Gemini only handles text/advice. The current phase implements these
experiments only in `frontend/demo_pipeline.py`, called by Streamlit. It adds
text classification, original-audio (WAV/M4A/MP3) transcription and original-image recovery,
sharing one Gemini call per analysis action, a 20-second timeout and one transport
attempt. The app's Flutter code, FastAPI routes and shared model adapters are
unchanged. App integration is explicitly deferred until models are evaluated.
Streamlit retains uploads in
its session until replaced/cleared; results retain fingerprints rather than raw
media. The demo does not write uploads to disk or use the provider Files API.
Cloud-processing permissions remain a deployment requirement. Target queues,
SQLCipher, GPU deployment and model performance are not claimed as shipped.
Advanced ASR gates and combined multimodal category extraction remain disabled
pending task-specific evaluation. See the Streamlit guide for runtime behavior.

Target orchestration bounds retries and provider switches, retains drafts after
failure and records separate transcription/extraction/classification provenance.
Invalid configuration is not retried indefinitely. Use a common per-job retry
budget (at most three retries), timeout and at most one provider fallback;
never alternate providers in a loop. Define media retention/deletion before
enabling upload. Schema-constrained generation still requires backend validation.
User confirmation precedes ledger writes; idempotency and draft version checks
prevent retries or late AI output from duplicating writes or overwriting edits.

See [SPECIFICATION sections 5.4–5.6](../SPECIFICATION.md#54-luồng-dữ-liệu-và-điểm-dùng-chung-model-1)
for dataflow, failure handling and the current implementation boundary. This
decision does not change the read-only generated-data boundary in ADR 0001 or
the management interactions in ADR 0002.
