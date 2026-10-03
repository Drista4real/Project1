-- ==============================================================================
-- ĐỀ TÀI 17: HỆ THỐNG QUẢN LÝ TÀI CHÍNH CÁ NHÂN DỰ BÁO DÒNG TIỀN THÔNG MINH
-- (AI-DRIVEN CASH FLOW FORECASTING & FINANCIAL MANAGEMENT)
-- BẢN THIẾT KẾ CƠ SỞ DỮ LIỆU ĐẦY ĐỦ (COMPLETE DATABASE SCHEMA)
-- NỀN TẢNG: POSTGRESQL TRÊN SUPABASE (CHUẨN PERFORMANCE, RLS & TRIGGERS TỰ ĐỘNG)
-- ==============================================================================

-- Bật các extensions cần thiết
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ==============================================================================
-- 1. PHÂN HỆ NGƯỜI DÙNG & CẤU HÌNH CÁ NHÂN (USER & PROFILE)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  avatar_url TEXT,
  currency TEXT NOT NULL DEFAULT 'VND',
  current_balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
  payroll_day INT CHECK (payroll_day BETWEEN 1 AND 31) DEFAULT 5, -- Ngày nhận lương cố định (dùng cho AI dự báo)
  monthly_savings_target DECIMAL(15, 2) DEFAULT 0.00, -- Mục tiêu tiết kiệm hàng tháng
  reminder_time TIME DEFAULT '20:30:00', -- Giờ nhắc nhở ghi sổ hàng ngày
  biometrics_enabled BOOLEAN NOT NULL DEFAULT true,
  dark_mode_enabled BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 2. PHÂN HỆ TÀI KHOẢN & VÍ TIỀN (WALLETS / ACCOUNTS)
