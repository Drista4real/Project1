# Dùng Postman cho Kakeibo

Dự án có hai địa chỉ: FastAPI xử lý dữ liệu tài chính, Supabase Auth xử lý đăng nhập. Collection dùng Bearer token của người dùng và tự lưu token sau khi đăng nhập.

## 1. Chạy backend

Mở PowerShell tại `D:\Project1\backend`. Nếu đã cài dependencies và cấu hình `.env`:

```powershell
.\.venv\Scripts\python.exe -m fastapi dev app/main.py
```

Hoặc chạy toàn bộ stack:

```powershell
docker compose up --build
```

Xem [backend/README.md](../backend/README.md) để cài đặt lần đầu và áp dụng các migration Supabase. Không ghi đè `.env` đang sử dụng. API mặc định ở `http://127.0.0.1:8000`, Swagger ở `/docs` và schema ở `/openapi.json`. `/health` chỉ kiểm tra tiến trình API; các request tài chính cần Supabase được cấu hình và schema/migration đã áp dụng.

## 2. Mở collection trong Postman

Các request hiện được lưu dưới dạng YAML của Postman Native Git:

- Collection: `postman/collections/Kakeibo API/`
- Environment mẫu: [Kakeibo Local.environment.yaml](<templates/Kakeibo Local.environment.yaml>)

Sau khi clone, tạo environment local từ bản mẫu:

```powershell
Copy-Item 'postman/templates/Kakeibo Local.environment.yaml' 'postman/environments/Kakeibo Local.environment.yaml'
```

Chạy lệnh từ thư mục gốc dự án khi chưa có environment local. File trong `environments/` được Git bỏ qua để giữ thông tin đăng nhập trên máy; không ghi đè file đó nếu đã điền cấu hình.

