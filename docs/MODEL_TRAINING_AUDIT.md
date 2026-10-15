# Báo cáo rà soát huấn luyện model — 14/10/2026

Phạm vi: dự án `D:\Project1_TPN\Project1`, gồm mã nguồn backend/frontend, scripts, dữ liệu, checkpoint, cache model trên máy, tài liệu, kiểm thử và lịch sử Git liên quan. Báo cáo phản ánh trạng thái cục bộ tại thời điểm rà soát; không kiểm tra database, dịch vụ cloud hoặc bản triển khai từ xa.

**Có bằng chứng hai model LightGBM đã được huấn luyện và lưu checkpoint.** Hệ thống gọi chung là bốn nhóm Model 1–4, nhưng các nhóm còn lại gồm model có sẵn, công thức thống kê hoặc tích hợp API. Không có bằng chứng dự án tự train/fine-tune PhoBERT, PhoWhisper, Qwen hay Gemini.

Đã đọc trực tiếp checkpoint, đếm CSV bằng trình đọc CSV, tái tạo dữ liệu trong thư mục tạm để đối chiếu, kiểm tra SHA256 của ASR, nạp ASR thật và đánh giá lại checkpoint hiện có. Không huấn luyện lại hoặc thay đổi dữ liệu/checkpoint. Kết quả máy đọc được: [model-training-audit-results.json](model-training-audit-results.json).

## 1. Danh sách model và những gì đã làm

| Thành phần | Model/công nghệ | Công dụng | Đã làm với việc train | Dữ liệu cục bộ | Bằng chứng |
|---|---|---|---|---|---|
| Model 1 — phân loại giao dịch | `vinai/phobert-base` + `LGBMClassifier` | Gán câu giao dịch vào 6 danh mục, trả độ tự tin | Dùng PhoBERT có sẵn để trích đặc trưng; **train LightGBM** | 1.500 câu; theo script: 1.200 train, 300 test | Checkpoint đã fit, 768 đặc trưng, 100 vòng boosting, 600 cây; thống kê cây đầu ghi nhận 1.200 mẫu |
| Model 2 — thu nhập cố định | `LGBMRegressor` | Dự báo biến động số dư và đường số dư 30 ngày; cảnh báo thiếu tiền trước lương | **Train LightGBM** trên chuỗi thời gian | 180 ngày; 7 ngày khởi tạo lag, 138 train, 35 test | Checkpoint đã fit, 6 đặc trưng, 100 cây; marker `delta_balance`; cây đầu ghi nhận 138 mẫu |
| Model 2 — thu nhập linh hoạt | EWMA + công thức runway | Ước lượng tốc độ tiêu tiền, số ngày còn đủ tiền, đường số dư và cảnh báo | Cài công thức, **không train** tham số từ dữ liệu | 180 ngày trong `balance_flexible.csv`; không chia train/test | `flexible_income.py`, alpha mặc định 0,3 |
| Model 3 — giọng nói | `vinai/PhoWhisper-tiny`, ONNX INT8, `sherpa-onnx` | Chuyển tiếng nói tiếng Việt thành văn bản offline | Tải trọng số có sẵn, chuyển định dạng, export và lượng tử hóa; **không train/fine-tune** | Không có bộ audio train/test cục bộ | Encoder/decoder thật; SHA256 khớp manifest; runtime nạp được với `allow_mock=False`, `is_mock=False` |
| Model 3 — chuẩn hóa tiền | Regex + quy tắc số tiếng Việt | Chuẩn hóa “35k”, “1 củ rưỡi”… thành VND | Viết quy tắc; **không phải model được train** | Các tình huống kiểm thử trong code | `normalizer.py` |
| Model 4 — đọc hóa đơn | Qwen2.5-VL-7B-Instruct qua API | Trích cửa hàng, ngày, món hàng, số tiền, danh mục | Tích hợp inference, prompt, JSON schema, kiểm tra số học; **không train** | Không có bộ hóa đơn train/test cục bộ | `qwen_client.py`, `schemas.py`; không có checkpoint Qwen tại dự án |
| Model 4 — cố vấn | Gemini 2.5 Flash qua API | Diễn giải cảnh báo và chỉ số đã tính | Tích hợp inference, prompt theo nhóm thu nhập, kiểm định phản hồi; **không train** | Chỉ số đầu vào và prompt lúc gọi; không có dataset train | `advisor.py`, `_gemini.py`; không có checkpoint Gemini |

