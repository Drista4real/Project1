-- B15: the live rebalance_plan is older than the repository definition.
--
-- 202611010001 was applied by hand in the SQL editor and edited in place
-- afterwards (named constants, PT409 instead of 40001), so the live body
-- still raises 40001 on a version conflict, which PostgREST does not turn
-- into the 409 the API expects (ADR 0009). Re-running 202611010001 is not an
-- option: it would also put back
-- the validate_envelope_capacity body that 202611230001 replaced (B13).
--
-- This file holds only rebalance_plan, with a body byte-identical to
-- 202611010001, followed by the grants 202611230001 leaves in place.
-- Signature and owner do not change. Safe to run again: CREATE OR REPLACE,
-- REVOKE and GRANT only. Rollback is a new forward migration.
BEGIN;

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

-- As after 202611230001: no EXECUTE for PUBLIC or anon.
REVOKE EXECUTE ON FUNCTION public.rebalance_plan(bigint, int, jsonb, jsonb, uuid)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.rebalance_plan(bigint, int, jsonb, jsonb, uuid)
  TO authenticated, service_role;

COMMIT;
