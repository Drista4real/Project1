# Demo AI trên Streamlit

Demo sử dụng trực tiếp bốn adapter model trong `backend/app/infrastructure/ai/`.
Ứng dụng Flutter hiện có vẫn chạy độc lập. Giai đoạn này tập trung kiểm thử model;
phần đấu nối với app được thực hiện sau.

## Khởi động

### Đo cold start và chạy sau khi nạp sẵn

Trong **Ghi chép & phân loại**, mở **Chuẩn bị model & đo thời gian** rồi bấm
**Nạp sẵn model 1 + 3**. Bước này chỉ nạp/chạy mẫu classifier cục bộ và nạp ASR;
không gửi audio, ảnh hoặc câu mẫu lên cloud. ASR báo rõ mock nếu thiếu trọng số;
việc nạp ASR chưa đo thời gian giải mã một bản ghi thật.

Sau đó phân tích nhiều câu khác nhau. Mở **Thời gian từng bước** dưới kết quả để
xem thời gian lấy classifier, suy luận, chuẩn hóa và fallback (nếu có). Giọng nói
có thêm thời gian lấy recognizer và phiên âm; hóa đơn có thời gian Qwen/Gemini.
Khởi động lại tiến trình Streamlit để đo lại cold start. Xóa kết quả trên màn hình
không giải phóng model trong RAM.

