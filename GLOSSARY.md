# Shared domain glossary

- **Guest**: a Supabase anonymous user with a private UID and server-stored finance
  data. It requires a network connection and a retained session until linked.
- **Email linking**: verifying an email on the current guest identity, retaining
  its UID and financial records. It does not merge two existing accounts.
- **Recovery OTP**: an email code verified for password recovery before setting
  a new password. It is distinct from the code used for passwordless sign-in.
- **Physical AI tier**: deployment location, distinct from a logical Model 1–4
  subsystem. Tier 1 is the user device; Tier 2 is the application CPU backend;
  Tier 3 is cloud GPU inference/Foundation APIs. “Local” classification is on
  Tier 2, not necessarily on the user device.
- **Automatic background fallback**: the pipeline invokes the configured backup
  when a model fails or its quality gate is not met. Every model's fallback runs
  without a Gemini button or per-request approval dialog. Manual recovery is
  offered only when automatic processing cannot resolve the draft; final review
  before saving is separate from triggering fallback.
- **Fallback orchestrator**: the shared Tier 2 backend component that chooses
  text, original audio or original image according to the failing operation,
  validates the result and enforces a common cloud-call/retry budget. Low Model 1
  classification confidence alone does not trigger audio or image re-extraction.
- **Combined multimodal fallback**: one Gemini audio/image request proposes both
  source-grounded extracted data and an allowed category. A complete validated
  result goes to review without another cloud classification call. Enable this
  route only after task-specific quality evaluation; otherwise keep the normal
  extraction-to-local-classification path within the same cloud-call budget.
- **Classification fallback**: automatically resolve a category from usable text when Model 1
  is unavailable or below its confidence threshold. Typed text, Model 3
  transcripts and readable Model 4 descriptions share this path.
- **Modality fallback**: recover the input itself from original audio (Model 3)
  or an original receipt image (Model 4). Classification fallback cannot recover
  transcription or document extraction errors. Cloud-processing permissions are
  established before using the feature, not requested for each fallback.
- **Transaction draft**: an unpersisted proposed transaction that the user can
  review and edit. AI job completion does not mean a ledger transaction exists;
  user confirmation and a successful save are required.
- **AI Advisor**: the language branch of Model 2 that explains existing forecast
  metrics and risk flags. It does not calculate or override financial quantities.

- **Generated finance data**: cashflow forecasts, cashflow alerts, AI consultations,
  chat sessions and chat messages produced by the system. The app exposes reading;
  generic manual CRUD is unavailable. Alert read/resolve are separate user actions.
- **App lock**: a device authentication gate protecting the visible finance app
  after startup or loss of focus. It is distinct from signing in to an account.
- **Daily reminder**: an opt-in notification on the current device reminding the
  signed-in account to record transactions at a selected local time.
- **Filtered report**: an XLSX or PDF containing every transaction matching the
  selected date range, search query and tags. A wallet transfer is not income or
  spending when calculating report totals.
