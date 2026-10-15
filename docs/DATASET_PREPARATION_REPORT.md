# Kết quả chuẩn bị dữ liệu classifier — 15/10/2026

Phạm vi: S04, D02–D04, D08 trong [checklist](APP_COMPLETION_CHECKLIST.md). Đã thực thi pipeline trên CSV hiện có; không train lại checkpoint dự án hoặc gọi API cloud.

## Quyết định đã nhận từ người dùng

Cập nhật sau đợt tạo bundle v1, ngày 15/10/2026: người dùng đã chốt Grab mặc định Đi lại, Shopee/mua đồ mặc định Mua sắm, bao bạn bè mặc định Khác. Đã áp dụng cho toàn bộ 75 dòng trong [annotation_approved.csv](../data/prepared/expense_six_v2_defaults_20261015_annotations/annotation_approved.csv): 6 Đi lại, 48 Mua sắm, 21 Khác; trạng thái `approved`, có ghi chú quyết định và giữ nguồn synthetic. Kiểm tra với [taxonomy v2](../data/taxonomy/expense_categories.v2_defaults.json) qua `read_sources`/`audit_records`: 72 mẫu duy nhất hợp lệ, 3 dòng trùng dư, 0 dòng bị cách ly. Chưa tạo bundle v2 hoặc gộp phần duyệt vào train/validation/test. Các số liệu và quyết định ban đầu dưới đây mô tả bundle v1, được giữ để truy vết.

- Giữ 6 nhãn hiện tại cho lần train tiếp theo.
- Tách câu mơ hồ để duyệt trước, không giữ chúng trong tập train chính.

Taxonomy version `expense_six_v1`; định nghĩa/ràng buộc/biên giữa các lớp, loại giao dịch ngoài phạm vi, Kakeibo và quy tắc ánh xạ được ghi tại [DATA_TAXONOMY_AND_ANNOTATION.md](DATA_TAXONOMY_AND_ANNOTATION.md).

## Kết quả chạy thật trên dữ liệu hiện có

Nguồn: `data/processed/data_transactions.csv`, **dữ liệu giả lập**. SHA256 `0cadb05bae8822c4bb11e74a9940523baa7e600d174c9f1a67c6ce572c6a8bc6`, khớp hash trong audit cũ.

| Chỉ số | Kết quả |
| --- | ---: |
| Dòng đầu vào | 1.500 |
| Bản sao trùng dư trước khi tách review | 12 |
| Dòng tách để duyệt vì mô tả mơ hồ | 75 |
| Bản sao dư bị bỏ trong phần đủ điều kiện | 9 |
| Dòng duy nhất còn lại để chia tập | 1.416 |
| Nhóm mô tả/near-duplicate | 113 |
| Nhóm lớn nhất | 32 dòng |
| Dòng có subject/template/source-group metadata trong nguồn gốc | 0 |

Ba bản sao dư còn lại trong tổng 12 thuộc phần review, không bị âm thầm xóa. Đối soát: **1.416 + 75 + 9 = 1.500**.

| Nhãn | Train | Validation | Test |
| --- | ---: | ---: | ---: |
| Ăn uống | 174 | 36 | 37 |
| Đi lại | 169 | 37 | 36 |
| Mua sắm | 141 | 30 | 31 |
| Hóa đơn/Nhà ở | 171 | 38 | 38 |
| Y tế | 174 | 38 | 38 |
| Khác | 161 | 33 | 34 |
| **Tổng dòng** | **990** | **212** | **214** |
| **Tổng nhóm** | **83** | **15** | **15** |

Tỷ lệ thực tế là **69,92% / 14,97% / 15,11%**, gần mục tiêu 70/15/15 nhưng giữ nguyên nhóm. CLI verify thành công: hash đúng, đủ 6 lớp trong từng tập, không giao nhau text chuẩn hóa/record ID/group ID.

Cập nhật kiểm tra trước khi đẩy nhánh ngày 15/10: kết quả verify thành công ở trên là tại thời điểm tạo bundle. Bản v1 trên máy hiện báo `annotation_template.csv hash mismatch` vì template đã thay đổi sau khi tạo manifest. Giữ nguyên bản đang có để truy vết; cần tái tạo bundle và verify trước khi dùng để train, không cập nhật hash để hợp thức hóa thay đổi.

