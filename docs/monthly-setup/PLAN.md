# Kế hoạch tính năng: Thiết lập kế hoạch tháng (Monthly Setup)

- Nhánh: `feature/monthly-setup` (tách từ `develop`)
- Ngày lập: 2026-11-12
- Trạng thái: **Chờ duyệt**. Chưa viết code, chưa vẽ Figma.
- Độ phức tạp: Trung bình, ước tính 10–14 giờ.
- Liên quan: `docs/SPECIFICATION.md` (FR1, §3.1 Onboarding Flow, §4 dòng "Onboarding Form"), `docs/APP_COMPLETION_CHECKLIST.md` (U01), ADR 0009 (engine ngân sách cố định), ADR 0010 (trang chủ chatbot).

## 1. Mục tiêu

Khi đăng nhập lần đầu, người dùng đi qua vài bước thiết lập ngắn. Từ số tiền đang có, các khoản cố định và mục tiêu tiết kiệm, hệ thống tính ra mỗi ngày được chi bao nhiêu cho tới lần nhận thu nhập cố định tiếp theo.

Mỗi con số đều do engine tính toán cố định có sẵn tính ra (ADR 0009). Mô hình ngôn ngữ không tham gia tính tiền.

### Phạm vi đã chốt

| # | Quyết định | Nguồn |
|---|---|---|
| 1 | **Giữ nguyên** 3 câu hỏi gợi ý nhanh của chatbot ("Phân bổ ngân sách tháng", "Tiết kiệm tiền như thế nào?", "Kiểm tra số dư hiện tại"). Chatbot không đổi gì. | Trả lời câu 1 |
| 2 | Kế hoạch kéo dài **tới ngày có thu nhập cố định tiếp theo**. | Trả lời câu 2 |
| 3 | Lần đầu đăng nhập thì bộ thiết lập **tự mở**, có nút **Bỏ qua**. Trang chủ luôn có nút để mở lại khi cần. | Trả lời câu 3 |
| 4 | Trang xem kế hoạch chi tiêu là **lịch tháng giống màn 03 (Sổ thu chi)**, mỗi ô ngày hiện số tiền đã chi của ngày đó. | Yêu cầu khi duyệt Figma |

### Khớp với đặc tả hiện có

Tính năng này hiện thực các bước 3–5 của `SPECIFICATION.md` §3.1 và một phần U01:
- **Bước 3 – Phân loại dòng tiền:** hỏi "có thu nhập cố định không" ở bước 2 của bộ thiết lập.
- **Bước 4 – Số dư ví:** bước 1 của bộ thiết lập, điền sẵn từ số dư các ví.
- **Bước 5 – Biến định kỳ:** bước 2 và 3 (ngày thu nhập, các khoản cố định).

Không làm trong nhánh này: 3 thẻ giới thiệu (bước 1), ghi chép thử (bước 6), dashboard dự báo (bước 7).

### Ngoài phạm vi (chưa làm)

- Thẻ "Hôm nay còn X ₫" và dải 7 ngày trên trang chủ (kiểu home của Mealbird). Có thể làm sau, xem mục 10.
- Thay đổi chatbot, công cụ `create_budget_plan` hay cách chatbot hỏi gom nhóm câu hỏi.
- Lưu loại hồ sơ dòng tiền (cố định / linh hoạt) vào DB, thông báo đẩy, chuỗi ngày (streak).

## 2. Tham khảo Mealbird

Mealbird (mealbird.app) là ứng dụng lập thực đơn, không phải app tài chính. Cái mượn ở đây là **cách thiết lập**:

1. **Hỏi theo bước ngắn, có tiến trình.** Mealbird hỏi lần lượt: mục tiêu → cơ thể → cửa hàng và ngân sách → chế độ ăn → mức lặp món.
2. **Cho xem con số trước khi cam kết.** "You see targets before paying": người dùng thấy mục tiêu đã tính rồi mới bắt đầu.
3. **Kết quả kiểm tra được.** Mỗi ngày trong tuần đều đạt mục tiêu ("a week that checks out"), có ghi rõ cách tính ("How we compute this").