`LabelEncoder` chỉ là bộ ánh xạ 6 tên nhãn sang số, không tính thành model dự đoán riêng. JSON schema, prompt và dữ liệu gửi lúc suy luận cũng không phải dữ liệu huấn luyện.

## 2. Kiểm kê dữ liệu thực tế

Số dòng dưới đây là **bản ghi dữ liệu, không tính dòng tiêu đề**.

| Tập dữ liệu | Số bản ghi | Cột | Nguồn / vai trò | Kiểm tra thực tế |
|---|---:|---|---|---|
| `data/processed/data_transactions.csv` | **1.500** | `text,category` | Câu giao dịch giả lập để train classifier | 1.488 câu/bản ghi duy nhất; 12 lần lặp dư; không ô thiếu |
| `data/processed/balance_fixed.csv` | **180** | `date,income,expense,balance` | Lịch sử số dư giả lập để train forecaster cố định | 01/01–29/06/2026; 180 bản ghi duy nhất; không ô thiếu; 6 ngày có thu nhập |
| `data/processed/balance_flexible.csv` | **180** | Như trên | Lịch sử giả lập làm đầu vào EWMA | 01/01–29/06/2026; 180 bản ghi duy nhất; không ô thiếu; 15 ngày có thu nhập |
| `data/raw/audio/` | **0 tệp audio** | — | Vị trí dự kiến chứa âm thanh | Chỉ có `.gitkeep` |
| `data/raw/receipts/` | **0 ảnh hóa đơn** | — | Vị trí dự kiến chứa hóa đơn | Chỉ có `.gitkeep` |

Tổng ba CSV là **1.860 bản ghi**, thuộc hai loại dữ liệu khác nhau, không phải một tập train chung. Cả ba file **khớp từng byte** với dữ liệu sinh từ script hiện tại bằng cấu hình mặc định và seed 42. Đây là bằng chứng dữ liệu giả lập, không phải dữ liệu giao dịch người dùng lấy từ Supabase.

| Nhãn classifier | Tổng | Train theo split hiện tại | Test theo split hiện tại | Câu rõ theo generator | Câu nhiễu theo generator |
|---|---:|---:|---:|---:|---:|
| Ăn uống | 250 | 200 | 50 | 175 | 75 |
| Đi lại | 250 | 200 | 50 | 175 | 75 |
| Mua sắm | 250 | 200 | 50 | 175 | 75 |
| Hóa đơn/Nhà ở | 250 | 200 | 50 | 175 | 75 |
| Y tế | 250 | 200 | 50 | 175 | 75 |
| Khác | 250 | 200 | 50 | 175 | 75 |
| **Tổng** | **1.500** | **1.200** | **300** | **1.050** | **450** |

Generator có 12 mẫu câu rõ và 12 mẫu câu nhiễu cho mỗi nhãn: tổng 144 mẫu câu, sau đó thay số tiền và chọn ngẫu nhiên. Câu nhiễu gồm không dấu, viết tắt, lỗi gõ và tiếng lóng. Biến thể số tiền làm tăng số câu nhưng chưa tạo ra mức đa dạng ngữ nghĩa tương đương dữ liệu thật.

Profile cố định bắt đầu với 5 triệu đồng, nhận 15 triệu vào ngày 5; chi cơ bản ngẫu nhiên 100–300 nghìn/ngày, tăng 30% cuối tuần, thêm 3,5 triệu tiền thuê vào ngày 30 nếu tháng có ngày đó. Profile linh hoạt bắt đầu với 8 triệu, nhận 4 hoặc 6 triệu cách nhau 7–18 ngày, chi 50–500 nghìn/ngày. Số dư được cộng dồn từ thu và chi.

## 3. Cách train và cách hoạt động

### Model 1: PhoBERT + LightGBM classifier

Luồng: **câu giao dịch → chữ thường/chuẩn hóa khoảng trắng → tách từ bằng underthesea → tokenizer PhoBERT → vector CLS 768 chiều → LightGBM → 6 xác suất → nhãn có xác suất cao nhất**.

PhoBERT chạy CPU ở chế độ `eval()` và `torch.no_grad()`, không cập nhật trọng số. Lấy token đầu từ `last_hidden_state`, giới hạn 256 token, padding theo batch. Script mặc định trích đặc trưng theo batch 16. Như vậy phần học theo bài toán của dự án nằm ở LightGBM, không phải fine-tune Transformer.

