# Kakeibo Backend

FastAPI and Celery foundation for the Kakeibo finance app. Flutter remains in
`../frontend`; this project owns HTTP endpoints and background jobs.

## Deploy v1

Android APK + Render Docker: xem [hướng dẫn phát hành](../docs/release-v1.md).
Blueprint ở `../render.yaml`; Docker CMD dùng `PORT` do Render cấp.

## Classifier dataset preparation

Taxonomy, annotation rules and grouped train/validation/test preparation are
documented in [DATA_TAXONOMY_AND_ANNOTATION.md](../docs/DATA_TAXONOMY_AND_ANNOTATION.md).
The preparation CLI only needs the Python standard library; it does not train
models or modify the source CSV. Use `--dataset-dir` in `scripts/train_classifier.py`
for verified fixed splits instead of the legacy random 80/20 mode.

## Requirements

- Python 3.12 or newer
- Docker Desktop with Docker Compose (for the local Redis service)

## Local setup (PowerShell)

From this directory:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
Copy-Item .env.example .env
```

`.env` is local configuration. Keep real credentials out of source control.
Set `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` to the same project used by
Flutter. These settings are required for finance endpoints; `/health` still works
without them. Use a publishable key (or legacy anon key), never a service role key.

Apply `../frontend/supabase/schema.sql` if this is a new Supabase project, then
apply [the transaction reference guard](supabase/migrations/202610030001_transaction_reference_guard.sql)
through the Supabase SQL editor. The guard checks wallet/category ownership
before the existing balance trigger executes. These scripts are not applied
automatically. Existing users need an account in `public.accounts`; the base
schema creates a cash account when a new user signs up.

### API AI (Model 4)

Khi pull code mới, bổ sung các biến còn thiếu từ `.env.example` vào `.env`;
giữ nguyên cấu hình Supabase, Redis và CORS đang dùng.

```dotenv
# Qwen: bóc tách ảnh hóa đơn qua FPT Cloud
FPT_API_KEY=
QWEN_BASE_URL=https://mkp-api.fptcloud.com/v1
QWEN_MODEL=Qwen2.5-VL-7B-Instruct

