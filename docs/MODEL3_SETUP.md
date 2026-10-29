# Chạy Model 3 giọng nói sau khi clone

Model 3 chỉ phiên âm audio thành transcript; văn bản sau chuẩn hóa đi qua
Model 1 để phân loại. Fallback Gemini phân loại text không sửa được phiên âm
sai. [Kiến trúc đích, mục 5.5](SPECIFICATION.md#55-ma-trận-fallback-theo-công-đoạn)
quy định bộ điều phối backend chọn text/audio theo lỗi. Luồng chính là
PhoWhisper → transcript dùng được → Model 1; điểm phân loại thấp chỉ gọi Gemini
bằng text. Fallback audio ban đầu tự kích hoạt khi runtime lỗi/transcript rỗng;
quality gate nâng cao chỉ bật sau khi kiểm chứng tín hiệu và hiệu chuẩn.
Khi đã gọi Gemini bằng audio, có thể yêu cầu cả transcript/dữ liệu giao dịch
và danh mục trong cùng request; nếu đủ và đạt kiểm định thì chuyển review,
không bắt buộc qua Model 1 hoặc gọi cloud phân loại lần nữa. Đường gộp cần
đánh giá trước khi bật; nếu chỉ có transcript thì vẫn dùng Model 1 trong cùng
ngân sách cloud, hết ngân sách mà còn mơ hồ thì giữ nháp cần kiểm tra. Không có nút
gọi Gemini hay hộp thoại xác nhận từng lần fallback; quyền xử lý cloud được
thiết lập trước khi dùng tính năng. Chỉ yêu cầu sửa/thu lại khi xử lý tự động
không giải quyết được (kể cả khi mất mạng). Tín hiệu chất lượng/ngưỡng ASR
cần được thiết kế và kiểm chứng, không lấy điểm phân loại Model 1 thay thế;
cloud ASR hiện chỉ được thử nghiệm trong [demo Streamlit](../frontend/STREAMLIT_DEMO.md):
runtime lỗi/transcript rỗng → Gemini nhận audio gốc → classifier local, không gọi
Gemini lần hai. `GEMINI_API_KEY` và `GEMINI_AUDIO_MODEL` dành cho demo; hỗ trợ WAV
PCM16 mono/stereo, 8–48 kHz và M4A/MP3 qua PyAV, tối đa 60 giây/8 MiB.
Flutter vẫn phiên âm trên thiết bị,
không tự tải audio lên backend; phần đấu nối app để giai đoạn sau. Offline phiên
âm không đồng nghĩa toàn bộ phân loại/lưu giao dịch hoạt động offline.
Mock không phải ASR dự phòng.

Model PhoWhisper-tiny INT8 được phân phối riêng qua GitHub Release, không đưa
binary vào lịch sử Git. Dùng Python 3.11 trở lên cho các script tải/đóng gói.

## Thành viên trong nhóm

Chạy từ thư mục gốc repository, sau khi đã thiết lập môi trường ứng dụng:

```powershell
python backend/scripts/download_asr_model.py
```

Script chỉ dùng thư viện chuẩn Python; không cần PyTorch hoặc bộ export.
Nó tải khoảng 104 MB một lần, kiểm tra kích thước và SHA256 theo manifest
trong checkout rồi cài vào `weights/onnx/phowhisper-tiny/`. File đã đúng sẽ
được giữ lại; file tải lỗi không thay thế model hiện có. Không tải lúc phiên âm.

Nếu repository là private, cài GitHub CLI, đăng nhập tài khoản có quyền đọc repo:

```powershell
gh auth login
python backend/scripts/download_asr_model.py --github-cli
```

Để chạy nhận giọng nói thật bằng backend hoặc demo Streamlit, cài runtime
trong môi trường Python dùng để chạy ứng dụng:

```powershell
python -m pip install -r backend/requirements-asr.txt
```

Để build Flutter Android có giọng nói offline, chép bộ đã tải vào assets:

```powershell
python frontend/scripts/prepare_voice_assets.py
```

Sau đó build/chạy Flutter theo hướng dẫn frontend. Bước chép assets không cần
runtime Python ASR. Web không dùng giọng nói offline Android.

Backend có thể trả dữ liệu mock khi thiếu model; để bắt buộc dùng model thật,
khởi tạo adapter với `allow_mock=False`. Việc clone code vẫn cần bước tải trên.

## Người phát hành model (một lần)

Release cố định: `model3-phowhisper-tiny-int8-v1` trong `Drista4real/Project1`.
Người có quyền ghi repository chạy với GitHub CLI đã đăng nhập, từ một commit
đã có trên GitHub:

```powershell
python backend/scripts/publish_asr_model.py
```

Script xác minh các file local theo manifest, tạo draft với bốn assets:
`encoder.int8.onnx`, `decoder.int8.onnx`, `tokens.txt`, `manifest.json`;
chỉ publish sau khi upload xong. Nó không ghi đè release đã tồn tại và không
đặt model release thành bản phát hành ứng dụng mới nhất. Nếu upload lỗi,
kiểm tra draft trên GitHub trước khi thử lại.

Nếu chưa có trọng số local, maintainer có thể tạo lại:

```powershell
python -m pip install -r backend/requirements-asr-export.txt
python backend/scripts/prepare_asr_model.py
```

Không thay assets của v1 bằng model khác. Khi nâng model, tạo tag mới và cập
nhật `RELEASE_TAG` cùng manifest trong cùng thay đổi code.

Nếu tải bị HTTP 404: kiểm tra Release đã publish chưa và quyền truy cập private
repo. Với mạng chập chờn, chạy lại lệnh tải; SHA256 sẽ phát hiện file không đầy đủ.