LightGBM là tập hợp cây quyết định được bổ sung lần lượt để cải thiện dự đoán. Checkpoint classifier dùng `gbdt`, `objective=multiclass`, `n_estimators=100`, `learning_rate=0.05`, `num_leaves=31`, `min_child_samples=20`, `random_state=42`. Sáu lớp tạo ra 600 cây trong 100 vòng boosting. Mô hình suy luận được đặt `n_jobs=1`.

Chia ngẫu nhiên có giữ tỷ lệ lớp: `test_size=0.2`, `stratify=labels`, seed 42. Chỉ fit 1.200 mẫu train; 300 mẫu còn lại dùng đánh giá. Không có tập validation riêng, vòng tìm siêu tham số hay cross-validation trong pipeline hiện tại.

Nếu xác suất cao nhất ≥0,8, trả tín hiệu `LOCAL`; thấp hơn trả `CLOUD_FALLBACK`. Use case đánh dấu cần người dùng kiểm tra, demo hiển thị nhãn tạm và yêu cầu xác nhận. **Chưa có luồng tự gọi Gemini phân loại lại** trong mã hiện tại.

Lưu `lgbm_classifier.pkl`, `label_encoder.pkl`, `classifier_config.json`; PhoBERT được cache riêng tại `weights/cache/phobert/`. Metadata hiện lưu revision `main`, không ghim commit; cache `main` trên máy trỏ tới `01daacda68afe13d83023d16ec647239e344a1e6`.

Nguồn: [train_classifier.py](../backend/scripts/train_classifier.py), [phobert_embedder.py](../backend/app/infrastructure/ai/classifier/phobert_embedder.py), [lgbm_inference.py](../backend/app/infrastructure/ai/classifier/lgbm_inference.py).

### Model 2: LightGBM forecaster cho thu nhập cố định

Model học **chênh lệch số dư giữa hai ngày**, không dự đoán trực tiếp số dư tuyệt đối. Sáu đặc trưng theo đúng thứ tự:

| Đặc trưng | Ý nghĩa |
|---|---|
| `is_payday` | Ngày 5, theo lịch lương mặc định |
| `is_rent_day` | Ngày 30, theo lịch thuê mặc định |
| `is_weekend` | Thứ Bảy/Chủ nhật |
| `day_of_month` | Ngày trong tháng |
| `delta_lag_1` | Biến động số dư ngày trước |
| `delta_lag_7` | Biến động số dư 7 ngày trước |

Không đưa thu/chi của chính ngày cần dự báo vào đầu vào, vì chưa biết chúng khi dự báo tương lai. Bảy ngày đầu khởi tạo lag, còn 173 mẫu đặc trưng. Chia theo thời gian, không xáo trộn: 138 train từ **08/01–25/05/2026**, 35 test từ **26/05–29/06/2026**.

Checkpoint dùng `gbdt`, 100 vòng/cây, learning rate 0,05, 15 lá, `min_child_samples=2`, seed 42, một luồng CPU. Chỉ lưu mô hình fit trên phần train, không fit lại toàn bộ 180 ngày sau đánh giá.

Khi chạy: dự đoán delta ngày kế tiếp, cộng vào số dư trước, cập nhật lag bằng delta vừa dự đoán rồi lặp lại. Đây là dự báo tự hồi quy: càng xa thì sai số có thể tích lũy. Runtime cần ít nhất 8 số dư liên tiếp để có 7 delta quan sát. Cảnh báo `CASHFLOW_MISMATCH` nếu số dư hiện tại hoặc một số dư dự báo trước kỳ lương dưới 500.000 đồng.

Nguồn: [train_forecaster.py](../backend/scripts/train_forecaster.py), [features.py](../backend/app/infrastructure/ai/forecaster/features.py), [fixed_income.py](../backend/app/infrastructure/ai/forecaster/fixed_income.py).

### Model 2: EWMA cho thu nhập linh hoạt

Không có bước `.fit()` hoặc checkpoint. Alpha 0,3 được chọn cố định trong code:

```text
burn đầu tiên = chi tiêu đầu tiên
burn hôm nay = 0,3 × chi hôm nay + 0,7 × burn trước
runway = max(số dư, 0) / burn, khi burn > 0
số dư dự kiến ngày d = số dư hiện tại − burn × d
safe_to_spend = số dư hiện tại / 30
```