-- Cho phép quản lý tiền mặt, nhiều tài khoản ngân hàng, ví điện tử, thẻ tín dụng
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.accounts (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL, -- VD: "Ví Tiền Mặt", "MB Bank", "Vietcombank Digi", "Ví MoMo"
  account_type TEXT NOT NULL CHECK (account_type IN ('cash', 'bank', 'e_wallet', 'credit_card', 'investment', 'savings')),
  balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
  currency TEXT NOT NULL DEFAULT 'VND',
  icon TEXT NOT NULL DEFAULT 'account_balance_wallet',
  color TEXT NOT NULL DEFAULT '#10B981',
  account_number TEXT, -- 4 số cuối tài khoản/thẻ
  institution_name TEXT, -- Tên ngân hàng/tổ chức (VD: "MBBank", "VCB", "MoMo")
  credit_limit DECIMAL(15, 2) DEFAULT 0.00, -- Hạn mức nếu là credit_card
  statement_day INT CHECK (statement_day BETWEEN 1 AND 31), -- Ngày chốt sao kê thẻ tín dụng
  payment_due_day INT CHECK (payment_due_day BETWEEN 1 AND 31), -- Ngày đến hạn thanh toán
  is_included_in_total BOOLEAN NOT NULL DEFAULT true, -- Có cộng vào tổng tài sản khả dụng không
  is_archived BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 3. PHÂN HỆ DANH MỤC THU/CHI & 4 TRỤ CỘT KAKEIBO (CATEGORIES)
-- Hỗ trợ phân loại chuẩn Kakeibo: Thiết yếu (Needs), Mong muốn (Wants), Văn hóa (Culture), Dự phòng (Unexpected)
-- Hỗ trợ phân cấp danh mục cha - con (Parent - Subcategory)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.categories (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- NULL nếu là danh mục mặc định của hệ thống
  parent_id BIGINT REFERENCES public.categories(id) ON DELETE SET NULL, -- Danh mục cha (nếu là danh mục con)
  name TEXT NOT NULL,
  icon TEXT NOT NULL DEFAULT 'category',
  color TEXT NOT NULL DEFAULT '#3ECF8E',
  is_income BOOLEAN NOT NULL DEFAULT false, -- true: Thu nhập, false: Chi tiêu
  pillar TEXT CHECK (pillar IN ('needs', 'wants', 'culture', 'unexpected', 'income')) DEFAULT 'needs', -- 4 trụ cột Kakeibo
  display_order INT DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Bổ sung cho database đã có bảng categories từ phiên bản schema cũ.
-- CREATE TABLE IF NOT EXISTS không thêm các cột còn thiếu vào bảng hiện hữu.
ALTER TABLE public.categories
  ADD COLUMN IF NOT EXISTS parent_id BIGINT
  REFERENCES public.categories(id) ON DELETE SET NULL;

-- ==============================================================================
-- 4. PHÂN HỆ GIAO DỊCH TÀI CHÍNH (TRANSACTIONS)
-- Hỗ trợ: Thu (income), Chi (expense), Chuyển tiền giữa các ví (transfer)
-- Lưu trữ metadata bóc tách thông minh từ PhoBERT & Gemini
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.transactions (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  account_id BIGINT REFERENCES public.accounts(id) ON DELETE SET NULL, -- Ví nguồn
  to_account_id BIGINT REFERENCES public.accounts(id) ON DELETE SET NULL, -- Ví đích (nếu transaction_type = 'transfer')
  category_id BIGINT REFERENCES public.categories(id) ON DELETE SET NULL,
  amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense', 'transfer')),
  raw_description TEXT, -- Nội dung chuyển khoản SMS / sao kê gốc (VD: "MBBank GD: 45,000VND qua QR tại The Coffee House")
  clean_description TEXT, -- Nội dung chuẩn hóa sau khi tiền xử lý NLP
  category_predicted TEXT, -- Nhãn phân loại do PhoBERT/Gemini gợi ý
  confidence_score NUMERIC(4, 3) DEFAULT 1.000, -- Điểm tin cậy AI (0.000 -> 1.000)
  is_verified BOOLEAN NOT NULL DEFAULT true, -- Người dùng đã xác nhận phân loại đúng
  pillar TEXT CHECK (pillar IN ('needs', 'wants', 'culture', 'unexpected', 'income')), -- Trụ cột Kakeibo tương ứng
  receipt_url TEXT, -- Ảnh hóa đơn/chứng từ (lưu trữ trên Supabase Storage)
  transaction_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 5. PHÂN HỆ GẮN THẺ TÙY CHỌN (TAGS & TRANSACTION_TAGS)
-- Phục vụ tìm kiếm theo sự kiện: #dulich, #damcuoi, #quatet, #tiectung...
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.tags (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT DEFAULT '#64748B',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_user_tag UNIQUE (user_id, name)
);

CREATE TABLE IF NOT EXISTS public.transaction_tags (
  transaction_id BIGINT NOT NULL REFERENCES public.transactions(id) ON DELETE CASCADE,
  tag_id BIGINT NOT NULL REFERENCES public.tags(id) ON DELETE CASCADE,
  PRIMARY KEY (transaction_id, tag_id)
);

-- ==============================================================================
-- 6. PHÂN HỆ HẠN MỨC NGÂN SÁCH (BUDGETS)
-- Thiết lập ngân sách theo Tháng, theo từng Danh mục hoặc theo Trụ cột Kakeibo
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.budgets (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category_id BIGINT REFERENCES public.categories(id) ON DELETE CASCADE, -- NULL nếu là ngân sách theo Trụ cột Kakeibo
  pillar TEXT CHECK (pillar IN ('needs', 'wants', 'culture', 'unexpected')), -- NULL nếu là ngân sách theo Category
  month_year DATE NOT NULL, -- Tháng áp dụng (quy ước lưu ngày đầu tháng: '2026-10-01')
  limit_amount DECIMAL(15, 2) NOT NULL CHECK (limit_amount > 0),
  alert_threshold_percent INT DEFAULT 80 CHECK (alert_threshold_percent BETWEEN 1 AND 100), -- Ngưỡng cảnh báo (mặc định 80%)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT check_budget_target CHECK (
    (category_id IS NOT NULL AND pillar IS NULL) OR 
    (category_id IS NULL AND pillar IS NOT NULL) OR
    (category_id IS NULL AND pillar IS NULL) -- Ngân sách tổng cho toàn bộ chi tiêu tháng
  )
);

-- ==============================================================================
-- 7. PHÂN HỆ MỤC TIÊU TIẾT KIỆM & HŨ TIỀN (SAVING GOALS / POCKETS)
-- Ví dụ: Quỹ khẩn cấp 6 tháng, Mua xe máy, Du lịch, Quỹ học tập
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.saving_goals (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  account_id BIGINT REFERENCES public.accounts(id) ON DELETE SET NULL, -- Tài khoản/Ví giữ tiền tiết kiệm (nếu có)
  name TEXT NOT NULL,
  target_amount DECIMAL(15, 2) NOT NULL CHECK (target_amount > 0),
  current_amount DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
  target_date DATE,
  color TEXT DEFAULT '#10B981',
  icon TEXT DEFAULT 'savings',
  status TEXT NOT NULL CHECK (status IN ('in_progress', 'completed', 'cancelled')) DEFAULT 'in_progress',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 8. PHÂN HỆ QUẢN LÝ SỔ NỢ & CHO VAY (DEBTS & LOANS)
-- Quản lý: Mình đi mượn (debt) hoặc Mình cho vay (loan), hạn trả và nhắc nợ
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.debts_loans (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('debt', 'loan')), -- 'debt': Đi vay; 'loan': Cho vay
  person_name TEXT NOT NULL, -- Tên đối tác, người quen, ngân hàng
  phone_number TEXT,
  amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
  paid_amount DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
  due_date DATE, -- Ngày hẹn thanh toán
  interest_rate DECIMAL(5, 2) DEFAULT 0.00, -- % Lãi suất/năm (nếu có)
  status TEXT NOT NULL CHECK (status IN ('pending', 'partial', 'paid', 'overdue')) DEFAULT 'pending',
  notes TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 9. PHÂN HỆ GIAO DỊCH ĐỊNH KỲ / HÓA ĐƠN ĐẾN HẠN (RECURRING BILLS & TRANSACTIONS)
-- Tiền nhà, tiền điện, mạng internet, gói dịch vụ Netflix, Spotify, gym...
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.recurring_transactions (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  account_id BIGINT REFERENCES public.accounts(id) ON DELETE SET NULL,
  category_id BIGINT REFERENCES public.categories(id) ON DELETE SET NULL,
  amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense')),
  description TEXT NOT NULL,
  frequency TEXT NOT NULL CHECK (frequency IN ('daily', 'weekly', 'biweekly', 'monthly', 'quarterly', 'yearly')),
  start_date DATE NOT NULL,
  end_date DATE,
  next_execution_date DATE NOT NULL,
  auto_create BOOLEAN NOT NULL DEFAULT true, -- Tự động tạo record transaction khi đến ngày
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 10. PHÂN HỆ DỰ BÁO DÒNG TIỀN AI (CASHFLOW FORECASTS - DLinear / LSTM)
-- Dữ liệu chuỗi thời gian dự báo số dư 7 - 30 ngày, phục vụ biểu đồ tương lai
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.cashflow_forecasts (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  forecast_date DATE NOT NULL,
  predicted_balance DECIMAL(15, 2) NOT NULL,
  predicted_income DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
  predicted_expense DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
  lower_bound DECIMAL(15, 2), -- Khoảng tin cậy cận dưới (Confidence Interval)
  upper_bound DECIMAL(15, 2), -- Khoảng tin cậy cận trên
  risk_level TEXT NOT NULL CHECK (risk_level IN ('safe', 'warning', 'danger')) DEFAULT 'safe',
  model_name TEXT NOT NULL DEFAULT 'DLinear-v1', -- 'DLinear', 'LSTM', 'ARIMA'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 11. PHÂN HỆ CẢNH BÁO THÂM HỤT & RỦI RO DÒNG TIỀN (CASHFLOW ALERTS)
-- Tự động sinh cảnh báo khi AI phát hiện số dư có nguy cơ âm trước ngày nhận lương
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.cashflow_alerts (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  alert_type TEXT NOT NULL CHECK (alert_type IN ('deficit_risk', 'budget_exceeded', 'unusual_expense', 'low_balance', 'bill_due')),
  severity TEXT NOT NULL CHECK (severity IN ('info', 'warning', 'critical')) DEFAULT 'warning',
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  predicted_deficit_date DATE,
  predicted_deficit_amount DECIMAL(15, 2),
  suggested_action TEXT, -- Đề xuất khắc phục (VD: "Cắt giảm 30% chi tiêu Mong muốn để duy trì số dư dương")
  is_read BOOLEAN NOT NULL DEFAULT false,
  is_resolved BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 12. PHÂN HỆ TRỢ LÝ TÀI CHÍNH GEMINI AI (CONSULTATIONS & CONVERSATIONS)
-- ==============================================================================
-- Bảng lịch sử câu hỏi nhanh (Backward-compatibility)
CREATE TABLE IF NOT EXISTS public.ai_consultations (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_query TEXT NOT NULL,
  context_summary JSONB, -- Snapshot: {"current_balance": 15000000, "burn_rate": 350000, "days_to_payroll": 12}
  ai_recommendation TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Bảng phiên hội thoại tư vấn liên tục (Chat Sessions)
CREATE TABLE IF NOT EXISTS public.ai_chat_sessions (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT 'Cuộc trò chuyện tư vấn',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Bảng tin nhắn chi tiết trong từng phiên hội thoại
CREATE TABLE IF NOT EXISTS public.ai_chat_messages (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  session_id BIGINT NOT NULL REFERENCES public.ai_chat_sessions(id) ON DELETE CASCADE,
  sender TEXT NOT NULL CHECK (sender IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  context_snapshot JSONB, -- Dữ liệu tài chính người dùng gửi kèm cho AI phân tích
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 13. BẢNG KIỂM TRA KẾT NỐI (NOTES)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.notes (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  title TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- TỐI ƯU HÓA HIỆU NĂNG: INDEXES CHO KHÓA NGOẠI VÀ CÁC TRUY VẤN TẦN SUẤT CAO
-- ==============================================================================
-- Accounts
CREATE INDEX IF NOT EXISTS idx_accounts_user_id ON public.accounts(user_id);

-- Categories
CREATE INDEX IF NOT EXISTS idx_categories_user_id ON public.categories(user_id);
CREATE INDEX IF NOT EXISTS idx_categories_parent_id ON public.categories(parent_id);
CREATE INDEX IF NOT EXISTS idx_categories_pillar ON public.categories(pillar);

-- Transactions (Rất quan trọng cho query list & aggregate)
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_account_id ON public.transactions(account_id);
CREATE INDEX IF NOT EXISTS idx_transactions_category_id ON public.transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON public.transactions(user_id, transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON public.transactions(user_id, transaction_type);
CREATE INDEX IF NOT EXISTS idx_transactions_pillar ON public.transactions(user_id, pillar);

-- Tags
CREATE INDEX IF NOT EXISTS idx_tags_user_id ON public.tags(user_id);
CREATE INDEX IF NOT EXISTS idx_transaction_tags_tag_id ON public.transaction_tags(tag_id);

-- Budgets
CREATE INDEX IF NOT EXISTS idx_budgets_user_month ON public.budgets(user_id, month_year);
CREATE INDEX IF NOT EXISTS idx_budgets_category ON public.budgets(category_id);

-- Saving Goals & Debts
CREATE INDEX IF NOT EXISTS idx_saving_goals_user ON public.saving_goals(user_id);
CREATE INDEX IF NOT EXISTS idx_debts_loans_user ON public.debts_loans(user_id, status);

-- Recurring Transactions
CREATE INDEX IF NOT EXISTS idx_recurring_next_exec ON public.recurring_transactions(next_execution_date, is_active);

-- Forecasts & Alerts
CREATE INDEX IF NOT EXISTS idx_forecasts_user_date ON public.cashflow_forecasts(user_id, forecast_date ASC);
CREATE INDEX IF NOT EXISTS idx_alerts_user_unread ON public.cashflow_alerts(user_id, is_read);

-- AI Chats
CREATE INDEX IF NOT EXISTS idx_consultations_user_id ON public.ai_consultations(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_sessions_user ON public.ai_chat_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_session ON public.ai_chat_messages(session_id, created_at ASC);

-- ==============================================================================
-- TRIGGERS & FUNCTIONS TỰ ĐỘNG HÓA NGHIỆP VỤ (BUSINESS LOGIC AUTOMATION)
-- ==============================================================================

-- 1. Function tự động cập nhật timestamp updated_at
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_profiles_updated_at
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE TRIGGER trg_accounts_updated_at
  BEFORE UPDATE ON public.accounts
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE TRIGGER trg_transactions_updated_at
  BEFORE UPDATE ON public.transactions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE TRIGGER trg_saving_goals_updated_at
  BEFORE UPDATE ON public.saving_goals
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE TRIGGER trg_debts_loans_updated_at
  BEFORE UPDATE ON public.debts_loans
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE TRIGGER trg_ai_chat_sessions_updated_at
  BEFORE UPDATE ON public.ai_chat_sessions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- 2. Function & Trigger: Tự động khởi tạo Profile & Ví Tiền Mặt khi có User đăng ký
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  new_account_id BIGINT;
BEGIN
  -- Tạo Profile
  INSERT INTO public.profiles (id, email, full_name, avatar_url, current_balance)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'avatar_url',
    0.00
  )
  ON CONFLICT (id) DO NOTHING;

  -- Tự động tạo một Ví mặc định: "Tiền mặt"
  INSERT INTO public.accounts (user_id, name, account_type, balance, currency, icon, color)
  VALUES (
    NEW.id,
    'Ví Tiền Mặt',
    'cash',
    0.00,
    'VND',
    'account_balance_wallet',
    '#10B981'
  )
  RETURNING id INTO new_account_id;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3. Function & Trigger: Tự động cập nhật số dư Ví (accounts.balance) và Profile (profiles.current_balance) khi có giao dịch
CREATE OR REPLACE FUNCTION public.update_account_and_profile_balance()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_delta DECIMAL(15, 2);
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_user_id := NEW.user_id;

    -- Điều chỉnh số dư ví nguồn
    IF NEW.account_id IS NOT NULL THEN
      IF NEW.transaction_type = 'income' THEN
        UPDATE public.accounts SET balance = balance + NEW.amount WHERE id = NEW.account_id;
      ELSIF NEW.transaction_type IN ('expense', 'transfer') THEN
        UPDATE public.accounts SET balance = balance - NEW.amount WHERE id = NEW.account_id;
      END IF;
    END IF;

    -- Điều chỉnh số dư ví đích (nếu là giao dịch chuyển khoản transfer)
    IF NEW.transaction_type = 'transfer' AND NEW.to_account_id IS NOT NULL THEN
      UPDATE public.accounts SET balance = balance + NEW.amount WHERE id = NEW.to_account_id;
    END IF;

  ELSIF TG_OP = 'DELETE' THEN
    v_user_id := OLD.user_id;

    -- Đảo ngược số dư ví nguồn
    IF OLD.account_id IS NOT NULL THEN
      IF OLD.transaction_type = 'income' THEN
        UPDATE public.accounts SET balance = balance - OLD.amount WHERE id = OLD.account_id;
      ELSIF OLD.transaction_type IN ('expense', 'transfer') THEN
        UPDATE public.accounts SET balance = balance + OLD.amount WHERE id = OLD.account_id;
      END IF;
    END IF;

    -- Đảo ngược ví đích của transfer
    IF OLD.transaction_type = 'transfer' AND OLD.to_account_id IS NOT NULL THEN
      UPDATE public.accounts SET balance = balance - OLD.amount WHERE id = OLD.to_account_id;
    END IF;

  ELSIF TG_OP = 'UPDATE' THEN
    v_user_id := NEW.user_id;

    -- 1. Hoàn nguyên số dư cũ
    IF OLD.account_id IS NOT NULL THEN
      IF OLD.transaction_type = 'income' THEN
        UPDATE public.accounts SET balance = balance - OLD.amount WHERE id = OLD.account_id;
      ELSIF OLD.transaction_type IN ('expense', 'transfer') THEN
        UPDATE public.accounts SET balance = balance + OLD.amount WHERE id = OLD.account_id;
      END IF;
    END IF;
    IF OLD.transaction_type = 'transfer' AND OLD.to_account_id IS NOT NULL THEN
      UPDATE public.accounts SET balance = balance - OLD.amount WHERE id = OLD.to_account_id;
    END IF;

    -- 2. Cộng dồn số dư mới
    IF NEW.account_id IS NOT NULL THEN
      IF NEW.transaction_type = 'income' THEN
        UPDATE public.accounts SET balance = balance + NEW.amount WHERE id = NEW.account_id;
      ELSIF NEW.transaction_type IN ('expense', 'transfer') THEN
        UPDATE public.accounts SET balance = balance - NEW.amount WHERE id = NEW.account_id;
      END IF;
    END IF;
    IF NEW.transaction_type = 'transfer' AND NEW.to_account_id IS NOT NULL THEN
      UPDATE public.accounts SET balance = balance + NEW.amount WHERE id = NEW.to_account_id;
    END IF;
  END IF;

  -- Đồng bộ lại tổng số dư khả dụng vào bảng profiles
  UPDATE public.profiles
  SET current_balance = COALESCE((
    SELECT SUM(balance)
    FROM public.accounts
    WHERE user_id = v_user_id AND is_included_in_total = true
  ), 0.00)
  WHERE id = v_user_id;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER trg_sync_transaction_balance
  AFTER INSERT OR UPDATE OR DELETE ON public.transactions
  FOR EACH ROW EXECUTE FUNCTION public.update_account_and_profile_balance();

-- ==============================================================================
-- BẢO MẬT DỮ LIỆU: ROW LEVEL SECURITY (RLS) CHUẨN TỐI ƯU SUPABASE
-- Sử dụng cú pháp cached subquery: (SELECT auth.uid()) = user_id
-- ==============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transaction_tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.saving_goals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.debts_loans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.recurring_transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_forecasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_chat_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_chat_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

-- 1. Profiles
CREATE POLICY "profiles_select_own" ON public.profiles FOR SELECT USING ((SELECT auth.uid()) = id);
CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE USING ((SELECT auth.uid()) = id);

-- 2. Accounts
CREATE POLICY "accounts_all_own" ON public.accounts FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- 3. Categories (Xem được category chung hệ thống và riêng của mình)
CREATE POLICY "categories_select" ON public.categories FOR SELECT
  USING (user_id IS NULL OR user_id = (SELECT auth.uid()));
CREATE POLICY "categories_insert" ON public.categories FOR INSERT
  WITH CHECK (user_id = (SELECT auth.uid()));
CREATE POLICY "categories_update" ON public.categories FOR UPDATE
  USING (user_id = (SELECT auth.uid()));
CREATE POLICY "categories_delete" ON public.categories FOR DELETE
  USING (user_id = (SELECT auth.uid()));

-- 4. Transactions
CREATE POLICY "transactions_all_own" ON public.transactions FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- 5. Tags & Transaction Tags
CREATE POLICY "tags_all_own" ON public.tags FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "transaction_tags_all_own" ON public.transaction_tags FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.transactions t 
    WHERE t.id = transaction_id AND t.user_id = (SELECT auth.uid())
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.transactions t 
    WHERE t.id = transaction_id AND t.user_id = (SELECT auth.uid())
  ));

-- 6. Budgets
CREATE POLICY "budgets_all_own" ON public.budgets FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- 7. Saving Goals
CREATE POLICY "saving_goals_all_own" ON public.saving_goals FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- 8. Debts & Loans
CREATE POLICY "debts_loans_all_own" ON public.debts_loans FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- 9. Recurring Transactions
CREATE POLICY "recurring_all_own" ON public.recurring_transactions FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- 10. Forecasts & Alerts
CREATE POLICY "forecasts_all_own" ON public.cashflow_forecasts FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "alerts_all_own" ON public.cashflow_alerts FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

-- 11. AI Consultations & Chats
CREATE POLICY "consultations_all_own" ON public.ai_consultations FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "chat_sessions_all_own" ON public.ai_chat_sessions FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

CREATE POLICY "chat_messages_all_own" ON public.ai_chat_messages FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.ai_chat_sessions s 
    WHERE s.id = session_id AND s.user_id = (SELECT auth.uid())
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.ai_chat_sessions s 
    WHERE s.id = session_id AND s.user_id = (SELECT auth.uid())
  ));

-- 12. Notes (bảng test)
CREATE POLICY "notes_public_access" ON public.notes FOR ALL USING (true) WITH CHECK (true);

-- ==============================================================================
-- DỮ LIỆU DANH MỤC MẪU CHUẨN KAKEIBO (SYSTEM DEFAULT CATEGORIES)
-- ==============================================================================
INSERT INTO public.categories (name, icon, color, is_income, pillar, user_id) VALUES
  -- Thu nhập (Income)
  ('Lương & Thưởng', 'payments', '#10B981', true, 'income', NULL),
  ('Thu nhập phụ & Freelance', 'work', '#06B6D4', true, 'income', NULL),
  ('Lãi đầu tư & Cổ tức', 'trending_up', '#14B8A6', true, 'income', NULL),
  ('Được tặng & Trợ cấp', 'card_giftcard', '#3B82F6', true, 'income', NULL),

  -- Trụ cột Kakeibo 1: Thiết yếu (Needs - Seikatsu)
  ('Ăn uống & Đi chợ', 'restaurant', '#285B45', false, 'needs', NULL),
  ('Tiền thuê nhà & Chung cư', 'home', '#3B82F6', false, 'needs', NULL),
  ('Hóa đơn điện nước & Internet', 'receipt_long', '#0284C7', false, 'needs', NULL),
  ('Xăng xe & Giao thông', 'directions_car', '#64748B', false, 'needs', NULL),
  ('Khám chữa bệnh & Thuốc men', 'medical_services', '#EF4444', false, 'needs', NULL),

  -- Trụ cột Kakeibo 2: Mong muốn (Wants - Morau)
  ('Cà phê & Gặp gỡ bạn bè', 'local_cafe', '#B64F2D', false, 'wants', NULL),
  ('Mua sắm quần áo & Phụ kiện', 'shopping_bag', '#EC4899', false, 'wants', NULL),
  ('Giải trí, Xem phim & Game', 'sports_esports', '#8B5CF6', false, 'wants', NULL),
  ('Du lịch & Nghỉ dưỡng', 'flight_takeoff', '#F59E0B', false, 'wants', NULL),

  -- Trụ cột Kakeibo 3: Văn hóa & Phát triển (Culture - Kyoyo)
  ('Sách báo & Tri thức', 'menu_book', '#15936D', false, 'culture', NULL),
  ('Khóa học & Kỹ năng mới', 'school', '#6366F1', false, 'culture', NULL),
  ('Tập thể thao & Gym', 'fitness_center', '#10B981', false, 'culture', NULL),

  -- Trụ cột Kakeibo 4: Dự phòng & Bất thường (Unexpected - Yobi)
  ('Hiếu hỷ, Cưới hỏi & Quà tặng', 'volunteer_activism', '#D97706', false, 'unexpected', NULL),
  ('Sửa chữa xe cộ & Đồ gia dụng', 'build', '#717973', false, 'unexpected', NULL),
  ('Chi phí phát sinh khác', 'more_horiz', '#94A3B8', false, 'unexpected', NULL)
ON CONFLICT DO NOTHING;

-- ==============================================================================
-- CÁC VIEWS THỐNG KÊ & BÁO CÁO TÀI CHÍNH TỰ ĐỘNG (ANALYTICS VIEWS)
-- ==============================================================================

-- 1. View: Báo cáo cơ cấu chi tiêu theo Danh mục trong tháng hiện tại
CREATE OR REPLACE VIEW public.v_current_month_spending_by_category AS
SELECT 
  t.user_id,
  c.id AS category_id,
  c.name AS category_name,
  c.color AS category_color,
  c.icon AS category_icon,
  c.pillar AS category_pillar,
  SUM(t.amount) AS total_amount,
  COUNT(t.id) AS transaction_count
FROM public.transactions t
JOIN public.categories c ON t.category_id = c.id
WHERE t.transaction_type = 'expense'
  AND date_trunc('month', t.transaction_date) = date_trunc('month', CURRENT_DATE)
GROUP BY t.user_id, c.id, c.name, c.color, c.icon, c.pillar;

-- 2. View: Báo cáo chi tiêu theo 4 Trụ cột Kakeibo trong tháng hiện tại
CREATE OR REPLACE VIEW public.v_kakeibo_monthly_summary AS
SELECT
  t.user_id,
  date_trunc('month', t.transaction_date)::DATE AS month_year,
  COALESCE(t.pillar, c.pillar, 'needs') AS pillar,
  SUM(t.amount) AS total_spent,
  COUNT(t.id) AS transaction_count
FROM public.transactions t
LEFT JOIN public.categories c ON t.category_id = c.id
WHERE t.transaction_type = 'expense'
GROUP BY t.user_id, date_trunc('month', t.transaction_date), COALESCE(t.pillar, c.pillar, 'needs');

-- 3. View: Tiến độ hạn mức ngân sách tháng hiện tại
CREATE OR REPLACE VIEW public.v_monthly_budget_progress AS
SELECT
  b.id AS budget_id,
  b.user_id,
  b.month_year,
  b.limit_amount,
  b.alert_threshold_percent,
  b.category_id,
  c.name AS category_name,
  b.pillar,
  COALESCE(SUM(t.amount), 0.00) AS current_spent,
  (b.limit_amount - COALESCE(SUM(t.amount), 0.00)) AS remaining_amount,
  ROUND((COALESCE(SUM(t.amount), 0.00) / b.limit_amount * 100), 1) AS percent_used
FROM public.budgets b
LEFT JOIN public.categories c ON b.category_id = c.id
LEFT JOIN public.transactions t ON t.user_id = b.user_id
  AND t.transaction_type = 'expense'
  AND date_trunc('month', t.transaction_date) = b.month_year
  AND (
    (b.category_id IS NOT NULL AND t.category_id = b.category_id) OR
    (b.pillar IS NOT NULL AND (t.pillar = b.pillar OR c.pillar = b.pillar)) OR
    (b.category_id IS NULL AND b.pillar IS NULL) -- Tổng chi
  )
GROUP BY b.id, b.user_id, b.month_year, b.limit_amount, b.alert_threshold_percent, b.category_id, c.name, b.pillar;
