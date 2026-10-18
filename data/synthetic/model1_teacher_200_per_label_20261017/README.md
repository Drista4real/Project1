# Model 1 — 200 mẫu AI mỗi nhãn

Ngày tạo: 17/10/2026. Theo dõi: [issue #30](https://github.com/Drista4real/Project1/issues/30).

AI trong phiên Codex trực tiếp soạn câu và gán nhãn theo `expense_six_v2_defaults`.
Đây là dữ liệu tổng hợp với nhãn cứng từ AI để huấn luyện student; chưa thực hiện
chưng cất xác suất/logits hay huấn luyện model. Không gọi teacher API bên ngoài.
Không chứa giao dịch thực của người dùng và chưa được người gán nhãn kiểm duyệt độc lập.

| Nhãn | Tổng | Train | Validation | Test |
| --- | ---: | ---: | ---: | ---: |
| Ăn uống | 200 | 140 | 30 | 30 |
| Đi lại | 200 | 140 | 30 | 30 |
| Mua sắm | 200 | 140 | 30 | 30 |
| Hóa đơn/Nhà ở | 200 | 140 | 30 | 30 |
| Y tế | 200 | 140 | 30 | 30 |
| Khác | 200 | 140 | 30 | 30 |
| **Tổng** | **1.200** | **840** | **180** | **180** |

Mỗi nhãn có 100 tình huống, mỗi tình huống có hai cách diễn đạt, thường gồm một
câu có dấu và một câu không dấu. Có câu ngắn, viết tắt, khẩu ngữ và ngữ cảnh dễ
nhầm giữa các nhóm. Hai cách diễn đạt cùng tình huống dùng chung `source_group`.
Vì vậy 1.200 dòng không tương đương 1.200 tình huống độc lập.

## Tệp dữ liệu

- `transactions.csv`: bản UTF-8 hai cột `text,category`, đúng 1.200 dòng dữ liệu.
- `transactions_with_provenance.csv`: cùng dữ liệu, bổ sung ID, nhóm tình huống,
  trạng thái `synthetic` và nguồn gán nhãn; dùng bản này khi chia/gộp tập.
- `sources.json`: khai báo nguồn cho pipeline hiện có.
- `generation.json`: phương pháp sinh, quy tắc, nguồn và giới hạn.
- `validation_report.json`: số lượng, hash và kết quả kiểm tra dữ liệu.
- `bundle_v1/`: train/validation/test đã đóng băng cùng taxonomy, audit và manifest.

Kiểm tra: 1.200 câu duy nhất sau chuẩn hóa NFC/chữ hoa thường/khoảng trắng;
không có nhãn xung đột, không có dòng bị cách ly, không trùng hoàn toàn với
`data/processed/data_transactions.csv` tại thời điểm tạo. Pipeline gom còn
597 nhóm sau khi xét thêm câu gần trùng. Các split không giao nhau ID, text
chuẩn hóa, nhóm tình huống hoặc nhóm do pipeline tìm thấy. Kiểm tra bằng luật
không chứng minh toàn bộ nhãn đúng hoặc các tình huống độc lập về ngữ nghĩa.

## Dùng trên Colab

Đưa thư mục này lên Drive, hoặc giải nén ZIP bàn giao giữ nguyên cấu trúc thư mục.
Trong ô cấu hình notebook, đặt đường dẫn tới **bundle_v1**, ví dụ:

```python
DATASET_DIR = "/content/drive/MyDrive/Project1/datasets/model1_teacher_200_per_label_20261017/bundle_v1"
RUN_LORA = True
RUN_CLASSIFIER = False
RUN_FORECASTER = False
```

Không cần thay CSV hiện có của dự án. Notebook dùng split đã đóng băng trong bundle.
Đợt bàn giao này chỉ chuẩn bị dữ liệu; chưa chạy train.

## Kiểm tra và tái tạo bundle

Từ thư mục gốc repository:

```powershell
python backend/scripts/prepare_classifier_data.py --verify data/synthetic/model1_teacher_200_per_label_20261017/bundle_v1
```

Tái tạo từ nguồn đã lưu bằng một thư mục output mới:

```powershell
python backend/scripts/prepare_classifier_data.py --taxonomy data/taxonomy/expense_categories.v2_defaults.json --sources data/synthetic/model1_teacher_200_per_label_20261017/sources.json --output-dir data/prepared/model1_teacher_200_per_label_20261017_rebuilt --ambiguity-policy quarantine --seed 42
```

Seed chỉ áp dụng cho chia tập, không tái sinh được câu chữ AI. Khi gộp với dữ liệu
khác, khai báo mọi nguồn và chia nhóm lại bằng pipeline; không nối ngẫu nhiên vào
train/test cũ. Các câu cùng nghĩa khác cách diễn đạt vẫn có thể cần duyệt thêm.

## Giới hạn đánh giá

Train/validation/test đều synthetic và cùng do một AI tạo. Chỉ dùng chúng cho
thử nghiệm phát triển; cần tập test thực tế độc lập, do người gán nhãn, trước khi
kết luận về độ chính xác hoặc tỷ lệ xử lý tự động. Phân bố cân bằng ở đây không
đại diện tần suất giao dịch thực tế.