Runway là số ngày ước lượng còn đủ tiền. Số dư dương và burn bằng 0 được biểu diễn runway vô hạn bằng `None`. Dự báo giả định không có khoản thu tương lai; đọc chi tiêu quan sát thay vì dùng delta số dư để tránh khoản thu làm che mất tốc độ tiêu tiền. Cảnh báo `WINDFALL_DEPLETION` khi runway ≤7 hoặc chi trung bình 3 ngày gần nhất vượt 130% mức trung bình các ngày trước.

CSV linh hoạt là đầu vào tính toán/demo, không phải tập train cho một LightGBM thứ ba. Nguồn: [flexible_income.py](../backend/app/infrastructure/ai/forecaster/flexible_income.py).

### Model 3: PhoWhisper và chuẩn hóa tiếng lóng

PhoWhisper là model nhận dạng tiếng nói có sẵn. Encoder xử lý biểu diễn âm thanh, decoder sinh chuỗi token văn bản. Dự án ánh xạ trọng số từ định dạng Hugging Face sang kiến trúc exporter, export ONNX và lượng tử hóa động INT8 cho MatMul. Chuyển định dạng/lượng tử hóa không phải huấn luyện.

Runtime dùng `sherpa_onnx.OfflineRecognizer.from_whisper`, tiếng Việt `vi`, tác vụ `transcribe`, `greedy_search`, CPU. Nhận WAV 16-bit hoặc PCM16; chuyển stereo thành mono khi cần. Sau phiên âm, bộ regex/quy tắc chuẩn hóa tiền, ví dụ “ba lăm k” → “35000 đồng”, “1 củ rưỡi” → “1500000 đồng”.

Nguồn model ghim revision `cc51d32be916efebde04ff549854fa1741cb5c02`; exporter ghim revision `7be9a38e275ece9ee9a9277cc78295f2cbfd6673`. Đã đối chiếu SHA256 cả encoder, decoder và tokens với manifest, đồng thời nạp runtime thật thành công. **Chưa đo WER hoặc độ trễ phiên âm**, vì không có bộ audio có bản chép chuẩn. Dữ liệu pretrain của nhà cung cấp không nằm trong dự án, nên không thể đếm số dòng từ hệ thống này.

Nguồn: [prepare_asr_model.py](../backend/scripts/prepare_asr_model.py), [manifest.json](../weights/onnx/phowhisper-tiny/manifest.json), [recognizer.py](../backend/app/infrastructure/ai/edge_asr/recognizer.py), [normalizer.py](../backend/app/infrastructure/ai/edge_asr/normalizer.py).

### Model 4: Qwen đọc hóa đơn và Gemini cố vấn

Qwen nhận ảnh Base64 và prompt/schema qua API chat completions tương thích OpenAI, dùng `httpx` bất đồng bộ. Mặc định model route là `qwen/qwen-2.5-vl-7b-instruct`, có cấu hình cho OpenRouter, DashScope hoặc FPT. JSON được kiểm định Pydantic; Python so tổng `quantity × price` với tổng hóa đơn trong sai lệch 5%. Confidence 0,95/0,60 sau kiểm tra số học là giá trị quy tắc, không phải xác suất đã được hiệu chuẩn trên tập test.

Gemini nhận nhóm thu nhập và chỉ số đã được Model 2 tính, rồi viết lời khuyên. Code không cho Gemini tính lại số dư/runway hoặc đổi cờ rủi ro; phản hồi lỗi được thay bằng mẫu lời khuyên cục bộ. Không có dữ liệu fine-tune, script train hoặc trọng số cục bộ cho hai model này. Việc có adapter không chứng minh một lần gọi API thật đã thành công; đợt rà soát này không gọi cloud.

Nguồn: [qwen_client.py](../backend/app/infrastructure/ai/cloud_vlm/qwen_client.py), [schemas.py](../backend/app/infrastructure/ai/cloud_vlm/schemas.py), [advisor.py](../backend/app/infrastructure/ai/cloud_vlm/advisor.py).

## 4. Chỉ số đo lại từ checkpoint hiện có

Đây là **đánh giá lại ngày 14/10/2026**, không phải log của lần train gốc. Tập chia được dựng lại bằng dữ liệu, code và seed hiện tại; checkpoint không lưu ID mẫu train/test để xác nhận tuyệt đối lịch sử chia dữ liệu. Số mẫu lưu trong cây khớp số train theo script.

Classifier dùng PhoBERT cache cục bộ, CPU một luồng PyTorch, batch 16 khi trích đặc trưng test. Độ trễ gồm tách từ + PhoBERT + LightGBM trên 50 câu sau warm-up, không gồm tải model.

