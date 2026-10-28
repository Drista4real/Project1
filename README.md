# Kakeibo Zen — Quản lý tài chính cá nhân và dự báo dòng tiền

Đề tài 17: **Hệ thống Quản lý Tài chính Cá nhân Dự báo Dòng tiền Thông minh**
(AI-driven Cash Flow Forecasting & Financial Management).

Dự án gồm ứng dụng Flutter, backend FastAPI và demo AI độc lập bằng Streamlit.
Ứng dụng quản lý thu/chi theo phương pháp Kakeibo, ngân sách, ví và các kế hoạch
cá nhân. Phần AI hỗ trợ tạo nháp giao dịch từ ngôn ngữ tự nhiên và nghiên cứu
các mô hình dự báo dòng tiền, nhận dạng giọng nói, đọc hóa đơn.

## Hiện trạng triển khai

| Phân hệ | Chức năng trong mã nguồn hiện tại |
| --- | --- |
| Tài khoản người dùng | Supabase Auth: đăng nhập mật khẩu, đăng ký/xác nhận email, OTP email, khôi phục mật khẩu; khách ẩn danh có UID riêng và có thể liên kết email. |
| Sổ thu chi | Xem, thêm, sửa, xóa giao dịch; chọn ví, danh mục, ngày; hỗ trợ thu, chi và chuyển ví. Trigger PostgreSQL cập nhật số dư. |
| Quản lý tài chính | Quản lý ví, danh mục, thẻ, ngân sách, mục tiêu tiết kiệm, sổ nợ và lịch giao dịch định kỳ. Lưu lịch định kỳ chưa đồng nghĩa tự động tạo giao dịch. |
| Ngân sách và báo cáo | Tổng hợp giao dịch thật theo kỳ, danh mục và trụ cột Kakeibo; xuất XLSX/PDF theo bộ lọc. Chuyển ví không tính vào tổng thu/chi. |
| Cài đặt thiết bị | Giao diện sáng/tối, khóa ứng dụng bằng xác thực thiết bị và nhắc nhập liệu hằng ngày. Tùy chọn lưu cục bộ theo UID; nhắc hằng ngày hỗ trợ Android/iOS/macOS. |
| Nhập nhanh AI | Flutter gọi `POST /api/v1/ingestion/text` để tạo một hoặc nhiều nháp; người dùng kiểm tra, sửa và xác nhận trước khi lưu. Có phiên âm PhoWhisper trên Android sau khi chuẩn bị assets. |
| Dự báo trong Flutter | Đọc dự báo, cảnh báo và tư vấn đã lưu; cập nhật trạng thái đã đọc/đã xử lý của cảnh báo. Chưa có luồng tự chạy Model 2 từ màn hình dự báo. |
| Demo AI | Streamlit nạp trực tiếp adapter Model 1–4 để thử phân loại, phiên âm, đọc hóa đơn, dự báo và Advisor; có thử nghiệm fallback Gemini cho text/audio/ảnh. |

Lịch sử dự báo, cảnh báo, tư vấn và hội thoại do hệ thống sinh ra được hiển thị
để đọc trong Flutter; ứng dụng không cung cấp CRUD thủ công chung cho các nhóm
này. Backend vẫn giữ các hợp đồng quản lý dữ liệu tương ứng.

Khách ẩn danh vẫn dùng Supabase và backend qua mạng. Phiên âm offline không có
nghĩa phân loại và lưu giao dịch đều chạy offline. Mất phiên khách trước khi liên
kết email có thể khiến dữ liệu không còn truy cập được.

## Kiến trúc và các mô hình AI

Luồng dữ liệu tài chính hiện tại:

```text
Flutter ── đăng nhập / xác minh email ──> Supabase Auth
Flutter ── HTTP + access token ────────> FastAPI ── JWT người dùng ──> Supabase PostgreSQL / RLS
Streamlit ── gọi trực tiếp ───────────> Adapter AI / trọng số local / API cloud
```

