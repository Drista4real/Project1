# Chuẩn bị Google Colab

Công việc được theo dõi tại [issue #20](https://github.com/Drista4real/Project1/issues/20).
Notebook: [project1_colab.ipynb](../notebooks/project1_colab.ipynb).

## Mở và chạy

1. Vào <https://colab.research.google.com/>, chọn **File → Upload notebook** và tải file notebook trên máy lên.
2. Để huấn luyện Model 1 bằng LoRA, chọn **Runtime → Change runtime type → T4 GPU**. Baseline LightGBM vẫn dùng CPU. GPU được cấp tùy khả năng của Colab.
3. Chuẩn bị mã nguồn theo một trong hai cách: clone GitHub bằng notebook nếu repo đọc công khai được; hoặc tải thư mục dự án lên Drive và đặt `SOURCE_MODE = "drive"`. Với repo riêng tư/chưa push thay đổi local, dùng cách Drive để không phải đưa token vào notebook. Thư mục phải chứa `backend/`, `data/`, và các file requirements mới.
4. Chạy lần lượt các ô. Chấp nhận kết nối Drive trong giao diện Google. Các ô sẽ tạo thư mục `MyDrive/Project1/colab_runs/<run_id>` để giữ thông tin môi trường, log và checkpoint. Mỗi lần chạy ô cấu hình tạo một run mới.
5. Giữ `RUN_CLASSIFIER = False`, `RUN_LORA = False`, `RUN_FORECASTER = False` khi chỉ chuẩn bị môi trường. Ô kiểm tra mặc định không tải PhoBERT hoặc gọi API cloud.

Không cần MCP để mở hoặc chạy notebook. MCP/kết nối trực tiếp là nhu cầu riêng nếu muốn trợ lý điều khiển phiên Colab; không có kết nối Colab nào được cấu hình trong đợt chuẩn bị này. Xem [FAQ chính thức](https://research.google.com/colaboratory/faq.html) về tải notebook, Drive và thời hạn runtime.

## Lỗi checkout nhánh trên GitHub

Nếu ô nạp mã nguồn báo `checkout --detach develop` với mã lỗi 128, bản notebook cũ đang dùng tên nhánh local trong khi bản clone mới chỉ có `origin/develop` (nhánh mặc định của repo là `main`). Bản sửa được theo dõi tại [issue #28](https://github.com/Drista4real/Project1/issues/28).

- Tải lại notebook đã sửa từ dự án. Notebook tự chọn ref remote cho tên nhánh; `REPO_REF` vẫn nhận tag hoặc commit SHA và commit thực tế được lưu trong `source-commit.txt`.
- Nếu cần sửa ngay notebook đang mở, thay đối số `REPO_REF` của lệnh `checkout` bằng `"origin/develop"` khi muốn chạy nhánh `develop`.
- Sau lần chạy lỗi, chạy lại **ô cấu hình** để tạo `RUN_ID` mới, rồi chạy lại ô nạp mã nguồn. Chạy lại riêng ô nạp mã nguồn sẽ gặp thư mục đã tồn tại. Không cần xóa dữ liệu trên Drive.
- Nếu ref không tồn tại hoặc Git không truy cập được repo, notebook hiển thị chi tiết lỗi Git. Kiểm tra `REPO_URL`/`REPO_REF`; với repo riêng tư, dùng `SOURCE_MODE = "drive"` theo hướng dẫn trên.

## Khi nhóm bàn giao dữ liệu

Classifier nhận **bundle đã đóng băng**, gồm train/validation/test, taxonomy và manifest do pipeline dự án tạo. Đặt `DATASET_DIR` thành đường dẫn bundle trên Drive, chạy lại ô kiểm tra rồi mới bật `RUN_LORA` (hoặc `RUN_CLASSIFIER` nếu cần so sánh baseline LightGBM). Notebook giữ nguyên split qua `--dataset-dir`, không tự chia ngẫu nhiên CSV mới.

Không dùng lại bundle v1 đã bị báo lệch hash trong [báo cáo dữ liệu](DATASET_PREPARATION_REPORT.md). Tạo bundle mới theo [hướng dẫn taxonomy](DATA_TAXONOMY_AND_ANNOTATION.md), dùng taxonomy v2 khi áp dụng các quy ước mặc định đã chốt, kiểm tra nguồn và phần annotation trước khi gộp. Không sửa manifest để bỏ qua lỗi. Dữ liệu hiện có là synthetic, chỉ dùng kiểm tra quy trình; chưa đại diện cho dữ liệu thực tế.

Forecaster chỉ kiểm tra dữ liệu và huấn luyện khi bật `RUN_FORECASTER`. Khi chỉ làm Model 1, không cần dữ liệu số dư. Forecaster nhận CSV `date,income,expense,balance` cho **thu nhập cố định**. Có thể đặt `FORECAST_CSV` sang file nhóm bàn giao; kiểm tra yêu cầu ngày liên tiếp bằng loader sẵn có. `balance_flexible.csv` thuộc luồng EWMA/runway, không có bước train riêng trong notebook này.

## Huấn luyện Model 1 với LoRA

Pipeline được theo dõi tại [issue #29](https://github.com/Drista4real/Project1/issues/29). **Tải lại notebook đã cập nhật lên Colab**, đồng thời cập nhật mã nguồn trên nhánh `REPO_REF` hoặc Drive. Không cần merge vào `main`; nhánh được chọn chỉ cần chứa script `backend/scripts/train_classifier_lora.py` và requirements mới.

Trong ô cấu hình:

```python
RUN_LORA = True
RUN_CLASSIFIER = False
RUN_FORECASTER = False
DATASET_DIR = "/content/drive/MyDrive/Project1/datasets/<ten_bundle_da_verify>"
```

Chọn T4 rồi chạy lại các ô từ đầu. `RUN_LORA` tự bật cài thư viện PEFT; không bắt buộc bật thêm `INSTALL_LORA`. Nếu chỉ muốn kiểm tra thư viện mà chưa train, giữ `RUN_LORA = False`, đặt `INSTALL_LORA = True`.

Mặc định dùng `vinai/phobert-base-v2`, LoRA vào attention `query`/`value`, rank 8, alpha 16 và dropout 0,1; lớp phân loại 6 nhãn cũng được huấn luyện và lưu cùng adapter. Tiền xử lý dùng quy trình chung của dự án: chữ thường, chuẩn hóa khoảng trắng, tách từ bằng Underthesea. PhoBERT yêu cầu đầu vào đã tách từ; xem [model card VinAI](https://huggingface.co/vinai/phobert-base-v2). `LORA_REVISION` nhận commit SHA của Hugging Face; phiên bản thực tế được ghi vào metadata khi tải model.

Cấu hình khởi đầu trên T4: 5 epoch, batch 8, tích lũy gradient 4 bước (batch hiệu dụng tối đa 32), độ dài 128 token, learning rate `2e-4`, FP16. Có thể chỉnh các biến `LORA_*` trong notebook. Nếu hết bộ nhớ, giảm batch xuống 4 hoặc 2. Đây là cấu hình khởi đầu, chưa phải bộ tham số tối ưu hay cam kết chất lượng/thời gian chạy.

Chỉ tập train được dùng cập nhật trọng số. Mỗi epoch đánh giá validation, lưu adapter tốt nhất theo Macro F1; nếu bằng điểm giữ epoch trước. Sau khi hoàn thành, pipeline **nạp lại adapter đã xuất** và đánh giá test một lần. Không dùng test để chọn epoch. Kết quả synthetic chỉ có ý nghĩa kiểm tra phát triển.

Artifact tại `colab_runs/<run_id>/classifier_lora/`:

- `adapter_model.safetensors`, `adapter_config.json`: trọng số LoRA và lớp phân loại.
- Các tệp tokenizer, `lora_config.json`: nhãn có thứ tự, tiền xử lý, độ dài và phiên bản mô hình nền.
- `training_config.json`, `training_data_manifest.json`: tham số, phiên bản thư viện và nguồn gốc dữ liệu.
- `history.json`, `metrics.json`: diễn biến validation, epoch được chọn và kết quả test (Macro F1, accuracy, báo cáo theo lớp, tỷ lệ xử lý tại ngưỡng 0,8).

Nhật ký được ghi vào `classifier_lora.log`. Mô hình tốt nhất được lưu sau mỗi epoch có cải thiện; chưa lưu trạng thái optimizer để tiếp tục chính xác một lượt bị ngắt. Nếu chạy lại, chọn thư mục output mới để tránh ghi đè. Khi chạy CLI ngoài notebook, đặt `PYTHONUTF8=1` để hiển thị nhãn tiếng Việt trên Windows.

Lệnh tương đương từ thư mục gốc repo:

```bash
python -m pip install -r backend/requirements-colab-lora.txt
python backend/scripts/train_classifier_lora.py --dataset-dir <bundle> --output-dir <run_moi>/classifier_lora --device cuda
python backend/scripts/predict_classifier_lora.py --artifact-dir <run_moi>/classifier_lora --text "ăn trưa 40k" --device cuda
```

CLI mặc định yêu cầu CUDA; `--device cpu` chỉ phù hợp lượt kiểm tra nhỏ và sẽ chậm với PhoBERT thật. `--no-fp16` tắt mixed precision. `--local-files-only` ngăn tải trọng số khi đã chuẩn bị cache. Nếu dùng `--cache-dir` khi train, truyền cùng cache khi dự đoán offline.

Để dự đoán trên máy khác, mang cả thư mục adapter và cache trọng số nền `model_cache/phobert-lora` hoặc cho phép tải lại đúng revision đã ghi. Notebook chạy thử một câu sau train bằng CLI dự đoán. **Adapter này chưa được nối vào API/Flutter đang dùng LightGBM**; không thay thế các tệp `.pkl` bằng adapter. Cờ `CLOUD_FALLBACK` trong kết quả chỉ là tín hiệu định tuyến, CLI không gọi Gemini.

## Phạm vi và lưu kết quả

- Baseline classifier là `vinai/phobert-base` trích CLS trên CPU + LightGBM, khớp mã inference hiện tại. Chọn GPU không tự làm baseline chạy GPU.
- `RUN_LORA` huấn luyện PhoBERT-base-v2/LoRA và xuất adapter dùng với CLI riêng. `INSTALL_LORA` vẫn cho phép kiểm tra thư viện trước khi có dữ liệu. Tham khảo [PEFT](https://huggingface.co/docs/peft/en/quicktour).
- Notebook cài riêng nhóm thư viện ML cần thiết trong runtime Colab, không cài toàn bộ backend API. Các bước ML chạy bằng tiến trình Python mới để tránh module cũ trong kernel sau khi pip cập nhật.
- `environment.json`, `pip-freeze.txt`, `source-commit.txt`, log train và artifact được lưu vào thư mục run trên Drive. Khoảng phiên bản requirements hỗ trợ bootstrap; `pip-freeze.txt` ghi chính xác phiên bản thực tế để tái lập lần chạy đó. Chưa phải lockfile được kiểm chứng trên mọi image Colab.
- Cache PhoBERT nằm ở `MyDrive/Project1/model_cache/phobert`; khi triển khai baseline cần mang cả cache và các artifact classifier như [README model](../backend/app/infrastructure/ai/classifier/README.md) mô tả.
- Ô cuối đóng gói riêng thư mục run thành ZIP và có tùy chọn tải về. Cache model lớn nằm ngoài ZIP. Runtime Colab có thể bị thu hồi; sau khi kết nối lại, chạy lại các ô setup. Chưa hỗ trợ resume một lượt train bị ngắt.

Kiểm tra pipeline LoRA tại máy phát triển dùng RoBERTa rất nhỏ và PEFT thật, không tải PhoBERT: huấn luyện, chọn epoch bằng validation, lưu/nạp lại adapter và lớp phân loại, kiểm tra manifest bị sửa và thư mục output đã tồn tại. Việc này không đo chất lượng PhoBERT trên dữ liệu thực tế. Xác thực Drive, cài toàn bộ thư viện trên image Colab thực tế và FP16/GPU T4 cần được kiểm tra trong tài khoản Google của người chạy.
