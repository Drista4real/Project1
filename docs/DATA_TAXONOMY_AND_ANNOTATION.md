# Taxonomy và hướng dẫn gán nhãn giao dịch

## Duyệt chín câu trong bộ gộp — 18/10/2026

Người dùng xác nhận cả chín câu trong review của bộ gộp đúng với nhãn hiện tại,
bao gồm `vay xam xe bi dinh dam het 30k` là vá săm xe, giữ Đi lại.
[Taxonomy v3](../data/taxonomy/expense_categories.v3_user_review.json) kế thừa
toàn bộ v2, thêm `approved_scope_exceptions` cho đúng chín cặp text/nhãn này.
Mỗi ngoại lệ có người duyệt, ngày và ghi chú. Chỉ bỏ cờ
`possible_income_transfer_or_debt` cho đúng text chuẩn hóa và nhãn đã duyệt;
nhãn lạ, xung đột, trạng thái pending và các kiểm tra khác vẫn cách ly bình thường.
Không áp dụng quyết định này cho mọi câu chứa vay/trả nợ. Bộ hiện hành là
`bundle_v2` trong [báo cáo bộ gộp](MODEL1_MERGED_DATASET.md).

## Quyết định hiện hành — quy ước mặc định ngày 15/10/2026

Người dùng đã yêu cầu duyệt toàn bộ 75 dòng trong annotation template theo các mặc định sau. Quyết định này thay thế yêu cầu review các mô tả tương ứng trong phần v1 bên dưới; các quy tắc khác vẫn áp dụng.

| Mô tả chỉ có tên chung và có thể kèm số tiền | Nhãn mặc định |
| --- | --- |
| `grab` | Đi lại |
| `shopee`, `shope`, `đơn hàng shopee`, `chốt đơn shopee`, `mua đồ` | Mua sắm |
| `bao bạn bè`, `bao bb` | Khác |

Nếu câu nói rõ hàng hóa hoặc dịch vụ thì ưu tiên nội dung cụ thể: `GrabFood đặt cơm` là Ăn uống, `mua thuốc trên Shopee` là Y tế. Không áp dụng mặc định cho mọi câu chỉ vì có chứa tên nền tảng. Các mô tả chưa rõ khác vẫn cần review; không dùng Khác thay cho mọi trường hợp không biết.

Cấu hình mới: [expense_categories.v2_defaults.json](../data/taxonomy/expense_categories.v2_defaults.json), version `expense_six_v2_defaults`. Pipeline vẫn dùng `quarantine` cho các cờ còn lại. Trường `default_label_policy` ghi nhận quyết định; pipeline không tự sửa nhãn đầu vào theo trường này. Các mô tả mặc định đã được bỏ khỏi `ambiguous_examples` trong v2.

Bản duyệt: [annotation_approved.csv](../data/prepared/expense_six_v2_defaults_20261015_annotations/annotation_approved.csv). Cả 75 dòng được đặt `approved`, xóa cờ đã giải quyết, ghi `annotator_id=user_policy_20261015` và ghi chú quyết định. Giữ nguyên nội dung, ID và nhãn; có 72 mẫu duy nhất, 3 dòng trùng dư được pipeline gộp và giữ provenance. Nguồn vẫn là synthetic, được khai báo trong [sources.approved_defaults.json](../data/taxonomy/sources.approved_defaults.json).

Đây là quyết định của người dùng được Codex áp dụng, không phải xác minh ngữ cảnh thực tế hay kiểm tra chéo bởi người thứ hai. Đã kiểm tra qua `read_sources` và `audit_records` với taxonomy v2: 72 mẫu hợp lệ, 0 dòng còn bị cách ly. File nguồn này chỉ chứa phần đã duyệt, không thay thế toàn bộ dữ liệu gốc. Chưa tạo lại train/validation/test; bước duyệt không ghi đè bundle v1 hoặc template đang có. File duyệt synthetic được chia sẻ trên Git theo ngoại lệ `.gitignore` riêng; các bundle khác vẫn bị bỏ qua. Kiểm tra lại v1 trước khi đẩy nhánh báo template không khớp hash manifest; cần tái tạo và verify bundle trước khi train.