Backend tổ chức theo các lớp `domain`, `application`, `infrastructure` và `api`.
Frontend tổ chức theo chức năng trong `frontend/lib/features/`, dùng BLoC/Cubit
cho nhiều luồng trạng thái. Redis/Celery đã có cấu hình nền tảng; hàng đợi xử lý
media theo kiến trúc đích còn cần tích hợp.

Ba tầng vật lý theo [ADR 0004](docs/adr/0004-three-tier-ai-and-modality-fallback.md)
là **thiết bị Flutter**, **backend CPU**, và **cloud GPU/Foundation API**.
Bốn mô hình bên dưới là các phân hệ logic, không phải bốn tầng triển khai.

| Mô hình | Vai trò | Cách sử dụng hiện tại |
| --- | --- | --- |
| Model 1 | Phân loại giao dịch tiếng Việt | PhoBERT + LightGBM là cấu hình mặc định; có backend PhoBERT + LoRA tùy chọn. API nhập nhanh và demo có thể dùng classifier này. |
| Model 2 | Dự báo và chỉ số tài chính | LightGBM cho nhóm thu nhập cố định, EWMA cho nhóm linh hoạt; chạy trong demo/use case. Gemini Advisor diễn giải chỉ số đã tính. |
| Model 3 | Phiên âm tiếng nói | PhoWhisper-tiny INT8 qua sherpa-onnx; Android chạy trên thiết bị, Python có adapter riêng cho demo. Transcript dùng được chuyển sang luồng phân loại. |
| Model 4 | Trích xuất hóa đơn | Qwen Document VLM đọc ảnh thành dữ liệu có cấu trúc trong demo/adapter. FastAPI chưa đăng ký endpoint tải hóa đơn. |

API nhập văn bản có fallback Gemini cho phân loại khi classifier thiếu tự tin
hoặc không khả dụng; trích xuất số tiền dùng quy tắc cục bộ. Demo Streamlit có
fallback riêng cho audio/ảnh gốc, dùng chung tối đa một yêu cầu Gemini mỗi lượt
phân tích. Fallback media chưa được đấu nối vào Flutter/FastAPI. Luồng gộp trích
xuất và phân loại từ media cùng các kiểm tra chất lượng ASR nâng cao cần đánh giá
trước khi bật.

Số dư, dự báo, runway và safe-to-spend do logic định lượng tính; LLM chỉ diễn giải
hoặc đề xuất dữ liệu cần kiểm tra. SQLCipher, nháp offline và bộ điều phối fallback
media chung là yêu cầu kiến trúc đích. Các ngưỡng F1, độ trễ và chất lượng trong
[đặc tả](docs/SPECIFICATION.md) là mục tiêu, không phải kết quả đã đo của toàn hệ thống.

## Cấu trúc repository

```text
Project1/
├── frontend/                  # Flutter và demo Streamlit
│   ├── lib/                   # app/, core/, features/, shared/
│   ├── test/                  # Unit/widget tests Flutter
│   ├── supabase/schema.sql    # Schema PostgreSQL, triggers, RLS và views
│   ├── app.py                 # Điểm khởi chạy Streamlit
│   └── demo_pipeline.py       # Điều phối fallback riêng cho demo
├── backend/
│   ├── app/                   # api/, application/, domain/, infrastructure/, workers/
│   ├── scripts/               # Chuẩn bị dữ liệu, tải/huấn luyện/export model
│   ├── tests/                 # Kiểm thử Python
│   ├── supabase/migrations/   # Migration bổ sung cho schema gốc
│   └── compose.yaml           # API, Redis và Celery worker
├── data/                      # Dữ liệu và các bộ đánh giá
├── weights/                   # Checkpoint, cache và model tải riêng
├── notebooks/                 # Thực nghiệm/huấn luyện
├── tests/                     # Dataset, browser và Java backend E2E
├── postman/                   # Collection và mẫu môi trường API
├── docs/                      # Đặc tả, ADR và hướng dẫn
├── GLOSSARY.md                 # Thuật ngữ miền dùng chung
└── render.yaml                # Cấu hình triển khai backend trên Render
```

