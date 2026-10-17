# Chuẩn bị Google Colab

Công việc được theo dõi tại [issue #20](https://github.com/Drista4real/Project1/issues/20).
Notebook: [project1_colab.ipynb](../notebooks/project1_colab.ipynb).

## Mở và chạy

1. Vào <https://colab.research.google.com/>, chọn **File → Upload notebook** và tải file notebook trên máy lên.
2. Baseline hiện tại chạy CPU: dùng runtime mặc định. Nếu muốn kiểm tra môi trường cho LoRA sau này, chọn **Runtime → Change runtime type → GPU** rồi đặt `INSTALL_LORA = True` ở ô cấu hình. GPU được cấp tùy khả năng của Colab.
3. Chuẩn bị mã nguồn theo một trong hai cách: clone GitHub bằng notebook nếu repo đọc công khai được; hoặc tải thư mục dự án lên Drive và đặt `SOURCE_MODE = "drive"`. Với repo riêng tư/chưa push thay đổi local, dùng cách Drive để không phải đưa token vào notebook. Thư mục phải chứa `backend/`, `data/`, và các file requirements mới.
4. Chạy lần lượt các ô. Chấp nhận kết nối Drive trong giao diện Google. Các ô sẽ tạo thư mục `MyDrive/Project1/colab_runs/<run_id>` để giữ thông tin môi trường, log và checkpoint. Mỗi lần chạy ô cấu hình tạo một run mới.
5. Giữ `RUN_CLASSIFIER = False`, `RUN_FORECASTER = False` khi chỉ chuẩn bị môi trường. Ô kiểm tra mặc định không tải PhoBERT hoặc gọi API cloud.

Không cần MCP để mở hoặc chạy notebook. MCP/kết nối trực tiếp là nhu cầu riêng nếu muốn trợ lý điều khiển phiên Colab; không có kết nối Colab nào được cấu hình trong đợt chuẩn bị này. Xem [FAQ chính thức](https://research.google.com/colaboratory/faq.html) về tải notebook, Drive và thời hạn runtime.

## Khi nhóm bàn giao dữ liệu

Classifier nhận **bundle đã đóng băng**, gồm train/validation/test, taxonomy và manifest do pipeline dự án tạo. Đặt `DATASET_DIR` thành đường dẫn bundle trên Drive, chạy lại ô kiểm tra rồi mới bật `RUN_CLASSIFIER`. Notebook giữ nguyên split qua `--dataset-dir`, không tự chia ngẫu nhiên CSV mới.

Không dùng lại bundle v1 đã bị báo lệch hash trong [báo cáo dữ liệu](DATASET_PREPARATION_REPORT.md). Tạo bundle mới theo [hướng dẫn taxonomy](DATA_TAXONOMY_AND_ANNOTATION.md), dùng taxonomy v2 khi áp dụng các quy ước mặc định đã chốt, kiểm tra nguồn và phần annotation trước khi gộp. Không sửa manifest để bỏ qua lỗi. Dữ liệu hiện có là synthetic, chỉ dùng kiểm tra quy trình; chưa đại diện cho dữ liệu thực tế.

Forecaster hiện có nhận CSV `date,income,expense,balance` cho **thu nhập cố định**. Có thể đặt `FORECAST_CSV` sang file nhóm bàn giao; kiểm tra yêu cầu ngày liên tiếp bằng loader sẵn có. `balance_flexible.csv` thuộc luồng EWMA/runway, không có bước train riêng trong notebook này.

## Phạm vi và lưu kết quả

- Baseline classifier là `vinai/phobert-base` trích CLS trên CPU + LightGBM, khớp mã inference hiện tại. Chọn GPU không tự làm baseline chạy GPU.
- `INSTALL_LORA` chỉ cài PEFT/Accelerate/Datasets và kiểm tra CUDA. Chưa triển khai fine-tune PhoBERT-base-v2/LoRA hoặc đổi định dạng checkpoint inference. Tham khảo [PEFT](https://huggingface.co/docs/peft/en/quicktour).
- Notebook cài riêng nhóm thư viện ML cần thiết trong runtime Colab, không cài toàn bộ backend API. Các bước ML chạy bằng tiến trình Python mới để tránh module cũ trong kernel sau khi pip cập nhật.
- `environment.json`, `pip-freeze.txt`, `source-commit.txt`, log train và artifact được lưu vào thư mục run trên Drive. Khoảng phiên bản requirements hỗ trợ bootstrap; `pip-freeze.txt` ghi chính xác phiên bản thực tế để tái lập lần chạy đó. Chưa phải lockfile được kiểm chứng trên mọi image Colab.
- Cache PhoBERT nằm ở `MyDrive/Project1/model_cache/phobert`; khi triển khai baseline cần mang cả cache và các artifact classifier như [README model](../backend/app/infrastructure/ai/classifier/README.md) mô tả.
- Ô cuối đóng gói riêng thư mục run thành ZIP và có tùy chọn tải về. Cache model lớn nằm ngoài ZIP. Runtime Colab có thể bị thu hồi; sau khi kết nối lại, chạy lại các ô setup. Chưa hỗ trợ resume một lượt train bị ngắt.

Đã kiểm tra cấu trúc notebook, cú pháp các ô và luồng dữ liệu/forecaster tại máy phát triển. Xác thực Drive, cài thư viện trên image Colab thực tế và GPU cần được kiểm tra trong tài khoản Google của người chạy.
