# CODEX INSTRUCTIONS & ARCHITECTURAL RULES

## 1. System Architecture: Clean Architecture (DDD-lite)
- `domain/`: Pure business logic, Entities, Protocols/Interfaces only. NO external framework imports (no FastAPI, no torch, no lightgbm).
- `application/`: Use cases and orchestrators. Depends ONLY on domain interfaces.
- `infrastructure/`: Concrete implementations (AI adapters, Database, External APIs).
- `api/`: FastAPI routers and controllers. Only calls application use cases.

## 2. Inviolable Engineering Rules
- RULE 1 (No LLM Math): NEVER use LLM/VLM for balance calculations, burn-rate, Runway, or cashflow forecasting. All forecasting must use LightGBM / EWMA via Model 2.
- RULE 2 (Strict Interfaces): Any AI model implementation in `infrastructure/ai/` must strictly inherit from its corresponding Protocol in `domain/interfaces/`.
- RULE 3 (Hardware Isolation): Edge components (`sherpa-onnx`, INT8 ASR) must run offline without internet dependency. Cloud calls (Gemini/VLM) must be asynchronous with timeouts.
- RULE 4 (Deterministic Output): All multimodal extractions must strictly parse into Pydantic schemas.

## 3. Technology Stack Constraints
- Language: Python >= 3.10 with strict type annotations.
- Edge ASR: `sherpa-onnx` (PhoWhisper INT8) + regex slang normalizer.
- Local NLP: `underthesea` (word segmentation) + `transformers` (PhoBERT-base) + `lightgbm`.
- Time-Series: `lightgbm` (Tabular Regressor) + analytical EWMA.
- Cloud Multimodal: `google-genai` SDK / vLLM client with structured JSON output.
- Database: PostgreSQL (Supabase) via SQLAlchemy / asyncpg.

## 4. Coding Conventions
- All functions must have explicit type hints and docstrings.
- Handle exceptions explicitly; never use bare `except: pass`.
- For references on business rules, always consult `docs/SPECIFICATION.md`.