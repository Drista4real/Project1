# Backend integration & API E2E — Java

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

Workflow: [Backend Java E2E](../../.github/workflows/backend-java-e2e.yml).

1. Push nhánh có thay đổi backend, schema, bộ test hoặc workflow; hoặc mở PR.
2. Vào repository trên GitHub → **Actions → Backend Java E2E**.
3. Mở job `backend-e2e` để xem build, khởi tạo database và kết quả Maven.
4. Tải artifact `backend-java-e2e-<run_id>-<attempt>` để xem
   `failsafe-reports/TEST-*.xml`, báo cáo `.txt`, `backend-reports/backend.xml`
   và `containers.log`.

CI chạy Ruff và bộ pytest hiện có của backend trong container riêng trước E2E,
để kiểm tra hồi quy khi sửa code Python. Bộ Java có 41 kịch bản sau tham số hóa.

Workflow cũng hỗ trợ **Run workflow** khi file workflow đã có trên nhánh mặc định
của repository. Sau đó có thể chọn nhánh cần test. Push trigger hoạt động ngay
trên nhánh chứa workflow.

Mật khẩu database và khóa JWT được sinh ngẫu nhiên mỗi job, che trong Actions log,
và ghi vào `.env.ci` đã được gitignore. Không cần khai báo GitHub Secrets hoặc đưa
khóa Supabase thật vào CI. Không có cổng container nào được publish ra host.
Runner dùng container tạm; bước cleanup luôn xóa containers, volumes và file env.

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
| `IsolationIT` | Chặn đọc/sửa/xóa và liên kết chéo người dùng; kiểm tra RLS và migration guard qua PostgREST thật |

Mỗi kịch bản tạo người dùng với email UUID và đăng nhập bằng password để nhận JWT.
Dữ liệu của các test độc lập, không phụ thuộc ID cố định hay thứ tự chạy. Cleanup
toàn bộ database sau job, thay vì dùng admin credential để xóa từng người dùng.
Assertions kiểm tra cả dữ liệu đọc lại và số dư, không chỉ HTTP status.

Các màn AI/dự báo hiện quản lý bản ghi đã lưu; bộ test không gọi mô hình AI,
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