Ánh xạ sang Kakeibo Zen:

| Mealbird | Kakeibo Zen |
|---|---|
| Mục tiêu và cơ thể | Số tiền đang có, ngày thu nhập tiếp theo |
| Ngân sách đi chợ theo tuần | Các khoản chi cố định, mục tiêu tiết kiệm |
| Chế độ ăn, mức lặp món | Kiểu chi tiêu (tỉ lệ nhóm ăn uống / đi lại / sinh hoạt) |
| Xem mục tiêu trước khi trả tiền | Màn **Xem trước**: hạn mức mỗi ngày, mức sàn, chia nhóm, trước khi bấm "Bắt đầu" |
| "How we compute this" | Dòng giải thích công thức ngay trên màn xem trước |

## 3. Luồng người dùng

```
Đăng nhập ──► Trang chủ chatbot
                 │
                 ├─ Lần đầu và chưa có kế hoạch nào ──► tự mở bộ thiết lập
                 │                                        ├─ Bỏ qua ──► về trang chủ (không tự mở nữa)
                 │                                        └─ Hoàn tất ──► tạo kế hoạch ──► màn Kế hoạch chi tiêu
                 │
                 └─ Nút "Thiết lập kế hoạch tháng" (luôn có) ──► bộ thiết lập
```

### Các bước

| Bước | Câu hỏi | Điền sẵn từ | Ô dữ liệu của engine |
|---|---|---|---|
| 1 | **Bạn đang có bao nhiêu tiền?** Ô số tiền, kèm chip nhanh 3tr / 5tr / 10tr | Tổng `accounts.balance` của các ví | `total_income` |
| 2 | **Bạn có thu nhập cố định không?** Có → chọn ngày thu nhập tiếp theo. Không → mặc định 30 ngày. Luôn hiện "Kế hoạch dài N ngày". | Xem quy tắc mục 4 | `duration_days`, `start_date` = hôm nay |
| 3 | **Khoản chi cố định đến hạn trước ngày đó.** Chọn nhiều (tiền nhà, điện nước, internet, học phí, trả nợ, khác), mỗi khoản có số tiền và ô "Đã trả" | `recurring_transactions` loại chi, đến hạn trong khoảng kế hoạch | `fixed_expenses` (tổng các khoản chưa trả) |
| 4 | **Muốn để dành bao nhiêu?** Chip 0 / 10% / 20% / tự nhập | `profiles.monthly_savings_target` | `savings_target` |
| 5 | **Kiểu chi tiêu.** Tiết kiệm (70/15/15), Cân bằng (60/15/25, mặc định), Thoải mái (50/15/35) | — | `group_ratios` |
| 6 | **Xem trước.** Hạn mức mỗi ngày, tổng được chi, mức sàn, chia theo nhóm, công thức. Nút "Bắt đầu kế hoạch" | API xem trước (mục 5) | Tạo kế hoạch |

Tỉ lệ ở bước 5 theo thứ tự ăn uống / đi lại / sinh hoạt, khớp `GroupRatios` (food / transport / lifestyle).

Khi bấm "Bắt đầu kế hoạch":
1. Tạo kế hoạch qua `POST /api/v1/budget-plans`, có `idempotency_key` để bấm hai lần không tạo trùng.
2. Lưu lại `monthly_savings_target` vào hồ sơ nếu người dùng đã đổi.
3. Chuyển sang màn Kế hoạch chi tiêu (`/plan`).

Mỗi bước có nút **Quay lại** và **Tiếp tục**. Thanh trên cùng có nút **Bỏ qua** và thanh tiến trình 1/6 … 6/6.

## 4. Quy tắc tính "ngày thu nhập cố định tiếp theo"

Lấy theo thứ tự ưu tiên:

1. `next_execution_date` nhỏ nhất (từ ngày mai trở đi) trong các `recurring_transactions` có `transaction_type = 'income'` và `is_active = true`.
2. Nếu không có: lần tới của `profiles.payroll_day`. Nếu tháng đó ít ngày hơn thì lấy ngày cuối tháng (ví dụ ngày 31 thành 30/11).
3. Nếu không có gì, hoặc người dùng chọn "Không có thu nhập cố định": hôm nay + 30 ngày.

