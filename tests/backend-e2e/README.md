# Backend integration & API E2E — Java

`EmailAndGuestAuthIT` bổ sung OTP email/recovery qua hộp thư SMTP Mailpit nội bộ,
từ chối dùng lại mã, mật khẩu mới, anonymous refresh, cách ly RLS và liên kết
email giữ nguyên UID/ví/giao dịch/số dư. Stack hiện dùng email autoconfirm để
giữ các test/Postman cũ; trường hợp liên kết cần nhập OTP được kiểm tra ở Flutter
và cần smoke trên dự án bật xác nhận email. Mailpit không có cổng host hay gửi
ra hộp thư bên ngoài. Template mã thử nghiệm được phục vụ bởi gateway nội bộ.

Không ghi log nội dung thư, mã OTP hoặc response chứa phiên. Nếu Docker daemon
không có trên máy local, việc thêm các ca này không có nghĩa là chúng đã chạy;
chờ bằng chứng workflow Backend Java E2E sau khi đẩy thay đổi.

Bộ test chạy **trong Docker trên GitHub Actions**. Không cần cài Java/Maven,
chạy backend hay database trên máy cá nhân. Không dùng Supabase production,
không dùng file `backend/.env`, không mock xác thực hoặc repository.

## Kiến trúc

```text
GitHub Actions runner
  └─ Docker Compose (project riêng cho mỗi job)
       ├─ tests: Java 21 + Maven + JUnit 5 + REST Assured
       │    └─ HTTP → api: FastAPI từ backend/Dockerfile
       │                  └─ gateway → Supabase Auth / PostgREST
       │                                    └─ Supabase PostgreSQL 17
       └─ migrate: schema.sql → backend/supabase/migrations/*.sql
```

Auth tự chạy migrations trước khi cài schema ứng dụng. PostgREST chỉ khởi động
sau khi migrations thành công; Java chỉ chạy khi các dịch vụ đã healthy.
Các lệnh gọi PostgREST trực tiếp trong `IsolationIT` sử dụng JWT người dùng thường
để kiểm tra RLS và trigger bảo vệ khóa ngoại, không dùng service-role key.

## Chạy trên GitHub Actions

### Chạy Docker tạm trên máy cá nhân

Có thể bật rõ `E2E_LOCAL=true` để chạy cùng stack trên Docker Desktop.
URL của Java vẫn bị khóa vào `http://api:8000` và `http://gateway:8000`;
không dùng `backend/.env` hoặc database đang deploy. Khóa thử nghiệm được
sinh riêng trong `.env.ci`, không in ra terminal khi chạy local.

Từ `tests/backend-e2e`, dùng PowerShell:

```powershell
$env:E2E_LOCAL = 'true'
python docker/generate_env.py
docker compose --project-name project1-finance-audit --env-file .env.ci build api tests backend-checks
docker compose --project-name project1-finance-audit --env-file .env.ci run --name project1-finance-audit-checks --no-deps backend-checks
docker compose --project-name project1-finance-audit --env-file .env.ci up --detach --wait --wait-timeout 240 api
docker compose --project-name project1-finance-audit --env-file .env.ci run --name project1-finance-audit-tests --no-deps tests
```

Sau khi thu báo cáo bằng `docker cp`, dọn đúng project tạm:

```powershell
docker compose --project-name project1-finance-audit --env-file .env.ci down --volumes --remove-orphans
Remove-Item -LiteralPath .env.ci
```

Postman vẫn dùng workflow CI và chứng chỉ TLS tạm theo quy trình bên dưới.
Không đặt `GITHUB_ACTIONS=true` để giả môi trường CI trên máy cá nhân.

### Workflow

Workflow: [Backend Java E2E](../../.github/workflows/backend-java-e2e.yml).

1. Push nhánh có thay đổi backend, schema, bộ test hoặc workflow; hoặc mở PR.
2. Vào repository trên GitHub → **Actions → Backend Java E2E**.
3. Mở job `backend-e2e` để xem build, khởi tạo database và kết quả Maven.
4. Tải artifact `backend-java-e2e-<run_id>-<attempt>` để xem
   `failsafe-reports/TEST-*.xml`, báo cáo `.txt`, `backend-reports/backend.xml`
   và `containers.log`.

