# Changelog

## Chưa phát hành

- Đồng bộ màn Ngân sách với giao diện quản lý phong bao: tổng quan tháng,
  định mức mỗi ngày, 4 trụ cột và hạn mức danh mục có thể mở rộng.
- Dùng chung form phân bổ/chỉnh hạn mức và làm rõ lối vào quản lý danh mục,
  mục tiêu tiết kiệm và thiết lập ngân sách nâng cao.
- Thiết kế lại quản lý danh mục và phong bao theo 4 trụ cột Kakeibo:
  tìm kiếm, chọn tháng, thẻ hạn mức và form thêm/sửa dạng bottom sheet.
- Cho phép sửa hạn mức riêng của danh mục hệ thống, tắt phong bao theo tháng,
  và lưu tái cân bằng phần trăm vào ngân sách thật.
- Sửa lỗi tạo danh mục do biến `parent_id` trùng tên cột trong SQL trigger;
  bổ sung migration `202610060001_management_category_parent_guard.sql`.
- Trang dữ liệu vượt cuối danh sách trả kết quả rỗng kèm tổng số bản ghi đúng,
  thay vì lỗi 503; giữ bộ lọc và giới hạn quyền người dùng khi đếm.
- Thêm bộ Integration/API E2E bằng Java 21, JUnit 5 và REST Assured tại
  `tests/backend-e2e/`, chạy trong Docker trên GitHub Actions.
- Dựng Supabase Auth, PostgREST và database test dùng schema/migrations thật;
  kiểm tra CRUD, số dư, validation và quyền dữ liệu theo người dùng.
- Workflow sinh khóa tạm mỗi lần chạy, lưu báo cáo JUnit/log và dọn môi trường test.
- Tổ chức Flutter theo chức năng: auth, ledger, transactions, budget, reports,
  forecast, ai, settings và management.
- Tách khởi tạo ứng dụng/router/dependencies vào `app/`, thành phần dùng chung
  vào `shared/`, và cấu hình Supabase vào `core/config/`.
- Tách các màn CRUD quản lý và chia kiểm thử theo chức năng, dùng chung fixtures
  trong `test/helpers/`.

## 1.0.0 — 2026-10-03

- Flutter đăng nhập bằng Supabase Auth và gọi API với access token.
- CRUD giao dịch, ví, danh mục, thẻ, ngân sách, tiết kiệm, sổ nợ và lịch định kỳ.
- Quản lý dữ liệu dự báo, cảnh báo, tư vấn và hội thoại đã lưu.
- Báo cáo tuần/tháng/năm và mức sử dụng ngân sách từ giao dịch thật.
- Hồ sơ cá nhân, tùy chọn và tìm kiếm giao dịch theo thẻ/khoảng ngày.
- API FastAPI theo layered architecture, truy vấn theo người dùng và RLS.
- Migration bảo vệ liên kết dữ liệu và đồng bộ tổng số dư.

### Phạm vi v1

AI tự phân tích/dự báo, tự thực thi giao dịch định kỳ, thông báo thiết bị,
khóa sinh trắc học, theme tối, xuất Excel/PDF và sao lưu Google Drive chưa
được triển khai. Version và changelog không đồng nghĩa đã deploy thành công;
URL và trạng thái triển khai sẽ được ghi sau khi phát hành lên hạ tầng.