## Chính sách v1 và hướng dẫn nền

Ngày chốt: **15/10/2026**. Người dùng đã chọn **giữ 6 nhãn** và **tách câu mơ hồ ra duyệt trước**. Cấu hình máy đọc được: [expense_categories.v1.json](../data/taxonomy/expense_categories.v1.json), version `expense_six_v1`.

## 1. Phạm vi và nhãn

Model này phân loại **mục đích một khoản chi đã xác định**, không quyết định số tiền, loại giao dịch hay trụ cột Kakeibo. Không đổi tên nhãn hiện tại và không làm mất tương thích với checkpoint 6 lớp.

| ID ổn định | Nhãn | Bao gồm | Ranh giới và ví dụ |
| --- | --- | --- | --- |
| `food` | Ăn uống | Đồ ăn, đồ uống, bữa ăn, thực phẩm để ăn/uống | Cơm, cà phê, trà sữa, mua rau. Phí giao đồ ăn chỉ gộp vào khoản này khi cùng đơn; đi Grab đến quán là Đi lại. |
| `transport` | Đi lại | Xăng, vé xe/tàu, taxi/xe ôm, phí gửi xe/cầu đường, bảo dưỡng xe phục vụ đi lại | `grab car`, `be bike` có căn cứ; riêng `grab` có thể là đồ ăn hoặc chuyến xe nên cần review. |
| `shopping` | Mua sắm | Hàng hóa phi thực phẩm, quần áo, đồ điện tử, gia dụng, sách/văn phòng phẩm | Giữ `mua sách` ở đây trong taxonomy 6 lớp. Thuốc là Y tế. Chỉ tên sàn `shopee` chưa chứng minh mua hàng gì. |
| `housing_utilities` | Hóa đơn/Nhà ở | Thuê nhà/phòng, điện, nước, internet, điện thoại, gas, phí quản lý/vệ sinh nhà ở | Không gán mọi câu có từ “hóa đơn” vào nhóm này: hóa đơn ăn uống vẫn là Ăn uống. |
| `healthcare` | Y tế | Khám/chữa bệnh, thuốc, nha khoa, xét nghiệm, tiêm phòng, vật tư y tế, bảo hiểm y tế được nói rõ | Mỹ phẩm làm đẹp thông thường là Mua sắm; câu chỉ nói “bảo hiểm” cần thêm loại bảo hiểm. |
| `other` | Khác | Khoản chi có mục đích rõ ngoài 5 nhóm trên: quà tiền, từ thiện, tiền phạt, học phí, giải trí, phí tài chính | `mừng cưới`, `từ thiện`, `vé xem phim` có mục đích. Không dùng Khác thay cho “không biết”. |

ID chuỗi ở bảng là ID taxonomy, **không phải primary key của bảng categories** và không phải chỉ số lớp của model. Thứ tự `LabelEncoder` cũ là: Hóa đơn/Nhà ở=0, Khác=1, Mua sắm=2, Y tế=3, Ăn uống=4, Đi lại=5. Mỗi model mới phải lưu mapping rõ ràng, không dùng vị trí trong mảng JSON làm class ID.

Ánh xạ đến app: dùng nhãn/ID chuẩn để tìm danh mục tương ứng của chính người dùng. Danh mục con được quy về mục đích của nhóm cha khi hợp lý; nếu nhiều danh mục phù hợp hoặc người dùng chưa có danh mục đó thì yêu cầu chọn. Không tự tạo hoặc dùng ID danh mục của người khác. Phần resolver API/UI thuộc B06, không được triển khai trong đợt pipeline này.

Kakeibo là trường riêng theo ngữ cảnh, không gán cứng từ 6 nhãn: thực phẩm thiết yếu có thể là `needs`, cà phê theo sở thích là `wants`, sách có thể là `culture`, khám bệnh đột xuất là `unexpected`. Nếu thiếu ngữ cảnh thì để người dùng chọn, không suy diễn bằng taxonomy.

## 2. Quy trình gán nhãn

