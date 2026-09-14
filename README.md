# BÁO CÁO KẾ HOẠCH TRIỂN KHAI ĐỀ TÀI VÀ ĐẶC TẢ HỆ THỐNG
## Đề tài 17: Hệ thống Quản lý Tài chính Cá nhân Dự báo Dòng tiền Thông minh (AI-driven Cash Flow Forecasting & Financial Management)

---

## 1. TỔNG QUAN DỰ ÁN (PROJECT OVERVIEW)

### 1.1. Bối cảnh & Vấn đề thực tế
Quản lý tài chính cá nhân là nhu cầu thiết yếu đối với người đi làm và sinh viên. Tuy nhiên, các giải pháp hiện nay trên thị trường (Money Lover, Spendee, Sổ Thu Chi...) đều tồn tại ba rào cản lớn:
1. **Nút thắt nhập liệu thủ công:** Người dùng phải tự tay nhập số tiền, chọn danh mục chi tiêu cho từng giao dịch. Hành vi chuyển khoản ngân hàng thường có nội dung ngắn gọn, không dấu hoặc viết tắt khiến việc tự động hóa gặp khó khăn.
2. **Thiếu khả năng nhìn về tương lai (Reactive vs. Proactive):** Hầu hết các ứng dụng chỉ thống kê lịch sử quá khứ ("tháng này đã tiêu bao nhiêu"), không thể trả lời câu hỏi cốt lõi: *"Với tốc độ chi tiêu này, liệu 10-20 ngày tới tài khoản có bị thâm hụt trước khi nhận lương không?"*.
3. **Chi phí & Độ trễ tích hợp AI:** Việc phụ thuộc hoàn toàn vào các mô hình ngôn ngữ lớn trên đám mây (Cloud LLMs như OpenAI GPT-4, Google Gemini) cho mọi tác vụ gán nhãn giao dịch gây ra độ trễ cao (>1-2s), chi phí đắt đỏ và dễ chạm giới hạn tần suất (rate-limit).

### 1.2. Giải pháp đề xuất: Kiến trúc Hybrid AI & Hệ thống Bất đồng bộ
Hệ thống giải quyết bài toán bằng cách kết hợp:
* **Kiến trúc AI phân tầng (Tiered Hybrid AI):**
  * *Tầng 1 (Local/Edge - Low Latency < 50ms):* Fine-tune mô hình ngôn ngữ nhỏ gọn tiếng Việt (PhoBERT) để gán nhãn tự động nội dung chuyển khoản và mô hình học sâu chuỗi thời gian (DLinear/LSTM) để dự báo số dư/dòng tiền 7–30 ngày.
  * *Tầng 2 (Cloud LLM - Reasoning Engine):* Gemini API đóng vai trò Chuyên gia tư vấn tài chính (Financial Advisor), chỉ kích hoạt khi fallback gán nhãn ca khó và phân tích thói quen, lập kế hoạch tiết kiệm chuyên sâu.
* **Hạ tầng phân tán chịu tải cao (High Concurrency & Rate-limit Resilience):**
  * Sử dụng hàng đợi thông điệp (Message Broker: Redis/RabbitMQ kết hợp Celery) xử lý bất đồng bộ, tích hợp Exponential Backoff & Retry giải quyết triệt để bài toán nghẽn cổ chai rate-limit.
  * Container hóa toàn bộ hệ thống bằng Docker, triển khai mở rộng tự động với Kubernetes (HPA) và kiểm thử tải với Locust (chịu tải tăng gấp 10 lần).

---

## 2. KẾ HOẠCH THỰC HIỆN CHI TIẾT THEO GIAI ĐOẠN

Dự án được phân chia nghiêm ngặt thành 2 giai đoạn kế thừa lẫn nhau:

```
                  ┌─────────────────────────────────────────────────────────┐
                  │                 GIAI ĐOẠN 1: GIỮA KỲ                    │
                  │        Nghiên cứu, Huấn luyện & Bàn giao AI             │
                  └───────────────────────────┬─────────────────────────────┘
                                              │ Pipeline, Weights, Evaluated Models
                                              ▼
                  ┌─────────────────────────────────────────────────────────┐
                  │                 GIAI ĐOẠN 2: CUỐI KỲ                    │
                  │       Đóng gói Microservices, Web Fullstack & K8s       │
                  └─────────────────────────────────────────────────────────┘
```

### 2.1. GIAI ĐOẠN 1: GIỮA KỲ (Nghiên cứu & Thực nghiệm Mô hình AI)