Bundle cuối: `data/prepared/expense_six_v1_20261015/`, dataset ID `dataset_37c405e5fa73308ddce63c3d`. Thư mục được gitignore vì bundle/review có thể chứa dữ liệu riêng tư khi dùng pipeline cho nguồn thật. Lệnh tái tạo và verify ở hướng dẫn; chạy lại cần output version mới.

## Mã và artifact đã bổ sung

- `data/taxonomy/expense_categories.v1.json`: taxonomy/version/ID, câu mơ hồ và scope guards.
- `data/taxonomy/sources.example.json`: nguồn giả lập và khai báo quyền sử dụng.
- `backend/scripts/dataset_pipeline.py`: đọc/kiểm tra CSV, review, exact dedup, near/provenance grouping, chia nhóm, manifest/hash và kiểm tra bundle.
- `backend/scripts/prepare_classifier_data.py`: CLI portable, hỗ trợ một hoặc nhiều nguồn.
- `backend/scripts/train_classifier.py`: thêm `--dataset-dir` giữ nguyên split; lưu manifest dataset cùng checkpoint khi chạy bước train sau này. Chế độ legacy có cảnh báo.
- `review.csv` và `annotation_template.csv` trong bundle: dòng cần duyệt và mẫu nhập lại, trạng thái mặc định pending.
- `.github/workflows/classifier-data.yml`: kiểm tra pipeline độc lập với thư viện/model AI nặng; chưa chạy workflow trên GitHub trong đợt này.

## Kiểm thử

Đã chạy **48 kiểm thử thành công**, gồm bộ kiểm tra dataset và bộ classifier hiện có/bổ sung. Bộ roundtrip dùng LightGBM nhỏ cùng encoder giả trong thư mục tạm, không tải PhoBERT hoặc thay checkpoint dự án. Kiểm tra: boundary nhãn cũ, tiền tệ/dấu, exact conflict, quarantine, provenance groups xuyên nguồn, transitive near grouping, tái lập khi đảo dòng, thiếu nhóm, CSV hỏng, artifact bị sửa, CLI từ thư mục khác và train không chia lại/fit lên validation/test.

Ruff pass trên toàn bộ file Python được sửa/thêm; `git diff --check` không có lỗi whitespace. Lệnh kiểm thử chọn đúng hai bộ, bỏ conftest API vì môi trường `.venv` phục vụ ML hiện không cài FastAPI:

```powershell
python -m pytest -c backend/pyproject.toml --noconftest tests/datasets backend/tests/classifier -q
python -m ruff check --config backend/pyproject.toml backend/scripts/dataset_pipeline.py backend/scripts/prepare_classifier_data.py backend/scripts/train_classifier.py tests/datasets backend/tests/classifier/test_classifier.py
```

## Phần còn mở

- **D02 còn mở phần kiểm tra chéo:** 75 dòng đã được người dùng duyệt theo quy ước mặc định và lưu riêng; chưa xác minh thêm ngữ cảnh thực tế, chưa có người thứ hai kiểm tra độc lập. Các dòng còn lại vẫn mang nhãn generator, chưa được kiểm tra chéo toàn bộ bởi con người. Cần tạo bundle v2 hoàn chỉnh trước khi train theo quy ước mới.
- **D01/D05/D06/D07 chưa hoàn tất:** không thu thập dữ liệu thật, không tạo bộ test người dùng/audio/hóa đơn độc lập trong đợt này.
- Split mới giảm rò rỉ từ exact/lexical templates theo quy tắc đã công bố; không chứng minh toàn bộ ngữ nghĩa độc lập. Nguồn cũ không có ID tác giả/họ mẫu, nên khi bổ sung dữ liệu phải lưu metadata từ đầu.
- Test 214 câu chỉ gồm 15 nhóm từ dữ liệu giả lập. Không dùng kết quả train cũ để suy ra chất lượng trên test mới hoặc dữ liệu thật; cần đánh giá lại baseline và LoRA trên cùng bundle sau này.
- Pipeline Colab/LoRA và triển khai AI vào app là các công việc tiếp theo, chưa được đánh dấu hoàn thành.
