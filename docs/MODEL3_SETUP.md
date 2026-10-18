# Chạy Model 3 giọng nói sau khi clone

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
