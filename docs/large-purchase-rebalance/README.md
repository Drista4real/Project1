# Xem trước và điều chỉnh kế hoạch khi mua khoản lớn

**Dự án:** Kakeibo Zen  
**Ngày:** 18/11/2026  
**Trạng thái:** Bản nháp để nhóm xem xét. Các chính sách và contract mới trong tài liệu này chưa được chấp thuận hoặc triển khai.

## 1. Kết luận và phạm vi

Hướng triển khai **khả thi trên kiến trúc hiện có**, vì dự án đã có engine ngân sách tất định, công cụ mô phỏng khoản mua, RPC tái cân bằng trong một transaction và chat có tool trace. Tuy nhiên, chưa thể nối trực tiếp các phần này thành luồng “xem trước → xác nhận” đáng tin cậy: mô phỏng và đề xuất đang dùng hai cách tính số dư khác nhau, chat chưa thu thập ví để ghi khoản mua, và xác nhận chưa gắn với đúng phương án người dùng đã xem.

**MVP đề xuất:**

1. Hiển thị tác động của khoản mua và phương án phân bổ trước/sau từ dữ liệu đã ghi.
2. Cho người dùng hoãn mua hoặc xác nhận **đã mua, ghi giao dịch và áp dụng đúng phương án đã xem**.
3. Nếu không có phương án hợp lệ, vẫn cho ghi khoản đã thực sự chi qua luồng giao dịch riêng; không ghi một phương án tái cân bằng giả.
4. Không thay mục tiêu tiết kiệm, tổng thu nhập hoặc thời hạn kế hoạch. Không đưa trả góp hoặc khoản nợ vào MVP.

**Điều kiện trước khi phát hành:** cần triển khai dấu chi phí cố định `transactions.fixed_expense_plan_id`, sửa adapter số dư và mốc ngày theo giờ Việt Nam, dùng cùng `E` cho mô phỏng/preview, thêm bảng proposal và bộ đếm revision, thu thập/kiểm tra ví nguồn, rồi ràng buộc RPC với xác nhận của người dùng. Đây là các việc đã chọn cho bản nháp, chưa có trong hệ thống.

