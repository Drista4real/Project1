# Checklist hoàn thiện ứng dụng Kakeibo Zen

Ngày tổng hợp: **15/10/2026**. Căn cứ: [MODEL_TRAINING_AUDIT.md](MODEL_TRAINING_AUDIT.md), đặc biệt mục 7; [SPECIFICATION.md](SPECIFICATION.md); [release-v1.md](release-v1.md); mã backend, Flutter và cấu hình triển khai hiện tại.

Đây là kế hoạch công việc, không phải xác nhận đã triển khai hoặc đã kiểm thử. Các ô trống là phần cần làm, hoàn thiện hoặc nghiệm thu thêm. CRUD, xác thực email, giao diện báo cáo/ngân sách, adapter AI và các checkpoint hiện có được kế thừa. Chưa xác minh database/cloud/bản APK từ xa trong lần tổng hợp này.

## 1. Chốt phạm vi và hợp đồng hệ thống

- [ ] **S01** Chốt bản bàn giao: Android APK hay cả web/iOS; phân biệt bản dùng thử cốt lõi và bản đáp ứng toàn bộ đặc tả. Google/Apple Sign-In, Guest Mode, SQLCipher, xuất báo cáo và sao lưu cần có quyết định phạm vi rõ ràng.
- [ ] **S02** Đồng bộ README, đặc tả và kiến trúc: 180 ngày dữ liệu thực có thay vì 90; 6 nhãn hiện tại; PhoBERT-base hiện có so với base-v2 được đề xuất trước đây; thêm thiết kế LoRA. Chọn và ghim chính xác base model/revision cho mỗi thí nghiệm.
- [ ] **S03** Chốt nơi chạy từng thành phần: Colab huấn luyện; server CPU phân loại/dự báo; điện thoại nhận dạng giọng nói offline; Qwen đọc hóa đơn; Gemini phân loại fallback và diễn giải. Làm rõ yêu cầu văn bản xử lý trên thiết bị hay server vì đặc tả có cả hai cách mô tả.
- [x] **S04** Chốt taxonomy nhãn, thu/chi/chuyển ví, Kakeibo và quy tắc ánh xạ nhãn model sang danh mục từng người dùng. Ngày 15/10: giữ 6 nhãn; chốt `expense_six_v2_defaults`: Grab mặc định Đi lại, Shopee/mua đồ mặc định Mua sắm, bao bạn bè mặc định Khác khi câu chưa nêu hàng hóa/dịch vụ cụ thể. Khoản thu/chuyển ví xử lý riêng, Kakeibo theo ngữ cảnh; resolver thực tế thuộc B06. Xem [hướng dẫn taxonomy](DATA_TAXONOMY_AND_ANNOTATION.md).
- [ ] **S05** Chốt hợp đồng dữ liệu/version: kết quả trích xuất, dự đoán, độ tin cậy, nguồn xử lý, trạng thái job, phiên bản model/prompt và trạng thái người dùng xác nhận. Phân biệt confidence đo được với điểm tự khai báo của LLM/quy tắc.
- [ ] **S06** Chốt quy tắc tiền tệ, múi giờ, ví tín dụng, số dư đầu kỳ/điều chỉnh và tài sản khả dụng. Trước mắt có thể chỉ hỗ trợ VND; không cộng trực tiếp các ví khác tiền tệ.

**Hoàn thành khi:** có phạm vi bàn giao, sơ đồ luồng và hợp đồng dữ liệu thống nhất để các phần còn lại triển khai theo.

## 2. Dữ liệu huấn luyện và đánh giá

- [ ] **D01** Thu thập giao dịch thật đã khử thông tin nhận diện, có quyền sử dụng; cân nhắc mục tiêu 5.000–10.000 câu theo kế hoạch ban đầu. Đánh dấu riêng dữ liệu thật, giả lập và nguồn sinh.
- [ ] **D02** Đã có hướng dẫn gán nhãn và đã duyệt toàn bộ 75 dòng từng bị cách ly theo quy ước mặc định được người dùng xác nhận ngày 15/10. Bản [annotation_approved.csv](../data/prepared/expense_six_v2_defaults_20261015_annotations/annotation_approved.csv) có 6 dòng Đi lại, 48 Mua sắm, 21 Khác; tất cả `approved`, có người duyệt/ghi chú và đã xóa cờ được giải quyết. Kiểm tra với taxonomy v2: 72 mẫu duy nhất hợp lệ, 3 dòng trùng dư, không còn dòng bị cách ly trong phần này. Nguồn vẫn synthetic. Còn mở kiểm tra chéo độc lập và rà soát các nhãn generator còn lại; không coi việc áp dụng quy ước là xác minh ngữ cảnh thực tế.
- [x] **D03** Đã có phát hiện trùng nguyên câu và gần trùng/mẫu câu, grouping theo mô tả/metadata, giữ nhóm nguyên vẹn khi chia. Đã áp dụng cho 1.500 câu hiện có; không có giao nhau text/ID/group trong bundle mới. Kiểm tra ngữ nghĩa ngoài heuristic vẫn cần gán nhãn/metadata.
- [x] **D04** Đã tạo bundle v1 70/15/15 theo nhóm, ID cố định, đủ 6 lớp trong cả ba tập; train=990, validation=212, test=214. Script train có `--dataset-dir`, kiểm tra integrity và không chia lại/fit validation hoặc test. Chưa tạo bundle v2 kết hợp dữ liệu gốc với 75 dòng đã duyệt; cần gộp trùng, chia lại theo nhóm và verify trước khi train theo chính sách mới. Giữ v1 để đối chiếu đến khi có v2 hoàn chỉnh.
- [ ] **D05** Dành bộ test thật độc lập, kiểm tra câu ngoài miền/không đủ thông tin. Chỉ augment train sau khi chia; không đưa phản hồi hoặc ví dụ test vào dữ liệu sinh/train.
- [ ] **D06** Thu thập chuỗi thu/chi/số dư của nhiều hồ sơ, nhiều lịch lương/tiền thuê và nhiều mức số dư. Dựng thêm kịch bản stress có nguồn gốc rõ ràng nếu chưa đủ dữ liệu thật.
- [ ] **D07** Tạo bộ audio có transcript chuẩn, người nói/giọng vùng miền/độ nhiễu đa dạng; tách theo người nói. Tạo bộ hóa đơn có nhãn cửa hàng, ngày, dòng hàng, tổng tiền và danh mục; tách theo cửa hàng/mẫu hóa đơn để hạn chế rò rỉ.
- [x] **D08** Đã version hóa dataset hiện có: manifest ghi nguồn/quyền sử dụng khai báo, schema, phân bố nhãn, hash pipeline/taxonomy/file và ID split; có CLI verify. Bundle/review và thư mục private được gitignore. Nguồn hiện tại vẫn là dữ liệu giả lập.

