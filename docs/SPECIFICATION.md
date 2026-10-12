# TÀI LIỆU ĐẶC TẢ YÊU CẦU HỆ THỐNG & THIẾT KẾ KIẾN TRÚC
**Dự án:** Multimodal Personal Finance Management (Hybrid AI PFM)

---

## 1. YÊU CẦU HỆ THỐNG

### 1.1. Yêu cầu Chức năng (Functional Requirements - FR)
- **FR1 - Quản lý tài khoản & Onboarding:**
  - Xác thực một chạm qua Google Sign-In hoặc Apple ID (cấp phát JWT ngầm).
  - Hỗ trợ chế độ khách (Guest Mode) sử dụng định danh thiết bị (`Device_UUID`) để trải nghiệm tức thì.
  - Phân luồng hồ sơ dòng tiền ngay lần đầu mở app: **Thu nhập cố định** hoặc **Thu nhập linh hoạt**.
- **FR2 - Quản lý nguồn tiền & Thu/Chi định kỳ:**
  - Khởi tạo, cập nhật số dư các ví tài chính (Tiền mặt, Ngân hàng, Ví điện tử).
  - Thiết lập các mốc thu/chi định kỳ hàng tháng (ngày nhận lương, hạn đóng tiền trọ, hóa đơn tiện ích) phục vụ làm biến ngoại sinh cho mô hình dự báo.
- **FR3 - Tiếp nhận dữ liệu Đa phương thức (Multimodal Ingestion):**
  - *Văn bản tự nhiên:* Tự động chuẩn hóa từ lóng tiếng Việt ("k", "cành", "củ rưỡi") và trích xuất số tiền, nội dung.
  - *Giọng nói (Voice-to-Transaction):* Thu âm khẩu ngữ và giải mã cục bộ on-device thành văn bản có cấu trúc.
  - *Thị giác hóa đơn (Receipt Document Understanding):* Tiếp nhận ảnh chụp biên lai, hóa đơn in nhiệt mờ/nghiêng/rách, trích xuất tức thì tên điểm bán, ngày tháng, danh mục và tổng tiền.
  - *Giao diện xác thực nhanh (Review Pop-up):* Hiển thị bảng tóm tắt thực thể để người dùng xác nhận hoặc sửa nhanh trước khi lưu sổ.
- **FR4 - Tự động phân loại giao dịch phân tầng (Hybrid Tiered Classification):**
  - Tự động gán nhãn danh mục MECE bằng mô hình xử lý ngôn ngữ nhẹ cục bộ tại server/device với độ trễ < 15ms.
  - Tự động chuyển các giao dịch có độ không chắc chắn cao (P < 0.8) sang hàng đợi để Foundation LLM (Gemini) xử lý ngầm.
  - Ép buộc cấu trúc đầu ra tuân thủ 100% JSON Schema thông qua bộ giải mã ràng buộc theo văn phạm (Grammar-Constrained Decoding - GCD / XGrammar).
- **FR5 - Dự báo dòng tiền thích ứng & Cố vấn tài chính AI:**
  - Ngoại suy số dư trong 7 đến 30 ngày tiếp theo bằng mô hình chuỗi thời gian chuyên biệt cho từng phân khúc người dùng.
  - Tự động phân tích nguy cơ lệch pha dòng tiền hoặc thâm hụt số dư (Burn Rate vượt ngưỡng) để sinh thẻ cảnh báo sớm và đưa ra hạn mức chi tiêu an toàn (*Safe-to-spend*).
- **FR6 - Báo cáo & Trực quan hóa số liệu:**
  - Hiển thị biểu đồ tròn tỷ trọng chi tiêu (Donut Chart) và biểu đồ chuỗi thời gian liên tục từ số dư thực tế trong quá khứ sang đường nét đứt dự báo tương lai.

