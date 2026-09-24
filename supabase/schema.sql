-- ==============================================================================
-- ĐỀ TÀI 17: HỆ THỐNG QUẢN LÝ TÀI CHÍNH CÁ NHÂN DỰ BÁO DÒNG TIỀN THÔNG MINH
-- (AI-DRIVEN CASH FLOW FORECASTING & FINANCIAL MANAGEMENT)
-- KIẾN TRÚC CƠ SỞ DỮ LIỆU POSTGRESQL TRÊN SUPABASE (CHUẨN PERFORMANCE & RLS)
-- ==============================================================================

-- Bật các extensions hữu ích của PostgreSQL
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ==============================================================================
-- 1. BẢNG HỒ SƠ NGƯỜI DÙNG (PROFILES - Liên kết auth.users)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email TEXT,
  full_name TEXT,
  avatar_url TEXT,
  currency TEXT NOT NULL DEFAULT 'VND',
  current_balance DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
  payroll_day INT CHECK (payroll_day BETWEEN 1 AND 31) DEFAULT 5, -- Ngày nhận lương (phục vụ mô hình AI dự báo)
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 2. BẢNG DANH MỤC CHI TIÊU & THU NHẬP (CATEGORIES)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.categories (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE, -- NULL nếu là danh mục mặc định của hệ thống
  name TEXT NOT NULL,
  icon TEXT NOT NULL DEFAULT 'category',
  color TEXT NOT NULL DEFAULT '#3ECF8E',
  is_income BOOLEAN NOT NULL DEFAULT false, -- true: Thu nhập, false: Chi tiêu
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 3. BẢNG GIAO DỊCH TÀI CHÍNH (TRANSACTIONS)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.transactions (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category_id BIGINT REFERENCES public.categories(id) ON DELETE SET NULL,
  amount DECIMAL(15, 2) NOT NULL CHECK (amount > 0),
  transaction_type TEXT NOT NULL CHECK (transaction_type IN ('income', 'expense')),
  raw_description TEXT, -- Nội dung sao kê ngân hàng gốc (VD: "MBBank CK an trua")
  clean_description TEXT, -- Nội dung đã làm sạch teencode & chuẩn hóa
  category_predicted TEXT, -- Danh mục do PhoBERT/Gemini gợi ý
  confidence_score NUMERIC(4, 3) DEFAULT 1.000, -- Điểm tin cậy của AI (0.000 -> 1.000)
  is_verified BOOLEAN NOT NULL DEFAULT true, -- Người dùng đã xác nhận phân loại
  transaction_date TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 4. BẢNG HẠN MỨC NGÂN SÁCH THÁNG (BUDGETS)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.budgets (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category_id BIGINT REFERENCES public.categories(id) ON DELETE CASCADE,
  month_year DATE NOT NULL, -- Tháng áp dụng (VD: '2026-10-01')
  limit_amount DECIMAL(15, 2) NOT NULL CHECK (limit_amount > 0),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT unique_user_category_month UNIQUE (user_id, category_id, month_year)
);

-- ==============================================================================
-- 5. BẢNG DỰ BÁO DÒNG TIỀN AI (CASHFLOW FORECASTS)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.cashflow_forecasts (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  forecast_date DATE NOT NULL,
  predicted_balance DECIMAL(15, 2) NOT NULL,
  predicted_income DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
  predicted_expense DECIMAL(15, 2) NOT NULL DEFAULT 0.00,
  risk_level TEXT NOT NULL CHECK (risk_level IN ('safe', 'warning', 'danger')) DEFAULT 'safe',
  model_name TEXT NOT NULL DEFAULT 'DLinear-v1', -- 'DLinear', 'LSTM', 'ARIMA'
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 6. BẢNG LỊCH SỬ TƯ VẤN TÀI CHÍNH GEMINI AI (AI CONSULTATIONS)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.ai_consultations (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  user_query TEXT NOT NULL,
  context_summary JSONB, -- Snapshot tài chính lúc hỏi: {"balance": 15000000, "spent_this_week": 2300000}
  ai_recommendation TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ==============================================================================
-- 7. BẢNG DÀNH CHO TEST NHANH (NOTES)
-- ==============================================================================
CREATE TABLE IF NOT EXISTS public.notes (
  id BIGINT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
  title TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ==============================================================================
-- TỐI ƯU HÓA HIỆU NĂNG: INDEXES CHO KHÓA NGOẠI VÀ TRUY VẤN TẦN SUẤT CAO
-- ==============================================================================
CREATE INDEX IF NOT EXISTS idx_categories_user_id ON public.categories(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user_id ON public.transactions(user_id);
CREATE INDEX IF NOT EXISTS idx_transactions_category_id ON public.transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_transactions_user_date ON public.transactions(user_id, transaction_date DESC);
CREATE INDEX IF NOT EXISTS idx_budgets_user_month ON public.budgets(user_id, month_year);
CREATE INDEX IF NOT EXISTS idx_forecasts_user_date ON public.cashflow_forecasts(user_id, forecast_date ASC);
CREATE INDEX IF NOT EXISTS idx_consultations_user_id ON public.ai_consultations(user_id);

-- ==============================================================================
-- TRIGGERS & FUNCTIONS TỰ ĐỘNG HÓA NGHIỆP VỤ
-- ==============================================================================

-- Function: Cập nhật cột updated_at tự động
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

CREATE OR REPLACE TRIGGER trg_transactions_updated_at
  BEFORE UPDATE ON public.transactions
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- Function: Tự động khởi tạo profile khi user đăng ký qua Supabase Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url, current_balance)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'avatar_url',
    0.00
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ==============================================================================
-- BẢO MẬT: ROW LEVEL SECURITY (RLS) THEO CHUẨN TỐI ƯU CỦA SUPABASE
-- (Dùng subquery (SELECT auth.uid()) để cache kết quả, tăng tốc 10x-100x)
-- ==============================================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cashflow_forecasts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_consultations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

-- 1. Policies cho profiles
CREATE POLICY "profiles_select_own" ON public.profiles
  FOR SELECT USING ((SELECT auth.uid()) = id);

CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING ((SELECT auth.uid()) = id);

-- 2. Policies cho categories (Xem danh mục mặc định hoặc của chính mình)
CREATE POLICY "categories_select" ON public.categories
  FOR SELECT USING (user_id IS NULL OR user_id = (SELECT auth.uid()));

CREATE POLICY "categories_insert" ON public.categories
  FOR INSERT WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "categories_update" ON public.categories
  FOR UPDATE USING (user_id = (SELECT auth.uid()));

CREATE POLICY "categories_delete" ON public.categories
  FOR DELETE USING (user_id = (SELECT auth.uid()));

-- 3. Policies cho transactions
CREATE POLICY "transactions_select_own" ON public.transactions
  FOR SELECT USING (user_id = (SELECT auth.uid()));

CREATE POLICY "transactions_insert_own" ON public.transactions
  FOR INSERT WITH CHECK (user_id = (SELECT auth.uid()));

CREATE POLICY "transactions_update_own" ON public.transactions
  FOR UPDATE USING (user_id = (SELECT auth.uid()));

CREATE POLICY "transactions_delete_own" ON public.transactions
  FOR DELETE USING (user_id = (SELECT auth.uid()));

-- 4. Policies cho budgets
CREATE POLICY "budgets_all_own" ON public.budgets
  FOR ALL USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- 5. Policies cho cashflow_forecasts
CREATE POLICY "forecasts_select_own" ON public.cashflow_forecasts
  FOR SELECT USING (user_id = (SELECT auth.uid()));

-- 6. Policies cho ai_consultations
CREATE POLICY "consultations_all_own" ON public.ai_consultations
  FOR ALL USING (user_id = (SELECT auth.uid()))
  WITH CHECK (user_id = (SELECT auth.uid()));

-- 7. Policy cho bảng test notes
CREATE POLICY "notes_public_access" ON public.notes
  FOR ALL USING (true) WITH CHECK (true);

-- ==============================================================================
-- DỮ LIỆU DANH MỤC MẪU (DEFAULT SYSTEM CATEGORIES)
-- ==============================================================================
INSERT INTO public.categories (name, icon, color, is_income, user_id) VALUES
  ('Lương & Thưởng', 'payments', '#10B981', true, NULL),
  ('Thu nhập phụ & Freelance', 'work', '#06B6D4', true, NULL),
  ('Lãi đầu tư & Cổ tức', 'trending_up', '#14B8A6', true, NULL),
  ('Ăn uống & Cà phê', 'restaurant', '#F59E0B', false, NULL),
  ('Nhà ở & Tiền điện nước', 'home', '#3B82F6', false, NULL),
  ('Mua sắm & Đồ gia dụng', 'shopping_bag', '#EC4899', false, NULL),
  ('Di chuyển & Xăng xe', 'directions_car', '#8B5CF6', false, NULL),
  ('Y tế & Sức khỏe', 'medical_services', '#EF4444', false, NULL),
  ('Giáo dục & Khóa học', 'school', '#6366F1', false, NULL),
  ('Giải trí & Du lịch', 'sports_esports', '#A855F7', false, NULL),
  ('Khác', 'more_horiz', '#64748B', false, NULL)
ON CONFLICT DO NOTHING;

-- ==============================================================================
-- VIEWS BÁO CÁO THỐNG KÊ (ANALYTICS VIEWS)
-- ==============================================================================

-- View: Cơ cấu chi tiêu theo danh mục trong tháng hiện tại
CREATE OR REPLACE VIEW public.v_current_month_spending_by_category AS
SELECT 
  t.user_id,
  c.id AS category_id,
  c.name AS category_name,
  c.color AS category_color,
  c.icon AS category_icon,
  SUM(t.amount) AS total_amount,
  COUNT(t.id) AS transaction_count
FROM public.transactions t
JOIN public.categories c ON t.category_id = c.id
WHERE t.transaction_type = 'expense'
  AND date_trunc('month', t.transaction_date) = date_trunc('month', CURRENT_DATE)
GROUP BY t.user_id, c.id, c.name, c.color, c.icon;