## Thiết lập ứng dụng cục bộ

Các lệnh bên dưới dùng PowerShell. Bắt đầu tại thư mục gốc repository.

### 1. Môi trường

- Python **3.12 trở lên**, theo `backend/pyproject.toml`.
- Flutter có Dart tương thích **`^3.11.1`**, theo `frontend/pubspec.yaml`.
  CI hiện dùng Flutter **3.41.3**.
- Một project Supabase cho Auth và PostgreSQL.
- Docker Desktop/Compose nếu chạy Redis, worker hoặc backend bằng container.

### 2. Database và Auth

Trong SQL Editor của project Supabase mới, chạy
[`frontend/supabase/schema.sql`](frontend/supabase/schema.sql), sau đó lần lượt
chạy các migration trong [`backend/supabase/migrations/`](backend/supabase/migrations/):

1. `202610030001_transaction_reference_guard.sql`
2. `202610030002_management_guards.sql`
3. `202610060001_management_category_parent_guard.sql`
4. `202610180001_auth_profile_email_sync.sql`

Với database đã có dữ liệu, kiểm tra các migration đã áp dụng và chạy phần còn
thiếu. Khởi động FastAPI không tự áp dụng schema/migration.

Cấu hình SMTP, mẫu email OTP, URL chuyển hướng và Anonymous Sign-Ins theo
[`frontend/supabase/README.md`](frontend/supabase/README.md). Các thiết lập này
thực hiện trên Supabase; sửa `.env` không tự cập nhật dịch vụ Auth.

### 3. Backend FastAPI

```powershell
cd backend
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
python -m pip install -r requirements-dev.txt
if (-not (Test-Path .env)) { Copy-Item .env.example .env }
```

Điền cấu hình trong `backend/.env`:

```dotenv
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_PUBLISHABLE_KEY=your-publishable-key
REDIS_URL=redis://localhost:6379/0
```

Backend và Flutter phải trỏ tới cùng project. Dùng publishable key hoặc legacy
anon key; dữ liệu tài chính được truy cập theo JWT người dùng và RLS. Giữ khóa
cloud thật trong `.env`, không commit và không đưa service role key vào Flutter.

Từ thư mục `backend/`, chạy API:

```powershell
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Kiểm tra `http://localhost:8000/health` trả `{"status":"ok"}`;
Swagger ở `http://localhost:8000/docs`. Health thành công chỉ xác nhận API đang
chạy; các endpoint tài chính còn cần Supabase được cấu hình và JWT hợp lệ.

Có thể chạy cả API, Redis và worker bằng `docker compose up --build` từ
`backend/` bằng Docker Compose v2 của Docker Desktop. Sau khi cập nhật code, chạy lại
`docker compose up --build -d --wait`; nút Start/Restart trong Docker Desktop
chỉ dùng lại image cũ và có thể gây 404 ở các route mới dù `/health` vẫn OK.
Luồng CRUD tài chính và phân tích text hiện không cần worker để xử lý
request. Xem thêm [hướng dẫn backend](backend/README.md).

### 4. Flutter

Mở terminal thứ hai, từ thư mục gốc:

```powershell
cd frontend
flutter pub get
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://localhost:8000 --dart-define=SUPABASE_URL=https://your-project.supabase.co --dart-define=SUPABASE_ANON_KEY=your-publishable-key
```

`SUPABASE_ANON_KEY` là tên biến phía Flutter, có thể nhận publishable key của
project. Hai biến Supabase trên ghi đè giá trị mặc định trong
[`supabase_config.dart`](frontend/lib/core/config/supabase_config.dart).

Với Android emulator, đổi URL API thành `http://10.0.2.2:8000` và chọn thiết bị
Android bằng `-d <device-id>`. Điện thoại thật dùng IP LAN của máy chạy backend.
`API_BASE_URL` là URL gốc, không thêm `/api/v1`. Khi đổi `--dart-define`, chạy lại
ứng dụng. Bản production dùng API HTTPS.