# Gemini: diễn giải chỉ số và sinh lời khuyên tài chính
GEMINI_API_KEY=
GEMINI_MODEL=gemini-3.8-flash
```

Điền `FPT_API_KEY` từ tài khoản [FPT Cloud Marketplace](https://marketplace.fptcloud.com/en/models/qwen2.5-vl-7b-instruct)
và tạo `GEMINI_API_KEY` tại [Google AI Studio](https://aistudio.google.com/apikey).
Không điền key thật vào `.env.example`. Key trống giữ adapter tương ứng ở chế độ
mock. Biến môi trường của tiến trình, kể cả giá trị rỗng, được ưu tiên hơn `.env`.
Khởi động lại tiến trình sau khi sửa cấu hình.

Cài các thư viện cloud AI từ thư mục `backend/`:

```powershell
.\.venv\Scripts\python.exe -m pip install -r requirements-cloud-vlm.txt
```

Adapter AI tự đọc `backend/.env` khi chạy local. Có thể thử qua demo Streamlit
`frontend/app.py` sau khi cài `frontend/requirements-demo.txt`, từ thư mục gốc:

```powershell
.\backend\.venv\Scripts\python.exe -m pip install -r frontend/requirements-demo.txt
.\backend\.venv\Scripts\python.exe -m streamlit run frontend/app.py
```

Cấu hình này phục vụ adapter, demo và API nhập văn bản
`POST /api/v1/ingestion/text`. API yêu cầu Supabase access token, trả danh sách
giao dịch nháp và không ghi vào database. Tối đa 5 khoản mỗi lần; có thể bỏ dấu
phẩy khi mỗi khoản có nội dung và số tiền, ví dụ `cơm 30k momo sửa xe 100k tiền mặt`.
Các câu tổng tiền, giảm giá hoặc khoảng giá vẫn cần kiểm tra để tránh ghi trùng.
Model local được ưu tiên khi có checkpoint/cache. Quy tắc ngữ nghĩa gán các
khoản quen thuộc vào danh mục hiện có ngay cả khi cloud lỗi (source `RULES`,
không hiển thị như độ tin cậy của model). Các khoản chưa rõ được gửi Gemini
trong một batch, chọn cả loại thu/chi và danh mục; `GEMINI_INPUT_MODEL` mặc định
`gemini-3.1-flash-lite`, độc lập model tư vấn, timeout 20 giây.
Số tiền luôn được chuẩn hóa bằng Python, không giao LLM tính số tiền, số dư
hoặc dự báo. Chỉ các khoản chưa thể phân loại mới yêu cầu chọn danh mục.
Phong bao tự theo danh mục đã chọn. Ví ghi rõ trong câu phải khớp ví hiện có;
ví dụ chưa có MoMo thì ứng dụng yêu cầu chọn ví, không tự đổi thành tiền mặt.
Flutter gửi tên danh mục thu/chi hiện có để Gemini chọn đúng nhãn của bạn;
schema giới hạn kết quả trong các tên đã gửi. Khi lưu, API giao dịch vẫn kiểm
tra danh mục/ví và quyền sở hữu qua Supabase, không dùng ID do LLM sinh ra.

Flutter: nhấn **+ → Nhập nhanh AI**, gõ hoặc nói, nhấn **Phân tích**, kiểm tra
từng thẻ rồi **Xác nhận & Lưu vào Sổ Thu Chi**. Có thể sửa số tiền, ngày, ví,
danh mục hoặc vuốt bỏ khoản. Ngân sách dùng dữ liệu đang lưu; danh mục ghi nhớ
được giới hạn theo người dùng và chỉ ghi nhớ sau khi lưu thành công. Nếu một
yêu cầu lưu bị mất kết nối, kiểm tra sổ trước khi nhập lại để tránh lưu trùng.

Model 1/2 và nhận dạng giọng nói offline không dùng hai API key này. Hóa đơn
và dự báo không được triển khai thêm trong đợt nhập liệu này. Demo Streamlit
vẫn chỉ hiển thị tín hiệu routing cho NLP; luồng fallback mới nằm ở API.
Xem [tài liệu adapter Model 4](app/infrastructure/ai/cloud_vlm/README.md).

### Chuẩn bị giọng nói Android offline

Từ thư mục gốc, chuẩn bị model và đóng gói asset trước khi build APK:

```powershell
.\backend\.venv\Scripts\python.exe backend/scripts/download_asr_model.py
.\backend\.venv\Scripts\python.exe frontend/scripts/prepare_voice_assets.py
```

Script tải kiểm tra kích thước/SHA256; script đóng gói kiểm tra lại trước khi cài asset.
Xem [hướng dẫn Model 3](../docs/MODEL3_SETUP.md) cho repo private và cách phát hành.
Model tải một lần lúc chuẩn bị; ứng dụng phiên âm tiếng Việt trên thiết bị
bằng sherpa-onnx, không tải âm thanh lên backend. Bấm **Nói nhanh**, cấp quyền
micro, chờ thông báo micro đã bật và thanh âm lượng rồi nói tối đa 20 giây.
Ngừng nói khoảng 2 giây hoặc bấm **Dừng ghi âm** để phiên âm. Văn bản có thể sửa
trước khi nhấn Phân tích. Chuyển app sang nền sẽ dừng thu âm.
Web vẫn hỗ trợ nhập văn bản; giọng nói offline ở bản này dành cho Android.
Trên Android Emulator, bật **Extended Controls → Microphone → Virtual microphone
uses host audio input** (hoặc `adb emu avd hostmicon`). Nếu thanh âm lượng không
chuyển động, kiểm tra đầu vào micro Windows và quyền micro. Hộp thoại cấp quyền
không hủy phiên ghi âm; khi ứng dụng thật sự xuống nền thì phiên bị hủy.

Để chạy backend cho điện thoại cùng mạng Wi-Fi, từ `backend/`:

```powershell
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

Từ `frontend/`, thay địa chỉ ví dụ bằng IP LAN của máy chạy backend:

```powershell
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

APK debug mặc định dùng `http://10.0.2.2:8000` cho Android Emulator. Điện thoại
thật cần build với IP LAN hoặc URL backend đã cập nhật code mới. Với Docker
Compose, `GEMINI_API_KEY` và `GEMINI_MODEL` được chuyển vào container API; trên
Render, điền key ở Environment rồi deploy phiên bản mới khi sẵn sàng.