Mở workspace của bạn trong Postman desktop và kết nối thư mục `D:\Project1` theo [hướng dẫn Native Git](https://learning.postman.com/docs/use/native-git/setup). Dùng **Local View** để chạy các request YAML và nhận thay đổi từ file. Chọn environment **Kakeibo Local** trong bộ chọn environment. Nếu dùng Postman web để gọi localhost, cần Desktop Agent.

Điền các biến của environment:

| Biến | Giá trị |
| --- | --- |
| `base_url` | `http://127.0.0.1:8000`, không có dấu `/` ở cuối; đổi sang URL backend khi cần |
| `supabase_url` | Giá trị `SUPABASE_URL` trong `backend/.env`, không có dấu `/` ở cuối |
| `supabase_publishable_key` | Giá trị `SUPABASE_PUBLISHABLE_KEY` trong `backend/.env` (publishable hoặc legacy anon key) |
| `email` | Email của tài khoản Supabase đã đăng ký |
| `password` | Mật khẩu tài khoản đó |

Nhập mật khẩu/token ở giá trị local trong Postman; file mẫu không chứa thông tin đăng nhập. Không dùng service role key. Nếu đã có access token của phiên đăng nhập Flutter, có thể điền `access_token` trực tiếp và bỏ qua request đăng nhập. Tài khoản phải được xác nhận email nếu Supabase bật xác nhận email.

## 3. Gửi request đầu tiên

1. **01 - Kết nối → Health**: bấm **Send**, mong đợi `200` và `{"status":"ok"}`.
2. **02 - Supabase Auth → Đăng nhập (tự lưu token)**: mong đợi `200`. Script lưu `access_token`, `refresh_token`, `user_id` vào environment. Request gọi `POST {{supabase_url}}/auth/v1/token?grant_type=password` với header `apikey` và body email/password.
3. **03 - Ví, danh mục, tổng quan → Lấy ví** và **Lấy danh mục thu và chi**: script điền `account_id`, `expense_category_id`, `income_category_id` nếu còn trống. Có thể thay bằng ID mong muốn từ response. Nếu chưa có ví/danh mục phù hợp, tạo trong module quản lý rồi điền ID.
4. **04 - Giao dịch → Danh sách giao dịch** và **Tạo giao dịch chi**: request tạo mong đợi `201` và lưu `transaction_id`. Sau đó dùng **Xem**, **Sửa**, **Xóa giao dịch vừa tạo**; xóa thành công trả `204` với body rỗng.
5. Khi token hết hạn, gửi **Làm mới token**. Script lưu cả access token và refresh token mới; nếu phiên không còn hợp lệ, đăng nhập lại.

Collection tự gửi `Authorization: Bearer {{access_token}}` cho API tài chính. Health, schema và Auth không dùng Bearer token của collection. Backend không có `/register`, `/login` hay `/api/v1/auth/register`; đăng ký hiện thực hiện qua Flutter/Supabase.

Gửi từng request trong quá trình làm quen. Các request POST/PATCH/DELETE thay đổi dữ liệu thật của tài khoản đăng nhập. Toàn collection là bộ ví dụ, không phải một kịch bản để chạy toàn bộ bằng Runner: tạo thu/chuyển ví sẽ thay `transaction_id`, cập nhật hồ sơ đổi tên người dùng, và một số module phụ thuộc bản ghi của module khác. Mỗi request có kiểm tra HTTP status trong kết quả script.

## 4. Các module quản lý

**05 - Quản lý tài chính** có danh sách module/schema và CRUD cho ví, danh mục, thẻ, gắn thẻ giao dịch, ngân sách, mục tiêu tiết kiệm, nợ/cho vay, lịch giao dịch định kỳ, bản ghi dự báo/cảnh báo và bản ghi tư vấn/chat. Hồ sơ chỉ có xem và cập nhật.

- Trong mỗi module, **Tạo** lưu `manage_<resource>_id`; **Chi tiết/Cập nhật/Xóa** dùng ID đó. Danh sách không tự chọn bản ghi để sửa/xóa. ID của ví/danh mục tạo ở đây không tự ghi đè các ID đang dùng cho giao dịch.
- `transaction_tags` cần `transaction_id` và `manage_tags_id`: tạo giao dịch và thẻ, giữ hai bản ghi này rồi mới tạo liên kết. Khóa liên kết là `transaction_id:tag_id`.
- `ai_chat_messages` cần `manage_ai_chat_sessions_id`: tạo phiên chat và giữ phiên trước khi tạo tin nhắn. Xóa phiên cũng xóa các tin nhắn trong phiên.
- `today` và `month_start` được script tính theo ngày UTC lúc gửi request; ngân sách dùng ngày đầu tháng. Các ví dụ số tiền dùng chuỗi để giữ chính xác Decimal. Nếu tự thêm `transaction_date`, dùng ISO 8601 có múi giờ, ví dụ `2026-10-07T08:30:00+07:00`; bỏ trường này thì API dùng thời điểm UTC hiện tại.
- Danh mục hệ thống chỉ được đọc. Ví/danh mục đang được tham chiếu có thể không xóa được; xóa bản ghi phụ thuộc trước hoặc lưu trữ ví. Xóa thẻ cũng xóa liên kết gắn thẻ.
- Các endpoint AI/dự báo/định kỳ ở đây quản lý bản ghi đã lưu; không tự sinh lời khuyên, chạy mô hình AI hoặc thực thi lịch định kỳ.

## 5. Khi gặp lỗi

| Kết quả | Cách xử lý |
| --- | --- |
| Không kết nối được | Kiểm tra backend đang chạy, `base_url`, cổng `8000`; dùng desktop app hoặc Desktop Agent cho localhost |
| Script báo thiếu biến | Chọn environment và điền biến được nêu trong thông báo |
| Health/Đăng nhập bị chặn vì thiếu `access_token` | Mở lại collection ở Local View để nhận script đã sửa. Nếu dùng bản cloud, sửa **Kakeibo API → Scripts → Pre-request**: bỏ dòng `const auth = pm.request.auth;` và dòng `if (!auth || auth.type !== "noauth") names.push("access_token");`, rồi Save. Health và đăng nhập không cần token trước đó |
| `Couldn't find this workspace` | Đây là lỗi mở workspace trong Postman. Mở workspace hiện có qua **Workspaces**, kiểm tra ID trong `.postman/resources.yaml` khớp workspace mới, rồi mở request từ sidebar của workspace mới thay vì tab/link cũ |
| `401` từ API | Đăng nhập/làm mới token; dùng access token người dùng, không dùng API key thay token |
| Lỗi đăng nhập Supabase | Kiểm tra đúng project, email/password, trạng thái xác nhận email và Email provider |
| `403` | Kiểm tra quyền sở hữu; danh mục hệ thống không được sửa/xóa |
| `404` | Kiểm tra đường dẫn và ID; bản ghi của người dùng khác cũng bị ẩn |
| `409` | Trùng bản ghi, ví/danh mục đang được dùng hoặc cập nhật xung đột |
| `422` | Xem `detail`; kiểm tra ID, số tiền dương, danh mục khớp thu/chi và ngày có múi giờ |
| `503` từ API | Kiểm tra Supabase trong `backend/.env`, dịch vụ Supabase và kết nối mạng |

**06 - Kiểm tra lỗi** có ví dụ thiếu token (`401`), `limit=0` và số tiền âm (`422`). Hai ví dụ `422` cần token hợp lệ.

`access_token` là token người dùng Supabase, không phải ID workspace hay API key Postman. Để trống trước lần đăng nhập đầu tiên; request đăng nhập sẽ tự lưu token khi thành công. Collection chỉ kiểm tra các biến URL/body/header; API kiểm tra Bearer token và trả `401` khi token thiếu hoặc không hợp lệ.

Tài liệu: [Import dữ liệu Postman](https://learning.postman.com/docs/getting-started/importing-and-exporting/importing-data), [biến environment](https://learning.postman.com/docs/use/send-requests/variables/environment-variables), [Supabase Auth REST](https://supabase.github.io/auth/).