| Chỉ số classifier | Đo lại | Mục tiêu đặc tả | Nhận xét |
|---|---:|---:|---|
| Accuracy, 300 câu | **95,33%** | Không quy định riêng | 286/300 câu đúng |
| Macro F1 | **95,33%** | ≥88% | Đạt trên tập giả lập này |
| Tỷ lệ P ≥0,8 | **83,67%** | ≥75% | 251/300 câu có thể xử lý cục bộ |
| Độ trễ trung bình | **76,56 ms/câu** | <15 ms | Chưa đạt trong điều kiện đo này |
| Độ trễ p95 | **92,14 ms/câu** | — | 95% mẫu đo nằm dưới mức này |

| Nhãn | Precision | Recall | F1 | Số mẫu test |
|---|---:|---:|---:|---:|
| Hóa đơn/Nhà ở | 96,15% | 100,00% | 98,04% | 50 |
| Khác | 92,31% | 96,00% | 94,12% | 50 |
| Mua sắm | 95,92% | 94,00% | 94,95% | 50 |
| Y tế | 100,00% | 92,00% | 95,83% | 50 |
| Ăn uống | 94,12% | 96,00% | 95,05% | 50 |
| Đi lại | 94,00% | 94,00% | 94,00% | 50 |

**Giới hạn classifier:** có 7 nội dung câu duy nhất xuất hiện ở cả train và test, tương ứng 8 bản ghi test đã có nội dung trong train. Ngoài trùng nguyên câu, nhiều câu hai phía cùng sinh từ một mẫu và khác số tiền. Kết quả này chưa chứng minh khả năng tổng quát trên câu người dùng thật.

Forecaster đánh giá sai số trên **số dư tái dựng**, không phải trực tiếp trên delta:

| Cách đánh giá | Số ngày | MAE | RMSE | MAPE |
|---|---:|---:|---:|---:|
| Một ngày tới, sử dụng lịch sử thực cập nhật mỗi ngày | 35 | **63.529 đồng** | 77.178 đồng | 0,1551% |
| Tự hồi quy toàn bộ holdout, không đưa quan sát tương lai vào lag | 35 | **213.458 đồng** | 243.127 đồng | 0,5139% |
| Tự hồi quy 30 ngày đầu holdout | 30 | **231.674 đồng** | 258.459 đồng | **0,5585%** |

Mục tiêu 30 ngày MAE <300.000 đồng và MAPE <10% đạt trên chuỗi giả lập hiện tại. Phép một ngày tới dễ hơn và không đại diện cho sai số dự báo 30 ngày. MAPE nhỏ trên số dư lớn không có nghĩa model cũng dự báo tốt delta hoặc thời điểm cạn tiền.

ASR: nạp model thật thành công; chưa có WER để đối chiếu mục tiêu <6%, chưa đo tốc độ so với mục tiêu <350 ms. Qwen/Gemini: chưa có tập đánh giá thực tế và chỉ số chất lượng trong repo. Kiểm thử với mock/double xác minh logic, không thay thế benchmark model thật.

## 5. Artifact và môi trường

| Artifact | Dung lượng byte | Vai trò |
|---|---:|---|
| `weights/checkpoints/lgbm_classifier.pkl` | 2.174.192 | Bộ phân loại đã fit |
| `weights/checkpoints/label_encoder.pkl` | 528 | Ánh xạ nhãn |
| `weights/checkpoints/classifier_config.json` | — | Quy tắc tiền xử lý, chiều vector, revision, ngưỡng |
| `weights/checkpoints/lgbm_forecaster.pkl` | 163.777 | Bộ hồi quy đã fit |
| `weights/onnx/phowhisper-tiny/encoder.int8.onnx` | 12.926.470 | Encoder ASR |
| `weights/onnx/phowhisper-tiny/decoder.int8.onnx` | 89.846.458 | Decoder ASR |
| `weights/onnx/phowhisper-tiny/tokens.txt` | 866.987 | Bảng token ASR |
| `weights/onnx/phowhisper-tiny/manifest.json` | — | Nguồn, revision và checksum ASR |

Cache PhoBERT và cache export ASR có trên máy. Checkpoint LightGBM được Git quản lý; cache và binary ONNX bị `.gitignore` loại trừ. Clone repo không tự có toàn bộ model để chạy offline.