### 1.2. Yêu cầu Phi chức năng (Non-Functional Requirements - NFR)
- **NFR1 - Hiệu năng & Độ trễ (Performance & Latency):**
  - *Phân hệ giọng nói cục bộ:* Tốc độ phiên âm đạt RTF < 0.2; độ trễ câu 3 giây không vượt quá 350ms trên thiết bị.
  - *Tầng phân loại văn bản nhanh:* Thời gian suy luận phân loại tại CPU đạt dưới 15ms.
  - *Phản hồi giao diện người dùng:* Mọi thao tác lưu giao dịch phải cập nhật tức thì trên giao diện trong vòng dưới 100ms (Optimistic UI Update); các tác vụ AI nặng bắt buộc chạy ngầm bất đồng bộ.
  - *Bóc tách hóa đơn:* Thời gian trích xuất qua VLM không vượt quá 1.600ms.
- **NFR2 - Khả năng chịu tải & Mở rộng (Scalability):**
  - Tầng API (FastAPI) đáp ứng thông lượng tối thiểu 500 RPS.
  - Vượt qua bài kiểm thử tải (Stress-test) 300 người dùng đồng thời qua Locust với tỷ lệ lỗi HTTP 5xx duy trì ở mức 0%.
- **NFR3 - Khả năng chịu lỗi & Đảm bảo toàn vẹn cấu trúc (Robustness & Fault Tolerance):**
  - Tỷ lệ lỗi cú pháp đầu ra (JSON Syntax Hallucination) bị triệt tiêu về 0% nhờ cơ chế XGrammar / JSON Schema enforcement.
  - Các tác vụ gọi Cloud LLM/VLM khi gặp rate-limit hoặc mất mạng phải được lưu an toàn trong hàng đợi Redis/Celery với cơ chế Exponential Backoff (tối đa 3 lần).
- **NFR4 - Chỉ số Chất lượng Mô hình AI (AI Metrics):**
  - *ASR tiếng Việt:* Tỷ lệ lỗi từ WER < 6% trên tập kiểm thử giao dịch tiếng Việt.
  - *Phân loại giao dịch (Local Model):* Macro F1-Score tối thiểu đạt 88% trên tập kiểm thử.
  - *Tỷ lệ giải quyết nội bộ:* Tối thiểu 75% số lượng giao dịch thông thường được xử lý hoàn tất tại tầng cục bộ (P >= 0.8) mà không cần gọi Cloud LLM.
  - *Sai số dự báo dòng tiền:* MAE < 300.000 VND, MAPE < 10% trên chuỗi 30 ngày.
- **NFR5 - Đóng gói, Tính di động & Tối ưu Phần cứng (Portability & Edge Optimization):**
  - Mô hình nhận dạng giọng nói và phân loại cục bộ được lượng tử hóa INT8, dung lượng nén dưới 100MB, chiếm dụng RAM thực thi dưới 300MB.
  - Toàn bộ backend, Celery workers, Redis, PostgreSQL và inference service được đóng gói đồng bộ qua Docker Compose.
- **NFR6 - An toàn & Quyền riêng tư Dữ liệu (Privacy & Security):**
  - Dữ liệu giọng nói và câu lệnh chi tiêu thông thường được xử lý cục bộ trên thiết bị (Privacy-by-Design).
  - Toàn bộ kênh truyền được mã hóa qua TLS 1.3 (HTTPS/WSS).
  - Database cục bộ trên client mã hóa bằng SQLCipher; xác thực người dùng bằng cặp khóa JWT.

---

## 2. MÔ TẢ CHI TIẾT CÁC PHÂN HỆ CHỨC NĂNG

### 2.1. Nhập liệu Đa phương thức Tiên tiến (Multimodal Ingestion)
- **Gõ văn bản tự nhiên:** Nhập câu khẩu ngữ (ví dụ: *"highland cf 55k"*, *"bún bò 40 cành"*, *"đóng tiền nhà 3 củ rưỡi"*). Hệ thống bóc tách số tiền, quy đổi tiếng lóng và gán danh mục tự động.
- **Xử lý âm thanh khẩu ngữ (Edge Voice-to-Text):** Bấm giữ micro để nói (ví dụ: *"vừa đổ năm mươi nghìn tiền xăng"*). Mô hình ASR nhúng trên thiết bị biên dịch trực tiếp sóng âm thành văn bản offline không cần mạng.
- **Thị giác tài liệu hóa đơn (Document VLM):** Chụp ảnh hóa đơn bán lẻ hoặc ảnh chụp màn hình chuyển khoản. VLM đọc trực tiếp ảnh thô, phân tích bảng biểu và trích xuất cây dữ liệu JSON chứa tên quán, danh sách món, đơn giá và tổng tiền.

