-- Ticket A: deterministic budget engine tables, RLS and the single-transaction
-- rebalance RPC. Apply after schema.sql and the previous migrations.
--
-- The budget plan is a projection of `public.budgets`, which stays the only
-- source of truth about envelope limits (ADR 0005). No language model writes
-- these tables; the API calls the RPC below.
BEGIN;

CREATE TABLE IF NOT EXISTS public.budget_plans (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title             TEXT NOT NULL DEFAULT 'Kế hoạch chi tiêu',
  status            TEXT NOT NULL DEFAULT 'COLLECTING'
                      CHECK (status IN ('COLLECTING','READY','ACTIVE','REBALANCED','EXPIRED','CANCELLED')),
  total_income      NUMERIC(15, 2) NOT NULL CHECK (total_income >= 0),
  duration_days     INT NOT NULL CHECK (duration_days BETWEEN 1 AND 365),
  savings_target    NUMERIC(15, 2) NOT NULL DEFAULT 0 CHECK (savings_target >= 0),
  fixed_expenses    NUMERIC(15, 2) NOT NULL DEFAULT 0 CHECK (fixed_expenses >= 0),
  start_date        DATE NOT NULL,
  spendable_budget  NUMERIC(15, 2) NOT NULL CHECK (spendable_budget > 0),
  daily_allowance   NUMERIC(15, 2) NOT NULL CHECK (daily_allowance >= 0),
  survival_floor    NUMERIC(15, 2),
  plan_version      INT NOT NULL DEFAULT 1 CHECK (plan_version >= 1),
  config_version    TEXT NOT NULL DEFAULT 'budget-engine-v1',
  idempotency_key   UUID,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT budget_plans_idempotency_unique UNIQUE (user_id, idempotency_key)
);

CREATE TABLE IF NOT EXISTS public.daily_allocations (
  id             BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  plan_id        BIGINT NOT NULL REFERENCES public.budget_plans(id) ON DELETE CASCADE,
  day_index      INT NOT NULL CHECK (day_index >= 1),
  alloc_date     DATE NOT NULL,
  group_key      TEXT NOT NULL CHECK (group_key IN ('food','transport','lifestyle','other')),
  pillar         TEXT NOT NULL CHECK (pillar IN ('needs','wants','culture','unexpected')),
  amount         NUMERIC(15, 2) NOT NULL CHECK (amount >= 0),
  actual_spent   NUMERIC(15, 2) NOT NULL DEFAULT 0 CHECK (actual_spent >= 0),
  CONSTRAINT daily_allocations_unique UNIQUE (plan_id, day_index, group_key)
);