Kết quả đợt S04, D02–D04, D08: [báo cáo chuẩn bị dữ liệu](DATASET_PREPARATION_REPORT.md). Đã duyệt 75 dòng theo quyết định của người dùng và lưu chính sách v2; chưa gộp vào train/validation/test, chưa train lại model hoặc tạo bộ test người dùng thật. D02 vẫn mở phần kiểm tra chéo độc lập và rà soát dữ liệu còn lại.

Kiểm tra trước khi đẩy nhánh ngày 15/10: 48 kiểm thử dataset/classifier và Ruff đều đạt. Bundle v1 từng verify thành công khi tạo; kiểm tra lại hiện báo `annotation_template.csv hash mismatch` do template đã được chỉnh sau khi tạo manifest. Không dùng bundle hiện tại để train cho đến khi tái tạo và verify thành công; không sửa hash trong manifest để bỏ qua lỗi. Bản duyệt synthetic được chia sẻ trên Git theo ngoại lệ riêng; các bundle khác và dữ liệu private vẫn bị bỏ qua.

**Hoàn thành khi:** có dữ liệu và split kiểm chứng được cho từng bài toán; không coi 1.860 bản ghi khác loại là một tập train chung.

## 3. Đưa pipeline huấn luyện lên Google Colab

- [ ] **C01** Tạo notebook kiểm tra dữ liệu/split, notebook fine-tune PhoBERT-LoRA và notebook train/đánh giá forecaster. Notebook gọi chung script của repository để tránh hai bản logic khác nhau.
- [ ] **C02** Clone checkout đúng commit; thiết lập đường dẫn Linux/Colab thay cho đường dẫn máy Windows; cài bộ phiên bản tương thích được ghim cho PyTorch, Transformers, PEFT, Accelerate, LightGBM, underthesea và thư viện đánh giá.
- [ ] **C03** Nhận dữ liệu qua upload, Drive hoặc kho riêng; kiểm tra hash/schema/split trước khi train. Quản lý token bằng secrets, không lưu token hoặc dữ liệu nhạy cảm trong notebook/output chia sẻ.
- [ ] **C04** Kiểm tra GPU/VRAM và dtype được hỗ trợ; cấu hình batch size, gradient accumulation, mixed precision và gradient checkpointing khi cần. Có lượt chạy nhỏ để xác nhận pipeline trước khi train đầy đủ.
- [ ] **C05** Lưu checkpoint định kỳ ra nơi bền vững; hỗ trợ resume gồm optimizer, scheduler, bước train và trạng thái RNG khi khả thi. Thử thực sự việc ngắt rồi tiếp tục; không chỉ lưu adapter cuối.
- [ ] **C06** Tạo thư mục riêng cho từng run, không ghi đè checkpoint tốt hiện tại. Lưu config, seed, code commit, base revision, dataset hash/split IDs, log loss/metrics, thời gian, phần cứng và versions.
- [ ] **C07** Export gói inference đầy đủ: base model/revision, tokenizer, adapter, classification head hoặc LightGBM tương ứng, label map, tiền xử lý, calibration/ngưỡng và checksum; có hướng dẫn tải về.
- [ ] **C08** Nạp lại artifact trong runtime sạch và server CPU; so kết quả Colab với môi trường triển khai trong sai số cho phép. Chạy LightGBM forecaster trên CPU nếu không cần GPU.

