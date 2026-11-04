# Shared domain glossary

- **Current assets**: the sum of wallet balances owned by the user and marked
  `is_included_in_total`. Opening wallet balances contribute to assets; monthly
  income is calculated from income transactions. Archiving a wallet does not
  change its inclusion flag.
- **Envelope capacity**: an explicitly configured pillar allocation or monthly
  budget against which the sum of category limits is checked. Category and parent
  limits describe nested allocations and are not added together as assets.
- **Initial wallet income**: newly received money explicitly recorded as a ledger
  income while creating a wallet. It increases assets once and contributes to
  income reports. An unused existing opening balance can be explicitly
  reclassified once as income, preserving the wallet balance.
- **Transaction tag**: a user-owned label linked to a transaction through
  `transaction_tags`. A `#hashtag` search matches attached tag names, ignoring
  Vietnamese tone marks and spaces; ordinary search also examines notes.

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

- **Budget plan**: a deterministic projection of a spending plan over a number of
  days, built from total income, fixed expenses, a savings target and a duration.
  It holds a spendable budget, a daily allowance, a survival floor and a daily
  allocation per planning group. It projects `public.budgets`; it never replaces
  the configured envelope limits, which stay the source of truth.
- **Survival floor**: the minimum daily allowance a plan may fall to before a
  purchase is classified as critical. It is derived from the fixed expenses per
  day and can be overridden by the user.
- **Planning group**: one of `food`, `transport` or `lifestyle`. Every group maps
  to exactly one envelope pillar: `food` and `transport` to `needs`, `lifestyle`
  to `wants`, and `other` to `unexpected`.
- **Rebalance**: a confirmed change of the remaining daily allocation after a
  purchase. It reduces cuttable pillars in a fixed order (`wants`, `culture`,
  `unexpected`) and never drops a funded pillar below its existing category
  limits. The allocation, the purchase, the actual spend and the plan version
  are written in one database transaction.
- **Purchase impact**: the deterministic verdict for a proposed purchase:
  `SAFE`, `WARNING_REBALANCE_NEEDED`, `CRITICAL_DANGER` or `INSUFFICIENT_DATA`.
  The engine never estimates when the balance history is too short.
- **Plan screen**: the screen that shows a budget plan: the daily allowance, the
  survival floor, the split across the four pillars and the planning groups, and
  the day-by-day projection. It renders the engine's figures and computes none
  of them.
- **Remaining plan budget**: the spendable budget of a plan minus the confirmed
  spending recorded inside the plan window. It is read from real rows, not
  projected; a plan without a projection has no known remaining budget.

- **Conversational canvas**: the home screen of the app. It hosts the assistant
  conversation, the quick question suggestions and the composer. It is a view of
  the conversational assistant, not the ledger.
- **Ledger**: the transaction ledger screen. It keeps its own navigation entry
  next to the conversational canvas; renaming the home screen does not merge or
  remove it.
- **Chat session**: one conversation between the user and the assistant. It owns
  the collected slots, the messages and the tool trace.
- **Budget slots**: the plan inputs the assistant collects across turns
  (`total_income`, `duration_days`, `savings_target`, `fixed_expenses`). They are
  stored on the chat session, so the context survives a turn change or an app
  restart.
- **Tool trace**: the record of one tool invocation on a message
  (`tool_name`, `tool_args`, `tool_result`). It is written for auditing only; the
  ledger never stores the trace as finance data.
- **Question options**: the choices the assistant offers with a question, at
  most four. They reach the user as tappable chips labelled A, B, C, D plus a
  "Khác" chip that opens a text field. The user answers by tapping one, so the
  question never has to be typed by hand. They are stored in the tool trace of
  the question message and restored from there.
- **Deterministic guard**: the rule that the language model may only propose a
  tool call. The validation, the money arithmetic and the database write are
  owned by the backend service and the database function.
- **Tool declaration dialect**: the narrower JSON-schema subset the Gemini
  function-calling API accepts. It has no `exclusiveMinimum`,
  `exclusiveMaximum`, `pattern` or `anyOf`. The registry converts a Pydantic
  schema into this dialect before the request leaves the process; the
  argument validation stays strict.
- **Provider availability**: the state of the conversational provider, reported
  as a 503 with an actionable message. It is distinct from a schema problem:
  a missing migration never reports the assistant as unavailable.
- **Migration state**: whether the database has the columns and tables a
  feature needs. Until migration `202611010002` is applied the chat keeps
  working and only the collected slots and the tool trace are dropped.
- **Money amount on the wire**: an amount is a `Decimal` on the server and
  travels as a JSON string, so the precision of the cent survives the round
  trip. A client must accept a string and a number for the same field.
- **Supabase project alignment**: the backend and the app must use the same
  Supabase project. The backend validates a token against its own
  `SUPABASE_URL`; a token signed by another project is refused with a 401.