#### A. Mục tiêu & Phạm vi
* Xây dựng bộ dữ liệu (dataset) tài chính cá nhân tiếng Việt chuẩn hóa.
* Huấn luyện và đánh giá mô hình phân loại giao dịch đa tầng (PhoBERT + LoRA vs. Gemini Fallback).
* Huấn luyện và thực nghiệm so sánh các mô hình dự báo chuỗi thời gian đa biến (ARIMA vs. LSTM/GRU vs. DLinear).
* Đo lường định lượng và bàn giao pipeline thực nghiệm hoàn chỉnh trên Google Colab/Jupyter Notebook.

#### B. Quy trình thực hiện chi tiết (Làm gì và Làm như thế nào?)

##### Bước 1: Xây dựng & Tiền xử lý Dataset (Data Engineering)
* **Dữ liệu phân loại văn bản (Transaction Text Classification):**
  * Thu thập/giả lập tập dữ liệu 5,000 - 10,000 giao dịch ngân hàng thực tế (sao kê MBBank, Vietcombank, Techcombank...).
  * Làm sạch text: Xử lý teencode, viết tắt (*"ck" -> "chuyển khoản"*, *"cf" -> "cà phê"*, *"an trua" -> "ăn trưa"*), chuẩn hóa unicode tiếng Việt, tách từ với `pyvi` hoặc `rdrsegmenter`.
  * Chuẩn hóa bộ nhãn phân loại (Taxonomy): 8 - 10 danh mục chính (Ăn uống, Hóa đơn dịch vụ, Nhà ở/Thuê trọ, Mua sắm, Di chuyển, Lương thưởng, Chuyển tiền cá nhân, Khác).
* **Dữ liệu chuỗi thời gian đa biến (Multivariate Time-Series):**
  * Cấu trúc đặc trưng: Thời gian (Timestamp), Số tiền thu/chi (Amount), Số dư lũy kế (Cumulative Balance), Chu kỳ nhận lương (Payroll Flag), Ngày trong tuần (Day of week - 0-6), Tính mùa vụ (Cuối tháng, Lễ tết).
  * Chuẩn hóa dữ liệu bằng `MinMaxScaler` hoặc `StandardScaler` để đảm bảo độ hội tụ cho Deep Learning.

##### Bước 2: Huấn luyện & Đánh giá Mô hình Phân loại Đa tầng
* **Tầng cục bộ (Local Model):**
  * Nền tảng: Mô hình ngôn ngữ `vinai/phobert-base-v2`.
  * Phương pháp: Ứng dụng kỹ thuật PEFT/LoRA (Parameter-Efficient Fine-Tuning) để tối ưu thời gian huấn luyện trên GPU T4 (Google Colab/Kaggle) mà vẫn giữ được độ chính xác cao.
  * Cơ chế định tuyến tự động (Routing Logic):
    $$	ext{Target} = egin{cases} 	ext{PhoBERT Output}, & 	ext{khi } \max(P) \ge 	au \ (	ext{ngưỡng tin cậy, ví dụ } 0.85) \ 	ext{Gemini API Fallback}, & 	ext{khi } \max(P) < 	au 	ext{ hoặc cấu trúc đa nghĩa} \end{cases}$$
* **Tầng dự phòng (Cloud Fallback):**
  * Prompt Engineering với Few-shot Learning và Structured Output (JSON Schema) cho Gemini 2.5 Flash / Flash-Lite nhằm trích xuất nhãn và độ tin cậy.

##### Bước 3: Nghiên cứu & Dự báo Dòng tiền Đa biến
* Triển khai mô hình cơ sở (Baseline): Mô hình thống kê truyền thống **ARIMA / SARIMAX**.
* Triển khai mô hình học sâu (Deep Learning): **LSTM / Bi-LSTM / GRU** và **DLinear** (Linear-based Time-Series Architecture).
* Dự báo đa bước (Multi-step Forecasting): Dự báo chuỗi 7 ngày và 30 ngày tiếp theo.
* Đánh giá so sánh định lượng:
  * Mean Absolute Error (MAE)
  * Root Mean Square Error (RMSE)
  * Mean Absolute Percentage Error (MAPE)
  * Độ trễ suy luận (Inference Latency tính bằng mili-giây).

##### Bước 4: Deliverables Giữa kỳ
1. `notebooks/01_nlp_phobert_finetune.ipynb`: Huấn luyện & đánh giá PhoBERT.
2. `notebooks/02_timeseries_forecasting.ipynb`: Thực nghiệm so sánh ARIMA vs LSTM vs DLinear.
3. `models/`: Trọng số mô hình đã huấn luyện (`phobert_lora_weights/`, `lstm_forecast.pt`).
4. `reports/Bao_cao_thuc_nghiem_giua_ky.pdf`: Đồ thị Training Loss, Bảng F1-score ma trận nhầm lẫn (Confusion Matrix), Biểu đồ đường dự báo dòng tiền vs thực tế.

---

### 2.2. GIAI ĐOẠN 2: CUỐI KỲ (Hệ thống Web Fullstack, Message Queue & DevOps K8s)

