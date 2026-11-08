## SonarCloud quality gate của PR #97 — đã xanh

PR #97 (`home_feat` → `main`) bị SonarCloud chặn vì 3 điều kiện trên **new code** đỏ.
Đã phân tích qua SonarCloud API và sửa cả 3.

### Trước khi sửa

```
new_security_rating            ERROR  3  (ngưỡng ≤ 1)
new_duplicated_lines_density    ERROR  5.0%  (ngưỡng ≤ 3%)
new_maintainability_rating      OK     1
new_reliability_rating          OK     1
new_security_hotspots_reviewed  OK     100%
```

### Nguyên nhân gốc

1. **Security rating 3** — `pythonsecurity:S8707` tại `backend/scripts/benchmark_inference.py:109`:
   "Path Traversal via faulty LLM-supplied CLI arguments". Script đọc thẳng file từ
   `--audio` của argparse: `args.audio.read_bytes()`. Sonar coi argv là nguồn taint
   không tin cậy, và chuỗi taint đi thẳng tới `read_bytes()`.

2. **Duplication 5.0%** — migration `202611010003_budget_plan_rebalance_conflict.sql`
   chép nguyên văn function `rebalance_plan` (187 dòng trùng, 82.4% density) chỉ để
   đổi `40001` → `PT409`. Migration `001` đã là file mới trong PR này, chưa từng apply
   ở đâu, nên không cần migration thứ hai.

3. **Typing + smell** — `python:S5655` (Sonar resolve `record.get()` thành method
   `get()` của chính lớp repository), `python:S5778` (payload được tạo bên trong
   `pytest.raises` → 2 invocation có thể ném), `plsql:S1192` (literal `'22023'` lặp 9 lần).

### Cách sửa

- **`read_audio()` mới** trong `benchmark_inference.py`: path từ CLI được coi là
  untrusted input. File được định vị bằng cách đi qua các directory entry thật
  (`os.scandir`), nên một tên chỉ "traverse" đi nơi khác không bao giờ tới được
  lệnh đọc. Thêm kiểm tra extension audio, phải là regular file, và giới hạn kích
  thước. Test mới: `backend/tests/unit/test_benchmark_audio.py` (6 test).

- **Gộp migration**: `202611010003_budget_plan_rebalance_conflict.sql` bị xoá.
  `202611010003_budget_plan_event_arrays.sql` mới chỉ thêm constraint mảng cho
  audit trail (40 dòng thay vì 187 dòng trùng). `PT409` nằm ngay trong RPC của
  `001`.

- **Typing**: `_to_plan` chuyển từ `@staticmethod` thành hàm module-level, nên
  `record.get()` không còn bị resolve nhầm thành method `get()` của lớp repository.
  `record` được khai báo `dict[str, Any]`.

- **SQL**: khai báo hằng `c_err_unauthenticated`, `c_err_input`, `c_group_key`,
  `c_status_rebalanced` trong DECLARE của RPC.

### Sai sót đã sửa trong lúc làm

- Khai báo nhầm `c_owner` thay vì `v_owner` → function không chạy được. Bắt được nhờ
  gọi RPC trực tiếp trên Postgres thật (`ERROR: column "v_owner" does not exist`).
- `Set-Content -Encoding UTF8` của PowerShell thêm BOM vào file SQL → Postgres từ
  chối. Đã strip BOM.
- Postgres **có** chấp nhận `USING ERRCODE = <biến>`: đã kiểm chứng SQLSTATE trả về
  đúng `22023` qua `RAISE NOTICE 'SQLSTATE was %', SQLSTATE`.

### Sau khi sửa

```
new_security_rating            OK  1
new_reliability_rating          OK  1
new_maintainability_rating      OK  1
new_duplicated_lines_density    OK  0.28%
new_security_hotspots_reviewed  OK  100%

new_vulnerabilities  0
new_code_smells      38  (đều là smell cũ ngoài phạm vi gate)
```

Quality gate: **OK**. Check `SonarCloud Code Analysis` của PR #97: **pass**.

### Kiểm chứng

- pytest toàn backend: **791 passed**; Ruff: sạch.
- Java E2E trên PostgreSQL 17 thật: **68/68**, `BudgetPlanIT` 11/11.
- Toàn bộ check CI của PR #97: pass (backend-e2e ×2, browser-smoke chrome/edge/firefox,
  build-web, flutter-checks, Selenium gate, SonarCloud).

### Ghi chú

Issue này xử lý các finding của **PR #97**. Các path-traversal finding cũ trong các
script khác (từ issue #79 trước đó) không thuộc PR này và chưa được đánh giá lại ở
đây.