Từ đó: `duration_days = ngày thu nhập − hôm nay`, giới hạn trong khoảng 1–365 theo engine.

Người dùng luôn sửa được ngày này ở bước 2. Nguồn được ghi rõ dưới ô ngày, ví dụ "Theo khoản thu định kỳ: Lương" hoặc "Theo ngày nhận lương trong hồ sơ".

> **Cần duyệt:** nếu thu nhập tiếp theo chỉ còn ≤ 3 ngày (ví dụ lương về ngày mai), kế hoạch sẽ rất ngắn. Đề xuất: khi đó **mặc định lấy kỳ thu nhập sau nữa** và hiện ghi chú, người dùng vẫn chọn lại được.

## 5. Thay đổi backend

Code tiền tệ mới: không có. Chỉ dùng lại `compute_plan_totals` ([backend/app/domain/budget_plan.py](../../backend/app/domain/budget_plan.py)) và `BudgetPlanService` ([backend/app/application/budget_plan.py](../../backend/app/application/budget_plan.py)).

| Endpoint | Mô tả |
|---|---|
| `POST /api/v1/budget-plans/preview` *(mới)* | Nhận đúng `BudgetPlanCreateInput`, trả về `PlanTotals` (số tiền được chi, hạn mức mỗi ngày, mức sàn, các nhóm). **Không ghi gì vào DB.** Số tiền được chi ≤ 0 thì trả 422 giống lúc tạo. |
| `GET /api/v1/budget-plans/setup-defaults` *(mới)* | Trả `{ available_balance, next_income_date, next_income_source, fixed_expenses: [{description, amount, next_date}], monthly_savings_target, has_plans }`. Đọc ví, giao dịch định kỳ và hồ sơ của **chính người đăng nhập**. |
| `POST /api/v1/budget-plans` *(giữ nguyên)* | Dùng để tạo kế hoạch ở bước cuối. |

- Quy tắc ở mục 4 viết thành một **hàm thuần** trong `app/domain/budget_plan.py`: nhận `today`, danh sách ngày thu định kỳ và `payroll_day`, không đụng DB, nên test được trực tiếp.
- Đọc dữ liệu qua repository Supabase hiện có (`account_totals.py`, `management.py`). Phân quyền theo hàng (RLS) và `user_id` phía server như các endpoint khác.

## 6. Thay đổi frontend

| File | Việc |
|---|---|
| `frontend/lib/features/onboarding/cubit/monthly_setup_cubit.dart` *(mới)* | Giữ câu trả lời, bước hiện tại, kết quả xem trước, trạng thái gửi và lỗi |
| `frontend/lib/features/onboarding/screens/monthly_setup_screen.dart` *(mới)* | `PageView` 6 bước, thanh tiến trình, Bỏ qua / Quay lại / Tiếp tục |
| `frontend/lib/features/onboarding/widgets/*.dart` *(mới)* | Mỗi bước một widget, dùng lại kiểu chip và nút của app |
| `frontend/lib/features/onboarding/data/monthly_setup_prefs.dart` *(mới)* | Ghi nhớ "đã tự mở" theo `user_id` |
| `frontend/lib/features/plan/data/budget_plan_repository.dart` | Thêm `preview()`, `create()`, `setupDefaults()` theo mẫu `BackendClient` hiện có |
| `frontend/lib/app/app_routes.dart`, `app_router.dart` | Thêm route `/monthly-setup` |
| `frontend/lib/features/chat/screens/chat_home_screen.dart` | Thêm nút "Thiết lập kế hoạch tháng" vào trạng thái trống, **3 câu gợi ý giữ nguyên**. Thêm logic tự mở lần đầu. |
| `frontend/lib/features/plan/screens/plan_screen.dart`, `plan_widgets.dart` | Đổi phần thân thành **lịch tháng** (bố cục giống lịch ở `ledger_screen.dart`): mỗi ô ngày hiện số tiền đã chi (`actual_spent` từ `/budget-plans/{id}/allocations`); nền xanh nếu trong hạn mức, cam nếu vượt; ngày chưa tới hiện hạn mức dự kiến bằng chữ mờ; ngày ngoài kỳ kế hoạch bị làm mờ. Chạm một ngày thì xem chi tiết ngày đó bên dưới. |

