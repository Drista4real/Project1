# Model 1 — 200 câu kiểm tra synthetic độc lập, ngày 18/10/2026

Ngày 18/10/2026, người dùng chốt nguyên văn 11 cặp câu/nhãn thuộc các lỗi
LoRA của lần đánh giá `teacher200_20261018T085405Z_a718e769`.
Quyết định lưu tại `annotation_approved_20261018.csv`, theo dõi issue #36:
https://github.com/Drista4real/Project1/issues/36 . Các nhãn được xác nhận giữ
nguyên so với CSV gốc, nên không thay đổi điểm đánh giá (LoRA đúng 189/200).
Phê duyệt chỉ áp dụng cho 11 cặp cụ thể; 189 câu còn lại chưa được người dùng
duyệt trong quyết định này. Nguồn câu vẫn là synthetic; đây là xác nhận của
người dùng sau khi xem lỗi, không phải kiểm duyệt độc lập trước đánh giá.
Không thêm các câu này vào train. CSV 200 câu, audit và ZIP bàn giao ban đầu
được giữ nguyên để đối chiếu. File duyệt này chưa được upload lên Drive.

Theo dõi: https://github.com/Drista4real/Project1/issues/35

`transactions.csv` có hai cột `text,category`, UTF-8: 34 câu Ăn uống,
34 câu Đi lại và 33 câu mỗi nhãn Mua sắm, Hóa đơn/Nhà ở, Y tế, Khác.
CSV không có cột ID hay chú thích để dễ đưa vào công cụ đánh giá.

Teacher là trợ lý Codex trong phiên hội thoại này, sinh trực tiếp câu và nhãn
cứng theo yêu cầu người dùng. Đây là dữ liệu synthetic do AI gán nhãn, chưa
được con người kiểm duyệt độc lập. Không có teacher API bên ngoài, logits,
soft targets hay bước tối ưu distillation loss. Tên phiên bản model teacher
không được suy đoán hoặc ghi như một thông tin đã xác minh.

Đây là bước teacher sinh dữ liệu có nhãn, có thể phục vụ chưng cất bằng nhãn
cứng nếu sau này được dùng để train. Trong lần bàn giao này dữ liệu được giữ
riêng để kiểm tra hai student đã train, không phải một lượt chưng cất đã chạy.

Nhãn theo `data/taxonomy/expense_categories.v3_user_review.json`. Hàng hóa hoặc
dịch vụ cụ thể ưu tiên hơn tên ứng dụng: GrabFood mua cơm là Ăn uống; GrabCar
chở người là Đi lại. `bao bb` dùng mặc định Khác đã được người dùng duyệt.
Các câu chủ động nêu mục đích; không tự ép thu nhập, vay nợ hoặc chuyển ví
vào một trong sáu nhãn chi tiêu. Có câu thiếu dấu và viết tắt để thử độ bền.

`audit.json` ghi hash file, phân bố nhãn và so sánh với CSV gộp 6.000 dòng.
Kiểm tra trùng theo NFC/chữ thường/khoảng trắng và khóa bỏ dấu/che số tiền;
đồng thời dò gần trùng SequenceMatcher ở ngưỡng 0,9. Các kiểm tra này không
chứng minh độc lập về ngữ nghĩa hay tính đúng của nhãn. Câu mới được sáng tác
không dựa trên lỗi dự đoán hoặc confidence của hai student.

Chạy lại audit từ thư mục gốc dự án:

```powershell
python data/evaluation/model1_teacher_eval_200_20261018/audit.py
```

Đánh giá cả hai mô hình trên cùng `transactions.csv`, lưu nhãn dự đoán,
confidence và nhãn teacher để so sánh. Duyệt lại các câu bất đồng trước khi
kết luận mô hình sai. Không dùng điểm trên bộ synthetic này để tuyên bố độ
chính xác trên giao dịch người dùng thực tế.

Giữ nguyên bộ train/validation/test hiện có. Không thêm 200 câu này vào train
nếu vẫn dùng chúng để báo cáo kiểm tra. Nếu dùng kết quả để sửa dữ liệu hoặc
chọn cấu hình thì coi đây là bộ kiểm tra phát triển, không còn là holdout
cuối cùng; cần một tập đánh giá khác chưa dùng để điều chỉnh.