1. Khử thông tin nhận diện trước khi nhập dữ liệu: tên thật, số tài khoản/điện thoại, mã giao dịch và địa chỉ không cần thiết. Dùng ID người dùng giả danh ổn định để chia tập; không ghi tên thật vào `subject_id`.
2. Xác định loại giao dịch từ ngữ cảnh nguồn: `expense`, `income` hoặc `transfer`. Chuyển tiền cho cửa hàng có thể là chi tiêu; từ “chuyển” không tự có nghĩa là chuyển giữa các ví của mình.
3. Tách vay/cho vay/trả gốc/thu hồi gốc để xử lý nghiệp vụ riêng, không ép vào 6 nhóm chi tiêu. Phí/lãi được nói rõ là khoản chi riêng theo chính sách kế toán của app.
4. Với khoản chi, xác định mục đích và chọn một trong 6 nhãn. Ưu tiên hàng hóa/dịch vụ thực tế thay cho tên nền tảng, cách thanh toán hoặc số tiền.
5. Câu chưa đủ căn cứ, nhiều mục đích chưa tách được, nhãn xung đột hoặc thiếu dữ liệu: đặt `pending` và ghi lý do. Không đoán theo nhãn generator và không coi đầu ra LLM là nhãn đã duyệt.
6. Mẫu rõ được gán `approved`; ghi `annotator_id` giả danh và `annotation_note` khi cần giải thích. Mẫu không dùng được là `rejected`. Dữ liệu generator mang `synthetic`, không gọi là nhãn người dùng thật.
7. Người thứ hai kiểm tra các mẫu mơ hồ/bất đồng và một mẫu ngẫu nhiên ở mỗi lớp/nguồn. Thống kê tỷ lệ bất đồng và quyết định cuối; không có đủ người thì ghi rõ chưa kiểm tra chéo.

| Nội dung | Xử lý |
| --- | --- |
| “ăn trưa 65k”, “đổ xăng 50k” | Ăn uống / Đi lại nếu xác định là khoản chi |
| “mua đồ 3tr5”, “shopee 200k”, “bao bạn bè 100k” | Review, cần loại hàng hoặc mục đích cụ thể |
| “nhận lương 15tr” | Income; không đưa vào classifier chi tiêu |
| “chuyển 500k từ ví tiền mặt sang ví ngân hàng” | Transfer nội bộ; không phải chi tiêu |
| “chuyển khoản tiền điện 300k” | Hóa đơn/Nhà ở nếu nguồn xác nhận là khoản chi |
| “ăn sáng 30k và đổ xăng 50k” | Tách thành hai giao dịch hoặc review; chưa dùng làm mẫu đơn nhãn |
| “mua thuốc cảm”, “mua áo tặng bạn” | Y tế / Mua sắm; mua món quà không tự thành quà tiền thuộc Khác |
| “mừng cưới 1 triệu”, “học phí tháng này” | Khác, mục đích đã rõ trong taxonomy 6 lớp |

Danh sách câu mơ hồ và bộ phát hiện loại giao dịch trong JSON chỉ là **heuristic có giới hạn**, không kiểm tra hết ngôn ngữ tự nhiên. Pipeline không tự chứng nhận mọi câu còn lại đều đúng nhãn. Không tự sửa nhãn hàng loạt theo keyword.

## 3. Định dạng dữ liệu đầu vào

UTF-8 CSV, bắt buộc `text,category`. Các trường khác được hỗ trợ:

| Cột | Ý nghĩa |
| --- | --- |
| `record_id` | ID gốc tùy chọn để truy vết; pipeline sinh ID nội dung riêng và lưu ID gốc trong origins |
| `transaction_type` | Mặc định `expense` cho CSV cũ; phải khai báo đúng với dữ liệu nhập mới. Income/transfer bị tách review |
| `annotation_status` | `approved`, `pending`, `rejected`, `synthetic`, `provided`; nguồn real/public không có trạng thái mặc định pending |
| `source_group` | Nhóm thu thập/phiên/nguồn con bên trong cùng `source_id`, không được rải qua các tập |
| `subject_id` | ID giả danh cùng một người, dùng nhất quán giữa các nguồn; toàn bộ dữ liệu người đó được gom một nhóm |
| `template_id` | ID họ mẫu sinh/ngữ nghĩa, dùng namespace ổn định như `generator_v1.food.rice`; cùng ID giữa các nguồn vẫn cùng nhóm |
| `review_reasons` | Ghi chú cờ lỗi chưa xử lý; có giá trị thì cần review và không được train |
| `annotator_id`, `annotation_note` | Người duyệt giả danh và lý do gán nhãn; được lưu trong provenance |