For the remaining management modules, also apply
[the management guards](supabase/migrations/202610030002_management_guards.sql)
in the SQL editor after the transaction guard. This migration validates foreign
references, protects used accounts/categories from deletion, and synchronizes
the profile total when a wallet balance or inclusion setting changes. It also
recalculates existing profile totals from included accounts. Review that balance
recalculation before applying it to a populated project.

## Run the API and worker

Start Redis with `docker compose up redis`, then in separate terminals run:

```powershell
python -m fastapi dev app/main.py
python -m celery -A app.workers.celery_app:celery_app worker --loglevel=INFO
```

The API liveness endpoint is `GET http://127.0.0.1:8000/health`. It reports
only whether the API process is responding; it does not probe Redis or Supabase.

Alternatively, start the complete local stack with:

```powershell
docker compose up --build
```

Compose exposes the API on port `8000` and Redis on `6379`. Its health check
waits for Redis before starting the API and worker; `/health` checks only the
API process.

Compose builds the API and worker from the current source on `docker compose up`
(`pull_policy: build`, use Docker Compose v2 from Docker Desktop). Build cache
keeps unchanged layers fast; a BuildKit pip cache also retains downloads across
dependency installation retries without including them in the final image.
Source is copied into the image; it is not mounted or reloaded live.
After pulling or editing code, run this from `backend/`:

```powershell
docker compose up --build -d --wait
docker compose logs --tail 50 api
```

Starting/restarting an existing container in Docker Desktop does not rebuild its
image. An old image may report `/health` as OK while returning 404 for newer
routes. Open `http://localhost:8000/openapi.json` and check that it contains
`/api/v1/transactions`, `/api/v1/manage/categories` and `/api/v1/ingestion/text`.
A request to a protected route without a token should return 401, not 404.
For Flutter web, an OPTIONS preflight from `http://localhost:5173` should return
200 with the matching `Access-Control-Allow-Origin` header.

Stop any locally running Uvicorn process using port `8000` before starting the
Docker API. Set Flutter's `API_BASE_URL` to `http://localhost:8000` (Android
emulator: `http://10.0.2.2:8000`), without an `/api/v1` suffix.

## Checks

Install the development dependencies plus the optional ML stacks before running
the complete test suite (from `backend/`):

```powershell
python -m pip install -r requirements-dev.txt -r requirements-classifier.txt -r requirements-forecaster.txt
```

```powershell
python -m pytest
python -m ruff check .
python -m ruff format --check .
python -m pip check
```

To measure coverage across all application modules:

```powershell
python -m coverage run --branch --source=app -m pytest
python -m coverage report
python -m coverage json -o .coverage.summary.json
```

The report's total combines statement and branch coverage. For branch coverage
alone, use `totals.percent_branches_covered` in `.coverage.summary.json`; the
target is greater than 85%. Unit tests use temporary configuration files and
mocks and do not require provider credentials or downloaded model weights.

Runtime packages are constrained in `requirements.in` and pinned in
`requirements.txt`. Development tools are declared in `requirements-dev.in`
and pinned in `requirements-dev.txt`.

## Layer boundaries

- `app/api`: HTTP routing, transport validation, and dependency wiring.
- `app/application`: use cases and orchestration.
- `app/domain`: business entities and repository contracts.
- `app/infrastructure`: settings and external service adapters.
- `app/workers`: Celery application and task entry points.

The worker does not read or write user data. Transaction CRUD runs synchronously
in the API; the database updates wallet/profile balances using its existing trigger.

## Transaction CRUD

All `/api/v1` routes require `Authorization: Bearer <Supabase access token>`.
The API validates the token using Supabase Auth and forwards it to PostgREST so
RLS applies. A new SDK client is created per request.

| Method | Route | Result |
|---|---|---|
| GET | `/api/v1/transactions?limit=30&offset=0` | `{items, total, limit, offset}` |
| POST | `/api/v1/transactions` | Created transaction, HTTP 201 |
| GET | `/api/v1/transactions/{id}` | Transaction detail |
| PATCH | `/api/v1/transactions/{id}` | Updated transaction |
| DELETE | `/api/v1/transactions/{id}` | HTTP 204, empty body |
| GET | `/api/v1/accounts` | Active wallets owned by the caller |
| GET | `/api/v1/categories` | System and caller categories |
| GET | `/api/v1/overview` | Current balance and current UTC month income/expense |