Colab dùng để train/đánh giá, không làm backend phục vụ app. GPU, thời gian phiên và tài nguyên không được đảm bảo cố định, nên checkpoint/resume là yêu cầu của pipeline. [Nguồn: Google Colab FAQ](https://research.google.com/colaboratory/faq.html).

**Hoàn thành khi:** từ một runtime Colab mới có thể tải đúng dữ liệu, train, resume, export và nạp lại model mà không sửa tay mã nguồn.

## 4. Fine-tune PhoBERT bằng LoRA và chọn classifier

- [ ] **L01** Giữ baseline PhoBERT đóng băng + LightGBM hiện tại để so sánh; đánh giá lại trên split mới. Không lấy F1 95,33% trên test giả lập cũ làm chất lượng đã được xác nhận trên dữ liệu thật.
- [ ] **L02** Xây dựng PhoBERT cho sequence classification với LoRA: base weights đóng băng, train adapter và classification head; kiểm tra tên module thực tế trước khi chọn các attention projection như `query`/`value`.
- [ ] **L03** Cấu hình đúng loại tác vụ, `num_labels`, `id2label`/`label2id`; đảm bảo head được train và lưu/nạp cùng adapter. In số tham số được train, kiểm tra gradient và xác nhận trọng số thực sự thay đổi.
- [ ] **L04** Dùng cùng tiền xử lý/tách từ/tokenizer/max_length giữa train và inference. Nếu đổi từ underthesea sang bộ tách từ khác, coi đó là một thí nghiệm/version mới và đánh giá lại.
- [ ] **L05** Tìm cấu hình trong ngân sách: rank, alpha, dropout, learning rate, batch size, số epoch, weight decay và xử lý mất cân bằng lớp. Early stopping/chọn checkpoint bằng validation macro F1; chạy nhiều seed nếu đủ tài nguyên.
- [ ] **L06** So sánh trên cùng split: A — PhoBERT đóng băng + LightGBM; B — PhoBERT-LoRA + classification head; C — embedding PhoBERT sau LoRA + LightGBM train mới nếu tiếp tục kiến trúc hybrid. C là thí nghiệm, không mặc định tốt hơn B.
- [ ] **L07** Nếu dùng C, trích lại toàn bộ embedding và train lại LightGBM với đúng encoder/adapter đã chọn. Không ghép LightGBM cũ với embedding PhoBERT vừa fine-tune.
- [ ] **L08** Báo cáo accuracy, macro/per-class F1, confusion matrix, chất lượng câu nhiễu/ngoài miền và lỗi điển hình. Tách đánh giá toàn tập khỏi độ đúng trên phần giao dịch được chấp nhận xử lý local.
- [ ] **L09** Hiệu chuẩn confidence trên validation hoặc tập calibration riêng; kiểm tra trade-off giữa độ đúng và tỷ lệ local tại ngưỡng 0,8. Nếu đổi ngưỡng phải version hóa và cập nhật đặc tả; không tự coi softmax hoặc số LLM tự trả là xác suất đúng.
- [ ] **L10** Chọn model phục vụ theo chất lượng, độ trễ, RAM, dung lượng và chi phí fallback. Lưu model card/manifest; kiểm tra save/load không mất head hoặc sai thứ tự nhãn.
- [ ] **L11** Cập nhật domain port, adapter và config inference để hỗ trợ kiến trúc được chọn. Config hiện bị khóa vào schema/base model/ngưỡng cũ nên cần migration tương thích rõ ràng.
- [ ] **L12** Benchmark toàn pipeline tách từ + encoder + classifier trên CPU đích: cold start, warm mean/p50/p95, concurrency và RAM. Thử merge LoRA/export ONNX/INT8 nếu tương thích; đo lại chất lượng sau tối ưu. LoRA không tự làm encoder nhỏ hoặc bảo đảm nhanh hơn.

Lựa chọn target modules và việc lưu classification head cần kiểm tra theo kiến trúc thực tế. [Nguồn: PEFT troubleshooting](https://huggingface.co/docs/peft/en/developer_guides/troubleshooting), [LoRA reference](https://huggingface.co/docs/peft/en/package_reference/lora), [PhoBERT model card](https://huggingface.co/vinai/phobert-base).

**Hoàn thành khi:** có checkpoint LoRA thực sự được train, báo cáo so sánh có thể tái lập và adapter inference chạy đúng trên server. Không bắt buộc checkpoint LoRA thắng baseline mới được ghi nhận là đã làm thí nghiệm.

## 5. Hoàn thành CLOUD_FALLBACK

- [ ] **F01** Tạo domain port và adapter Gemini dành riêng cho phân loại NLP; tách khỏi advisor. Bổ sung orchestrator quyết định local/cloud/review, không nhúng gọi cloud vào domain.
- [ ] **F02** Giữ kết quả local khi confidence đạt ngưỡng; dưới ngưỡng tạo job bền vững. Thống nhất trạng thái `PENDING`, `RUNNING`, `SUCCEEDED`, `FAILED`, `REVIEW_REQUIRED` hoặc bộ trạng thái tương đương.
- [ ] **F03** Tích hợp Redis/Celery với bảng job, outbox hoặc cơ chế phục hồi tương đương để tránh mất job giữa ghi database và publish queue. API trả job ID và kết quả tạm, không giữ request chờ toàn bộ cloud.
- [ ] **F04** Prompt chỉ nhận văn bản cần thiết và danh mục hợp lệ, có version; giới hạn input và coi nội dung giao dịch là dữ liệu. Không cho nội dung nhập thay đổi schema/chỉ dẫn hoặc thực hiện thao tác ngoài phân loại.
- [ ] **F05** Yêu cầu structured output khi nhà cung cấp hỗ trợ, sau đó validate Pydantic/JSON Schema và kiểm tra enum/danh mục/nghiệp vụ. Đầu ra không hợp lệ không được ghi như kết quả thành công; không tuyên bố GCD nếu API không cung cấp.
- [ ] **F06** Ghi rõ nguồn kết quả, local score, cloud model/prompt version, thời gian xử lý và trạng thái review. LLM có thể chọn chưa đủ thông tin; không ép mọi câu vào một danh mục hoặc dùng confidence tự khai báo làm xác suất đã hiệu chuẩn.
- [ ] **F07** Timeout, exponential backoff có jitter cho lỗi tạm thời/rate limit; chốt tối đa 3 lần thử tổng cộng hay 3 lần retry và kiểm thử đúng quy ước. Không retry vô ích lỗi input/schema lặp lại; có trạng thái lỗi cuối và retry thủ công.
- [ ] **F08** Idempotency cho request/task; chống worker xử lý trùng và kết quả trả trễ. Chỉ cập nhật phân loại khi phiên bản giao dịch còn khớp; không ghi đè danh mục người dùng đã sửa/xác nhận hoặc hồi sinh giao dịch đã xóa.
- [ ] **F09** Worker kiểm tra chủ sở hữu và phạm vi quyền từ dữ liệu tin cậy, không tin `user_id` do client gửi. Thiết kế credential cho job chạy lâu để không phụ thuộc token người dùng đã hết hạn; giới hạn quyền service credential.
- [ ] **F10** Polling hoặc realtime để Flutter nhận trạng thái; khi cloud hỏng/không có mạng cho xác nhận/sửa thủ công. Kết quả AI là gợi ý; không tự thay số tiền, ví hay ngày đã xác nhận.
- [ ] **F11** Rate limit/quota theo người dùng, giới hạn concurrency, chống gọi lại cùng yêu cầu; cache chỉ khi không trộn dữ liệu người dùng/danh mục/prompt version. Theo dõi tỷ lệ fallback, thời gian, token, chi phí và lỗi nhà cung cấp.
- [ ] **F12** Kiểm thử các nhánh local thành công; cloud thành công; 429/timeout; JSON sai; nhãn không hợp lệ; job trùng; sửa/xóa giao dịch khi chờ; hết số lần thử; cách ly người dùng. Có smoke test API thật với bộ dữ liệu đã khử thông tin nhạy cảm.
- [ ] **F13** Đánh giá chất lượng toàn hệ hybrid trên test độc lập: trước/sau fallback, tỷ lệ phải review và chi phí. Giao dịch người dùng sửa chỉ vào tập ứng viên gán nhãn sau kiểm duyệt, không tự động train lại từ output LLM.

Luồng đích: **văn bản → model local → đạt ngưỡng: LOCAL; dưới ngưỡng: job CLOUD_FALLBACK → Gemini → validate → gợi ý kết quả hoặc yêu cầu review → cập nhật có kiểm soát**.

**Hoàn thành khi:** `CLOUD_FALLBACK` có gọi Gemini thật qua job, có trạng thái truy vấn được, chịu được lỗi và không ghi đè lựa chọn người dùng.

## 6. Hoàn thiện Model 2 và dự báo từ dữ liệu thật

- [ ] **P01** Tạo dịch vụ tổng hợp lịch sử hằng ngày theo người dùng/ví, múi giờ và thời điểm dự báo; dựng số dư đầu/cuối ngày từ dữ liệu sổ cái. Phân biệt ngày không giao dịch với dữ liệu bị thiếu.
- [ ] **P02** Loại chuyển ví nội bộ khỏi thu/chi tổng; xử lý số dư đầu kỳ, hoàn tiền, chỉnh số dư, ví lưu trữ và tiền tệ theo quy tắc đã chốt. Thu/chi và số dư phải đối soát được với báo cáo.
- [ ] **P03** Mở rộng input/domain contract gồm chi tiêu thực quan sát và lịch định kỳ. Nhánh flexible hiện nhận lịch sử số dư nhưng vẫn đọc expense từ CSV; thay hoàn toàn đường dữ liệu demo khi chạy production.
- [ ] **P04** Lưu và dùng hồ sơ cố định/linh hoạt, lịch lương, số tiền lương, tiền thuê và nghĩa vụ khác. Thay giả định ngày 5/ngày 30; xử lý ngày 29–31 không có trong tháng/ngày nghỉ theo quy tắc rõ ràng.
- [ ] **P05** Train LightGBM trên nhiều lịch/hồ sơ; version hóa feature schema và preprocessing. Chia theo thời gian và đánh giá thêm trên người dùng chưa thấy; chỉ dùng thông tin đã biết tại thời điểm dự báo.
- [ ] **P06** Rolling-origin backtest cho horizon 7/14/30 ngày; báo cáo one-step riêng với rollout tự hồi quy. So với baseline số dư giữ nguyên, chi trung bình/EWMA và quy tắc thu chi định kỳ.
- [ ] **P07** Báo cáo MAE/RMSE, MAPE có cảnh báo khi số dư gần 0/âm và chỉ số bổ sung như WAPE/MASE khi thích hợp; đo độ đúng và thời điểm phát hiện thiếu tiền, không chỉ sai số số dư lớn.
- [ ] **P08** Đánh giá EWMA/alpha và quy tắc safe-to-spend bằng backtest/kịch bản; xử lý burn bằng 0, số dư âm, thu nhập thất thường và nghĩa vụ sắp đến hạn. Nếu thêm lịch định kỳ vào dự báo, tránh tính cùng khoản hai lần qua model và phần lịch.
- [ ] **P09** Tính khoảng dự báo bằng phương pháp được đánh giá coverage/độ rộng trên backtest nếu giữ yêu cầu dải 95%. Không vẽ dải giả hoặc coi point forecast là khoảng tin cậy.
- [ ] **P10** Cold start cho người mới/chưa đủ lịch sử: dùng kế hoạch đã khai báo hoặc baseline có nhãn rõ, thông báo giới hạn; không sinh dự báo model như thể đã đủ dữ liệu.
- [ ] **P11** Lưu forecast run ID, as-of, model version, input version, horizon, kết quả/cảnh báo. Trigger cập nhật sau thêm/sửa/xóa giao dịch và đổi lịch/hồ sơ, có debounce; tránh kết quả cũ ghi đè run mới.

**Hoàn thành khi:** cả hai nhóm dùng giao dịch thật, đối soát số dư đúng và có backtest nhiều cửa sổ cùng báo cáo baseline.

## 7. Tích hợp AI backend và nhập nhanh văn bản

- [ ] **B01** Đăng ký router AI đúng prefix chung của app; nối dependency với model thật. Không chỉ include router rồi giữ hook `503`; router AI hiện tự mang `/api/v1`, cần kiểm tra tránh lặp prefix.
- [ ] **B02** Khởi tạo model có kiểm soát tại startup/lazy load, giới hạn số bản sao theo worker/RAM, đóng HTTP client khi shutdown; tác vụ CPU nặng không chặn event loop.
- [ ] **B03** Bổ sung settings đường dẫn/model version, cloud key/model/timeout, queue và feature flags. Tách chế độ demo/mock khỏi production; thiếu model/key phải báo khả năng thực tế, không trả giao dịch mock như thật.
- [ ] **B04** Endpoint AI có xác thực, kiểm tra sở hữu, giới hạn kích thước/tần suất, schema response và lỗi rõ ràng. Chuỗi lịch sử chuẩn lấy từ database của người dùng; dữ liệu client gửi dùng cho mô phỏng phải được phân biệt.
- [ ] **B05** Tách extraction với classification: chuẩn hóa tiền, trích số tiền, thu/chi/chuyển ví, nội dung, ngày và gợi ý ví. Câu nhiều khoản/không đủ thông tin chuyển review; không tự đoán số tiền mơ hồ.
- [ ] **B06** Flutter gọi API AI, hiển thị kết quả phân tích và trạng thái nền; màn xác nhận cho sửa tiền, ví, ngày, loại và danh mục trước khi ghi sổ. Nhãn model ánh xạ vào danh mục thật, không dùng tên nhãn làm ID.
- [ ] **B07** Ghi giao dịch qua luồng nghiệp vụ hiện có với idempotency; cập nhật sổ thu chi, số dư, báo cáo, ngân sách và dự báo. Lưu provenance cần thiết mà không ghi nội dung nhạy cảm tràn lan vào log.
- [ ] **B08** Kiểm tra hợp đồng API/Flutter, enum và precision tiền; tài liệu OpenAPI và ví dụ Postman có text, job status, forecast, receipt và lỗi.

**Hoàn thành khi:** nhập một câu thật trong Flutter tạo được bản nháp đúng, người dùng xác nhận và số dư cập nhật đúng.

## 8. Giọng nói offline và hóa đơn

- [ ] **M01** Tích hợp PhoWhisper/sherpa-onnx thật vào Android qua plugin/native bridge phù hợp; ghi âm, xin quyền, chuẩn hóa sample rate/channel và quản lý vòng đời. Python offline trên server không đáp ứng yêu cầu on-device.
- [ ] **M02** Đóng gói/tải gói ASR có version/checksum, bảo đảm lần nhận dạng offline có đủ artifact. Nối transcript → chuẩn hóa tiền → extraction/classification → màn xác nhận; ghi rõ bước nào vẫn cần backend.
- [ ] **M03** Đo WER, độ đúng số tiền/thực thể, latency, RTF, RAM và dung lượng trên điện thoại đích. Chạy chế độ máy bay để kiểm chứng ASR offline; xử lý im lặng, audio dài và quyền bị từ chối.
- [ ] **M04** Flutter chụp/chọn ảnh, xoay/cắt/nén phù hợp; endpoint multipart có giới hạn kích thước, định dạng thực và xử lý ảnh lỗi. Xác thực và cách ly dữ liệu ảnh nếu lưu trữ.
- [ ] **M05** Nối Qwen thật qua job bất đồng bộ, kiểm tra JSON/nghiệp vụ và tổng tiền bằng Python. Hỗ trợ giảm giá, thuế, phí, làm tròn và trường thiếu theo schema; không sửa tổng hóa đơn để ép khớp dòng hàng.
- [ ] **M06** Hiển thị ảnh/kết quả để sửa và xác nhận; chống tạo trùng khi upload/retry. Chốt một hóa đơn tạo một giao dịch hay nhiều giao dịch chia danh mục, giữ quan hệ nguồn.
- [ ] **M07** Đánh giá field accuracy/exact match tổng tiền, chất lượng ảnh mờ/nghiêng, latency và chi phí API thật. Timeout/lỗi trả trạng thái review/nhập thủ công, không dùng mock thay thành công.

**Hoàn thành khi:** có luồng voice và receipt thật trên điện thoại với số đo chất lượng riêng, không chỉ test bằng mock.

## 9. Cảnh báo, Gemini Advisor và hội thoại

- [ ] **A01** Tạo cảnh báo từ kết quả Model 2/ngân sách/nghĩa vụ đến hạn; chống cảnh báo trùng, xác định mức độ, thời hạn hiệu lực, đã đọc/đã xử lý và điều kiện phát lại.
- [ ] **A02** Gọi Gemini Advisor bằng snapshot chỉ số đã tính và ngữ cảnh tối thiểu; prompt riêng cho thu nhập cố định/linh hoạt, có version, timeout và lời khuyên cục bộ khi lỗi.
- [ ] **A03** Kiểm tra lời khuyên không sửa số dư, runway, cờ rủi ro hoặc bịa số liệu. Các phép tính tài chính vẫn do Python/Model 2 thực hiện; hiện rõ thời điểm dữ liệu.
- [ ] **A04** Lưu consultation liên kết forecast/snapshot/model version; hiển thị trên màn dự báo và đánh dấu lời khuyên cũ khi dữ liệu thay đổi.
- [ ] **A05** Nếu bàn giao tính năng chat: làm màn hội thoại và API sinh câu trả lời thật, giới hạn lịch sử/token, cách ly phiên và chống request trùng. CRUD session/message hiện có chưa phải trợ lý trò chuyện.
- [ ] **A06** Kiểm thử chất lượng tư vấn theo bộ tình huống, tính bám dữ liệu và lỗi dịch vụ; đo chi phí/latency riêng với phân loại fallback và VLM.

## 10. Onboarding, xác thực và tùy chọn ứng dụng

- [ ] **U01** Onboarding chọn nhóm thu nhập, ví/số dư đầu kỳ, lịch lương/tiền nhà, ngân sách và các khoản bắt buộc; cho sửa sau và giải thích dữ liệu cần để dự báo.
- [ ] **U02** Thêm migration/API/UI cho hồ sơ thu nhập và cấu hình còn thiếu; hồ sơ hiện có chưa đủ thể hiện toàn bộ hai phân khúc trong đặc tả.
- [ ] **U03** Hoàn thiện xác nhận email, quên/đổi mật khẩu, deep link, session refresh/hết hạn và đăng xuất an toàn. Thêm Google/Apple Sign-In theo nền tảng đã chốt nếu giữ FR1.
- [ ] **U04** Nếu giữ Guest Mode: dùng anonymous auth hoặc định danh có bảo vệ phù hợp, cách ly dữ liệu và chuyển sang tài khoản thật; không dùng Device UUID làm bí mật xác thực.
- [ ] **U05** Áp dụng dark mode thật; nếu giữ sinh trắc học thì tích hợp khóa/mở ứng dụng, fallback và lifecycle. Giá trị lưu trong profile không tự bật được chức năng thiết bị.
- [ ] **U06** Optimistic UI cho thao tác phù hợp với rollback khi lưu thất bại, chống bấm lặp, trạng thái chờ đồng bộ và cập nhật nhất quán giữa màn hình. Chốt mục tiêu 50ms/100ms đang được mô tả khác nhau.
- [ ] **U07** Hoàn thiện empty/loading/error/retry cho luồng mới; kiểm tra responsive, bàn phím, cỡ chữ lớn, định dạng tiền/ngày và khả năng truy cập.
- [ ] **U08** Nếu giữ offline ledger/SQLCipher: thiết kế cache mã hóa, key management, outbox đồng bộ, xử lý xung đột và xóa dữ liệu khi đăng xuất; tách rõ nhập thủ công offline với AI/cloud cần mạng.

## 11. Tác vụ định kỳ và thông báo

- [ ] **J01** Tạo worker nghiệp vụ và scheduler như Celery Beat; hiện worker mới đăng ký task health. Triển khai lịch sinh giao dịch, forecast và cảnh báo theo múi giờ người dùng.
- [ ] **J02** Quy tắc lịch định kỳ: ngày cuối tháng, tạm dừng, chỉnh lịch, chạy bù, ví lưu trữ và thiếu dữ liệu tham chiếu; unique key mỗi lịch/kỳ để chạy lại không tạo trùng.
- [ ] **J03** Tạo giao dịch và cập nhật kỳ tiếp theo nhất quán/atomic; nếu lỗi có thể phục hồi. Lịch tương lai dùng cho dự báo không được tính hai lần khi đã trở thành giao dịch thật.
- [ ] **J04** Local notification cho nhắc ghi chép và push khi cần cảnh báo từ server; xin quyền, quản lý token/thiết bị, múi giờ, cài đặt tắt và deeplink đến đúng màn.
- [ ] **J05** Theo dõi queue length, tuổi job, số lần thử, lỗi cuối và worker heartbeat; cơ chế retry/replay có kiểm soát và thông báo không bị gửi lặp.

## 12. Hoàn thiện nghiệp vụ tài chính và tiện ích

- [ ] **N01** Chốt liên hệ tiết kiệm/nợ với ví: đóng góp/rút tiết kiệm, vay/cho vay, trả/thu nợ có giao dịch và liên kết đối soát; hỗ trợ thanh toán một phần, hủy/sửa đúng ảnh hưởng số dư. Nếu chỉ là theo dõi thủ công phải ghi rõ trong sản phẩm.
- [ ] **N02** Rà soát ngân sách trùng/chồng lấn, danh mục cha-con, thu/chi/chuyển ví và tổng tài sản; không cộng lặp hạn mức hoặc tính chuyển ví là chi tiêu. Quy tắc đa tiền tệ phải theo S06.
- [ ] **N03** Kiểm tra tính nhất quán khi sửa/xóa giao dịch, sửa số dư ví, lưu trữ ví, đổi danh mục và nạp trang dữ liệu lớn. Trigger/RPC/database transaction phải là nguồn cập nhật số dư thống nhất.
- [ ] **N04** Nếu giữ xuất dữ liệu: Excel/CSV/PDF theo bộ lọc/múi giờ, số liệu khớp báo cáo; có chia sẻ/lưu file và xử lý lỗi.
- [ ] **N05** Nếu giữ sao lưu Google Drive: kết nối tài khoản, phạm vi quyền tối thiểu, version file/checksum và thử khôi phục không tạo bản ghi trùng. Phân biệt sao lưu người dùng với backup database vận hành.
- [ ] **N06** Thiết kế xuất/xóa dữ liệu cá nhân và chính sách lưu/xóa ảnh/audio/nội dung cloud; không lưu raw media vô thời hạn mặc định.

## 13. Database, bảo mật và hạ tầng AI

- [ ] **I01** Migration cho hồ sơ thu nhập, job/outbox, metadata AI, forecast runs, thông báo và liên kết nghiệp vụ cần thiết; có index/constraints, RLS cho mọi bảng và policy storage riêng tư nếu dùng.
- [ ] **I02** Test quyền người dùng cho API/database/job/media và các quan hệ tham chiếu; service key chỉ ở server, secret không nằm trong APK/notebook/Git/log. Giới hạn input, upload và tần suất gọi AI.
- [ ] **I03** Chính sách tối thiểu hóa dữ liệu gửi Gemini/Qwen, mã hóa truyền/lưu phù hợp; thông tin thiết lập quyền riêng tư phải khớp nơi thực sự xử lý dữ liệu.
- [ ] **I04** Docker cho API/worker/inference cài đúng dependencies; cung cấp model qua image, volume hoặc tải artifact có checksum. Image hiện chỉ copy requirements/app nên chưa mang đủ gói inference/checkpoint/cache.
- [ ] **I05** Ghim môi trường inference tương thích artifact; kiểm thử cài từ máy sạch. Không nạp pickle không tin cậy; artifact có nguồn, version và checksum kiểm tra được.
- [ ] **I06** Triển khai API, Redis, worker, scheduler và Supabase với tài nguyên phù hợp model/RAM/concurrency; môi trường staging riêng và kế hoạch chi phí. Render blueprint CRUD hiện chưa đủ vận hành các job AI.
- [ ] **I07** Tách liveness và readiness; readiness phản ánh dependency/model bắt buộc. Structured log có request/job ID, metrics latency/error/queue/model version và che nội dung tài chính nhạy cảm.
- [ ] **I08** Backup database và thử restore; hướng dẫn migration, rollback app/model và xử lý migration không đảo ngược. Có cảnh báo lỗi dịch vụ, quota và chi phí cloud.

## 14. Kiểm thử, benchmark và tiêu chí nghiệm thu

Rà soát 17/10/2026: đã bổ sung Postman regression, Java `IngestionIT` và workflow Flutter analyze/test/build debug; xem [hướng dẫn và khoảng trống kiểm thử](TESTING.md), [issue #21](https://github.com/Drista4real/Project1/issues/21). Chưa đánh dấu hoàn tất T01–T06 vì còn device E2E, queue/model/load và kết quả chạy integration trên Actions.

- [ ] **T01** Kế thừa test hiện có; bổ sung unit cho parser/tiền/lịch, lựa chọn model, fallback state machine và quy tắc forecast; integration với database/queue cho idempotency, cân bằng số dư và cách ly người dùng.
- [ ] **T02** Contract/API/Flutter tests cho AI; E2E thực sự từ nhập liệu → review → lưu → số dư/báo cáo → forecast → cảnh báo. Mock xác minh logic, benchmark model và smoke test cloud thật xác minh tích hợp/chất lượng riêng.
- [ ] **T03** Kiểm thử mất mạng, token hết hạn, worker chết giữa task, Redis/cloud unavailable, request trùng và phản hồi lệch thứ tự; không mất giao dịch hoặc ghi đè sửa tay.
- [ ] **T04** CI chạy lint/Python tests, Java E2E hiện có, Flutter analyze/tests và kiểm tra build Android. Benchmark nặng/cloud có workflow riêng để kiểm soát thời gian, secrets và chi phí.
- [ ] **T05** Benchmark CPU/điện thoại/infrastructure đích, gồm model warm/cold, queue và end-to-end; load test workload đại diện, phân biệt CRUD với AI. So mục tiêu 500 RPS và 300 người đồng thời trong cấu hình công bố, không ngoại suy từ máy khác.
- [ ] **T06** Lập bảng PASS/FAIL/chưa đo cho từng NFR. Mục tiêu dưới đây là yêu cầu hiện ghi trong đặc tả, chưa phải cam kết đã đạt; nếu thay đổi phải cập nhật phạm vi và lý do trước nghiệm thu.

| Hạng mục | Mục tiêu hiện có cần đo/đối chiếu |
| --- | --- |
| Phân loại local | Macro F1 ≥88%; tỷ lệ local ≥75% tại ngưỡng 0,8; thêm độ đúng trên phần được chấp nhận local |
| Latency local CPU | <15ms toàn pipeline theo định nghĩa đo thống nhất; audit hiện khoảng 76,56ms trung bình |
| Forecast 30 ngày | MAE <300.000 VND, MAPE <10%; thêm baseline, số dư thấp và chất lượng cảnh báo |
| ASR trên thiết bị | WER <6%, RTF <0,2 và latency câu 3 giây ≤350ms; đo riêng mỗi chỉ số |
| Hóa đơn | ≤1.600ms theo phạm vi đo thống nhất; bổ sung độ đúng trường/số tiền và chi phí |
| UI | Chốt <50ms hay <100ms cho cập nhật lạc quan; xác minh rollback và tính nhất quán |
| Chịu tải | 500 RPS và 300 người đồng thời, mục tiêu 0% HTTP 5xx trong bài test xác định |
| Model trên thiết bị | Xác định áp dụng cho gói nào: INT8, dung lượng nén <100MB, RAM <300MB; tính cả runtime khi đánh giá RAM |
| Cấu trúc đầu ra | Không nhận/ghi kết quả vi phạm schema; thống kê lỗi/ retry thật, không coi validation là bảo đảm model không sinh JSON sai |

## 15. Đóng gói, bàn giao và vòng lặp cải thiện model

- [ ] **R01** Build APK release bằng URL HTTPS thật, khóa ký được sao lưu, version tăng đúng và application ID được chốt; hoàn thiện icon/tên app/quyền thiết bị theo tính năng đã triển khai.
- [ ] **R02** Cài và kiểm tra trên điện thoại thật: tài khoản mới/cũ, xác thực, text/voice/receipt, định kỳ, thông báo, forecast và phục hồi sau lỗi. Nếu phát hành web/iOS, nghiệm thu riêng nền tảng và đăng nhập/deep link tương ứng.
- [ ] **R03** Xác minh migration trên môi trường đích, readiness, API/worker/model version; chuẩn bị APK/model trước để rollback, release notes và hướng dẫn vận hành.
- [ ] **R04** Bàn giao notebook Colab chạy được, script/config, dataset manifest/split, model card, báo cáo experiment/benchmark, API docs và kịch bản demo; không chỉ bàn giao file checkpoint.
- [ ] **R05** Lưu phản hồi sửa nhãn vào tập chờ kiểm duyệt có quyền sử dụng; theo dõi drift, tỷ lệ fallback, lỗi theo lớp và chi phí. Chỉ phát hành model mới sau đánh giá trên bộ test được quản lý và có rollback.
- [ ] **R06** Cập nhật audit sau khi train/tích hợp: model nào thực sự được train, dataset/run nào, kết quả nào đo thật, tính năng nào hoạt động trên bản phát hành; giữ audit cũ làm lịch sử.

## Thứ tự triển khai và các mốc bàn giao

| Mốc | Nhóm công việc chính | Điều kiện bàn giao |
| --- | --- | --- |
| 1. Hợp đồng và dữ liệu | S, D, thiết kế migration I01 | Phạm vi, taxonomy, split và input forecast thống nhất |
| 2. Training có thể tái lập | C, L; P05–P09 | Colab chạy/resume được; có LoRA, baseline và báo cáo; gói model nạp trên CPU |
| 3. AI dùng được trong app | B, F; P01–P04/P10–P11; U01–U02 | Nhập text → review → lưu; fallback thật; dự báo dữ liệu thật |
| 4. Luồng sản phẩm đầy đủ | M, A, U, J, N | Voice/receipt, tư vấn, onboarding, định kỳ và tiện ích theo phạm vi |
| 5. Vận hành và phát hành | I, T, R | Nghiệm thu có bằng chứng, hạ tầng thật và APK ký release |

Thiết kế API/job và UI có thể tiến hành với baseline hiện tại trong lúc chuẩn bị dữ liệu/LoRA. Tích hợp model cuối sau khi vượt qua kiểm tra artifact; không cần chờ mọi thử nghiệm kết thúc mới bắt đầu nối app. Các nhóm I và T được thực hiện xuyên suốt, không dồn toàn bộ đến mốc 5.

**Kịch bản nghiệm thu xuyên suốt:** tạo tài khoản/onboarding → thiết lập ví và lịch thu nhập → nhập câu/giọng nói/hóa đơn → xem và sửa bản nháp → xác nhận một lần → số dư/ngân sách/báo cáo khớp → câu khó được fallback và không ghi đè sửa tay → dự báo 7/14/30 ngày từ dữ liệu thật → cảnh báo và lời khuyên → định kỳ/thông báo hoạt động → ứng dụng vẫn giữ đúng dữ liệu khi mạng hoặc cloud lỗi.