Tài liệu này là bản thảo thiết kế trong repo. Quyết định miền chính thức vẫn ở [GLOSSARY.md](../../GLOSSARY.md) và [docs/adr](../adr/); đặc tả hoặc ticket được theo dõi bằng [GitHub Issues](https://github.com/Drista4real/Project1/issues).

### Nền tảng đã có

| Thành phần | Hiện trạng | Việc còn thiếu cho luồng này |
|---|---|---|
| Engine ngân sách | Tính ngân sách khả dụng, hạn mức/ngày, sàn, nhóm và đề xuất cắt giảm bằng Decimal | Đề xuất phải dùng số dư chi tiêu thực; xác định rõ tiền chưa phân bổ |
| Purchase impact | Đọc mọi giao dịch `expense` đã ghi để tính số dư còn lại | Loại phần chi phí cố định đã khấu trừ, giữ số dư âm, dùng mốc ngày `Asia/Ho_Chi_Minh` và trả dữ liệu cho preview |
| RPC `rebalance_plan` | Ghi phân bổ, giao dịch, phiên bản và audit trong một transaction; có `plan_version` và idempotency key | Xác minh phương án đã xem, dữ liệu nguồn, ngày, ví và nội dung retry |
| Chat | Có tool registry, tool trace và tối đa một tool call mỗi lượt | Tool preview, chip xác nhận có tham chiếu phương án, trạng thái hủy/xác nhận |

Các đề xuất dưới đây phải giữ [ADR 0005](../adr/0005-envelope-capacity-and-wallet-totals.md), [ADR 0009](../adr/0009-deterministic-budget-engine.md) và [ADR 0010](../adr/0010-conversational-home-canvas.md): LLM không tính tiền; `public.budgets` là nguồn hạn mức envelope; giao dịch và phân bổ chỉ được ghi qua thao tác người dùng xác nhận.

## 2. Khái niệm và chính sách đề xuất

### “Khoản mua lớn” chỉ là nhãn để mời xem xét

**Quyết định của bản nháp:** một khoản mua giá `P` được gắn nhãn lớn khi `P ≥ 10% × B_spendable` **hoặc** `P ≥ 3 × D_current`, với `D_current = budget_plans.daily_allowance` hiện hành. Dấu bằng thuộc phía “lớn”. Hai hệ số là hằng trong engine, đi cùng phiên bản chính sách trong `config_version` (ví dụ `large-purchase-v1`); `is_expensive` được ghi vào tool trace để hiệu chỉnh sau khi có dữ liệu sử dụng. Kế hoạch rất ngắn có thể gắn nhãn phần lớn khoản mua; điều này được chấp nhận vì nhãn không chặn thao tác.

Nhãn này **không** quyết định khả năng mua. Khoản nhỏ vẫn cần preview nếu làm thay đổi phân bổ hoặc tạo cảnh báo. `risk_level` (mức rủi ro theo sàn) và `needs_rebalance` (phân bổ sau mua có đổi hay không) phải được trả riêng; không đổi ngầm nghĩa của `SAFE`, `WARNING_REBALANCE_NEEDED` hoặc `CRITICAL_DANGER` đang có.

### Sàn sống tối thiểu chỉ là cảnh báo

[ADR 0009](../adr/0009-deterministic-budget-engine.md) dùng survival floor để phân loại tác động. **Quyết định của bản nháp: sàn chỉ cảnh báo, không chặn tái cân bằng.** Với `CRITICAL_DANGER`, phương án vẫn có thể khả thi nhưng phải có chip xác nhận riêng nêu rõ mức dưới sàn. Proposal cần có `floor_acknowledgement_required = true`; RPC phải từ chối khi thiếu bằng chứng người dùng đã xác nhận cảnh báo này. Chỉ `A < 0`, vi phạm ADR 0005 hoặc `INSUFFICIENT_DATA` mới chặn phương án.

Lý do: khi `D_current = D_min` và người dùng đã chi đúng tiến độ, với `R = n × D_min`, mọi khoản mua thêm `P > 0` đều cho `(R − P) / n < D_min`. [DYNAMIC_BUDGET_SPEC.md](../DYNAMIC_BUDGET_SPEC.md) ghi `D_min == D_i` là hành vi mặc định đúng; chặn theo sàn sẽ làm mọi khoản mua thêm trong trường hợp này không thể tái cân bằng. Việc xem lại ý nghĩa của sàn mặc định, hiện lấy từ chi phí cố định/ngày dù chi phí cố định đã trừ khỏi `B_spendable`, được đưa sang sau MVP.

Việc cho phép một phương án có cảnh báo **không** cho phép phá vỡ [ADR 0005](../adr/0005-envelope-capacity-and-wallet-totals.md): trụ cột có hạn mức danh mục con phải giữ đủ hạn mức theo đúng kỳ cấu hình.

### Tiết kiệm và thời hạn

`savings_target` là mục tiêu, không phải số dư tiền mặt. Luồng này không rút mục tiêu tiết kiệm, không tự tăng thu nhập và không tự kéo dài thời hạn. Trả góp chỉ có thể xem xét sau khi có lịch trả, phí/lãi, nghĩa vụ tương lai và mô hình công nợ riêng. Hoãn mua không tự tạo thêm tiền; khi người dùng quay lại phải tính lại từ dữ liệu mới.

## 3. Nguồn số liệu và phép tính

Ký hiệu:

- `B_spendable`: ngân sách khả dụng lúc tạo kế hoạch.
- `E`: tổng `expense` của chủ sở hữu có `transaction_date` từ 00:00 ngày `start_date` đến thời điểm preview theo `Asia/Ho_Chi_Minh`, không gồm khoản mua đang xem; trừ phần chi phí cố định đã đánh dấu tối đa bằng `fixed_expenses`.
- `R = B_spendable − E`: số còn lại trước mua, không kẹp về 0; nếu không đủ dữ liệu để xác định `E`, trả `INSUFFICIENT_DATA`.
- `P`: giá mua; `A = R − P` là số còn lại sau mua.
- `n`: số ngày còn lại, gồm ngày mua theo hằng `Asia/Ho_Chi_Minh` của MVP; `budget_plans` hiện chưa lưu múi giờ.
- `D_capacity = A / n`: khả năng chi bình quân/ngày sau mua, trước khi làm tròn để hiển thị.
- `D_allocated`: tổng hạn mức/ngày thực sự phân cho các nhóm sau tái cân bằng.

Mô phỏng và preview phải dùng **cùng định nghĩa `E`**. Preview đọc snapshot mới nhất; bước xác nhận kiểm tra lại đúng snapshot của preview đó. Hiện mô phỏng trừ giao dịch thật, còn `BudgetPlanService.propose()` lấy `B_spendable × n / duration_days`; hai số chỉ bằng nhau khi chi tiêu trước đó đúng tiến độ. Cần sửa adapter đề xuất trước khi đưa preview cho người dùng.

**Quyết định dữ liệu của bản nháp:** cần thêm cột nullable `transactions.fixed_expense_plan_id → budget_plans(id)` để người dùng đánh dấu rõ khoản chi phí cố định đã khấu trừ khi lập kế hoạch, lúc ghi hoặc sửa giao dịch. Danh mục hoặc mục định kỳ trùng khớp chỉ gợi ý trước, không tự đánh dấu. Gọi `M` là tổng `expense` đã đánh dấu cho kế hoạch trong khoảng thời gian trên: `E = tổng expense − min(M, fixed_expenses)`. Nếu `M` vượt `fixed_expenses`, phần vượt vẫn thuộc `E`. `income` và `transfer` không thuộc `E`; không lọc theo `is_verified` vì cột đó xác nhận nhãn phân loại, không xác nhận giao dịch có thật.

Khi `D_capacity` lớn hơn phân bổ/ngày hiện hành, không bắt buộc tăng phân bổ. Phần chênh lệch là **tiền còn chưa phân bổ**, phải hiển thị riêng; không khẳng định tổng phân bổ bằng `A` nếu còn phần này. Khi cần cắt, engine cắt theo `wants → culture → unexpected → needs`, giữ các hạn mức danh mục con theo [ADR 0005](../adr/0005-envelope-capacity-and-wallet-totals.md). Quy tắc làm tròn bằng Decimal phải bảo toàn tổng phân bổ đã chọn.

### Ví dụ kiểm tra

| Dữ liệu | Giá trị |
|---|---:|
| Thu nhập, chi phí cố định, mục tiêu tiết kiệm | 8.000.000đ; 3.000.000đ; 2.000.000đ |
| Thời hạn và ngày mua | 30 ngày; ngày thứ 5 |
| Chi thuộc ngân sách khả dụng đã xác nhận trước mua | 400.000đ; không gồm khoản nào được đánh dấu chi phí cố định |
| Giá mua | 1.500.000đ |

`B_spendable = 3.000.000đ`; `R = 2.600.000đ`; `n = 26`; `A = 1.100.000đ`; `D_capacity ≈ 42.307,69đ/ngày`. Hạn mức ban đầu và sàn mặc định đều là `100.000đ/ngày`, nên đây là khoản mua lớn và có cảnh báo `CRITICAL_DANGER`. Để giữ mức sàn trong 26 ngày cần `2.600.000đ`; sau mua thấp hơn mức đó `1.500.000đ`.

**Không kết luận “không có phương án tái cân bằng” chỉ từ phép so với sàn.** Cần đọc hạn mức danh mục con và chạy kiểm tra envelope để biết có thể cắt xuống mức mới hay không. Nếu không đáp ứng ADR 0005 hoặc `A < 0`, phương án là `INFEASIBLE`. Nếu đáp ứng, có thể cho xem phương án với cảnh báo nghiêm trọng và thao tác xác nhận rõ ràng.

Ví dụ này có `R = B_spendable × 26 / 30` vì đã chi đúng `400.000đ` trong bốn ngày đầu. Nếu đã chi ít hoặc nhiều hơn, công thức tỷ lệ ngày của code hiện tại sẽ cho kết quả sai so với sổ giao dịch.

## 4. Luồng xem trước và xác nhận

```text
Người dùng nêu khoản mua
  → simulate_purchase_impact: mức tác động từ số dư đã xác nhận
  → người dùng yêu cầu xem phương án
  → propose_rebalance: đọc snapshot, trả trước/sau, cảnh báo và lựa chọn
       ├─ Hoãn/hủy: chuyển proposal sang CANCELLED, không ghi tài chính
       ├─ Không khả thi: giải thích; nếu đã mua, chuyển sang ghi giao dịch riêng
       └─ Khả thi: nếu dưới sàn, hiện chip riêng ghi rõ mức dưới sàn
            → người dùng bấm “Đã mua, ghi giao dịch và áp dụng”
            → confirm_and_rebalance_budget: kiểm tra đúng đề xuất rồi ghi một transaction
                 ├─ Thành công: trả biên nhận và trạng thái mới
                 └─ Cũ/hết hạn/xung đột: preview lại, yêu cầu đồng ý lại
```

`propose_rebalance` là **tool mới, chỉ đọc tài chính**. Nó trả cấu trúc phương án và chip trong chính kết quả tool, để không cần gọi `ask_user_question` cùng lượt. Backend và frontend phải hỗ trợ chip có `option_id`/`proposal_id` ổn định; chip nhãn văn bản hiện tại chưa đủ chứng minh người dùng đã chọn đúng phương án. Mỗi lượt chat vẫn tối đa một tool call.

Cần phân biệt hai ý định:

- “Tôi muốn cân nhắc phương án này”: chưa ghi giao dịch hoặc sửa kế hoạch.
- “Tôi đã mua, ghi giao dịch và áp dụng”: ghi khoản mua và phân bổ trong cùng transaction sau khi xác nhận.

Câu “mua luôn” nói **trước khi xem preview** không thay thế sự đồng ý với số liệu sau điều chỉnh. Nếu người dùng đã thực sự chi nhưng không thể tái cân bằng, cho họ ghi giao dịch qua luồng hiện có và giữ cảnh báo.

MVP chỉ áp dụng phương án khi người dùng xác nhận đã mua. Nếu cắt phân bổ mà chưa ghi giao dịch, `E` không đổi; khoản mua thật được ghi sau đó có thể làm giảm ngân sách thêm lần nữa. Vì vậy, nhánh `purchase_amount = 0` tạo event `REBALANCED` của RPC hiện có không được mở cho chat trong MVP. Lưu phương án dự kiến là việc sau MVP.

### Ràng buộc phương án đã xem

**Quyết định lưu trữ của bản nháp:** cần bảng riêng `public.budget_plan_proposals`, không dùng `ai_chat_sessions.budget_slots`: slots là JSONB được ghi lại khi thu thập đầu vào, không có ràng buộc trạng thái và không thể khóa như một hàng proposal trong RPC. Bảng đề xuất có `id uuid`, `user_id`, `plan_id`, `chat_session_id` nullable, `status` (`ACTIVE`/`CANCELLED`/`APPLIED`/`EXPIRED`), `plan_version`, `source_revision`, `local_date`, `account_id`, `category_id`, `group_key`, `amount`, `description`, `options jsonb`, `digest`, `algorithm_version`, `floor_acknowledgement_required`, `expires_at`, `applied_event_id`, `idempotency_key`, `request_fingerprint`, `created_at`. Preview ghi snapshot nhất quán; TTL đề xuất mười phút và hết hiệu lực khi sang ngày địa phương mới.

RLS đề xuất cho chủ sở hữu `SELECT`/`INSERT`; chỉ backend tạo nội dung proposal đã kiểm chứng. Chuyển trạng thái chỉ qua hàm `SECURITY DEFINER`: RPC `rebalance_plan` mở rộng để áp dụng và một hàm hủy để đặt `CANCELLED`. Token/digest đơn lẻ không đủ vô hiệu hóa proposal đã hủy. RPC phải kiểm tra nội dung đã lưu, không tin giá hoặc phân bổ gửi lại từ LLM.

Khi xác nhận, backend kiểm tra quyền sở hữu, bằng chứng từ tương tác người dùng, trạng thái đề xuất, TTL, phiên bản kế hoạch và revision của **mọi dữ liệu phụ thuộc**. Nếu dữ liệu hoặc kết quả tính lại khác snapshot đã hiển thị, trả xung đột và yêu cầu preview mới. Không tự áp dụng kết quả mới.

Chỉ tăng `plan_version` là chưa đủ. Cần bảng `public.finance_revisions(user_id PK, revision bigint)` và trigger `AFTER INSERT/UPDATE/DELETE` trên `transactions`, `budgets`, `categories`, `budget_plans`, `daily_allocations`; trigger tăng revision cho chủ sở hữu bị ảnh hưởng, kể cả khi sửa danh mục hệ thống có `user_id` null. RPC phải khóa hàng revision của người dùng và hàng proposal bằng `SELECT … FOR UPDATE` **trước khi so sánh** revision/snapshot rồi mới ghi. Các ghi tài chính của cùng một người dùng vì thế bị tuần tự hóa; chấp nhận được với ứng dụng cá nhân. Revision không cần theo dõi `accounts` vì `E` không đọc số dư ví, nhưng RPC phải xác minh `account_id` thuộc chủ sở hữu.

Một lần xác nhận thành công phải ghi phân bổ, giao dịch, `actual_spent`, phiên bản, audit, idempotency và dấu đã dùng proposal cùng lúc. Retry cùng khóa **và cùng nội dung** trả biên nhận cũ sau khi xác thực quyền, kể cả khi TTL đã qua; cùng khóa khác nội dung bị từ chối. Một proposal không được áp dụng lần hai bằng khóa khác.

## 5. Contract và thay đổi cần triển khai

| Phần | Thay đổi đề xuất |
|---|---|
| `simulate_purchase_impact` | Trả `is_expensive`, `risk_level`, `needs_rebalance`, `R`, `n`, `D_capacity`, revision nguồn và số tiền đã định dạng; ngày được backend đối chiếu |
| `propose_rebalance` | Nhận kế hoạch, khoản mua, ngày và thông tin ví/danh mục cần thiết; đọc cùng nguồn số dư; trả trước/sau, cảnh báo, lý do không khả thi, tiền chưa phân bổ, `proposal_id`/token, TTL và chip |
| `confirm_and_rebalance_budget` | Nhận tham chiếu proposal, `option_id` và bằng chứng bấm xác nhận; không nhận giá hoặc phân bổ tự do do LLM dựng lại |
| RPC và dữ liệu | Xác minh proposal/snapshot/revision trong transaction; kiểm tra lại envelope và nguồn tiền; ghi audit và fingerprint cho idempotency |
| Chat và frontend | Hiển thị snapshot, cảnh báo, ví nguồn và nhãn xác nhận rõ; gửi tham chiếu lựa chọn từ thao tác người dùng; xử lý hủy, hết hạn và 409 |
| `transactions.fixed_expense_plan_id` | Cột nullable liên kết kế hoạch; người dùng đánh dấu khi ghi/sửa; chỉ miễn trừ tối đa `fixed_expenses` khỏi `E` |
| `budget_plan_proposals` | Bảng mới chứa snapshot, trạng thái, cảnh báo dưới sàn, digest, TTL và thông tin xác nhận; chỉ hàm được quyền đổi trạng thái |
| `finance_revisions` | Bảng mới và trigger trên năm bảng dữ liệu nguồn; RPC khóa revision và proposal trước khi đối chiếu |

Backend tự tạo idempotency key, lấy chủ sở hữu từ phiên xác thực và làm mọi phép tính tiền bằng Decimal. Số chatbot nói ra phải có trong tool result. Không coi các trường trên là contract đã có.

**Lưu ý với schema hiện tại:**

- Chat tool xác nhận chưa có `account_id`; RPC yêu cầu ví khi `purchase_amount > 0`. Phải thu thập và kiểm tra ví trước xác nhận.
- `transactions` chưa liên kết kế hoạch hay `recurring_transactions`; `budget_plans` chỉ lưu tổng `fixed_expenses`. Schema có `auto_create` nhưng chưa có code tự tạo giao dịch từ mục định kỳ.
- `_spent_between` hiện cộng mọi `expense`, kể cả chi phí cố định, và lọc `TIMESTAMPTZ` bằng chuỗi ngày `YYYY-MM-DD`, không tạo ranh giới 00:00 theo `Asia/Ho_Chi_Minh`; cách diễn giải ranh giới phụ thuộc múi giờ database/session. `remaining_balance` hiện kẹp số dư âm về 0; cần bỏ kẹp để nhận ra `R < 0`.
- `rebalance_plan` hiện dùng `CURRENT_DATE` của database cho ngày phân bổ và `actual_spent`; cần dùng ngày địa phương đã được ràng buộc trong proposal. RPC cũng cần xác minh ví thuộc chủ sở hữu.
- `evaluate_purchase_impact` hiện trả `SAFE` khi `daily_after ≤ daily_allowance` và chưa dưới sàn; khi `daily_after > daily_allowance` thì trả `WARNING_REBALANCE_NEEDED`. Hai nhánh có vẻ ngược nghĩa theo cách diễn đạt hiện tại; cần xác minh bằng test trước khi quyết định, chưa đổi nghĩa enum.
- `budget_plan_events` hiện ghi `PURCHASE_CONFIRMED` khi RPC có khoản mua, `REBALANCED` khi không có khoản mua. MVP giữ event `PURCHASE_CONFIRMED` và không mở nhánh mua bằng 0 cho chat.
- `public.budgets` tiếp tục là nguồn duy nhất cho hạn mức envelope. Snapshot phục vụ xác nhận và audit, không thành nguồn hạn mức thứ hai.
- Mapping hiện hành trong glossary và engine là `lifestyle → wants`; `food`, `transport → needs`; `other → unexpected`. Không cần mở lại câu hỏi này nếu chưa có yêu cầu nghiệp vụ mới.

## 6. Trường hợp biên và kiểm chứng

| Trường hợp | Kết quả yêu cầu |
|---|---|
| `A < 0` hoặc vi phạm hạn mức danh mục | `INFEASIBLE`; không ghi phân bổ âm |
| Dưới sàn nhưng không vi phạm điều kiện chặn | `CRITICAL_DANGER`; hiện rõ mức thiếu và yêu cầu xác nhận |
| Dưới sàn nhưng thiếu bằng chứng đã xác nhận cảnh báo | RPC từ chối; không ghi giao dịch hoặc phân bổ |
| Thiếu dữ liệu chi tiêu thuộc kế hoạch | `INSUFFICIENT_DATA`; không lấy dự báo hoặc tỷ lệ ngày thay thế số dư thật |
| Chi phí cố định đã đánh dấu | Miễn trừ khỏi `E` tối đa bằng `fixed_expenses` của kế hoạch |
| Tổng khoản đánh dấu vượt `fixed_expenses` | Phần vượt vẫn tính vào `E` |
| Giao dịch lúc 23:30 giờ Việt Nam, khác ngày UTC | Xếp vào ngày địa phương đúng và dùng đúng ranh giới preview |
| `R < 0` trước mua | Giữ số âm; trả `INFEASIBLE`, không kẹp về 0 |
| Đổi giá, ví, danh mục hoặc hủy | Đề xuất cũ mất hiệu lực; phải preview lại |
| Giao dịch, envelope hoặc kế hoạch đổi ở nơi khác | Xung đột; không tự nâng phiên bản hoặc thay phương án đã xem |
| Sửa danh mục hoặc envelope giữa preview và xác nhận | Trigger đổi revision; RPC trả 409, yêu cầu preview lại |
| Hai khoản mua liên tiếp | Khoản sau dùng số dư sau commit trước; proposal cùng snapshot không cùng thành công |
| Sang ngày mới, hết TTL, bấm hai lần, mất mạng sau commit | Ngày/TTL mới cần preview; retry commit thành công trả biên nhận cũ, không ghi đôi |
| Đã mua nhưng tái cân bằng không khả thi | Cho ghi giao dịch riêng sau xác nhận, vẫn hiển thị cảnh báo |

Kiểm chứng tối thiểu trước khi triển khai: ví dụ số ở phần 3; chi ít hơn/nhiều hơn tiến độ; các ca chi phí cố định, phần vượt và `R` âm trong bảng trên; khoản mua ngay dưới/bằng/trên ngưỡng lớn; sàn bằng hạn mức ban đầu; xác nhận dưới sàn thiếu bằng chứng; envelope có hạn mức tháng; sửa giao dịch, danh mục hoặc envelope giữa preview và xác nhận; hai xác nhận cạnh tranh; retry cùng khóa khác nội dung; giao dịch lúc 23:30 giờ Việt Nam khác ngày UTC; hủy đồng thời với xác nhận. Viết test để xác minh hai nhánh `SAFE`/`WARNING_REBALANCE_NEEDED` hiện tại mà chưa đổi nghĩa enum. Kiểm tra trên PostgreSQL thật vì tính đúng đắn phụ thuộc transaction và khóa.

## 7. Quyết định đã chọn

1. **Phạm vi `E`:** dùng các `expense` trong kỳ theo giờ Việt Nam, trừ phần đã đánh dấu `fixed_expense_plan_id` tối đa bằng `fixed_expenses`; giữ `R` âm. Cột đánh dấu, adapter và mốc thời gian vẫn là điều kiện chặn phát hành; xem [mục 3](#3-nguồn-số-liệu-và-phép-tính).
2. **Khoản mua lớn:** giữ ngưỡng `10% × B_spendable` hoặc `3 × D_current`, version hóa và ghi `is_expensive` vào tool trace; nhãn không chặn. Xem [mục 2](#2-khái-niệm-và-chính-sách-đề-xuất).
3. **Sàn sống:** chỉ cảnh báo; dưới sàn cần chip riêng và bằng chứng xác nhận, còn điều kiện chặn chỉ là `A < 0`, ADR 0005 hoặc `INSUFFICIENT_DATA`. Xem [mục 2](#sàn-sống-tối-thiểu-chỉ-là-cảnh-báo) và [mục 4](#4-luồng-xem-trước-và-xác-nhận).
4. **Chỉ áp dụng khi đã mua:** MVP ghi giao dịch và phân bổ cùng lúc; hoãn đặt proposal `CANCELLED`, không mở nhánh `purchase_amount = 0` cho chat. Xem [mục 4](#4-luồng-xem-trước-và-xác-nhận).
5. **Proposal và revision:** dùng `budget_plan_proposals` riêng và `finance_revisions` tăng bằng trigger; RPC khóa, kiểm tra rồi áp dụng. Xem [mục 4](#ràng-buộc-phương-án-đã-xem) và [mục 5](#5-contract-và-thay-đổi-cần-triển-khai).

### Việc sau MVP

Xem lại ý nghĩa sàn mặc định; lưu phương án dự kiến chưa ghi giao dịch; hiệu chỉnh ngưỡng khoản mua lớn bằng dữ liệu sử dụng; liên kết mục định kỳ với giao dịch khi triển khai `auto_create`; thêm cột múi giờ cho kế hoạch.