Example create body:

```json
{
  "amount": "45000.00",
  "transaction_type": "expense",
  "account_id": 1,
  "category_id": 5,
  "raw_description": "Cà phê sáng",
  "transaction_date": "2026-10-03T08:30:00+07:00"
}
```

Use actual wallet/category IDs from the lookup routes. Amounts use exact Decimal
validation (`DECIMAL(15,2)`) and are returned as strings. Date values must include
a timezone; omitted create dates use the current UTC time. `PATCH` only changes
supplied fields; explicit `null` clears optional fields. Owner, ID and metadata
fields cannot be supplied by clients. Transfers require distinct source and
destination wallets and no category. A category must match income/expense type.

Missing/invalid tokens return 401; hidden or missing transactions return 404;
validation failures return 422. An update interrupted by another modification
returns 409. External service failures return 503 without leaking provider errors.
The list limit is 1–100; `transaction_type` is an optional filter.

Swagger UI: `http://127.0.0.1:8000/docs`. Use **Authorize** with a signed-in user's
access token to exercise protected endpoints. Local automated API tests use a
mock HTTP transport for Supabase and do not modify a live project.

For Postman, open the local collection and copy the environment template from
[`../postman`](../postman/README.md).
The Vietnamese guide covers Supabase login, automatic token storage, transaction
CRUD and management requests. Sample environment files contain no credentials.

Opening `http://127.0.0.1:8000/` redirects to Swagger. Registration and login
currently run through the Flutter Supabase Auth SDK, not FastAPI routes;
`/register` and `/api/v1/auth/register` are not defined in this API.

If registration fails, inspect the Flutter console line `Supabase Auth failed`
for its HTTP status and provider error code. No passwords or access tokens are
logged. In Supabase, enable the Email provider and allow new user signups.
When email confirmation is enabled, registration does not immediately create a
session: confirm the email before signing in. If the confirmation link opens
the wrong site or returns 404, set **Authentication → URL Configuration → Site
URL** to your Flutter web origin (for example `http://localhost:5173`) and add
the matching allowed redirect URL. It should point to Flutter, not the API.

