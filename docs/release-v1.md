# Phát hành v1: Android APK + Render Docker

## 1. Backend trên Render

Đưa mã backend hiện tại và `render.yaml` lên nhánh `app_CRUD` trên GitHub
trước khi deploy. Render chỉ đọc commit đã push, không đọc thay đổi trên máy.
Không commit `backend/.env`, keystore hoặc `key.properties`.

Trên Render Dashboard, chọn **New → Blueprint**, kết nối repository
`Drista4real/Project1`, chọn nhánh `app_CRUD`, dùng `render.yaml` ở thư mục gốc.
Blueprint tạo Web Service `kakeibo-api`, Docker runtime, Singapore, Free.
Điền hai biến từ cấu hình Supabase đang dùng:

| Biến | Giá trị |
| --- | --- |
| `SUPABASE_URL` | URL project Supabase giống Flutter |
| `SUPABASE_PUBLISHABLE_KEY` | Publishable key của project đó |
| `CORS_ORIGINS` | `[]` cho bản Android |

Nếu tạo **New → Web Service** thủ công, dùng:

| Mục | Giá trị |
| --- | --- |
| Branch | `app_CRUD` |
| Language / Runtime | Docker |
| Root Directory | Để trống |
| Dockerfile Path | `backend/Dockerfile` |
| Docker Build Context | `backend` |
| Docker Command | Để trống, dùng CMD của image |
| Health Check Path | `/health` |
| Instance Type | Free |

Docker CMD lắng nghe `0.0.0.0` và dùng biến `PORT` do Render cấp, mặc định
8000 khi chạy cục bộ. Không upload `.env` vào image. Android native không
cần CORS; thêm origin cụ thể nếu sau này phát hành web.

Sau khi service báo **Live**, mở URL service với `/health` và `/docs`.
`/health` chỉ xác nhận API đang chạy, không kiểm tra Supabase hoặc Redis.
Đảm bảo đã áp dụng hai migration trong `backend/supabase/migrations` theo
README backend; không chạy lại toàn bộ schema trên database đang chứa dữ liệu.

V1 dùng API CRUD và Supabase Auth/Postgres. Worker Celery hiện chỉ có task
health, nên Blueprint chưa tạo Redis/worker. Khi thêm job nghiệp vụ, triển khai
worker và Redis riêng; Render không chạy cả Docker Compose như trên máy local.
Free service có thể ngủ khi không dùng, lần gọi đầu có thể chậm hoặc cần thử lại.

## 2. Khóa ký Android

Chạy từ thư mục `frontend`:

```powershell
.\scripts\initialize-android-signing.ps1 -KeytoolCommand 'C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe'
```

Script tạo khóa ký riêng `android/kakeibo-release.jks` và mật khẩu ngẫu nhiên
trong `android/key.properties`; cả hai đã được gitignore. Sao lưu hai file ở nơi
riêng tư, dùng cùng khóa cho mọi phiên bản cập nhật. Không chạy script để ghi
đè khóa cũ. APK dùng application ID hiện tại `com.example.project_one`.
Đây là bản cài APK trực tiếp; trước khi lên Play Store cần chốt application ID.

## 3. Build APK với URL thật

Sau khi có URL HTTPS của Render, chạy từ `frontend` (thay URL ví dụ):

```powershell
.\scripts\build-android-release.ps1 -ApiBaseUrl 'https://your-service.onrender.com'
```

URL chỉ chứa host, không thêm `/api/v1`. Script yêu cầu HTTPS và khóa ký riêng,
build APK release chung cho các kiến trúc Android, rồi lưu:

- `frontend/build/app/outputs/flutter-apk/app-release.apk`
- `frontend/build/releases/kakeibo-1.0.0+1.apk`
- File `.sha256` và `.json` bên cạnh APK ghi checksum, phiên bản và URL API.

Cài APK trên điện thoại bằng trình quản lý file hoặc `adb install -r <file.apk>`.
Nếu đã có bản dùng khóa debug, Android có thể từ chối cập nhật do khóa ký khác;
cần gỡ bản cũ trước khi cài. Gỡ app sẽ xóa session và dữ liệu cục bộ.
Đổi URL API cần build lại APK. Không đưa service role key vào app.

## 4. Cập nhật và rollback

Tăng version trong `frontend/pubspec.yaml`, giữ nguyên khóa ký và build lại.
Trên Render dùng **Manual Deploy** để chọn commit; automatic deploy đang tắt
để tránh thay backend ngay khi push. Nếu có lỗi, redeploy commit trước; không
xóa dữ liệu Supabase. Giữ APK trước đó cùng checksum để có bản đối chiếu.

Tài liệu chính thức:
[Render Docker](https://render.com/docs/docker),
[Render Blueprint](https://render.com/docs/blueprint-spec),
[Flutter Android release](https://docs.flutter.dev/deployment/android).
