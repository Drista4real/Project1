# Dữ liệu giả để thử app trên máy cá nhân

Từ thư mục gốc `D:\Project1`, khi Docker Desktop đang chạy:

```powershell
python dev/local/demo.py start
.\dev\local\run-app.ps1
```

Script thứ hai chạy Flutter trên Chrome ở cổng 5173, trỏ cả API và Supabase Auth
vào local. Dùng email/mật khẩu trong [runtime/login.json](runtime/login.json)
để đăng nhập. Đăng nhập đúng tài khoản demo để thấy dữ liệu đã nạp. Cần khởi động
lại app bằng cấu hình này; hot reload không thay được các `dart-define`.
Dừng phiên `flutter run` cũ trước khi chạy script để giải phóng cổng 5173.

Android emulator:

```powershell
.\dev\local\run-app.ps1 -Device emulator-5554
```

Thay ID bằng ID máy ảo trong `flutter devices`. Cấu hình Android dùng `10.0.2.2`;
không dành cho điện thoại thật qua LAN. Windows desktop dùng `-Device windows`.

## Dữ liệu ban đầu

| Nội dung | Dữ liệu |
| --- | --- |
| Ví mẫu | Tiền mặt 2 triệu có sẵn; ngân hàng nhận thu nhập 30 triệu; ví điện tử nhận thu nhập 10 triệu |
| Giao dịch | 2 khoản thu, 9 khoản chi, 1 chuyển ví; ngày nằm trong tháng tạo bộ mẫu |
| Thẻ | Du lịch, Gia đình, Công việc, Học tập, Bạn bè |
| Liên kết thẻ | 11 liên kết; có giao dịch nhiều thẻ và giao dịch chưa gắn thẻ |
| Ngân sách | Tổng tháng 15 triệu; 4 trụ cột và 5 hạn mức danh mục |
| Thu nhập tháng | 40.000.000 ₫ |
| Chi tiêu tháng | 3.205.000 ₫ |
| Tổng số dư | 38.795.000 ₫ (gồm 2 triệu có sẵn; chuyển ví không tạo thu/chi) |

Auth còn tạo ví mặc định 0 đồng. Các ví/danh mục/giao dịch mẫu có tiền tố `[Demo]`.
Đây là dữ liệu giả được ghi qua API thật và database local, không phải dữ liệu
cố định ghi đè lên màn hình. Không nạp lịch sử AI/dự báo hoặc gọi dịch vụ AI cloud.

## Thử thẻ và tìm kiếm

1. Vào **Cài đặt** → **Thẻ của bạn**. **Quản lý thẻ** tạo/sửa/xóa thẻ;
   **Gắn thẻ** chọn giao dịch và thẻ để tạo liên kết.
2. Nhập `#dulich`, `#du lich` hoặc `#Du lịch` vào ô tìm kiếm. Cả ba cách đều khớp
   thẻ **Du lịch**, chỉ trả về giao dịch thực sự đã gắn thẻ đó.
3. Ban đầu có 3 giao dịch mang thẻ Du lịch: khách sạn, vé máy bay và chuyển ví
   cho chuyến đi. Giao dịch thuốc có chữ “du lịch” trong ghi chú nhưng chưa gắn
   thẻ sẽ không xuất hiện với hashtag. Tìm thường `du lich` vẫn xét cả ghi chú.
4. Chọn thêm chip **Gia đình** khi đang tìm `#dulich`: chỉ vé máy bay khớp cả hai.
5. Gắn hoặc gỡ một thẻ, quay lại để tải dữ liệu và kiểm tra tìm kiếm/xuất báo cáo.
   Khoảng thời gian đang chọn cũng được áp dụng; dữ liệu mẫu thuộc tháng tạo mẫu.

## Quản lý local

```powershell
python dev/local/demo.py verify # Đọc lại tổng tiền và số lượng thẻ/liên kết
python dev/local/demo.py stop   # Dừng local, giữ dữ liệu
python dev/local/demo.py start  # Chạy lại, giữ các thay đổi và không seed trùng
python dev/local/demo.py reset  # Xóa RIÊNG database demo local
python dev/local/demo.py start  # Tạo lại bộ mẫu từ đầu sau reset
```

API: `http://localhost:18000`; Auth/PostgREST: `http://localhost:18001`;
Mailpit thử email: `http://localhost:18025`. Chỉ bind loopback. File cấu hình và
tài khoản sinh trong `runtime/` được Git bỏ qua. Không dùng `backend/.env`, không
trỏ frontend demo vào Supabase thật và không seed dữ liệu vào tài khoản thật.
URL HTTP chỉ dùng cho cổng Docker bind loopback. Android emulator dùng alias
`10.0.2.2` để truy cập chính các cổng đó; đây không phải cấu hình LAN/production.
Khóa local giữ nguyên giữa các lần chạy; app/test account không bị đổi khi start.
Base schema chỉ chạy một lần. Migrations được theo dõi theo tên và checksum;
script dừng nếu sửa một migration đã áp dụng thay vì tự ghi đè cấu trúc cũ.

## Lỗi “dữ liệu không tồn tại” khi ghi nhận thu nhập ví

Migration cập nhật database; container API cũng cần được build lại. Với backend
ở cổng 8000, từ thư mục `backend`:

```powershell
docker compose up --detach --build --no-deps api
```

Kiểm tra `/openapi.json` có endpoint
`/api/v1/manage/accounts/{key}/initial-income`. Nếu thiếu endpoint này, 404 là
backend chưa cập nhật, không phải bằng chứng ví đã bị xóa. App phân biệt lỗi này
với trường hợp bản ghi thực sự không còn tồn tại. Sau khi cập nhật backend, tải
lại danh sách và mở ví hiện có để ghi nhận thu nhập; không cần xóa/tạo lại ví.
