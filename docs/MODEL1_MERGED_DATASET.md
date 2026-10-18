# Model 1 — bộ gộp 5 nguồn ngày 18/10/2026

Theo dõi: [issue #31](https://github.com/Drista4real/Project1/issues/31).
Phê duyệt chín câu và bundle v2: [issue #32](https://github.com/Drista4real/Project1/issues/32).

**Bản hiện hành: `bundle_v2/`.** Người dùng đã duyệt cả chín câu ngày 18/10/2026,
giữ nguyên câu và nhãn hiện tại. `vay xam xe bi dinh dam het 30k` được hiểu là
vá săm xe bị dính dăm, giữ **Đi lại**. Cả chín câu được đưa trở lại bộ chia tập;
không còn dòng chờ duyệt. Tổng hiện hành **5.996 mẫu duy nhất**, chỉ loại 4 bản
sao dư. Các số liệu v1 bên dưới được giữ để đối chiếu lịch sử.

Quyết định ghi tại `annotation_approved_20261018.csv`, các nguồn cập nhật
`sources_user_review_20261018/` và `sources_v2.json`. Taxonomy mới
`data/taxonomy/expense_categories.v3_user_review.json` ghi ngoại lệ đúng từng
cặp text chuẩn hóa/nhãn; không bỏ luật kiểm tra trả nợ cho các câu khác. Đây là
quyết định người dùng cho chín câu cụ thể, không phải thay đổi toàn bộ taxonomy
về khoản vay. `bundle_v1/review.csv` vẫn giữ chín dòng lịch sử; xem
`bundle_v2/review.csv` cho trạng thái hiện hành (rỗng).

Thư mục bàn giao local: `data/prepared/model1_merged_1000_per_label_20261018/`.
ZIP: `data/prepared/model1_merged_1000_per_label_20261018.zip`.
CSV gộp có **6.000 dòng, đúng 1.000 dòng mỗi nhãn**, UTF-8, hai cột
`text,category`. Giữ nguyên câu và nhãn của bốn file `01.csv`–`04.csv` cùng
1.200 dòng teacher trong `data/synthetic/model1_teacher_200_per_label_20261017/`.
Không gộp thêm bộ giả lập 1.500 dòng cũ ở `data/processed/`.

## Kết quả hiện hành — bundle v2

| Nhãn | Mẫu duy nhất | Train | Validation | Test |
| --- | ---: | ---: | ---: | ---: |
| Ăn uống | 1.000 | 700 | 150 | 150 |
| Đi lại | 998 | 698 | 150 | 150 |
| Mua sắm | 1.000 | 700 | 150 | 150 |
| Hóa đơn/Nhà ở | 998 | 698 | 150 | 150 |
| Y tế | 1.000 | 700 | 150 | 150 |
| Khác | 1.000 | 700 | 150 | 150 |
| **Tổng** | **5.996** | **4.196** | **900** | **900** |

## Kết quả kiểm tra và chia tập v1 (lịch sử)

Có 5.996 câu duy nhất theo NFC/chữ hoa thường/khoảng trắng, 4 bản sao dư,
không có xung đột nhãn trên câu trùng. Pipeline cách ly thêm 9 dòng theo luật
`possible_income_transfer_or_debt`, còn **5.987 mẫu** trong bundle.

| Nhãn | CSV gộp | Dùng trong bundle | Train | Validation | Test |
| --- | ---: | ---: | ---: | ---: | ---: |
| Ăn uống | 1.000 | 1.000 | 700 | 150 | 150 |
| Đi lại | 1.000 | 997 | 698 | 150 | 149 |
| Mua sắm | 1.000 | 994 | 696 | 149 | 149 |
| Hóa đơn/Nhà ở | 1.000 | 996 | 698 | 149 | 149 |
| Y tế | 1.000 | 1.000 | 700 | 150 | 150 |
| Khác | 1.000 | 1.000 | 700 | 150 | 150 |
| **Tổng** | **6.000** | **5.987** | **4.192** | **898** | **897** |

Chín dòng chờ duyệt nằm trong `bundle_v1/review.csv` và có template duyệt tại
`bundle_v1/annotation_template.csv`. Hai dòng nói về trả nợ tiền nhà/khoản vay
nhà; sáu dòng nói về váy và một dòng `vay xam xe bi dinh dam het 30k` có khả
năng là cách viết sai của vá săm. Luật bỏ dấu khiến “váy” thành “vay”, nên đây
là cách ly bảo thủ, không phải kết luận cả chín nhãn sai. Cả chín câu đã được
người dùng duyệt và đưa vào bundle v2; không sửa trực tiếp bundle v1 đã đóng băng.

Tỷ lệ mục tiêu 70/15/15, seed 42, taxonomy `expense_six_v2_defaults`, ngưỡng
gần trùng 0,9. Ngân sách dò gần trùng được tăng từ mặc định 2 triệu lên 20 triệu
phép so sánh và ghi trong manifest; không bỏ qua cặp khi hết ngân sách.
Chia lại toàn bộ năm nguồn, giữ nhóm tình huống teacher và nhóm gần trùng cùng
một split. Đã verify hash, nhãn, ID, text chuẩn hóa và group giữa các tập.
Không thêm câu giả hoặc nhân bản để ép đủ 1.000 mẫu sạch mỗi nhãn.

## Nội dung gói

- `transactions.csv`: đủ 6.000 dòng, dùng kiểm tra hoặc trao đổi dữ liệu.
- `transactions_with_provenance.csv`: thêm nguồn, dòng CSV gốc, ID và metadata.
- `originals/`: bản sao nguyên byte bốn CSV và CSV teacher có provenance;
  `teacher_generation.json` giữ mô tả nguồn teacher.
- `sources/`, `sources.json`: nguồn có metadata để tái tạo qua pipeline.
- `validation_report.json`: số mẫu, phân bố nhãn, hash và kết quả chia tập.
- `bundle_v2/`: bộ hiện hành sau duyệt; train/validation/test, taxonomy, manifest, audit, review và template.
- `bundle_v1/`, `validation_report_v1.json`: bộ và báo cáo trước duyệt, giữ nguyên.
- `transactions_with_provenance_v2.csv`: bản provenance hiện hành có chín nhãn `approved`.
- `README.md`: bản hướng dẫn này đi kèm ZIP.

Bốn CSV được người dùng cung cấp với mô tả do nhóm cào cho Model 1. Tạm khai
báo nguồn `public` để truy vết nguồn cào; chưa có URL, giấy phép, phương pháp
thu thập hoặc bằng chứng phân biệt dữ liệu thật/synthetic. Trạng thái nhãn là
`provided`, thể hiện nhãn do nhóm bàn giao được dùng cho thử nghiệm, chưa phải
`approved` qua kiểm duyệt độc lập. Riêng chín câu đã duyệt được đặt `approved`
với ghi chú quyết định người dùng, không phải kiểm duyệt độc lập. Không suy ra nhóm tình huống hay danh tính
người viết khi CSV không có metadata đó. Dữ liệu teacher giữ `synthetic` và
`source_group` gốc. Bộ test pha dữ liệu teacher và nhãn chưa kiểm duyệt chỉ phù
hợp đánh giá phát triển; chưa chứng minh chất lượng trên giao dịch thực tế.

Gói CSV và bundle được giữ local theo `.gitignore`; chưa commit hoặc upload
dữ liệu cào. Các file đầu vào trong Downloads và bộ teacher gốc được giữ nguyên.

## Dùng trên Colab

Giải nén ZIP vào `MyDrive/Project1/datasets/`, giữ thư mục cha, rồi đặt:

```python
DATASET_DIR = "/content/drive/MyDrive/Project1/datasets/model1_merged_1000_per_label_20261018/bundle_v2"
RUN_LORA = True
RUN_CLASSIFIER = False
RUN_FORECASTER = False
```

Notebook: `notebooks/project1_colab.ipynb`; chọn T4 GPU để chạy LoRA.
Dùng mã nguồn hiện tại qua Drive nếu chưa push các thay đổi. Không đưa
`transactions.csv` vào thay bundle: notebook và script cần manifest và split
đã đóng băng. Công việc này chỉ chuẩn bị dữ liệu, **chưa train model**.

## Verify và tái tạo

Từ thư mục gốc dự án, Python 3.10+, không cần thư viện ML:

```powershell
python backend/scripts/prepare_classifier_data.py --verify data/prepared/model1_merged_1000_per_label_20261018/bundle_v2

python backend/scripts/merge_classifier_data.py --imports-dir C:/Users/PC/Downloads --output-dir data/prepared/model1_merged_1000_per_label_20261018_rebuilt

python backend/scripts/prepare_classifier_data.py --taxonomy data/taxonomy/expense_categories.v3_user_review.json --sources data/prepared/model1_merged_1000_per_label_20261018/sources_v2.json --output-dir data/prepared/model1_merged_bundle_v2_rebuilt --ambiguity-policy quarantine --seed 42 --max-near-comparisons 20000000
```

Lệnh thứ hai cần `01.csv`–`04.csv` trong thư mục imports, mặc định lấy bộ teacher
gốc và tạo lại v1 trước duyệt; có thể truyền `--teacher-dir` khác. Lệnh thứ ba
tạo lại v2 đã duyệt, chỉ cần các nguồn đã lưu
trong gói và mã nguồn/taxonomy hiện tại. Luôn chọn thư mục output mới.

Kiểm tra mã: 34 kiểm thử dataset đạt; Ruff đạt cho các script thay đổi.