#### A. Mục tiêu & Phạm vi
* Xây dựng ứng dụng Web hoàn chỉnh phục vụ người dùng cuối.
* Đóng gói mô hình AI thành Microservices hiệu năng cao.
* Thiết kế kiến trúc chịu tải với Message Queue (Redis/RabbitMQ + Celery), xử lý giới hạn Rate-limit.
* Triển khai hạ tầng Container hóa (Docker, Docker Compose, Kubernetes) và Stress-test chứng minh khả năng chịu tải tăng 10 lần.

#### B. Quy trình thực hiện chi tiết

##### Bước 1: Thiết kế Kiến trúc Hệ thống & Cơ sở Dữ liệu
* **Kiến trúc phân tầng (Tiered Architecture):**
  * **Frontend Client (Next.js 14 App Router, TailwindCSS):** Giao diện Dashboard trực quan, tích hợp thư viện biểu đồ Recharts/Chart.js hiển thị dòng tiền lịch sử và đường dự báo 7–30 ngày.
  * **Backend API Gateway (FastAPI):** Tiếp nhận yêu cầu, xử lý nghiệp vụ xác thực (JWT), CRUD giao dịch, tương tác PostgreSQL.
  * **AI Worker / Microservice (Python / Celery):** Xử lý bất đồng bộ các tác vụ nặng: chạy mô hình dự báo định kỳ, gọi Gemini API phân tích báo cáo tuần/tháng.
  * **Message Broker & Cache (Redis / RabbitMQ):** Đệm hàng đợi yêu cầu và lưu trữ cache dự báo, cache session.
  * **Database (PostgreSQL):** Lưu trữ quan hệ thực thể người dùng, danh mục, giao dịch và lịch sử dự báo.

##### Bước 2: Xử lý Bài toán Rate-Limit & Scale x10 (Tư duy Phản biện)
* **Giải quyết nghẽn Rate-limit của Gemini API:**
  * Giới hạn thông thường của Gemini Free Tier là 15 RPM (Requests Per Minute). Khi có 200 người dùng đồng thời bấm "Tạo báo cáo chi tiêu", hệ thống không gọi trực tiếp API đồng bộ.
  * *Cơ chế giải quyết:* 
    1. Request được đóng gói thành Task đẩy vào **Redis Queue**.
    2. Backend trả về ngay mã Task ID (`HTTP 202 Accepted`) cho Client để Client không bị treo UI.
    3. **Celery Worker** sử dụng cơ chế Token Bucket / Rate Limiter để giới hạn tần suất gọi Gemini (ví dụ: tối đa 12 requests/phút).
    4. Tích hợp giải thuật **Exponential Backoff & Retry** khi gặp lỗi `HTTP 429 Too Many Requests`.
    5. Kết quả sau khi sinh xong được ghi vào PostgreSQL/Redis, đẩy thông báo về Client qua WebSocket hoặc Server-Sent Events (SSE).
* **Giải quyết bài toán tải tăng gấp 10 lần:**
  * Chia tách Backend phục vụ I/O và AI Inference Service thành 2 container riêng biệt.
  * Sử dụng Redis Cache cho các dữ liệu ít biến động (báo cáo tháng, danh mục).

##### Bước 3: DevOps, Container Hóa & Kubernetes Deployment
* **Docker hóa:** Viết `Dockerfile` tối ưu nhiều tầng (Multi-stage build) cho Next.js, FastAPI và Celery Worker.
* **Kubernetes (K8s) Orchestration:**
  * Viết các manifest `Deployment`, `Service`, `ConfigMap`, `Secret`, `Ingress`.
  * Cấu hình **Horizontal Pod Autoscaler (HPA)** dựa trên CPU/Memory Utilization (tự động mở rộng từ 2 pods lên 10 pods khi CPU đạt > 70%).
* **Kiểm thử tải (Stress Testing):**
  * Sử dụng **Locust** viết kịch bản giả lập hàng nghìn người dùng đồng thời thực hiện thao tác: Đăng nhập, thêm giao dịch, tải biểu đồ dự báo.
  * Lập báo cáo kiểm thử: Tỉ lệ thành công (Success Rate 99.x%), Response Time (P95, P99), biểu đồ K8s tự động scale-up pods khi tải tăng đột biến.

---

## 3. THIẾT KẾ CƠ SỞ DỮ LIỆU & KIẾN TRÚC DỮ LIỆU (DATA SCHEMA)

## 4. CẤU TRÚC KHO CHỨA MÃ NGUỒN TRÊN GITHUB (REPOSITORY STRUCTURE)

Dự án được tổ chức theo mô hình **Monorepo** rõ ràng, tạo sự liên kết mạch lạc giữa nghiên cứu giữa kỳ và mã nguồn cuối kỳ:

