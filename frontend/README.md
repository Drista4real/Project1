# Flutter ↔ FastAPI

Bản v1 phát hành Android APK, backend Docker trên Render. Xem
[hướng dẫn phát hành](../docs/release-v1.md) để tạo khóa ký và build APK với URL API thật.

Ứng dụng dùng Supabase Auth để đăng nhập và chuyển access token của người dùng
qua header `Authorization: Bearer ...` khi gọi FastAPI. Dữ liệu tài chính được
đọc/ghi qua backend; không cần và không được đưa service role key vào Flutter.

## Chạy cục bộ

Khởi động API từ thư mục `backend`:

```powershell
.\.venv\Scripts\Activate.ps1
python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Từ thư mục `frontend`, chạy web trên cổng được CORS cho phép:

```powershell
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://localhost:8000
```

Android emulator dùng:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

Web/desktop mặc định gọi `localhost:8000`; Android mặc định gọi `10.0.2.2:8000`.
Trên điện thoại thật, truyền địa chỉ IP LAN của máy chạy backend bằng
`--dart-define=API_BASE_URL=http://<IP-LAN>:8000`. `API_BASE_URL` là URL gốc,
không thêm `/api/v1`. Khi thay đổi biến này cần chạy lại ứng dụng.
Production dùng API có HTTPS.

Backend `.env` và cấu hình Supabase Flutter phải trỏ tới cùng một project.
Chạy các migration theo [hướng dẫn backend](../backend/README.md) trước khi
quản lý dữ liệu. Đăng nhập trước khi mở các màn tài chính.

## Các màn đã kết nối

- **Sổ thu chi:** tổng số dư và CRUD giao dịch, chọn ví/danh mục thật.
- **Ngân sách:** hạn mức theo tháng từ `/manage/budgets`; mức sử dụng được tính
  từ giao dịch chi tiêu thật. Sửa/tạo phong bao mở form CRUD và tải lại khi trở về.
  Ngân sách tổng được hiển thị riêng; các hạn mức danh mục/trụ cột có thể chồng
  lấn nên không được cộng vào nhau. Nếu trùng nhiều ngân sách tổng trong một
  tháng, bản ghi có ID mới nhất được dùng cho chỉ số tổng.
- **Báo cáo:** phân bổ danh mục và thu/chi theo tuần/tháng/năm được chọn, dùng
  ngày địa phương của thiết bị. Chuyển tiền giữa các ví không tính vào thu/chi.
- **Dự báo:** dữ liệu từ `/manage/cashflow_forecasts`, cảnh báo từ
  `/manage/cashflow_alerts` và tư vấn từ `/manage/ai_consultations`. Bộ lọc 7/14/30
  ngày có tác dụng; nếu nhiều dự báo cùng ngày thì dùng bản ghi có ID mới nhất.
  Các nút đã đọc/đã xử lý lưu trạng thái qua PATCH.
- **Cài đặt:** hồ sơ, giờ nhắc và tùy chọn được đọc/lưu qua `/manage/profile/me`.
  Thẻ, liên kết thẻ và giao dịch được lấy từ API để tìm theo nội dung/số tiền,
  thẻ và khoảng ngày. Các tùy chọn sinh trắc học/giao diện tối hiện được lưu vào
  hồ sơ; tích hợp khóa thiết bị và theme tối là chức năng riêng.
- **Quản lý tài chính:** CRUD toàn bộ phân hệ còn lại qua `/manage/...`.

Các màn có trạng thái tải, lỗi/thử lại và dữ liệu rỗng; không dùng số liệu mẫu
khi API gặp lỗi. Kéo xuống để tải lại báo cáo, ngân sách và dự báo. Sau khi thêm
giao dịch qua nút điều hướng, màn hiện tại cũng tải lại.

Backend hiện cung cấp CRUD dữ liệu AI đã lưu, chưa có endpoint tự động phân
tích văn bản hoặc chạy mô hình dự báo. Màn Nhập Nhanh AI cho phép chuyển nội
dung người dùng sang form giao dịch thủ công và lưu qua API; không tạo giao
dịch mẫu hoặc hiển thị kết quả AI giả. Các chức năng gửi thông báo, sao lưu
Google Drive và xuất Excel/PDF chưa được triển khai.
