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

## Sửa sau khi đóng Ticket B — lựa chọn A/B/C/D và hạn mức Gemini

Hai vấn đề phát hiện sau khi đóng bốn ticket con, đều nằm trong luồng chat.

### Lựa chọn A/B/C/D không hiện (`89dc7d2`)

Chips `A. B. C. D.` **không phải UI tĩnh**. Chúng chỉ tồn tại khi model gọi tool
`ask_user_question`; khi đó `ChatService` đọc `options` từ kết quả tool và trả
về cùng lượt chat, client render thành chip kèm một chip `Khác`.

Prompt cũ chỉ *nhắc* tới tool, nên Gemini thường trả lời bằng văn bản thuần →
`options` rỗng → không có chip, **không có lỗi nào hiện ra**. Kiểm chứng với
Gemini 2.5 Flash thật:

| Tin nhắn | Trước | Sau |
|---|---|---|
| "Lập kế hoạch chi tiêu cho tôi" | ✗ | ✓ `7/30/90/365 ngày` |
| "Phân bổ ngân sách tháng" | ✗ | ✓ `7/30/90/365 ngày` |
| "Tiết kiệm tiền như thế nào?" | ✗ | ✓ 2 lựa chọn hướng đi |
| "Kiểm tra số dư hiện tại" | ✗ | ✓ 3 lựa chọn hướng đi |
| "Mình muốn ăn cơm tối, chi phí cố định 3 triệu" | ✗ | ✓ 3 lựa chọn hướng đi |

Sửa trong `backend/app/infrastructure/ai/chat/gemini_chat.py`:

- `SYSTEM_PROMPT_VERSION` → `finance-assistant-v2`.
- Thêm mục **"QUY TẮC VỀ CÁCH HỎI"** ở đầu prompt: câu trả lời có 2–4 đáp án
  rời rạc → **bắt buộc** gọi `ask_user_question`.
- **Cấm** liệt kê lựa chọn dạng văn bản rồi bảo người dùng "chọn 1, 2, 3".
- Con số tự do (thu nhập, chi phí cố định) vẫn hỏi bằng **văn bản** — không có
  gì để bấm.
- Mỗi lượt một câu hỏi, tránh spam chip.

Test hồi quy: `TestQuestionPrompt` trong `backend/tests/unit/test_chat.py` (4 test).

### Hạn mức Gemini hết (`429` → `429` riêng)

Key Gemini free tier chỉ cho **20 request/ngày**. Khi hết, provider trả
`429 RESOURCE_EXHAUSTED`. Trước đây lỗi này bị nuốt chung vào message
*"Trợ lý hội thoại tạm thời không phản hồi"* — sai, vì đây không phải sự cố tạm
thời mà là hạn mức đã dùng hết, thử lại ngay cũng vẫn lỗi.

Sửa:

- `backend/app/infrastructure/ai/chat/gemini_chat.py`: thêm `_quota_error()` nhận
  diện `APIError` code 429 / status `RESOURCE_EXHAUSTED`, trả message riêng
  *"Trợ lý hội thoại đã hết hạn mức gọi hôm nay. Vui lòng thử lại sau hoặc dùng
  gói có hạn mức cao hơn."* và `code="quota"`, **status 429** thay vì 503.
- Mọi lỗi provider khác vẫn là **503** `code="unavailable"` như cũ.
- `frontend/lib/core/network/finance_api_error.dart`: `/chat` pass qua detail cho
  status 429; thêm case 429 trong `switch` phòng khi không có detail.

Test: `TestQuotaExhaustion` (5 test) trong `backend/tests/unit/test_chat.py`,
`TestQuotaEndpoint` trong `backend/tests/unit/test_chat_endpoints.py`, và 2 test
trong `frontend/test/features/finance/data/finance_api_error_test.dart`.

> **Lưu ý vận hành:** key free tier giới hạn 20 request/ngày cho `gemini-2.5-flash`.
> Chat sẽ dừng hoạt động sau 20 lượt nếu không nâng plan. Khi triển khai thật cần
> key có billing, hoặc tự động đổi model khi hết hạn mức.

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

7. **Tính năng dựa trên tool call thì phải kiểm bằng provider thật.** Chips
   A/B/C/D chỉ hiện khi Gemini gọi `ask_user_question`. Unit test dùng model giả
   luôn pass, nên không bắt được prompt không đủ mạnh. Kiểm chứng bằng script gọi
   Gemini thật với đúng `SYSTEM_PROMPT` + tool declarations mới biết model có gọi
   tool không. Đừng tin vào việc "prompt có nhắc tới tool là đủ".

8. **Phân biệt lỗi provider theo nguyên nhân.** `429 RESOURCE_EXHAUSTED` (hết hạn
   mức) khác hẳn `503` (sự cố tạm thời): thử lại ngay cũng vẫn lỗi. Gộp chung
   khiến người dùng tưởng chỉ cần bấm lại. Backend đã trả status 429 riêng cho
   trường hợp này.

## Kiểm thử đã chạy

| Bộ test | Kết quả |
|---|---|
| `pytest tests` (backend) | 748 passed |
| `ruff check app tests` | All checks passed |
| `flutter test` (frontend) | 180 passed |
| `flutter analyze lib test` | No issues found |

> Sau các sửa bổ sung (chips A/B/C/D + hạn mức 429): `pytest tests` → **758
> passed**, `ruff check app tests` → **All checks passed**, `flutter test` → **182
> passed**, `flutter analyze` → **No issues found**.

## Trạng thái Ticket B

| Ticket | Nội dung | Phụ thuộc | Trạng thái |
|---|---|---|---|
| [#91](https://github.com/Drista4real/Project1/issues/91) | Đăng ký `forecast.router` + trả 503 | — | ✅ Đóng — `18fe061` |
| [#92](https://github.com/Drista4real/Project1/issues/92) | Tải + bundle model ASR PhoWhisper INT8 | — | ✅ Đóng — setup, không sửa code |
| [#93](https://github.com/Drista4real/Project1/issues/93) | Nút "Hóa đơn" báo đúng trạng thái | #91 | ✅ Đóng — `f0a12d7` |
| [#94](https://github.com/Drista4real/Project1/issues/94) | Test hồi quy transcript → `/ingestion/text` | #92 | ✅ Đóng — `3bacadf` |

Issue cha [#90](https://github.com/Drista4real/Project1/issues/90) đóng theo khi cả
bốn ticket con đã đóng.

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
- `docs/adr/0010-conversational-home-canvas.md` — quyết định khung hội thoại, gồm
  amendment về lựa chọn A/B/C/D và về hạn mức provider
- `GLOSSARY.md` — thuật ngữ *Receipt scan*