### 2.2. Dự báo Dòng tiền Thích ứng & Trợ lý Cố vấn AI
- **Ngoại suy số dư đa chu kỳ:** Dùng mô hình học máy chuỗi thời gian tính toán đường đi của số dư tài khoản trong 7 đến 30 ngày kế tiếp dựa trên lịch sử dòng tiền và biến ngoại sinh.
- **Cảnh báo sớm lệch pha dòng tiền:**
  - Nhóm Cố định: Quét nguy cơ số dư bị âm trước ngày nhận lương tiếp theo để phát cảnh báo lệch pha dòng tiền.
  - Nhóm Linh hoạt: Tính toán chỉ số Runway (số ngày sống sót) và hạn mức an toàn mỗi ngày (*Safe-to-spend*).

### 2.3. Quản lý Nguồn tiền & Cập nhật Trạng thái Tức thì (Optimistic UI)
- Quản lý tập trung các ví: Tiền mặt, Ngân hàng, Ví điện tử.
- Cập nhật số dư hiển thị ngay lập tức (< 50ms) sau khi xác nhận, đẩy tác vụ AI nặng và lưu cơ sở dữ liệu chạy ngầm bất đồng bộ.

### 2.4. Báo cáo & Trực quan hóa Dòng tiền Liên tục
- Biểu đồ Donut thể hiện tỷ trọng chi tiêu phân cấp.
- Biểu đồ Plotly liền mạch nối từ số dư quá khứ sang đường nét đứt dự báo tương lai kèm dải tin cậy 95%.

### 2.5. Quản lý Nghĩa vụ Định kỳ & Biến Ngoại sinh
- Quản lý mốc lương, tiền trọ, hóa đơn điện nước. Các mốc này được mã hóa thành biến ngoại sinh (`is_payday`, `is_rent_day`) đưa vào mô hình dự báo.

---

## 3. THIẾT KẾ LUỒNG NGHIỆP VỤ (WORKFLOWS)

### 3.1. Luồng Người dùng Mới (Onboarding Flow)
1. **Mở App & Giới thiệu:** Xem 3 thẻ giới thiệu tính năng chính.
2. **Xác thực 1-Chạm:** Đăng nhập qua Google/Apple hoặc Guest Mode (cấp phát JWT ngầm).
3. **Phân loại dòng tiền:** Chọn hồ sơ **Thu nhập cố định** hoặc **Thu nhập linh hoạt**.
4. **Khởi tạo ví ban đầu:** Điền số dư xuất phát của các ví.
5. **Cấu hình biến định kỳ:**
   - *Nhóm Cố định:* Nhập ngày nhận lương, tiền lương, hạn đóng tiền nhà.
   - *Nhóm Linh hoạt:* Nhập hạn mức chi tiêu trần mong muốn và các khoản cố định không thể cắt giảm.
6. **Ghi chép thử nghiệm (Empty-state Mitigation):** Làm thử một lệnh bằng giọng nói hoặc chụp hóa đơn để làm quen luồng nhập liệu.
7. **Hạ cánh Dashboard:** Hiển thị số dư thực tế, đồ thị dự báo 30 ngày đầu tiên và lời khuyên ban đầu từ AI.