### Trang kế hoạch dạng lịch

- **Thẻ trên cùng:** khoảng ngày, "Ngày X/N", số tiền còn lại của cả kỳ, số còn được chi hôm nay, thanh tiến độ.
- **Lịch:** chuyển tháng được, vì kỳ có thể vắt qua hai tháng (12/11 – 05/12).
- **Chi tiết ngày đang chọn:** đã chi / hạn mức và danh sách giao dịch của ngày đó.
- **Dữ liệu:** dùng lại endpoint allocations sẵn có. Cộng các nhóm theo `alloc_date` để có hạn mức và đã chi của từng ngày, nên không cần API mới.

### Nhận biết "lần đầu đăng nhập"

Bộ thiết lập chỉ tự mở khi **cả hai** điều kiện đúng:

1. `setup-defaults.has_plans == false`: người dùng chưa từng có kế hoạch nào.
2. Trên máy này chưa có cờ `monthly_setup_prompted_<user_id>`.

Cờ được ghi ngay lúc tự mở. Vì vậy bấm Bỏ qua hay đóng app giữa chừng thì lần sau cũng không tự mở lại; người dùng vẫn mở được bằng nút ở trang chủ. Cờ dùng `shared_preferences`, gói này đã có trong `pubspec.yaml`, nên **không cần migration**.

> **Cần duyệt:** cờ lưu trên máy nên khi cài lại app hoặc đổi máy, nếu vẫn chưa có kế hoạch thì bộ thiết lập tự mở thêm một lần. Muốn tuyệt đối "chỉ một lần" thì cần thêm cột `profiles.setup_prompted_at` (một migration nhỏ).

### Tài khoản khách

Khách vẫn dùng được thiết lập, vì backend cần mạng giống chatbot. Nếu mất mạng: hiện lỗi và nút "Thử lại", bỏ qua bước điền sẵn và cho nhập tay.

## 7. Thiết kế Figma (giai đoạn 1)

File: https://www.figma.com/design/iduQKxOtAXjFKMMD4j8j23

Section **"Tính năng: Thiết lập kế hoạch tháng"** — **đã vẽ xong 2026-11-12**, chờ duyệt. Dùng lại các component và biến màu đã có:

| Khung | Nội dung |
|---|---|
| S1 · Số tiền hiện có | Ô số tiền điền sẵn từ ví, chip 3tr / 5tr / 10tr |
| S2 · Thu nhập cố định | Chọn Có / Không, ngày thu nhập tiếp theo, nguồn ngày, "Kế hoạch dài 23 ngày" |
| S3 · Khoản chi cố định | Danh sách chọn nhiều, khoản "Đã trả" bị gạch, tổng cần trả |
| S4 · Mục tiêu tiết kiệm | Chip 0 / 10 / 20% / Tự nhập, bảng tạm tính |
| S5 · Kiểu chi tiêu | 3 thẻ Tiết kiệm / Cân bằng / Thoải mái kèm thanh tỉ lệ |
| S6 · Xem trước | Hạn mức mỗi ngày, mức sàn, chia nhóm, cách tính, nút "Bắt đầu kế hoạch" |
| S6b · Xem trước – không đủ tiền | Báo thiếu tiền, gợi ý sửa, nút Bắt đầu bị khóa |
| H · Trang chủ | Thẻ "Thiết lập kế hoạch tháng" phía trên 3 câu gợi ý (giữ nguyên) |
| K · Kế hoạch chi tiêu – dạng lịch | Lịch tháng giống màn 03, mỗi ô ngày hiện số đã chi, chi tiết ngày đang chọn |