CI chạy Ruff và bộ pytest hiện có của backend trong container riêng trước E2E,
để kiểm tra hồi quy khi sửa code Python. Bộ Java có thêm `IngestionIT` cho luồng
phân tích → review → lưu và kiểm tra dữ liệu qua Auth/database thật.
Sau Java, Postman CLI chạy [28 request regression](../../postman/README.md)
trong container riêng, xuất `postman-reports/postman.xml` cùng artifact.
Postman vẫn chạy nếu Java test thất bại nhưng stack đã khởi động thành công;
lỗi ở một bộ không che mã lỗi của bộ còn lại.

Hai image kiểm thử chạy bằng user không phải root. Image Python dùng
`docker/requirements.lock`, khóa phiên bản và SHA-256 của toàn bộ wheel cho
Python 3.13/Linux amd64, cài với `--require-hashes --only-binary=:all:`.
Nguồn dependency là `docker/requirements.in`, gồm backend dev, classifier và
forecaster; PyTorch dùng wheel CPU cố định cho Python 3.13/Linux amd64.
Các dependency test như `pytest-asyncio`, `pandas` và `coverage` cũng phải có
trong lockfile này. Runner yêu cầu plugin `pytest-asyncio>=1.4` và bật
`--strict-markers` để báo lỗi ngay nếu môi trường thiếu plugin hoặc sai marker.
Image có `libgomp1` cho LightGBM và giữ cấu trúc `backend/` cùng `data/taxonomy/`
để các test import training scripts và đọc taxonomy được như trong repo.
Sau khi cập nhật các requirements nguồn hoặc phiên bản PyTorch CPU, chạy
`python docker/lock_dependencies.py` từ thư mục này để tạo lại lockfile, rồi
commit các file nguồn cùng lockfile. Lệnh này cần Docker, phân giải dependency
trong image `python:3.13-slim` Linux, chỉ đọc source và không cài thư viện lên máy cá nhân.
Không tạo lockfile bằng pip trên Windows với `--platform`: tùy chọn đó chỉ chọn
wheel, vẫn đánh giá điều kiện dependency theo Windows và có thể bỏ sót `uvloop`.

Workflow cũng hỗ trợ **Run workflow** khi file workflow đã có trên nhánh mặc định
của repository. Sau đó có thể chọn nhánh cần test. Push trigger hoạt động ngay
trên nhánh chứa workflow.

Mật khẩu database và khóa JWT được sinh ngẫu nhiên mỗi job, che trong Actions log,
và ghi vào `.env.ci` đã được gitignore. Không cần khai báo GitHub Secrets hoặc đưa
khóa Supabase thật vào CI. Không có cổng container nào được publish ra host.
Runner dùng container tạm; bước cleanup luôn xóa containers, volumes và file env.