### 3.2. Luồng Người dùng Thường xuyên (Returning User Workflow)
1. **Khởi động:** Xác thực JWT ngầm, mở Dashboard trong vòng 1 giây.
2. **Đọc trạng thái tài chính (3–5s):** Quan sát số dư khả dụng, đồ thị 30 ngày và thẻ cảnh báo AI nếu có nguy cơ thâm hụt.
3. **Nhập giao dịch:** Bấm (+) chọn 1 trong 3 cách: Text, Voice (PhoWhisper INT8), hoặc Chụp hóa đơn (Document VLM).
4. **Xác nhận nhanh (Pop-up Review):** Kiểm tra số tiền, danh mục tự động và bấm Xác nhận trong 1 giây.
5. **Cập nhật Lạc quan & Xử lý Ngầm:** UI trừ tiền ví ngay lập tức (< 50ms). Nếu câu khó (P < 0.8), đẩy Celery task gọi Gemini chuẩn hóa lại sau. Mô hình chuỗi thời gian chạy ngầm tính lại đường dự báo 30 ngày.

---

## 4. CHIẾN LƯỢC PHÂN HÓA 2 PHÂN KHÚC DÒNG TIỀN

| Tiêu chí | Phân khúc 1: Thu nhập Cố định (Salaried Profile) | Phân khúc 2: Thu nhập Linh hoạt (Flexible Profile) |
| :--- | :--- | :--- |
| **Đối tượng** | Nhân viên văn phòng, công chức có lịch lương cố định. | Freelancer, tài xế công nghệ, sinh viên nhận tiền không cố định ngày. |
| **Chỉ số Trọng tâm** | **Khoảng cách tới Ngày lương:**<br>• Đếm ngược ngày tới kỳ lương.<br>• Số dư dự kiến vào ngày nhận lương. | **Chỉ số Sinh tồn (Runway):**<br>• Runway (Số ngày đủ sống): `Current Balance / Burn Rate`.<br>• Hạn mức an toàn mỗi ngày (*Safe-to-spend*). |
| **Mô hình Dự báo** | **LightGBM Regressor (Tabular):**<br>Khai thác tính chu kỳ với biến ngoại sinh: `is_payday`, `is_rent_day`, `day_of_week`. | **EWMA Burn Rate:**<br>`BurnRate_t = alpha * Expense_t + (1 - alpha) * BurnRate_{t-1}` với `alpha = 0.3`. |
| **Logic AI Advisor** | **Cảnh báo Lệch pha Chu kỳ:**<br>Báo động khi tiền trọ/hóa đơn đến hạn trước ngày nhận lương gây âm số dư. | **Kiểm soát Bội chi Đột biến:**<br>Báo động khi tốc độ chi tiêu 3 ngày gần nhất tăng vượt 30% sau khi vừa nhận khoản thu lớn. |
| **Onboarding Form** | Mở form: Ngày lương, lương thực nhận, ngày đóng tiền nhà. | Mở form: Ngân sách trần trong tháng và chi phí tối thiểu bắt buộc. |

---

## 5. THIẾT KẾ KIẾN TRÚC HỆ THỐNG VÀ 4 MÔ HÌNH AI

### 5.1. Phân bổ Kiến trúc 3 Tầng Vật lý
- **Tầng 1 (Client / Edge):** PhoWhisper-tiny INT8 qua `sherpa-onnx` (Voice -> Text < 350ms), chuẩn hóa từ lóng regex, SQLite mã hóa, Optimistic UI.
- **Tầng 2 (Local Server CPU):** FastAPI gateway, Model 1 (PhoBERT + LightGBM phân loại < 15ms), Model 2 (Cashflow Engine LightGBM/EWMA), hàng đợi Redis + Celery.
- **Tầng 3 (Cloud GPU & Foundation API):** Model 4 dùng Qwen2.5-VL riêng cho Document VLM bóc tách bill qua vLLM/API và JSON Schema validation; Gemini 2.5 Flash riêng cho cố vấn tài chính và Fallback NLP.

### 5.2. Bóc tách 4 Mô hình AI Cốt lõi
1. **Model 1 (Bộ phân loại giao dịch - In-house):**
   - *Kỹ thuật:* PhoBERT-base (135M) trích xuất embedding + LightGBM Classifier. Ngưỡng tự tin rẽ nhánh $P = 0.8$.
   - *Nhiệm vụ:* Phân loại câu ngắn tiếng Việt trong < 15ms trên CPU.