Số liệu mẫu: có 8.000.000 ₫, lương về 05/12 (23 ngày), chi cố định 3.100.000 ₫, để dành 10%. Kết quả: được chi 4.100.000 ₫, tức 178.261 ₫ mỗi ngày, mức sàn 134.783 ₫ mỗi ngày.

Bạn duyệt thiết kế xong mới sang giai đoạn 2.

## 8. Các giai đoạn và kiểm thử

| Giai đoạn | Nội dung | Kiểm chứng |
|---|---|---|
| 1. Figma | 8 khung như mục 7 | Bạn duyệt trên Figma |
| 2. Backend | Hàm tính ngày thu nhập, 2 endpoint mới | `pytest backend/tests`: tính ngày (có thu định kỳ, chỉ có payroll_day, ngày 31, không có gì, ≤ 3 ngày); xem trước khớp tạo thật; 422 khi được chi ≤ 0; preview không ghi DB; chỉ đọc dữ liệu của chính người dùng |
| 3. Frontend | Cubit, màn 6 bước, nút trang chủ, tự mở lần đầu | `flutter analyze`; `flutter test`: cubit (cộng khoản cố định, bỏ khoản đã trả, % tiết kiệm, khóa nút khi được chi ≤ 0), widget bộ thiết lập, `chat_home_screen_test` (vẫn còn 3 câu gợi ý, có nút mới, tự mở đúng một lần) |
| 4. Chạy thật | Đăng nhập tài khoản thử, đi hết luồng, đối chiếu kết quả ở màn Kế hoạch | Ảnh chụp từng bước |
| 5. Tài liệu | ADR 0011 (thiết lập lần đầu và cờ trên máy), thêm "Monthly setup" vào `GLOSSARY.md`, đánh dấu tiến độ U01 | Review PR vào `develop` |

## 9. Rủi ro

| Rủi ro | Mức | Cách xử lý |
|---|---|---|
| Chi cố định + tiết kiệm ≥ số tiền có, nên số tiền được chi ≤ 0 | Cao | Màn xem trước báo đỏ, khóa "Bắt đầu", gợi ý giảm tiết kiệm hoặc bỏ bớt khoản cố định |
| Mức sàn mặc định = chi cố định ÷ số ngày, có thể bằng hạn mức mỗi ngày (spec ngân sách §3.7) | Trung bình | Ô "Đã trả" ở bước 3; khoản đã trả không cộng vào `fixed_expenses` |
| Kỳ kế hoạch quá ngắn khi lương về sát ngày | Trung bình | Quy tắc ≤ 3 ngày ở mục 4 (cần duyệt) |
| Bấm "Bắt đầu" hai lần tạo hai kế hoạch | Thấp | `idempotency_key` sinh một lần cho mỗi lần mở bộ thiết lập |
| Đã có kế hoạch ACTIVE mà chạy thiết lập lại | Thấp | Engine cho phép nhiều kế hoạch ACTIVE, màn Kế hoạch đã hiện dạng chip. Bước cuối ghi chú "Kế hoạch mới sẽ thêm vào danh sách". |
| Cờ tự mở lưu trên máy | Thấp | Xem ghi chú ở mục 6 |

## 10. Đề xuất cho sau (không làm trong nhánh này)

- Thẻ trang chủ kiểu Mealbird: "Hôm nay còn X ₫ / hạn mức Y ₫", dải 7 ngày có đánh dấu đạt hay vượt.
- Tự đề xuất chạy lại thiết lập khi kế hoạch hết hạn, tức là vào ngày có thu nhập.
- Lưu loại hồ sơ dòng tiền (cố định / linh hoạt) để dùng cho dự báo (`SPECIFICATION.md` §4).

## 11. Cần bạn duyệt

1. Toàn bộ phạm vi ở mục 1 và luồng ở mục 3.
2. Tỉ lệ 3 kiểu chi tiêu ở bước 5.
3. Quy tắc "≤ 3 ngày thì lấy kỳ sau" ở mục 4.
4. Lưu cờ tự mở trên máy (không migration) hay thêm cột `profiles.setup_prompted_at`.