```text
financial-cashflow-ai-system/
├── .github/
│   └── workflows/
│       └── ci-cd.yml                # Pipeline kiểm tra lint, test tự động
├── docs/                            # Tài liệu phân tích, kiến trúc, báo cáo
│   ├── architectures/               # Sơ đồ C4, sequence diagram
│   ├── reports/                     # File PDF báo cáo giữa kỳ & cuối kỳ
│   └── api-spec.yaml                # OpenAPI / Swagger specs
├── mid-term-ai/                     # [GIAI ĐOẠN GIỮA KỲ] Không gian nghiên cứu AI
│   ├── data/
│   │   ├── raw/                     # Dữ liệu gốc thu thập
│   │   └── processed/               # Dữ liệu sau khi làm sạch & tokenize
│   ├── notebooks/
│   │   ├── 01_eda_and_cleaning.ipynb
│   │   ├── 02_phobert_classification.ipynb
│   │   └── 03_time_series_dlinear_lstm.ipynb
│   ├── models/                      # Trọng số mô hình đã huấn luyện (.pt, LoRA weights)
│   └── requirements-ai.txt          # PyTorch, Transformers, PEFT, Scikit-learn
├── backend/                         # [GIAI ĐOẠN CUỐI KỲ] FastAPI Application
│   ├── app/
│   │   ├── api/v1/                  # Router endpoints (auth, transactions, forecast)
│   │   ├── core/                    # Config, database connection, security
│   │   ├── models/                  # SQLAlchemy ORM models
│   │   ├── schemas/                 # Pydantic validation schemas
│   │   ├── services/                # Business logic
│   │   └── workers/                 # Celery task definitions, Gemini rate-limiter
│   ├── Dockerfile
│   └── requirements.txt
├── frontend/                        # [GIAI ĐOẠN CUỐI KỲ] Next.js Client App
│   ├── src/
│   │   ├── app/                     # Next.js App Router (pages & layouts)
│   │   ├── components/              # UI components (charts, forms, tables)
│   │   ├── hooks/                   # Custom hooks
│   │   └── lib/                     # API client, utility functions
│   ├── Dockerfile
│   └── package.json
├── k8s/                             # Manifests triển khai Kubernetes
│   ├── backend-deployment.yaml
│   ├── frontend-deployment.yaml
│   ├── celery-worker-deployment.yaml
│   ├── redis-deployment.yaml
│   ├── hpa.yaml                     # Cấu hình Horizontal Pod Autoscaler
│   └── ingress.yaml
├── load-test/                       # Kịch bản stress test hệ thống
│   ├── locustfile.py
│   └── run_test.sh
├── docker-compose.yml               # Môi trường chạy full-stack cục bộ
├── README.md                        # Giới thiệu tổng quan dự án trên GitHub
└── LICENSE
```

---

## 5. BẢNG PHÂN BỔ NHIỆM VỤ THỰC HIỆN TRONG NHÓM

Dự án phân chia công việc cho các thành viên đảm bảo tiến độ song song cả hai giai đoạn

## 6. KẾ HOẠCH BÀN GIAO & TIÊU CHÍ NGHIỆM THU (ACCEPTANCE CRITERIA)

### 6.1. Nghiệm thu Giữa kỳ
* **Mô hình NLP:** PhoBERT đạt F1-Score $\ge 88\%$ trên tập kiểm thử nội dung tiếng Việt. Độ trễ suy luận tầng cục bộ $< 50	ext{ms}$. Cơ chế Fallback sang Gemini kích hoạt chuẩn xác khi độ tin cậy thấp.
* **Mô hình Time-Series:** Mô hình học sâu (LSTM/DLinear) chứng minh được sai số MAPE thấp hơn rõ rệt so với Baseline ARIMA trên chuỗi dự báo 7 – 30 ngày.
* **Báo cáo:** Bản thuyết minh đầy đủ bảng so sánh định lượng, biểu đồ mất mát và mã nguồn Jupyter Notebook chạy tái lập kết quả 100%.

### 6.2. Nghiệm thu Cuối kỳ
* **Chức năng:** Người dùng tạo tài khoản, nhập giao dịch được tự động phân loại, xem báo cáo trực quan và biểu đồ dự báo số dư tương lai.
* **Độ bền hệ thống:** Khi gửi đồng loạt 100 requests yêu cầu phân tích LLM, hệ thống không bị lỗi 429 hoặc Crash nhờ hàng đợi Celery + Redis.
* **Khả năng co giãn (Scalability):** Dưới tải giả lập của Locust gấp 10 lần lưu lượng thông thường, Kubernetes tự động mở rộng số Pod (HPA) thành công, tỉ lệ phản hồi lỗi $< 1\%$.
