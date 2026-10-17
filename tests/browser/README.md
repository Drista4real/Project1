# Selenium automation trên trình duyệt

Workflow: [Selenium web browsers](../../.github/workflows/selenium-web.yml).
Theo dõi tại [issue #22](https://github.com/Drista4real/Project1/issues/22).

Pipeline khởi đầu chạy **ứng dụng Flutter web đã compile thật** trên Chrome,
Edge và Firefox, không dùng mock UI. Phạm vi hiện tại là smoke UI/validation;
chưa xác nhận đăng nhập thành công, CRUD hoặc số dư với backend/database thật.

## Các pipeline/job

```text
push / pull_request / workflow_dispatch
  └─ build-web (Ubuntu 24.04, Flutter 3.41.3)
       └─ artifact web build duy nhất
            ├─ browser-smoke: chrome  (Windows Server 2022)
            ├─ browser-smoke: edge    (Windows Server 2022)
            └─ browser-smoke: firefox (Windows Server 2022)
                 └─ Selenium browser gate
```

- Build một lần, tất cả trình duyệt dùng cùng bundle. Python 3.12, pytest 9.1.1
  và Selenium 4.51.0 được ghim trong workflow/requirements.
- Runner Windows 2022 có Chrome, Edge và Firefox; Selenium Manager chọn driver
  khớp browser đang cài. Browser do runner cập nhật, phiên bản thực tế được ghi
  vào `browser.json`; không xem đây là môi trường browser cố định phiên bản.
- `fail-fast: false`: lỗi Chrome không hủy test Edge/Firefox. Không retry hay
  dùng `continue-on-error`; gate chỉ đạt khi build và mọi browser đều đạt.
- Bật trên push/PR thay đổi `frontend/**`, `tests/browser/**` hoặc workflow.
  Muốn chạy thủ công: **Actions → Selenium web browsers → Run workflow** sau
  khi workflow có trên default branch. Push trigger chạy trên nhánh chứa file.
- Đây là CI, không publish website hoặc deploy backend. Gate cũng chịu path
  filter của workflow; nếu muốn bắt buộc với mọi PR, cần bỏ filter hoặc thêm
  workflow điều phối luôn chạy trước khi cấu hình branch protection.

## Năm kịch bản smoke hiện tại

1. Flutter render được, có navigation và lời nhắc đăng nhập khi chưa có phiên.
2. Bấm chuyển Sổ thu chi/Báo cáo/Ngân sách/Cài đặt; refresh giữ route Cài đặt.
3. Gửi form đăng nhập rỗng hiển thị validation email/password.
4. Nhập email sai và password ngắn vẫn bị chặn ở UI.
5. Chuyển đăng nhập ↔ đăng ký và validation form đăng ký.

Mỗi test tạo browser/profile mới. Selenium dùng explicit wait thay cho sleep
cố định, thao tác click/gõ qua WebDriver; không truy cập Dart state hoặc gọi
thẳng callback nghiệp vụ bằng JavaScript.

## Build kiểm thử và cấu hình

`build_web.py` build entry point thật `lib/main.dart` với:

| Define | Giá trị |
| --- | --- |
| `SUPABASE_URL` | `http://127.0.0.1:1` |
| `SUPABASE_ANON_KEY` | `sb_publishable_browser_smoke_only` |
| `API_BASE_URL` | `http://127.0.0.1:1` |
| `ENABLE_WEB_SEMANTICS` | `true` |

Các địa chỉ này cố ý không có service: test chỉ dùng form không hợp lệ, không
đăng nhập/ghi dữ liệu thật và không cần GitHub Secrets. `SupabaseConfig` đọc
`--dart-define`; khi build app bình thường không truyền define thì giữ cấu hình
mặc định hiện có. Không sử dụng service-role key trong frontend.

Flutter render canvas; build kiểm thử bật `SemanticsBinding.ensureSemantics()`
để có accessibility DOM. Các phần tử quan trọng có `Semantics.identifier` và
Selenium tìm `flt-semantics-identifier` qua shadow DOM. Không dùng Dart `Key`
như HTML ID. Các identifier được dùng chung với UI thật, không có màn fake.

`--no-web-resources-cdn` đóng gói CanvasKit cục bộ. Model ASR được sinh cục bộ
không có trong checkout CI; browser smoke không kiểm tra voice trên Android.
Bundle có marker `browser-test-config.json`; runner từ chối bundle không do
script build tạo hoặc cấu hình không khớp. Đây là kiểm tra nhầm cấu hình,
không phải cơ chế sandbox cho code không tin cậy.

## Chạy local trên PowerShell

Cần Flutter 3.41.3, Python >=3.12 và browser tương ứng. Không cần Docker.
Chạy từ root repo:

```powershell
python -m venv tests/browser/.venv
& tests/browser/.venv/Scripts/python.exe -m pip install -r tests/browser/requirements.txt
Push-Location frontend
flutter pub get --enforce-lockfile
Pop-Location
python tests/browser/build_web.py
& tests/browser/.venv/Scripts/python.exe tests/browser/run.py --browser chrome
& tests/browser/.venv/Scripts/python.exe tests/browser/run.py --browser edge
& tests/browser/.venv/Scripts/python.exe tests/browser/run.py --browser firefox
```

Thêm `--headed` để quan sát browser. Runner tự mở static server ở cổng trống,
chỉ bind `127.0.0.1`; luôn dừng server khi pytest kết thúc và trả đúng exit code.
Không chạy `pytest` từ root dùng config của backend/ML; `run.py` chọn riêng
`tests/browser/pytest.ini`. Selenium Manager cần mạng ở lần đầu để tải driver;
nếu máy không có Firefox thì cài Firefox trước hoặc để Manager tải browser
trong cache. Không cần tắt kiểm tra TLS để chạy test.

## Báo cáo và xử lý lỗi

Artifact Actions: `selenium-<browser>-<run_id>-<attempt>`, giữ 7 ngày:

- `junit.xml`: kết quả pytest, gồm lỗi setup/driver và lỗi assertion.
- `browser.json`: browser, phiên bản driver và nền tảng thực tế.
- `server.log`: request tới web bundle.
- Khi lỗi có browser session: PNG, HTML và console log nếu driver hỗ trợ;
  Firefox có thể không hỗ trợ `get_log`, khi đó có file ghi lý do thiếu evidence.

Local ghi trong `tests/browser/artifacts/<browser>/` (gitignore). Build artifact
giữ 3 ngày, chỉ dùng debug CI và không phát hành thành bản người dùng.
Không upload session/token hay dùng profile Chrome cá nhân trong các test mới.

Nếu không thấy semantics, kiểm tra đã build bằng `build_web.py`, build có
`ENABLE_WEB_SEMANTICS=true` và đã đợi app khởi động. Nếu driver không khởi động,
xem lỗi Selenium Manager, version thực tế, quyền chạy browser và truy cập mạng
tới vendor; lỗi setup phải giữ CI thất bại.

## Mở rộng sau pipeline nền

Thêm các file `test_*.py` trong `scenarios/` và dùng fixture `browser` để có
cleanup/evidence. Giữ selector trong helper/page object khi số màn tăng lên.
Không đưa case CRUD thật vào suite này với endpoint cổng 1. Bước tiếp theo là
job riêng có Auth/API/database thử nghiệm, user ngẫu nhiên và teardown dữ liệu,
rồi test đăng nhập → nhập/review → lưu → ví/báo cáo → sửa/xóa → logout. OAuth,
camera/microphone, offline sync, performance và Safari cần môi trường/job riêng.

Tài liệu chính thức: [Flutter web accessibility](https://docs.flutter.dev/ui/accessibility/web-accessibility),
[Selenium Manager](https://www.selenium.dev/documentation/selenium_manager/),
[Windows 2022 runner image](https://github.com/actions/runner-images/blob/main/images/windows/Windows2022-Readme.md).

## Kết quả local ngày 17/10/2026

| Browser trên Windows | Kết quả |
| --- | --- |
| Chrome 155.0.8059.84 | 5/5 đạt |
| Edge 155.0.4283.45 | 5/5 đạt |
| Firefox 158.0 | 5/5 đạt |

Đã kiểm tra build Flutter web release, `flutter analyze`, Ruff và `actionlint`.
85 Flutter unit/widget test đạt; sau chỉnh ranh giới semantics đã chạy lại 8 test
app/ledger/transaction liên quan và đều đạt. Local dùng Python 3.13.7; workflow
ghim Python 3.12. Chưa chạy workflow trên GitHub Actions, nên kết quả local
không phải xác nhận toàn pipeline trên runner GitHub đã đạt.