Nguồn và quyền sử dụng khai báo qua CLI hoặc JSON sources riêng: `source_id`, `kind` (`synthetic`/`real`/`public`), `usage_rights`, `path`. Đây là khai báo truy vết, không phải bằng chứng tự động rằng dataset được cấp phép.

`provided` dùng khi người dùng bàn giao dữ liệu đã gán nhãn và yêu cầu dùng cho
thử nghiệm phát triển. Pipeline giữ nhãn và cho phép chia tập nhưng không khẳng
định nhãn đã được người duyệt phê duyệt. Mọi luật kiểm tra và cách ly vẫn áp dụng.
Không tự chuyển nguồn `pending` thành `provided` hoặc `approved` khi chưa có yêu
cầu sử dụng dữ liệu gán nhãn. Bộ gộp ngày 18/10/2026 dùng trạng thái này cho bốn
CSV từ nhóm; nhãn teacher tiếp tục là `synthetic`.

Legacy CSV hiện có không có subject/template IDs. Pipeline gom họ mẫu bằng mô tả đã bỏ số tiền, dấu, khoảng cách và so khớp gần; không suy ra được tác giả hoặc chứng minh toàn bộ họ ngữ nghĩa độc lập. Khi thu thập/sinh mới phải lưu metadata ngay từ nguồn. Không dùng `source_id` toàn bộ dataset làm một group nếu muốn chia bên trong nguồn đó; dùng các group thực sự độc lập.

## 4. Quy tắc kiểm tra và chia tập

- Exact key: Unicode NFC, chữ thường, chuẩn hóa khoảng trắng; giữ dấu và số tiền. Cùng nội dung nhưng khác nhãn/loại giao dịch: cách ly toàn bộ, không chọn bản đầu tiên.
- Bản sao cùng nhãn được gộp nhưng giữ mọi nguồn, dòng gốc và ràng buộc nhóm; cờ review của một bản sao không bị bỏ qua bởi bản khác.
- Description key để phát hiện rò rỉ bỏ số tiền viết bằng chữ số và đơn vị phổ biến, bỏ dấu/chấm câu/khoảng cách. Chỉ dùng cho grouping, không làm preprocessing của PhoBERT và không dùng để xóa bản gần trùng.
- So gần bằng SequenceMatcher trên candidate có trigram, ngưỡng mặc định 0,9; gom transitive closure với mô tả/group/subject/template. Quá ngân sách so sánh sẽ báo lỗi, không âm thầm bỏ qua. Có thể gom dư; cần đọc audit.
- `--max-near-comparisons` cho phép khai báo ngân sách lớn hơn mặc định 2 triệu;
  giá trị được lưu trong manifest. Bộ gộp 6.000 dòng dùng 20 triệu, vẫn giữ ngưỡng 0,9.
- Chia toàn nhóm, mặc định **70% train / 15% validation / 15% test**, seed 42; cân đối lớp xấp xỉ. Không phá nhóm để đạt đúng tỷ lệ. Mỗi nhãn cần ít nhất 3 nhóm độc lập; không đủ thì báo lỗi và không xuất các tập train/validation/test.
- Cùng nội dung và constraint cho membership ổn định khi đảo thứ tự dòng. Nếu đổi dữ liệu/config/taxonomy thì là **dataset version mới**, không bảo đảm mẫu cũ giữ nguyên split. Đóng băng bundle để so các thí nghiệm trên cùng test.
- Validation dùng chọn model/siêu tham số/calibration; test chỉ dùng đánh giá sau khi chốt. Nếu cần calibration độc lập, chia tiếp **bên trong train/validation**, không lấy từ test. Augment sau chia và chỉ augment train; giữ quan hệ mẫu cha.
- Test tách từ dữ liệu giả lập vẫn chỉ là benchmark phát triển. Bộ test thật độc lập thuộc D05 và hiện **chưa có**.