Demo dùng chung bộ nạp classifier của backend. Bật `CLASSIFIER_LORA_MERGE=true`
trong cấu hình rồi khởi động lại để thử merge LoRA trong RAM; mặc định chưa bật
vì phép đo ngắn chưa cho thấy lợi ích tốc độ rõ ràng. Checkpoint không bị ghi đè.
Các tùy chọn và benchmark CLI được mô tả trong
[backend README](../backend/README.md#model-runtime-and-latency).

### Chạy demo

Chạy từ thư mục gốc repository, trong môi trường Python của dự án:

```powershell
python -m pip install -r frontend/requirements-demo.txt
python -m streamlit run frontend/app.py
```

Trên Windows, có thể chỉ rõ Python của `.venv` để cài và chạy trong cùng môi trường:

```powershell
.\.venv\Scripts\python.exe -m pip install -r frontend/requirements-demo.txt
.\.venv\Scripts\python.exe -m streamlit run frontend/app.py
```

Nếu gặp `ModuleNotFoundError: No module named 'pydantic_settings'`, môi trường
đang chạy demo thiếu gói `pydantic-settings` (đã có trong file requirements).
Dừng Streamlit, cài gói bằng Python của môi trường đó rồi khởi động lại:

```powershell
.\.venv\Scripts\python.exe -m pip install "pydantic-settings>=2,<3"
.\.venv\Scripts\python.exe -m streamlit run frontend/app.py
```

Truy cập `http://localhost:8501`. Đường dẫn dữ liệu được xác định theo vị trí mã
nguồn, nên có thể khởi động từ thư mục khác nếu chỉ đúng đường dẫn tới file app.
Các module backend chỉ được nạp khi cần và không khởi động FastAPI. Model local
được lưu trong bộ nhớ đệm để tái sử dụng; lần nạp đầu tiên có thể lâu hơn.

## Nhập liệu và phân loại

Màn hình đầu tiên hỗ trợ văn bản, âm thanh WAV PCM16/M4A/MP3 và ảnh hóa đơn JPEG/PNG/WebP.
Mã điều phối riêng cho demo nằm trong `frontend/demo_pipeline.py`.

### Model 1: phân loại văn bản

Demo tự gọi Gemini khi classifier local không khả dụng, trả nhãn hoặc xác suất
không hợp lệ, hoặc có độ tin cậy `P < 0.8`. Số tiền được trích xuất bằng quy tắc
cục bộ; kết quả phân loại từ cloud không được thay thế số tiền. Nếu thiếu tiền
hoặc có nhiều số tiền mơ hồ, kết quả vẫn để chưa xác định.

Giao diện hiển thị nguồn phân loại, nguồn trích xuất, cảnh báo cần kiểm tra và
thời gian xử lý thực tế. Thời gian này bao gồm cả nạp model nếu chưa có trong
bộ nhớ đệm.

### Model 3: nhận dạng giọng nói

Khi thiếu file PhoWhisper ONNX, adapter chuyển sang chế độ giả lập có nhãn
`MOCK` rõ ràng. Với âm thanh người dùng tải lên, nếu ASR local không khả dụng, lỗi
runtime hoặc trả transcript rỗng, demo tự gửi âm thanh gốc sang Gemini.
File tải lên không được thay bằng bản phiên âm giả lập.

Sau khi cài trọng số, bấm **Nạp lại model ASR** để xóa bộ nhớ đệm của recognizer.
Nút **Test phiên âm mẫu (MOCK)** luôn chọn chế độ giả lập, kể cả khi đã có trọng số
thật. Nút **Phân tích Voice** xử lý file tải lên bằng model thật hoặc fallback.

### Model 4: đọc hóa đơn

Qwen2.5-VL đọc ảnh trước. Nếu thiếu cấu hình truy cập, dịch vụ lỗi hoặc quá thời
gian chờ, phản hồi bị cắt, sai schema hay không khớp số học, demo tự gửi ảnh gốc
sang Gemini rồi kiểm định lại kết quả.

Schema của adapter Qwen dùng chung được giữ nguyên. Schema Gemini riêng của demo
có thêm thuế, phụ phí và giảm giá được in riêng trên hóa đơn. Phép kiểm tra số học
đối chiếu tổng sau điều chỉnh trong ngưỡng sai lệch 5%, không sửa số tiền in trên
hóa đơn để ép khớp. Nếu vẫn mâu thuẫn, số tiền được chấp nhận sẽ để chưa xác định.
Nếu schema hoặc dịch vụ không xử lý được, giao diện báo lỗi để người dùng phục
hồi thủ công, không tạo hóa đơn giả lập thay thế.

Nút **Test hóa đơn mẫu (MOCK)** dùng hóa đơn mẫu cố định và không gửi dữ liệu
lên cloud. Model 2 và hành vi Gemini Advisor/mẫu lời khuyên cục bộ được giữ nguyên.

## Cấu hình dịch vụ

### Qwen

Đặt `OPENROUTER_API_KEY`, `QWEN_BASE_URL` và `QWEN_MODEL` trong `backend/.env`
(file được Git bỏ qua), hoặc nhập khóa vào ô mật khẩu trong mục **Kết nối Qwen**.
Model mặc định là `qwen/qwen-2.5-vl-7b-instruct`; có thể chọn biến thể `:free`
nếu có nhà cung cấp phục vụ. Với DashScope, dùng URL ở chế độ tương thích,
`DASHSCOPE_API_KEY` và mã model `qwen2.5-vl-7b-instruct`.

Với FPT Cloud, đặt các giá trị sau trong cùng file cấu hình:

```dotenv
FPT_API_KEY=your-key
QWEN_BASE_URL=https://mkp-api.fptcloud.com/v1
QWEN_MODEL=Qwen2.5-VL-7B-Instruct
```

### Gemini

Khóa Gemini có ô mật khẩu riêng. Các khóa nhập ở thanh bên chỉ tồn tại trong
phiên làm việc, không được ghi ra đĩa. Chế độ kiểm thử mặc định không gọi mạng,
kể cả khi đã có khóa.

Đặt các giá trị sau trong `backend/.env` hoặc biến môi trường:

```dotenv
GEMINI_API_KEY=your-key
GEMINI_INPUT_MODEL=gemini-3.1-flash-lite
GEMINI_AUDIO_MODEL=gemini-3.1-flash-lite
GEMINI_RECEIPT_MODEL=gemini-3.1-flash-lite
```

Đây là các mã model có thể chọn độc lập, không đảm bảo mọi tài khoản đều có quyền
truy cập. Khi không đặt model audio/ảnh riêng, demo dùng `GEMINI_INPUT_MODEL`.
Kiểm tra API thật ngày 18/10/2026 đã thành công với văn bản, ảnh hóa đơn tổng hợp
và giọng nói tổng hợp trên `gemini-3.1-flash-lite`. Với tài khoản đang cấu hình,
`gemini-2.5-flash` trả lỗi không tìm thấy model (404). Mẫu giọng nói là tiếng Anh
được tổng hợp bằng TTS, chưa chứng minh độ chính xác ASR tiếng Việt.

`GEMINI_MODEL` hiện có vẫn chọn model cho Advisor. Thay đổi này không sửa phép
tính của Model 2 hoặc cách Advisor tạo lời khuyên.

## Giới hạn fallback và dữ liệu

Mỗi lần bấm phân tích dùng chung tối đa một yêu cầu fallback Gemini, với một lần
gửi ở tầng SDK, không tự thử lại và thời gian chờ tối đa 20 giây. Qwen có thời
gian chờ 15 giây. Mỗi client cloud được mở, gọi bất đồng bộ và đóng trong cùng
vòng lặp sự kiện của tác vụ.

Transcript được khôi phục từ Gemini quay về Model 1 local. Nếu transcript local
đã dùng được nhưng độ tin cậy phân loại thấp, demo chỉ gửi văn bản lên Gemini,
không gửi lại âm thanh. Danh mục do Gemini đọc ảnh đề xuất chưa được sử dụng như
một kết quả gộp đã kiểm định: phần mô tả đọc được sẽ được phân loại cục bộ, không
gọi cloud lần hai. Danh mục chưa xác định vẫn có cảnh báo rõ ràng. Luồng gộp
trích xuất/phân loại và quality gate ASR nâng cao chưa được bật, cần đánh giá riêng.

Giới hạn file tải lên:

- Âm thanh: WAV PCM16 không nén, mono hoặc stereo, 8–48 kHz; hoặc M4A/MP3
  được giải mã bằng PyAV. Mỗi file tối đa 60 giây và 8 MiB. Fallback giữ nguyên
  byte âm thanh gốc và gửi MIME tương ứng cho Gemini.
- Ảnh: JPEG/PNG/WebP, tối đa 4 MiB; chữ ký file phải khớp MIME khai báo.

Demo gửi dữ liệu trực tiếp trong yêu cầu tới nhà cung cấp, không dùng Files API
hay lưu file tải lên ra đĩa. Streamlit giữ file trong phiên hiện tại đến khi thay
hoặc xóa; kết quả phân tích chỉ lưu mã băm nhận diện, không sao chép media gốc.
Đổi đầu vào sẽ ẩn kết quả cũ. Fallback có thể tự gửi file lên cloud, vì vậy chỉ
dùng dữ liệu bạn có quyền xử lý theo chính sách của nhà cung cấp đã cấu hình.

## Dự báo dòng tiền và Advisor

Màn hình dự báo cho phép chọn số dư hiện tại, loại thu nhập và ngày bắt đầu dự báo
trong lịch sử. Ngày được lấy từ `balance_fixed.csv` hoặc `balance_flexible.csv`;
mặc định là ngày quan sát cuối cùng có dữ liệu.

Dự báo thu nhập cố định cần tám số dư lịch sử và checkpoint dự báo chênh lệch.
Số dư nhập vào dịch chuyển mức số dư lịch sử, không đổi các chênh lệch quan sát.
Ngày nhận lương được chọn ảnh hưởng đến biến đầu vào về ngày lương, số ngày đếm
ngược và cảnh báo lệch dòng tiền. Dữ liệu huấn luyện giả định nhận lương ngày 5,
nên lịch nhận lương khác cần được đo độ chính xác riêng. Biểu đồ hiển thị 30 ngày
tương lai; ngày nhận lương cách 31 ngày không có ước lượng trong khoảng này.

Dự báo thu nhập linh hoạt dùng mức chi hằng ngày nhập tay hoặc lịch sử chi tiêu
đến ngày đã chọn. Model 2 tính bằng EWMA; mức tiêu hao bằng 0 sẽ hiển thị thời
gian duy trì số dư không giới hạn. Advisor chỉ diễn giải chỉ số và cờ rủi ro đã
có, không tự tính dự báo tài chính. Biểu đồ gồm số dư ban đầu, 30 số dư tương lai
và đường ngang tại mức 0. Đổi kịch bản sẽ ẩn kết quả cũ đến khi tính lại.

## Chuẩn bị dữ liệu và trọng số

Nếu thiếu dữ liệu hoặc checkpoint, chạy từ thư mục gốc repository:

```powershell
python backend/scripts/generate_synthetic_data.py
python backend/scripts/train_classifier.py
python backend/scripts/train_forecaster.py
```

Tải model PhoWhisper-tiny INT8 đã phát hành và cài thư viện ASR:

```powershell
python backend/scripts/download_asr_model.py
python -m pip install -r backend/requirements-asr.txt
```

Nếu cần truy cập repository riêng tư, chạy `gh auth login` và thêm `--github-cli`
vào lệnh tải model. Công cụ tải kiểm tra kích thước và SHA256 theo manifest trước
khi cài các file runtime vào `weights/onnx/phowhisper-tiny/`. Sau đó nạp lại ASR
ở tab **Giọng nói**; quá trình suy luận local chạy offline. Xem
[hướng dẫn Model 3](../docs/MODEL3_SETUP.md) về phát hành model và quy trình export
từ nguồn nếu cần.

## Kiểm thử và phạm vi nghiệm thu

Khi thiếu file, thư viện hoặc file tải lên không hợp lệ, demo hiển thị thông báo
lỗi dễ hiểu. Kết quả chỉ phục vụ thử nghiệm model, không ghi vào tài khoản tài
chính. Mã Flutter, route FastAPI và hợp đồng model/domain dùng chung được giữ
nguyên; việc tích hợp app thuộc giai đoạn sau khi đánh giá model.

Chạy kiểm thử không dùng mạng từ thư mục gốc repository:

```powershell
python -m pytest tests/test_demo_fallback.py tests/test_demo_app.py -q
```

Kiểm thử giả lập xác minh định tuyến, kiểm định dữ liệu và ngân sách gọi dịch vụ;
không đo độ chính xác model. Vẫn cần đánh giá trên tập văn bản, âm thanh, hóa đơn
thực tế đại diện và đo hiệu năng trên phần cứng đích trước khi kết luận model
đủ ổn định để tích hợp app.
