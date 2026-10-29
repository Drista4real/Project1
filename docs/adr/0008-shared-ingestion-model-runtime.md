# Shared model runtime for text and voice ingestion

Date: 2026-10-29. Status: accepted, backend and Streamlit only.
Implementation: [#85](https://github.com/Drista4real/Project1/issues/85).

Models 1 and 3 form one transaction-input capability. Retain separate ASR and
classifier adapters: audio becomes text, then uses the same deterministic money
normalizer and category classifier as typed input. `ParseTransaction.execute_audio`
adds this composition through domain ports without a new upload route. Flutter,
its on-device runtime, Model 2 and Advisor are unchanged. Model 4 remains a
separate receipt extractor which already produces a receipt-level category.

The backend and Streamlit share one classifier loader per Python process. A lock
prevents duplicate initialization; a separate inference lock bounds simultaneous
model execution to one, avoiding competing CPU inference thread pools. This is
not a cross-process cache, a persistent job queue or a throughput guarantee.
Additional API workers each consume their own model memory. CPU thread count is
configurable, with the installed PyTorch default retained when unset.

FastAPI prepares and warms the classifier in lifespan startup by default. Warm-up
uses synthetic local text, never downloads weights or calls cloud providers.
Missing optional dependencies/artifacts or failed warm-up preserve process
liveness and existing classification fallback/review behavior. `/health` still
reports liveness; `/ready/ai` reports startup local-classifier warm-up (503 unless
successful). It is not readiness of cloud providers, ASR, database or all routes.
Disabling startup warm-up leaves this probe at `not_warmed`; lazy loading on later
requests does not update that startup report. CRUD-only deployments can keep
using `/health`. Restart after installing artifacts or changing runtime settings.

For LoRA, `CLASSIFIER_LORA_MERGE=true` opts into
`merge_and_unload(safe_merge=True)` in RAM. Original adapter/checkpoints remain
unchanged; serving and standalone construction default to unmerged. Local short
CPU runs did not establish a repeatable speed benefit, so merging is not enabled
by default. Set the option false for rollback. This does not combine ASR and PhoBERT
weights, quantize the model, or remove PhoBERT's memory requirement. Validate
category decisions and confidence around the 0.8 fallback threshold when changing
weights or runtimes.

Single-transaction cloud fallback reuses the already computed local draft rather
than running the classifier again. Amounts remain deterministic and the existing
fallback/schema/review policies remain in force. Combined multimodal fallback
from ADR 0004 remains disabled pending its own evaluation.

The backend owns one receipt adapter and async HTTP connection pool per lifespan.
The existing receipt dependency hook reuses it, refusing implicit mock results.
No receipt upload HTTP route is added. An externally supplied HTTP client remains
owned by its caller. Streamlit continues request-local cloud clients because it
creates a new asyncio loop per action; caching those clients across loops would
be invalid. Model 4's existing request timeouts and validation remain unchanged.

Streamlit adds an explicit local preparation button and per-stage timings.
An offline benchmark measures cold acquisition, warm classification and bounded
concurrent requests; these timings are not production HTTP load or quality tests.

## Local validation

On Windows CPU / Python 3.11.4 / six PyTorch threads, a fresh unmerged LoRA
process measured 11.69 s acquisition, 272 ms synthetic warm-up, warm p50 29.95 ms
and p95 35.15 ms over 60 varied synthetic inputs. A separate merged run measured
p50 32.04 ms and p95 37.87 ms. Two threads measured p50 40.11 ms. These short
sequential runs do not establish a speed benefit for merging or fewer threads;
defaults preserve unmerged inference and the installed thread count. Acquisition
includes imports and disk/cache effects; it is not a before/after speedup claim.

Comparing unmerged and safely merged weights in one process over the existing
200 evaluation CSV inputs changed zero labels and zero decisions at the 0.8
fallback gate; maximum confidence delta was 0.000002206. This is equivalence on
that corpus, not an independent model accuracy assessment. Cloud latency,
representative ASR speech and production HTTP load were not benchmarked. The
project deployment target remains Python 3.12+; local tests used available 3.11.4.