Postman đi qua service `postman-gateway` bằng TLS 1.3. Mỗi job tạo CA và server
certificate với SAN `postman-gateway`; CLI chỉ tin CA được mount read-only và
không bỏ qua xác minh TLS. CA private key được xóa ngay sau khi ký; server key
chỉ mount vào Nginx. `.certs.ci/` được gitignore và xóa trong cleanup; không copy
chứng chỉ/private key vào artifact. Java vẫn kiểm tra API/Auth qua mạng nội bộ
như trước. Image Postman cài lockfile với lifecycle scripts bị tắt và chạy binary
bằng đường dẫn tuyệt đối. Xem [issue security #26](https://github.com/Drista4real/Project1/issues/26).

Lệnh thực thi trong container Java là `mvn --batch-mode --no-transfer-progress verify`.
Failsafe tìm các lớp `*IT`, trả mã lỗi nếu test thất bại hoặc không tìm thấy test;
không retry test thất bại. Biến môi trường và URL nội bộ được kiểm tra để tránh
chạy nhầm vào localhost hoặc một API đang deploy. Đây là bộ test dành cho CI;
không chạy `mvn test` trên máy cá nhân (`test` cũng chưa đến pha Failsafe).

## Phạm vi kiểm thử

| Lớp | Hành vi được kiểm tra |
| --- | --- |
| `AuthIT` | Health; thiếu/sai JWT; đăng ký + đăng nhập thật; trigger tạo profile/ví; danh mục hệ thống |
| `TransactionsIT` | CRUD; tiền có phần thập phân; hoàn số dư khi sửa/xóa; chuyển ví; tổng tháng UTC; phân trang/lọc/sắp xếp; dữ liệu không hợp lệ |
| `ManagementIT` | CRUD 11 tài nguyên độc lập; profile; composite key của thẻ giao dịch; tin nhắn; cascade; dữ liệu đang được sử dụng; danh mục hệ thống; validation |
| `WalletIncomeIT` | Tạo ví với thu nhập mới; tổng tiền chỉ tăng một lần; retry; ghi nhận số dư cũ giữ nguyên tài sản; cách ly người dùng; từ chối ví đã có giao dịch/số dư thay đổi; rollback ví nếu ghi ledger thất bại |
| `IsolationIT` | Chặn đọc/sửa/xóa và liên kết chéo người dùng; kiểm tra RLS và migration guard qua PostgREST thật |
| `IngestionIT` | JWT thật; tiền tiếng Việt; phân tích không lưu; review sửa tiền trước lưu; đối soát số dư; người dùng khác không sửa/xóa được; input lỗi không thay đổi dữ liệu |

Mỗi kịch bản tạo người dùng với email UUID và đăng nhập bằng password để nhận JWT.
Dữ liệu của các test độc lập, không phụ thuộc ID cố định hay thứ tự chạy. Cleanup
toàn bộ database sau job, thay vì dùng admin credential để xóa từng người dùng.
Assertions kiểm tra cả dữ liệu đọc lại và số dư, không chỉ HTTP status.

Các màn quản lý AI/dự báo xử lý bản ghi đã lưu; test text ingestion chạy parser
và nhánh không có model/cloud credential, không đánh giá chất lượng mô hình AI,
không kiểm tra Celery job, Flutter UI, email delivery, OAuth hoặc cấu hình gateway
production. Gateway Nginx ở đây chỉ định tuyến nội bộ; quyền dữ liệu vẫn do Auth,
PostgREST và RLS kiểm soát.

## Thêm test

- Tạo lớp `*IT.java` trong `src/test/java/vn/kakeibo/e2e/`.
- Dùng `Api.newUser()` để tạo dữ liệu riêng qua HTTP.
- Đặt tên theo hành vi, assert trạng thái sau thao tác và các trường hợp bị từ chối.
- Không log password, Authorization header hoặc response đăng nhập.
- Khi thêm migration, giữ tên SQL có tiền tố thời gian; job áp dụng theo thứ tự tên.
- Đẩy thay đổi lên nhánh để kiểm tra bằng workflow; xem báo cáo trước khi merge.

Lỗi tại bước `Start isolated backend and database` thường cần xem log `db`, `auth`
hoặc `migrate`. Lỗi biên dịch Java nằm ở bước chạy Maven; nếu Maven chưa vào pha test
thì sẽ chưa có JUnit XML. Bước thu log không thay thế mã lỗi của bước build/test.

Các lần chạy đầu tiên đã phát hiện lỗi SQL guard khi tạo danh mục và lỗi 503
khi phân trang vượt cuối danh sách. Các ca này được giữ lại để kiểm tra hồi quy.
Database đang sử dụng schema cũ cần áp dụng migration
`202610060001_management_category_parent_guard.sql` sau các migrations trước đó;
CI tự áp dụng theo thứ tự. Workflow này không thay đổi database đang deploy.

## Tài liệu tham chiếu

- [Supabase Docker stack](https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml): cấu hình Auth, PostgREST và PostgreSQL.
- [Supabase Auth](https://github.com/supabase/auth): đăng ký/đăng nhập và migrations tự động.
- [REST Assured](https://github.com/rest-assured/rest-assured/wiki/GettingStarted): HTTP API assertions trong Java.
- [Maven Failsafe](https://maven.apache.org/surefire/maven-failsafe-plugin/usage.html): lifecycle `integration-test` và `verify`, báo cáo JUnit.