## 5. Chạy pipeline

Từ thư mục gốc, chỉ cần Python **3.10+**, không tải model, không gọi cloud, không cần thư viện ML. Dùng `python` hoặc `.\.venv\Scripts\python.exe` tùy môi trường.

```powershell
python backend/scripts/prepare_classifier_data.py --taxonomy data/taxonomy/expense_categories.v1.json --sources data/taxonomy/sources.example.json --output-dir data/prepared/expense_six_v1_20261015 --ambiguity-policy quarantine

python backend/scripts/prepare_classifier_data.py --verify data/prepared/expense_six_v1_20261015
```

Thư mục đầu ra phải mới hoặc rỗng; nếu đã chạy thì dùng version khác. Không tự ghi đè dữ liệu/checkpoint. Đường dẫn trong `sources.example.json` tính tương đối với chính file JSON, nên dùng được trên Windows và Colab/Linux.

Một nguồn khác có thể dùng `--input ... --source-id ... --source-kind real --usage-rights ...` thay `--sources`. Bộ pipeline chung có `keep_flagged` cho thí nghiệm được ghi rõ, nhưng **quyết định sản phẩm hiện tại là `quarantine`**.

Bundle thành công gồm:

- `train.csv`, `validation.csv`, `test.csv`: text gốc, taxonomy ID, record/group ID và origins.
- `review.csv`: mọi dòng bị tách và lý do, kể cả bản sao xung đột; giữ riêng khỏi training.
- `annotation_template.csv`: bản dùng để gán nhãn lại với các cột đầu vào hợp lệ, mặc định pending. Sao chép ra thư mục mới để chỉnh, không sửa artifact của bundle đóng băng. Thêm ngữ cảnh chính xác khi nguồn có, sửa nhãn/loại giao dịch, ghi reviewer, xóa cờ đã giải quyết và đổi trạng thái approved. Không chỉ xóa cờ để ép câu vẫn mơ hồ được train. Không đổi tên source synthetic thành real khi duyệt lại câu giả lập.
- `taxonomy.json`: snapshot cấu hình đã dùng.
- `audit.json`: kiểm tra dữ liệu, số bản trùng trước/sau review, lý do tách, độ phủ metadata, nhóm gần trùng và giới hạn của kiểm tra.
- `manifest.json`: hash nguồn/quyền sử dụng khai báo, pipeline hash/config/seed, taxonomy version/hash, split IDs/counts/hash và dataset ID.

`--verify` kiểm tra hash, schema, class coverage, record IDs và không giao nhau ID/group/text giữa các tập. Manifest dùng để phát hiện thay đổi ngoài ý muốn; không phải chữ ký chống giả mạo. Bundle/review có thể chứa dữ liệu nhạy cảm nên `data/prepared/` và `data/private/` được gitignore.

Với dữ liệu lỗi không đủ nhóm, pipeline giữ audit, review và annotation template, trả exit code 2 và không có manifest/tập train. Với lỗi schema/CSV hỏng, pipeline dừng trước khi coi đó là dataset hợp lệ.

## 6. Dùng bundle cho script train hiện có

Đã thêm lựa chọn đọc bundle **không chia lại**:

```powershell
# Chỉ chạy ở bước training tiếp theo khi đã sẵn sàng, chưa chạy trong đợt này.
python backend/scripts/train_classifier.py --dataset-dir data/prepared/expense_six_v1_20261015 --output-dir weights/experiments/baseline_grouped_v1 --local-files-only
```

Script kiểm tra bundle trước khi nạp model, fit chỉ train, in riêng validation/test và lưu `training_data_manifest.json` cùng checkpoint. Tham số baseline hiện cố định; script này chưa triển khai tìm siêu tham số/LoRA. Chế độ `--data` cũ vẫn có để tương thích, có cảnh báo random 80/20; không dùng chế độ đó cho thí nghiệm mới cần split đã chốt.

Đợt này không ghi đè CSV/checkpoint cũ, không train model dự án, không khẳng định đã có test thật hoặc hoàn tất kiểm tra chéo nhãn bởi con người.