Phiên bản trong môi trường `.venv` lúc đánh giá: NumPy 2.4.6, PyTorch 2.14.1, Transformers 5.19.0, underthesea 8.3.0, LightGBM 4.7.0, scikit-learn 1.9.1, sherpa-onnx 1.13.8, ONNX Runtime 1.31.0, google-genai 2.29.0. Đây là phiên bản **hiện tại**, không có bằng chứng chúng chính là phiên bản của lần train gốc. Requirements ML hiện dùng khoảng phiên bản, không ghim đầy đủ môi trường train.

## 6. Trạng thái tích hợp và lịch sử

- `frontend/app.py` là demo Streamlit, có đường nạp classifier, forecaster và ASR thật; có lựa chọn mock rõ ràng cho audio/hóa đơn và chế độ cloud tùy cấu hình.
- Backend có use case và router khung cho AI ingestion/forecast, nhưng `backend/app/api/v1/router.py` chỉ đăng ký health, transactions, finance và management. Router AI chưa được đăng ký; các dependency hook AI vẫn trả 503 nếu chưa thay thế. Chưa thể kết luận AI đã hoạt động trong luồng Flutter/API chính.
- `CLOUD_FALLBACK` mới là tín hiệu định tuyến/yêu cầu xác nhận, chưa thực hiện fallback NLP bằng Gemini.
- Lịch sử Git liên quan được tìm thấy trong commit `e873c32` ngày 12/10/2026, thông điệp `feat: add AI ingestion, forecasting, and Streamlit demo`. Commit chứng minh các artifact/code được đưa vào lịch sử, không chứng minh chính xác giờ train hoặc số lần train.
- Không tìm thấy log gốc/experiment registry lưu metrics, thời gian train, phần cứng train, hash dataset của lần train, các ID split, search siêu tham số hoặc nhiều phiên bản checkpoint. Vì vậy không thể thống kê chắc chắn “đã train bao nhiêu lần”.
- Đặc tả mục 5.3 còn nói hai chuỗi 90 ngày, nhưng CSV và generator hiện tại đều là 180 ngày. Báo cáo lấy số đếm thực tế.

## 7. Những việc nên bổ sung cho lần train tiếp theo

| Việc | Lý do |
|---|---|
| Thu thập câu giao dịch thật đã gán nhãn và có bộ test độc lập | Đo chất lượng ngoài 144 mẫu câu giả lập |
| Loại trùng và chia theo nhóm mẫu câu/nguồn | Giảm rò rỉ giữa train/test |
| Lưu manifest mỗi lần train: hash dữ liệu, commit code/model, split, versions, thời gian, metrics | Có lịch sử có thể kiểm chứng và tái lập |
| Ghim revision PhoBERT thay cho `main` | Tránh train/inference vô tình dùng encoder khác |
| Benchmark và tối ưu cả tách từ + PhoBERT + LightGBM | Độ trễ đo hiện tại chưa đạt 15 ms |
| Kiểm tra forecaster trên nhiều người, lịch lương/thuê khác và số dư thấp | Lịch ngày 5/ngày 30 cùng dữ liệu giả lập chưa đại diện đầy đủ |
| So forecaster với baseline đơn giản trên nhiều cửa sổ thời gian | Biết model học có cải thiện so với quy tắc lịch và trung bình hay không |
| Tạo bộ audio với transcript chuẩn và bộ hóa đơn có nhãn | Đo WER, tốc độ ASR và độ đúng từng trường hóa đơn |
| Kết nối dependency/router AI vào ứng dụng chính nếu muốn đưa vào sử dụng | Phân biệt demo có model với tính năng đã phục vụ người dùng |

## 8. Lệnh hiện có để tái tạo/train

Các lệnh dưới đây là tài liệu; **không được chạy trong đợt audit này**. Generator sẽ ghi đè CSV và các lệnh train mặc định sẽ ghi đè checkpoint.

```powershell
# Chạy từ thư mục gốc dự án, sau khi cài requirements tương ứng.
python backend/scripts/generate_synthetic_data.py
python backend/scripts/train_classifier.py
python backend/scripts/train_forecaster.py

# Chuẩn bị model ASR có sẵn, không phải train:
python backend/scripts/prepare_asr_model.py
```

Dependencies riêng: `backend/requirements-classifier.txt`, `requirements-forecaster.txt`, `requirements-asr.txt`, `requirements-asr-export.txt`, `requirements-cloud-vlm.txt`. Script classifier hỗ trợ `--local-files-only`, `--cache-dir`, `--batch-size`, `--data`, `--output-dir`; script forecaster hỗ trợ `--data`, `--output-dir`.
