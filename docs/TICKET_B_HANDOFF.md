# Bàn giao Ticket B — Nền API cho media

Tài liệu này ghi lại trạng thái Ticket B sau khi hoàn tất #91 và #93, để có thể
bổ sung và kiểm thử về sau. Ticket cha: [#90](https://github.com/Drista4real/Project1/issues/90).

Spec gốc: `docs/DYNAMIC_BUDGET_SPEC.md`, mục 13 — "Ticket B — Nền media cho
pre-purchase advisor".

## Trạng thái hiện tại

| Ticket | Nội dung | Phụ thuộc | Trạng thái |
|---|---|---|---|
| [#91](https://github.com/Drista4real/Project1/issues/91) | Đăng ký `forecast.router` + trả 503 | — | ✅ Đóng — `18fe061` |
| [#92](https://github.com/Drista4real/Project1/issues/92) | Tải + bundle model ASR PhoWhisper INT8 | — | ✅ Đóng — setup, không sửa code |
| [#93](https://github.com/Drista4real/Project1/issues/93) | Nút "Hóa đơn" báo đúng trạng thái | #91 | ✅ Đóng — `f0a12d7` |
| [#94](https://github.com/Drista4real/Project1/issues/94) | Test hồi quy transcript → `/ingestion/text` | #92 | ✅ Đóng — phần test tự động không cần model |

Cả ba commit đã push lên `origin/home_feat`.

> **Lưu ý về #94:** issue ghi *"blocked by #92"* vì cần model thật để kiểm chứng thủ
> công trên Android. Phần test tự động thì **không** cần model — nó dùng
> `VoiceInput` giả lập qua tham số `voiceInput` của `AiQuickInputScreen`, nên chạy
> được trên CI Ubuntu không có Android, không có model. Vì vậy #94 đã làm được và
> đóng trước #92. Phần còn lại của #92 là kiểm chứng thủ công trên thiết bị.

## Quyết định kiến trúc đã chốt

Theo ADR 0004 (ASR on-device) và ADR 0008 (không mở route upload receipt):

- **ASR chạy on-device trên Flutter.** Nút "Nói nhanh" phiên âm bằng
  sherpa-onnx/PhoWhisper INT8 trên máy. **Không** mở `POST /api/v1/ingestion/audio`
  ở backend Python.
- **Không mở route upload hóa đơn.** Hook `get_receipt_ingestor`
  (`backend/app/api/v1/ingestion.py:52`) giữ nguyên, không gắn route. Mở route này
  sau này phải là ticket riêng kèm cập nhật ADR 0008.
- `POST /ingestion/audio` và `POST /ingestion/receipt` **hoãn sang milestone 4**
  (`docs/APP_COMPLETION_CHECKLIST.md`).

## Đã xong

### #91 — Forecast router (`18fe061`)

- `backend/app/api/v1/router.py` include `forecast.router`.
- `backend/app/api/v1/forecast.py`: `get_cashflow_forecaster()` trả `None` thay vì
  `raise HTTPException`; route trả **503** với message tiếng Việt
  *"Dự báo dòng tiền chưa sẵn sàng. Vui lòng thử lại sau."*
- Body 503 chỉ có `detail` — không bao giờ trả dự báo giả.
- `ValueError` từ Model 2 map thành **422**.
- Test: `backend/tests/api/test_forecast.py` — 12 test.

### #93 — Nút "Hóa đơn" (`f0a12d7`)

- `frontend/lib/features/ai/widgets/natural_input_card.dart`: thêm callback bắt buộc
  `onReceipt` và hằng `receiptUnavailableMessage`. Nút dùng
  `key: ValueKey('aiReceiptButton')`.
- Nút disable theo `disabled`, `isAnalyzing`, `recording`, `voiceBusy` — cùng điều
  kiện với nút "Dán nội dung" và "Phân tích" trong cùng `Wrap`.
- `frontend/lib/features/ai/screens/ai_quick_input_screen.dart`:
  `_showReceiptUnavailable()` hiện SnackBar giải thích rõ tại sao chưa dùng được.
- **Xóa dead code** `frontend/lib/features/ai/widgets/ai_input_box_card.dart`
  (216 dòng, không nơi nào import).
- Test: 2 test widget trong
  `frontend/test/features/ai/ai_quick_input_screen_test.dart`.
- Tài liệu: `docs/DYNAMIC_BUDGET_SPEC.md` (mục Ticket B + bảng tra nhanh) và
  `GLOSSARY.md` (thêm thuật ngữ *Receipt scan*).

## Còn lại

### #92 — Model ASR cho thiết bị

Đây là **setup, không phải code** — không có thay đổi source nào được commit.
Chi tiết đầy đủ trong issue #92. Đã chạy thành công:

```powershell
python backend/scripts/download_asr_model.py --github-cli   # ~104 MB, verify SHA256 theo manifest
python frontend/scripts/prepare_voice_assets.py              # chép vào frontend/assets/models/
python -m pip install -r backend/requirements-asr.txt        # sherpa-onnx 1.13.8, av 16.1.0
```

Kết quả kiểm chứng:

- `weights/onnx/phowhisper-tiny/` có đủ 3 artifact, SHA256 khớp `manifest.json`.
- `frontend/assets/models/phowhisper-tiny/` có đủ 3 file, SHA256 khớp (verify cả 6
  file ở cả hai vị trí).
- `SherpaOnnxRecognizer(allow_mock=False)` → `is_mock: False`, recognizer load
  thành công → model thật chạy được, không phải mock.
- `import sherpa_onnx` (1.13.8) và `import av` (16.1.0) OK.

Ràng buộc quan trọng:

- **Không commit binary model vào Git.** `.gitignore` đã ignore
  `weights/onnx/phowhisper-tiny/*.onnx` và
  `frontend/assets/models/phowhisper-tiny/*.onnx`. Giữ nguyên — phân phối qua
  GitHub Release `model3-phowhisper-tiny-int8-v1`.
- **Không đổi model.** Chỉ dùng bản INT8 đã ghim trong manifest.
- Không sửa `voice_input_native.dart` trong ticket này — code phiên âm đã có test.
- CI (`flutter build apk --debug`) build **không kèm** model nên vẫn phải xanh.

**Việc còn lại của #92 là kiểm chứng thủ công trên Android** (không làm được
trong môi trường CI): build APK, cài lên máy, bấm "Nói nhanh" và nói
*"ăn trưa bún bò 65k"* → transcript đúng → bấm "Phân tích" → draft `65.000`.

> **Lưu ý về lockfile:** `flutter pub deps` (hay `flutter pub get` không khoá) có
> thể nâng các package transitive (`matcher`, `meta`, `test_api`, `vector_math`).
> CI chạy `flutter pub get --enforce-lockfile` với Flutter 3.41.3 còn local là
> 3.47.7, nên **không được commit thay đổi `frontend/pubspec.lock`**. Nếu lỡ
> sửa, dùng `git checkout -- frontend/pubspec.lock`.

### #94 — Test hồi quy transcript → `/ingestion/text`

Đã xong. Ba test widget trong
`frontend/test/features/ai/ai_quick_input_screen_test.dart`:

- Transcript đi vào ô nhập rồi gửi **nguyên văn** tới `/ingestion/text`.
- Transcript rỗng → hiện lỗi tiếng Việt và **không** gọi API.
- Transcript dài hơn 2000 ký tự bị cắt đúng giới hạn endpoint.

Phần backend đã có sẵn: `test_spoken_money_without_punctuation` tại
`backend/tests/api/test_ingestion.py:259`.

Test dùng `VoiceInput` giả lập (`FakeVoice`) nên chạy được trên CI Ubuntu không
có Android, không có model. `FakeVoice` được thêm field `transcript` để test điều
khiển được nội dung phiên âm.

Phần còn lại của #92 là kiểm chứng thủ công trên Android — phần test tự động của
#94 không phụ thuộc model.

## Bài học cần nhớ cho các phiên sau

1. **Lỗi gốc của #91 là 404, không phải 500.** FastAPI đã tự chuyển
   `HTTPException` trong dependency thành response 503 đúng cách. Lỗi thật là route
   chưa được include vào `api_router`. Đừng vội sửa dependency thành `raise` trước khi
   route đã được đăng ký.

2. **Có thể có revert chưa commit trong working tree.** Trước khi bắt đầu ticket mới,
   luôn chạy `git status` và `git diff HEAD` để phát hiện thay đổi lạ. Trong phiên này
   `router.py` bị gỡ `include_router(forecast_router)` khiến 9 test fail với 404.

3. **Prefix router đã chuẩn hoá — không sửa lại.** Mỗi router tự mang prefix đầy đủ
   (`/api/v1/...`), `api_router` không có prefix. OpenAPI ra đúng `/api/v1/*`, không
   lặp. Yêu cầu "sửa prefix lặp `/api/v1`" trong Ticket B gốc là **đã lỗi thời**.

4. **Lockfile phải giữ nguyên khi commit.** CI build Flutter 3.41.3 còn local là
   3.47.7. Không commit thay đổi `frontend/pubspec.lock`, dùng `--enforce-lockfile`.

5. **`flutter analyze` mất ~2 phút.** Chạy nền và chờ, đừng để timeout.

6. **File nhị phân lớn không vào git.** Model ONNX ~102 MB phân phối qua GitHub
   Release, không phải commit.

## Kiểm thử đã chạy

| Bộ test | Kết quả |
|---|---|
| `pytest tests` (backend) | 748 passed |
| `ruff check app tests` | All checks passed |
| `flutter test` (frontend) | 180 passed |
| `flutter analyze lib test` | No issues found |

## Trạng thái Ticket B

| Ticket | Nội dung | Phụ thuộc | Trạng thái |
|---|---|---|---|
| [#91](https://github.com/Drista4real/Project1/issues/91) | Đăng ký `forecast.router` + trả 503 | — | ✅ Đóng — `18fe061` |
| [#92](https://github.com/Drista4real/Project1/issues/92) | Tải + bundle model ASR PhoWhisper INT8 | — | ✅ Đóng — setup, không sửa code |
| [#93](https://github.com/Drista4real/Project1/issues/93) | Nút "Hóa đơn" báo đúng trạng thái | #91 | ✅ Đóng — `f0a12d7` |
| [#94](https://github.com/Drista4real/Project1/issues/94) | Test hồi quy transcript → `/ingestion/text` | #92 | ✅ Đóng — phần test tự động không cần model |

Cả ba commit đã push lên `origin/home_feat`.

> **Lưu ý về #94:** issue ghi *"blocked by #92"* vì cần model thật để kiểm chứng thủ
> công trên Android. Phần test tự động thì **không** cần model — nó dùng
> `VoiceInput` giả lập qua tham số `voiceInput` của `AiQuickInputScreen`, nên chạy
> được trên CI Ubuntu không có Android, không có model. Vì vậy #94 đã làm được và
> đóng trước #92. Phần còn lại của #92 là kiểm chứng thủ công trên thiết bị.

## Tài liệu liên quan

- `docs/DYNAMIC_BUDGET_SPEC.md` — mục 13 (Ticket B) và Phụ lục B (bảng tra nhanh)
- `docs/MODEL3_SETUP.md` — hướng dẫn tải và đóng gói model ASR
- `docs/adr/0004-three-tier-ai-and-modality-fallback.md` — quyết định ASR on-device
- `docs/adr/0008-shared-ingestion-model-runtime.md` — quyết định không mở route upload receipt
- `GLOSSARY.md` — thuật ngữ *Receipt scan*