CREATE TABLE IF NOT EXISTS public.budget_plan_events (
  id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  plan_id         BIGINT NOT NULL REFERENCES public.budget_plans(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  event_type      TEXT NOT NULL
                    CHECK (event_type IN ('CREATED','REBALANCED','PURCHASE_CONFIRMED','CANCELLED')),
  proposal        JSONB NOT NULL,
  accepted        JSONB NOT NULL,
  before_state    JSONB,
  after_state     JSONB,
  result          JSONB,
  idempotency_key UUID,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CONSTRAINT budget_plan_events_idempotency_unique UNIQUE (plan_id, idempotency_key)
);

CREATE INDEX IF NOT EXISTS idx_budget_plans_user_status
  ON public.budget_plans(user_id, status);
CREATE INDEX IF NOT EXISTS idx_daily_allocations_plan
  ON public.daily_allocations(plan_id, day_index);
CREATE INDEX IF NOT EXISTS idx_budget_plan_events_plan
  ON public.budget_plan_events(plan_id, created_at DESC);

ALTER TABLE public.budget_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_allocations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budget_plan_events ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "budget_plans_all_own" ON public.budget_plans;
CREATE POLICY "budget_plans_all_own" ON public.budget_plans FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "daily_allocations_own" ON public.daily_allocations;
CREATE POLICY "daily_allocations_own" ON public.daily_allocations FOR ALL
  USING (EXISTS (
    SELECT 1 FROM public.budget_plans p
    WHERE p.id = plan_id AND p.user_id = (SELECT auth.uid())
  ))
  WITH CHECK (EXISTS (
    SELECT 1 FROM public.budget_plans p
    WHERE p.id = plan_id AND p.user_id = (SELECT auth.uid())
  ));

DROP POLICY IF EXISTS "budget_plan_events_own" ON public.budget_plan_events;
CREATE POLICY "budget_plan_events_own" ON public.budget_plan_events FOR ALL
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP TRIGGER IF EXISTS trg_budget_plans_updated_at ON public.budget_plans;
CREATE TRIGGER trg_budget_plans_updated_at
  BEFORE UPDATE ON public.budget_plans
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

-- ---------------------------------------------------------------------------
-- Envelope capacity (ADR 0005)
-- ---------------------------------------------------------------------------
-- The sum of category limits inside a pillar must not exceed the pillar
-- envelope, and a pillar envelope must not exceed the monthly total budget.
-- Equality is allowed. A pillar without a configured envelope has no implicit
-- cap derived from its own category limits.
CREATE OR REPLACE FUNCTION public.validate_envelope_capacity(
  p_user_id uuid, p_month date
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_total numeric;
  v_pillar record;
  v_categories numeric;
BEGIN
  SELECT COALESCE(SUM(b.limit_amount), 0) INTO v_total
    FROM public.budgets b
   WHERE b.user_id = p_user_id
     AND b.category_id IS NULL
     AND b.pillar IS NULL
     AND b.month_year = p_month;

  FOR v_pillar IN
    SELECT b.pillar, SUM(b.limit_amount) AS envelope
      FROM public.budgets b
     WHERE b.user_id = p_user_id
       AND b.category_id IS NULL
       AND b.pillar IS NOT NULL
       AND b.month_year = p_month
     GROUP BY b.pillar
  LOOP
    IF v_total > 0 AND v_pillar.envelope > v_total THEN
      RAISE EXCEPTION 'Tổng ngân sách tháng không đủ cho trụ cột %', v_pillar.pillar
        USING ERRCODE = '23514';
    END IF;

    SELECT COALESCE(SUM(b.limit_amount), 0) INTO v_categories
      FROM public.budgets b
      JOIN public.categories c ON c.id = b.category_id
     WHERE b.user_id = p_user_id
       AND b.category_id IS NOT NULL
       AND b.month_year = p_month
       AND COALESCE(c.pillar, b.pillar) = v_pillar.pillar;

    IF v_categories > v_pillar.envelope THEN
      RAISE EXCEPTION 'Tổng hạn mức danh mục vượt hạn mức trụ cột %', v_pillar.pillar
        USING ERRCODE = '23514';
    END IF;
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.validate_envelope_capacity(uuid, date) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.validate_envelope_capacity(uuid, date) TO authenticated;

-- ---------------------------------------------------------------------------
-- Single-transaction rebalance
-- ---------------------------------------------------------------------------
-- Applies the new daily allocation, writes the confirmed purchase, updates
-- `actual_spent`, bumps `plan_version` and records the audit event in one
-- database transaction. A repeated `idempotency_key` returns the stored
-- result instead of writing twice.
CREATE OR REPLACE FUNCTION public.rebalance_plan(
  p_plan_id          bigint,
  p_expected_version int,
  p_allocations      jsonb,
  p_purchase         jsonb,
  p_idempotency_key  uuid
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  -- The SQL states this function raises. Naming them once keeps the
  -- meaning of every raise in one place.
  c_err_unauthenticated constant text := '42501';
  c_err_input          constant text := '22023';
  -- The allocation payload names the engine and the tables share.
  c_group_key          constant text := 'group_key';
  -- The status a plan carries after a rebalance.
  c_status_rebalanced  constant text := 'REBALANCED';
  v_owner uuid := auth.uid();
  v_plan  public.budget_plans%ROWTYPE;
  v_event public.budget_plan_events%ROWTYPE;
  v_item  jsonb;
  v_row   record;
  v_group text;
  v_pillar text;
  v_amount numeric;
  v_before jsonb := '{}'::jsonb;
  v_after  jsonb := '{}'::jsonb;
  v_pillar_before jsonb := '{}'::jsonb;
  v_pillar_after  jsonb := '{}'::jsonb;
  v_total_before numeric := 0;
  v_total_after  numeric := 0;
  v_transaction_id bigint;
  v_purchase_amount numeric := 0;
  v_account_id bigint;
  v_category_id bigint;
  v_description text;
  v_purchase_group text;
  v_day_index int;
  v_month date;
BEGIN
  IF v_owner IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = c_err_unauthenticated;
  END IF;
  IF p_idempotency_key IS NULL THEN
    RAISE EXCEPTION 'Thiếu idempotency key.' USING ERRCODE = c_err_input;
  END IF;

  SELECT * INTO v_plan FROM public.budget_plans
   WHERE id = p_plan_id AND user_id = v_owner
   FOR UPDATE;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Kế hoạch không khả dụng.' USING ERRCODE = c_err_unauthenticated;
  END IF;

  -- A repeated request returns the previous result without writing again.
  SELECT * INTO v_event FROM public.budget_plan_events
   WHERE plan_id = p_plan_id AND idempotency_key = p_idempotency_key;
  IF FOUND THEN
    RETURN COALESCE(v_event.result, '{}'::jsonb);
  END IF;

  IF v_plan.plan_version <> p_expected_version THEN
    -- PT409, not 40001: PostgREST treats a serialization failure as a
    -- transient error and retries it forever, so the request would hang
    -- instead of answering 409. A PT code carries the HTTP status directly.
    RAISE EXCEPTION 'Kế hoạch đã thay đổi, hãy tải lại.' USING ERRCODE = 'PT409';
  END IF;
  IF p_allocations IS NULL
     OR pg_catalog.jsonb_typeof(p_allocations) <> 'array' THEN
    RAISE EXCEPTION 'Danh sách phân bổ không hợp lệ.' USING ERRCODE = c_err_input;
  END IF;

  -- The current per-group daily amount is the "before" state.
  FOR v_row IN
    SELECT a.group_key, a.pillar, a.amount
      FROM public.daily_allocations a
     WHERE a.plan_id = p_plan_id
       AND a.day_index = 1
  LOOP
    v_before := v_before || pg_catalog.jsonb_build_object(
      v_row.group_key, v_row.amount);
    v_pillar_before := v_pillar_before || pg_catalog.jsonb_build_object(
      v_row.pillar, pg_catalog.jsonb_build_object(
        v_row.group_key, v_row.amount));
    v_total_before := v_total_before + v_row.amount;
  END LOOP;

  FOR v_item IN SELECT * FROM pg_catalog.jsonb_array_elements(p_allocations) LOOP
    v_group := v_item ->> c_group_key;
    v_pillar := v_item ->> 'pillar';
    v_amount := (v_item ->> 'daily_amount')::numeric;
    IF v_group IS NULL OR v_pillar IS NULL OR v_amount IS NULL THEN
      RAISE EXCEPTION 'Phân bổ thiếu trường bắt buộc.' USING ERRCODE = c_err_input;
    END IF;
    IF v_amount < 0 THEN
      RAISE EXCEPTION 'Hạn mức không được âm.' USING ERRCODE = c_err_input;
    END IF;
    IF v_group NOT IN ('food','transport','lifestyle','other') THEN
      RAISE EXCEPTION 'Nhóm chi tiêu không hợp lệ.' USING ERRCODE = c_err_input;
    END IF;
    IF v_pillar NOT IN ('needs','wants','culture','unexpected') THEN
      RAISE EXCEPTION 'Trụ cột không hợp lệ.' USING ERRCODE = c_err_input;
    END IF;
    IF NOT EXISTS (
      SELECT 1 FROM public.daily_allocations a
       WHERE a.plan_id = p_plan_id AND a.group_key = v_group
    ) THEN
      RAISE EXCEPTION 'Nhóm % không thuộc kế hoạch này.', v_group USING ERRCODE = c_err_input;
    END IF;
    v_after := v_after || pg_catalog.jsonb_build_object(v_group, v_amount);
    v_pillar_after := v_pillar_after || pg_catalog.jsonb_build_object(
      v_pillar, pg_catalog.jsonb_build_object(v_group, v_amount));
    v_total_after := v_total_after + v_amount;
  END LOOP;

  IF v_total_after > v_total_before THEN
    RAISE EXCEPTION 'Tổng hạn mức mới không được lớn hơn tổng hiện tại.'
      USING ERRCODE = c_err_input;
  END IF;

  v_month := v_plan.start_date - (EXTRACT(DAY FROM v_plan.start_date)::int - 1);
  PERFORM public.validate_envelope_capacity(v_owner, v_month);

  -- Apply the new daily amount to the days that are still ahead.
  FOR v_item IN SELECT * FROM pg_catalog.jsonb_array_elements(p_allocations) LOOP
    UPDATE public.daily_allocations a
       SET amount = (v_item ->> 'daily_amount')::numeric
     WHERE a.plan_id = p_plan_id
       AND a.group_key = v_item ->> c_group_key
       AND a.alloc_date >= CURRENT_DATE;
  END LOOP;

  -- Record the confirmed purchase and its effect on the day's actual spend.
  v_purchase_amount := COALESCE((p_purchase ->> 'amount')::numeric, 0);
  IF p_purchase IS NOT NULL AND v_purchase_amount > 0 THEN
    v_account_id := (p_purchase ->> 'account_id')::bigint;
    v_category_id := (p_purchase ->> 'category_id')::bigint;
    v_description := p_purchase ->> 'description';
    v_purchase_group := p_purchase ->> c_group_key;
    IF v_account_id IS NULL THEN
      RAISE EXCEPTION 'Cần chọn ví để ghi giao dịch.' USING ERRCODE = c_err_input;
    END IF;
    INSERT INTO public.transactions (
      user_id, account_id, amount, transaction_type, transaction_date,
      raw_description, clean_description, category_id
    ) VALUES (
      v_owner, v_account_id, v_purchase_amount, 'expense', pg_catalog.now(),
      v_description, v_description, v_category_id
    ) RETURNING id INTO v_transaction_id;

    v_day_index := GREATEST(1, (CURRENT_DATE - v_plan.start_date) + 1);
    UPDATE public.daily_allocations a
       SET actual_spent = a.actual_spent + v_purchase_amount
     WHERE a.plan_id = p_plan_id
       AND a.day_index = v_day_index
       AND a.group_key = COALESCE(v_purchase_group, a.group_key);
  END IF;

  UPDATE public.budget_plans
     SET plan_version = plan_version + 1,
         daily_allowance = v_total_after,
         status = c_status_rebalanced,
         updated_at = pg_catalog.now()
   WHERE id = p_plan_id;

  INSERT INTO public.budget_plan_events (
    plan_id, user_id, event_type, proposal, accepted,
    before_state, after_state, result, idempotency_key
  ) VALUES (
    p_plan_id, v_owner,
    CASE WHEN v_purchase_amount > 0
         THEN 'PURCHASE_CONFIRMED' ELSE c_status_rebalanced END,
    p_allocations, p_allocations,
    v_before, v_after,
    pg_catalog.jsonb_build_object(
      'plan_id', p_plan_id,
      'plan_version', v_plan.plan_version + 1,
      'rebalanced', true,
      'before', v_before,
      'after', v_after,
      'pillar_before', v_pillar_before,
      'pillar_after', v_pillar_after,
      'daily_allowance_before', v_total_before,
      'daily_allowance_after', v_total_after,
      'survival_floor', v_plan.survival_floor,
      'transaction_id', v_transaction_id,
      'warnings', '[]'::jsonb
    ),
    p_idempotency_key
  ) RETURNING * INTO v_event;

  RETURN v_event.result;
END;
$$;

REVOKE ALL ON FUNCTION public.rebalance_plan(bigint, int, jsonb, jsonb, uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.rebalance_plan(bigint, int, jsonb, jsonb, uuid) TO authenticated;

COMMIT;
