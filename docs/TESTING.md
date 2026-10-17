# Kiểm thử hệ thống Kakeibo Zen

Rà soát ngày **17/10/2026**; công việc và tiêu chí nghiệm thu được theo dõi ở
[issue #21](https://github.com/Drista4real/Project1/issues/21).
Tài liệu này hướng dẫn chạy và giải thích phạm vi các bộ test trong repo.

## Hiện có và phần bổ sung

| Loại kiểm thử | Bộ test / cách chạy | Phạm vi và giới hạn |
| --- | --- | --- |
| Unit Python | `backend/tests/unit`, `classifier`, `forecaster` | Logic/config/model adapter; classifier/forecaster cần dependencies ML |
| API trong tiến trình | `backend/tests/api` qua pytest | FastAPI validation, parser và service; nhiều ca thay Auth/repository bằng fake, không chứng minh DB thật hoạt động |
| Integration / API E2E | `tests/backend-e2e`, Java + REST Assured | HTTP thật qua FastAPI → Supabase Auth/PostgREST → PostgreSQL; migration, trigger, CRUD, precision tiền, hoàn số dư, chuyển ví, RLS và cách ly người dùng |
| Integration text ingestion mới | `IngestionIT.java` | JWT thật → parser → bản nháp chưa lưu → người dùng sửa/xác nhận → lưu → đối soát số dư → xóa; từ chối input lỗi và truy cập chéo người dùng |
| Postman thủ công | `postman/collections/Kakeibo API` | Thư viện request Native Git; thêm thư mục `07 - Nhập liệu AI`; gửi từng request, không chạy cả thư viện bằng Runner |
| Postman regression mới | `postman/ci/regression.postman_collection.json` | 28 request có thứ tự, user/ví riêng, đăng nhập/refresh, contract bản nháp, 401/404/422, tạo/sửa/xóa và đối soát tiền; chạy trong stack tạm bằng Postman CLI |
| Flutter unit/widget | `frontend/test` | Cubit, repository mapping, form, review AI, lỗi và retry; dùng fake dữ liệu, chưa phải E2E trên điện thoại với backend thật |
| Dataset integrity | `tests/datasets` | Taxonomy, chia nhóm, chống rò rỉ train/validation/test; không thay thế đánh giá model trên dữ liệu thật |
| Android build mới trong CI | `.github/workflows/frontend.yml` | Build debug kiểm tra Dart/Gradle/plugin; checkout CI không có model ASR sinh cục bộ, nên build này không chứng minh voice offline hoạt động |

Postman và CI/CD là công cụ/cách chạy, không phải các mức kiểm thử riêng.
Postman có thể kiểm tra smoke, contract và integration; CI tự chạy các bộ test
khi mã thay đổi. Đã có nhiều kiểm thử ngoài unit trong repo, cần mở rộng theo
rủi ro nghiệp vụ thay vì viết lại toàn bộ bằng công cụ khác.

## Chạy kiểm tra

Từ thư mục `backend`, dùng môi trường dev đã cài dependencies:

```powershell
.\.venv\Scripts\python.exe -m ruff check app tests
.\.venv\Scripts\python.exe -m pytest tests/api tests/unit -q
.\.venv\Scripts\python.exe -m pytest -q
```

Lệnh cuối bao gồm ML tests, cần requirements classifier/forecaster. Không bỏ
qua lỗi thiếu dependency để báo toàn bộ backend đã đạt. CI backend sử dụng
lockfile đầy đủ trong container `backend-checks`.

Từ thư mục `frontend`:

```powershell
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub --coverage
flutter build apk --debug --no-pub
```

Workflow Flutter ghim SDK **3.41.3**, Java **17**, chạy trên Ubuntu 24.04; upload
test log và coverage ngay cả khi bước sau thất bại. Không phát hành APK debug
thành bản release. Bản có voice cần model thật và manifest được xác minh bằng
`frontend/scripts/prepare_voice_assets.py` trước build, rồi kiểm tra trên thiết bị.

Java và Postman chạy trên **GitHub Actions → Backend Java E2E**, bằng push/PR
chạm các đường dẫn backend/schema/test hoặc `postman/ci`; cũng có
`workflow_dispatch`. Xem [hướng dẫn stack](../tests/backend-e2e/README.md).
Mỗi job sinh credential riêng, không dùng `.env` production, không mở cổng host,
luôn thu báo cáo và xóa container/volume. Java và Postman có JUnit XML trong
artifact `backend-java-e2e-<run_id>-<attempt>`; lỗi test giữ workflow thất bại.

CI dùng Postman CLI **1.75.0**. JSON v2.1 cho phép xuất JUnit;
[YAML v3 hiện chỉ hỗ trợ CLI reporter](https://learning.postman.com/docs/postman-cli/postman-cli-reporters).
[Newman đã ngừng duy trì và không đọc Native Git v3](https://learning.postman.com/docs/reference/newman-cli/command-line-integration-with-newman).
Collection CI không có cloud ID, không login Postman hay đồng bộ kết quả lên
workspace; environment credential chỉ tồn tại trong container rồi được xóa.

## Những kiểm thử vẫn cần thêm

| Ưu tiên | Kiểm thử | Điều kiện và kết quả cần xác minh |
| --- | --- | --- |
| P0 | Mobile E2E với backend thật | Dùng `integration_test` + emulator/thiết bị và Supabase thử nghiệm: đăng nhập → nhập tay/text → review → lưu → ví/báo cáo → sửa/xóa; khởi động lại vẫn đọc đúng; user khác không nhìn thấy dữ liệu |
| P0 | Đường lỗi Auth/network | Hết hạn JWT/refresh bị thu hồi, logout/login đổi user không lộ cache; Supabase timeout/429/5xx; mất mạng khi lưu, thử lại không ghi trùng, UI thể hiện đúng trạng thái |
| P1 | Đồng thời và tính toàn vẹn tiền | Hai request sửa cùng giao dịch, ghi song song cùng ví, xóa/sửa khi đang lưu; kiểm tra xung đột và đối soát transaction/account/profile sau mọi thao tác |
| P1 | Queue và chịu lỗi AI | Sau khi triển khai job thật: Redis/Celery thật, worker restart, retry/backoff 429/timeout, payload JSON sai, job trùng, hết retry, giao dịch đã sửa/xóa; không ghi đè dữ liệu người dùng đã xác nhận |
| P1 | Contract receipt/forecast/job | Chỉ thêm khi route được đăng ký và có auth/giới hạn upload; hiện receipt là hook, router inference forecast chưa được include, Celery mới có `health.ping`; không dùng CRUD bản ghi dự báo để nhận là đã test inference |
| P1 | Model/thiết bị/cloud smoke | Model thật + bộ dữ liệu độc lập đã khử thông tin nhạy cảm: ASR WER/RTF/offline/quyền mic, VLM JSON và số học, classifier F1/fallback, forecast rolling-origin 7/14/30 ngày; cloud chạy riêng có giới hạn chi phí |
| P1 | Load/stress/soak | Workload user đã đăng nhập, transaction/overview/AI đo riêng; tăng tải đến 300 user, ghi RPS, p50/p95/p99, timeout, 4xx/5xx, CPU/RAM/DB connections và đối soát tiền; 500 RPS và 0% 5xx hiện là mục tiêu, chưa có bằng chứng đạt |
| P1 | Security regression | Bổ sung token hết hạn/chữ ký sai, mass assignment mọi resource, truy cập liên kết chéo user, input/upload quá cỡ, CORS theo cấu hình triển khai; kiểm tra dependency/secret trên CI |
| P1 | Triển khai và rollback | Staging tách biệt, migration từ schema phiên bản trước có dữ liệu, smoke sau deploy với user thử nghiệm, rollback image và phục hồi backup; kiểm tra model manifest trước phát hành |
| P2 | Accessibility/giao diện | Semantics, text scale, contrast, bàn phím, tablet/mobile; golden test cho màn ổn định; không thay widget test hiện có |

Flutter [phân biệt unit/widget và integration test trên ứng dụng thật](https://docs.flutter.dev/testing/overview).
Việc thêm `integration_test` mà vẫn fake toàn bộ backend không đủ để xác nhận
luồng toàn hệ thống.

## CI và CD

Hai workflow cũ kiểm tra backend/E2E và dataset; workflow mới bổ sung Flutter.
`render.yaml` đang đặt `autoDeployTrigger: off`: repo chưa có CD tự động được
bảo vệ bằng test. Chưa đổi cấu hình deploy trong công việc này.

Trước khi bật CD: chốt nhánh release, staging và credential, cấu hình các check
bắt buộc trong branch protection, rồi triển khai sau khi tất cả gate đã đạt;
smoke staging và rollback là bước tiếp theo. Path filter giảm chạy thừa nhưng
check bị skip có thể chặn merge nếu đặt trực tiếp làm required check; cần thiết kế
gate tổng hợp chạy mọi PR khi bật branch protection.

## Kết quả kiểm tra tại máy ngày 17/10/2026

- Ruff backend: đạt; pytest API + unit: **66 passed**.
- Flutter analyze: đạt; Flutter unit/widget: **85 passed**.
- Android debug APK: build local thành công; máy có model ASR cục bộ, khác checkout CI không có model. Chưa chạy APK trên thiết bị trong lần rà soát này.
- Java: Maven `test-compile` đạt cho toàn bộ 6 source files, target Java 21; chưa thực thi integration. Hai workflow thay đổi đã qua `actionlint` 1.7.7.
- Compose: `config --quiet` đạt với giá trị giả chỉ dùng kiểm tra cấu hình; collection JSON, 29 script JavaScript và YAML mới đã kiểm tra cú pháp. Postman CLI 1.75.0 đã xác nhận đọc collection/xuất JUnit và trả mã lỗi khi không có API; đây không phải kết quả regression nghiệp vụ đạt.
- Pytest toàn backend: chưa thu thập được toàn bộ do môi trường local thiếu `lightgbm`.
- Docker daemon chưa hoạt động: chưa chạy Java/Postman với stack thật hoặc xác nhận workflow trên GitHub. Bộ mới cần kết quả Actions trước khi coi là đã nghiệm thu integration.