Backend mặc định cho phép web origin `http://localhost:5173` và
`http://127.0.0.1:5173`; cổng/origin khác cần cấu hình `CORS_ORIGINS` dưới dạng
mảng JSON trong `backend/.env` rồi khởi động lại backend.

## Chuẩn bị model và chạy demo AI

CRUD tài chính không cần tải toàn bộ model. Để API phân loại bằng PhoBERT +
LightGBM, dùng môi trường Python của backend, chạy từ thư mục gốc:

```powershell
python -m pip install -r backend/requirements-classifier.txt
python backend/scripts/download_classifier_model.py
```

Script tải cache PhoBERT còn thiếu và kiểm tra checkpoint, không huấn luyện lại.
Cấu hình `CLASSIFIER_BACKEND=lightgbm` hoặc `lora` trong `backend/.env`;
[README classifier](backend/app/infrastructure/ai/classifier/README.md) có hướng
dẫn chuẩn bị adapter/cache riêng cho LoRA. Thiếu model/khóa cloud thì kết quả có
thể cần sửa thủ công; không coi nháp đó là suy luận thành công từ model local.

Để dùng phiên âm offline trên Android, tải model rồi chuẩn bị assets:

```powershell
python backend/scripts/download_asr_model.py
python frontend/scripts/prepare_voice_assets.py
```

Sau đó build/chạy lại Flutter. Xem [hướng dẫn Model 3](docs/MODEL3_SETUP.md)
cho kiểm tra SHA256, tải từ repository private và cài runtime Python ASR.

Demo Streamlit chạy độc lập, từ thư mục gốc trong môi trường Python đã chọn:

```powershell
python -m pip install -r frontend/requirements-demo.txt
python -m streamlit run frontend/app.py
```

Mở `http://localhost:8501`. Demo không cần khởi động FastAPI. Làm theo
[hướng dẫn Streamlit](frontend/STREAMLIT_DEMO.md) để chuẩn bị checkpoint/dữ liệu,
cấu hình Qwen/Gemini, xem giới hạn file và nhận biết chế độ MOCK.
Model 2 cần dữ liệu/checkpoint riêng cho kịch bản dự báo tương ứng.
Phiên bản model cloud chọn theo tác vụ và quyền truy cập của tài khoản; không
coi tên model trong cấu hình mẫu là bảo đảm dịch vụ đang khả dụng.

## Kiểm tra và tài liệu liên quan

Các lệnh kiểm tra mã chính, sau khi cài dependencies tương ứng:

```powershell
# Từ thư mục backend/
python -m pytest
python -m ruff check .

# Từ thư mục frontend/
flutter analyze
flutter test
```

Kiểm thử sinh trắc học, thông báo và chia sẻ/lưu file còn cần kiểm tra trên thiết
bị thật. Hướng dẫn các bộ kiểm thử khác nằm tại
[Java backend E2E](tests/backend-e2e/README.md),
[browser/Selenium](tests/browser/README.md) và [Postman](postman/README.md).

- [Đặc tả hệ thống và kiến trúc đích](docs/SPECIFICATION.md)
- [Thuật ngữ dùng chung](GLOSSARY.md) và [quyết định kiến trúc](docs/adr/)
- [Hướng dẫn frontend](frontend/README.md) và [backend](backend/README.md)
- [Taxonomy và quy tắc gán nhãn](docs/DATA_TAXONOMY_AND_ANNOTATION.md)
- [Bàn giao dataset Model 1](docs/MODEL1_MERGED_DATASET.md)
- [Phát hành Android APK và backend Render](docs/release-v1.md)
- [Lịch sử thay đổi](CHANGELOG.md)
- [GitHub Issues — yêu cầu và công việc triển khai](https://github.com/Drista4real/Project1/issues)