`over_email_send_rate_limit` means the project has exhausted its Auth email
quota, even if this user is registering for the first time. The built-in sender
also restricts delivery to organization team addresses; other recipients may
receive `email_address_not_authorized`. Configure custom SMTP for public users
and review **Authentication → Rate Limits**. For development-only testing,
disabling **Confirm email** removes the confirmation step and treats signup
emails as verified; keep confirmation enabled when email ownership matters.
See [Supabase Auth rate limits](https://supabase.com/docs/guides/auth/rate-limits)
and [custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp).

## Run Flutter against the API

```powershell
cd ../frontend
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://localhost:8000
```

The backend allows `localhost:5173` and `127.0.0.1:5173` by default. For other
web origins, set `CORS_ORIGINS` to a JSON array in `.env`. On the Android emulator,
use `--dart-define=API_BASE_URL=http://10.0.2.2:8000`; debug builds allow local HTTP.
Production mobile builds need an HTTPS API URL. Compose forwards Supabase and
CORS settings from `.env` to the API container.

Nếu Android build dừng với `What went wrong: 25.0.3`, kiểm tra Java mà Flutter
đang dùng bằng `flutter doctor -v`. Cấu hình Gradle hiện tại chạy được với JDK 17.
Trên máy đã có JDK 17, chọn thư mục cài đặt bằng
`flutter config --jdk-dir="<đường dẫn JDK 17>"`, rồi khởi động lại IDE.
Với giả lập đã mở, chạy từ `frontend/`:

```powershell
flutter run -d emulator-5554 --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Giữ backend chạy ở cổng 8000 trong lúc thử. `GET http://localhost:8000/health`
phải trả `{"status":"ok"}`.

Android project tắt Kotlin incremental compilation để tránh lỗi
`this and base files have different roots` khi Pub cache ở ổ C: và repo ở ổ D:.
Thay đổi này chỉ ảnh hưởng thời gian biên dịch Kotlin.

Sign in (or register and confirm email) from the ledger prompt or Settings.
Use the add button to create, tap a ledger row to view/edit, and confirm deletion
from the detail screen. The form supports selecting a wallet, category and date.
Successful changes reload the ledger; errors are shown without demo-data fallback.

Implementation references: [Supabase token validation](https://supabase.com/docs/reference/python/auth-getuser),
[Supabase Flutter password login](https://supabase.com/docs/reference/dart/auth-signinwithpassword),
and [Flutter HTTP networking](https://docs.flutter.dev/cookbook/networking/fetch-data).

## Remaining modules: CRUD management

Open **Cài đặt → Quản lý tài chính** in Flutter. Each module has a paginated list,
detail/edit form, create action and deletion confirmation. System categories
are read-only. Profiles support reading and editing; Supabase Auth owns their
creation and deletion. The public connection-test `notes` table is excluded.

The API uses a fixed resource registry, schema validation in the domain layer,
reference checks in the application layer and user-scoped Supabase repositories.
Existing `/accounts`, `/categories`, `/overview` and transaction routes retain
their contracts. Management requests require the same Supabase access token.

| Resource | Module |
| --- | --- |
| `accounts` | Wallets, bank accounts and credit cards |
| `categories` | Personal categories and parent hierarchy |
| `tags` | Personal tags |
| `transaction_tags` | Transaction/tag associations |
| `budgets` | Monthly category, pillar or overall budgets |
| `saving_goals` | Savings goals |
| `debts_loans` | Debts and loans |
| `recurring_transactions` | Recurring transaction schedules |
| `cashflow_forecasts` | Saved forecast records |
| `cashflow_alerts` | Alerts and read/resolved state |
| `ai_consultations` | Saved consultation records |
| `ai_chat_sessions` | Conversation sessions |
| `ai_chat_messages` | Messages in owned conversations |
| `profile` | Own profile and stored preferences |

Routes (relative to `/api/v1/manage`):

| Method | Path | Result |
| --- | --- | --- |
| GET | `/resources` | Available modules and input JSON schemas |
| GET | `/{resource}?limit=30&offset=0` | `{items,total,limit,offset}`; limit 1–100 |
| POST | `/{resource}` | Created record, HTTP 201 (except profile) |
| GET | `/{resource}/{key}` | Detail |
| PATCH | `/{resource}/{key}` | Update supplied fields; nullable fields accept null |
| DELETE | `/{resource}/{key}` | HTTP 204 (except profile) |

Keys are positive numeric IDs. For `transaction_tags`, use
`{transaction_id}:{tag_id}`, for example `/transaction_tags/12:3`.
Use `/profile/me` for profile detail/update. Client-supplied owners, IDs and
timestamps are rejected. Decimal amounts accept strings to preserve precision.
Swagger documents a separate typed create/update contract for every module.

Example budget POST `/api/v1/manage/budgets`:

```json
{
  "month_year": "2026-10-01",
  "pillar": "needs",
  "limit_amount": "5000000.00",
  "alert_threshold_percent": 80
}
```

Deleting a used wallet/category returns 409. Archive wallets instead, or remove
their references first. Deleting a tag removes its associations; deleting a
conversation also deletes its messages. These cascades are shown in Flutter's
confirmation dialog. Category type changes are blocked while referenced.

This implements CRUD for saved records. Automatic recurring execution, AI model
inference, AI chat generation, notification delivery and applying stored profile
preferences to device features are separate features. Savings/debt progress
changes do not create wallet transactions. After wallet edits, pull to refresh
the ledger to reload totals.

Flutter edits the optional note within consultation/message context while
preserving other stored context fields. The API supports the full context object.

## Java integration and API E2E tests

The Docker-only Java suite lives in [`tests/backend-e2e`](../tests/backend-e2e/README.md).
GitHub Actions builds this backend and starts disposable Supabase Auth, PostgREST
and PostgreSQL containers with the actual application schema and migrations.
Tests use real user tokens and verify CRUD, financial balances and user isolation.
Run it by pushing relevant changes or using the **Backend Java E2E** workflow;
no local backend, Maven installation or production Supabase credentials are needed.

The Java suite exposed a category-trigger name collision. Apply
`supabase/migrations/202610060001_management_category_parent_guard.sql` after
the earlier migrations on existing databases. CI applies it automatically to
its disposable database. Paginated API collections return an empty `items` list
and the filtered, user-scoped `total` when the offset exceeds the last record.