2. **Model 2 (Dự báo dòng tiền - In-house):**
   - *Kỹ thuật:* LightGBM Regressor kèm Covariates (Nhóm Cố định) + công thức giải tích EWMA/Runway (Nhóm Linh hoạt). Tuyệt đối không dùng LLM để tính toán số dư.
   - *Nhiệm vụ:* Ngoại suy đường cong số dư 30 ngày tới, tính toán MAE, RMSE, MAPE.
3. **Model 3 (Nhận dạng giọng nói cục bộ - Pre-trained On-device):**
   - *Kỹ thuật:* PhoWhisper-tiny INT8 đóng gói qua runtime `sherpa-onnx`.
   - *Nhiệm vụ:* Giải mã âm thanh khẩu ngữ tiếng Việt offline không cần mạng, WER < 6%.
4. **Model 4 (Thị giác Hóa đơn & Trợ lý Cố vấn - Foundation Model):**
   - *Document VLM:* Qwen2.5-VL-7B chỉ bóc tách ảnh hóa đơn thành JSON, được kiểm định bằng Pydantic schema. Kiểm tra số học tại Python với sai lệch tối đa 5%; confidence 0.95 nếu hợp lệ, 0.60 nếu không hợp lệ.
   - *Financial Advisor & Fallback NLP:* Gemini 2.5 Flash chỉ sinh lời khuyên/cảnh báo cho nhóm Cố định và Linh hoạt, hoặc xử lý phân loại NLP khi Model 1 thiếu tự tin. Không dùng Gemini đọc ảnh hóa đơn; không dùng Qwen tư vấn hay NLP fallback.
   - *Tính toán tài chính:* Số dư, burn rate, runway và dự báo luôn do Model 2 tính; Advisor chỉ diễn giải các chỉ số có sẵn.

### 5.3. Kế hoạch Triển khai Thực nghiệm (5 Gói Nhiệm vụ)
- **Gói 1: Dữ liệu thực nghiệm:**
  - `data/processed/data_transactions.csv` (1.500 dòng text, 6 nhãn).
  - `data/processed/balance_fixed.csv` & `data/processed/balance_flexible.csv` (90 ngày chuỗi thời gian).
  - Mẫu âm thanh tại `data/raw/audio/` và mẫu hóa đơn tại `data/raw/receipts/`.
- **Gói 2: Phân loại Phân tầng (Hybrid NLP):**
  - Huấn luyện Model 1, lưu mô hình vào `weights/checkpoints/lgbm_classifier.pkl`.
  - Logic fallback sang Gemini khi $P < 0.8$. Đo đạc F1-Score, Latency, tỷ lệ xử lý nội bộ.
- **Gói 3: Dự báo Dòng tiền 2 Nhóm:**
  - Huấn luyện LightGBM Regressor trên `balance_fixed.csv`, lưu checkpoint vào `weights/checkpoints/lgbm_forecaster.pkl`.
  - Cài đặt công thức toán EWMA Runway trên `balance_flexible.csv`.
- **Gói 4: Xử lý Hóa đơn & AI Advisor:**
  - Xây dựng pipeline VLM bóc tách hóa đơn, ép kiểu JSON Schema:
    ```json
    {
      "merchant": "string",
      "date": "YYYY-MM-DD",
      "items": [{"name": "string", "quantity": 1, "price": 0}],
      "total_amount": 0,
      "category": "string",
      "confidence_score": 0.95
    }
    ```
  - Kiểm tra tính nhất quán toán học: Đối chiếu $\sum (\text{quantity} \times \text{price})$ với $\text{total\_amount}$.
  - Viết Persona Prompt cho AI Advisor cho 2 nhóm đối tượng.
- **Gói 5: Giao diện Mô phỏng Streamlit (`frontend/app.py`):**
  - Màn hình 1: Demo tiếp nhận Đa phương thức (Text, Voice PhoWhisper, Upload hóa đơn VLM) kèm bảng đo độ trễ và nhãn nguồn (`LOCAL_CPU` vs `CLOUD_FALLBACK`).
  - Màn hình 2: Dashboard tương tác Plotly dự báo 30 ngày, thanh gạt chuyển hồ sơ và thẻ cảnh báo động từ AI Advisor.
