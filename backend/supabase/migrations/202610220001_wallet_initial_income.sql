-- Explicitly record new-wallet funds as income, or reclassify an unused opening
-- balance. Account creation/adjustment and ledger insertion commit together.
BEGIN;

ALTER TABLE public.accounts
  ADD COLUMN IF NOT EXISTS initial_income_request_id text,
  ADD COLUMN IF NOT EXISTS initial_income_payload jsonb;
CREATE UNIQUE INDEX IF NOT EXISTS accounts_initial_income_request
  ON public.accounts(user_id, initial_income_request_id)
  WHERE initial_income_request_id IS NOT NULL;

CREATE OR REPLACE FUNCTION public.record_wallet_initial_income(
  p_account jsonb, p_request_id text, p_existing_account_id bigint DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql SECURITY INVOKER SET search_path = '' AS $$
DECLARE
  owner_id uuid := auth.uid();
  wallet public.accounts%ROWTYPE;
  amount numeric;
  payload jsonb := pg_catalog.jsonb_build_object(
    'account', p_account, 'existing_account_id', p_existing_account_id);
BEGIN
  IF owner_id IS NULL THEN
    RAISE EXCEPTION 'Authentication required' USING ERRCODE = '42501';
  END IF;
  IF p_request_id IS NULL OR p_request_id !~ '^[a-f0-9]{32}$' THEN
    RAISE EXCEPTION 'Mã yêu cầu không hợp lệ.' USING ERRCODE = '22023';
  END IF;
  PERFORM pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(owner_id::text || ':' || p_request_id, 0));
  SELECT * INTO wallet FROM public.accounts
    WHERE user_id = owner_id AND initial_income_request_id = p_request_id;
  IF FOUND THEN
    IF wallet.initial_income_payload IS DISTINCT FROM payload THEN
      RAISE EXCEPTION 'Yêu cầu đã được lưu với nội dung khác. Tải lại danh sách ví.'
        USING ERRCODE = '22023';
    END IF;
    RETURN pg_catalog.to_jsonb(wallet);
  END IF;

  IF p_existing_account_id IS NOT NULL THEN
    IF p_account IS NULL OR NOT (p_account ? 'expected_balance') OR
        (p_account - 'expected_balance') <> '{}'::jsonb THEN
      RAISE EXCEPTION 'Thiếu số dư xác nhận của ví.' USING ERRCODE = '22023';
    END IF;
    SELECT * INTO wallet FROM public.accounts
      WHERE id = p_existing_account_id AND user_id = owner_id FOR UPDATE;
    IF NOT FOUND OR wallet.is_archived THEN
      RAISE EXCEPTION 'Ví không tồn tại hoặc đã lưu trữ.' USING ERRCODE = '22023';
    END IF;
    IF wallet.initial_income_request_id IS NOT NULL OR EXISTS (
      SELECT 1 FROM public.transactions
      WHERE account_id = wallet.id OR to_account_id = wallet.id
    ) THEN
      RAISE EXCEPTION 'Ví đã có giao dịch. Chỉ ghi nhận số dư ban đầu của ví chưa có giao dịch.'
        USING ERRCODE = '22023';
    END IF;
    amount := wallet.balance;
    IF amount IS DISTINCT FROM (p_account->>'expected_balance')::numeric THEN
      RAISE EXCEPTION 'Số dư ví đã thay đổi. Tải lại ví trước khi xác nhận.' USING ERRCODE = '22023';
    END IF;
  ELSE
    IF p_account IS NULL OR pg_catalog.jsonb_typeof(p_account) <> 'object' THEN
      RAISE EXCEPTION 'Thiếu thông tin ví.' USING ERRCODE = '22023';
    END IF;
    amount := (p_account->>'balance')::numeric;
    IF COALESCE((p_account->>'is_archived')::boolean, false) THEN
      RAISE EXCEPTION 'Vui lòng chọn ví chưa lưu trữ.' USING ERRCODE = '22023';
    END IF;
  END IF;
  IF amount IS NULL OR amount <= 0 OR amount <> pg_catalog.round(amount, 2) THEN
    RAISE EXCEPTION 'Thu nhập phải lớn hơn 0 và tối đa 2 chữ số thập phân.'
      USING ERRCODE = '22023';
  END IF;

  IF p_existing_account_id IS NULL THEN
    INSERT INTO public.accounts (
      user_id, name, account_type, balance, currency, icon, color,
      account_number, institution_name, credit_limit, statement_day,
      payment_due_day, is_included_in_total, is_archived,
      initial_income_request_id, initial_income_payload
    ) VALUES (
      owner_id, p_account->>'name', p_account->>'account_type', 0,
      COALESCE(p_account->>'currency', 'VND'),
      COALESCE(p_account->>'icon', 'account_balance_wallet'),
      COALESCE(p_account->>'color', '#10B981'),
      p_account->>'account_number', p_account->>'institution_name',
      COALESCE((p_account->>'credit_limit')::numeric, 0),
      (p_account->>'statement_day')::integer, (p_account->>'payment_due_day')::integer,
      COALESCE((p_account->>'is_included_in_total')::boolean, true), false,
      p_request_id, payload
    ) RETURNING * INTO wallet;
  ELSE
    -- Reclassify existing funds: the income trigger restores the same balance.
    UPDATE public.accounts SET balance = 0,
      initial_income_request_id = p_request_id, initial_income_payload = payload
      WHERE id = wallet.id AND user_id = owner_id;
  END IF;
  INSERT INTO public.transactions (
    user_id, account_id, amount, transaction_type, transaction_date,
    raw_description, clean_description
  ) VALUES (
    owner_id, wallet.id, amount, 'income', pg_catalog.now(),
    'Thu nhập ban đầu vào ví ' || wallet.name,
    'Thu nhập ban đầu vào ví ' || wallet.name
  );
  SELECT * INTO wallet FROM public.accounts WHERE id = wallet.id AND user_id = owner_id;
  RETURN pg_catalog.to_jsonb(wallet);
END;
$$;

REVOKE ALL ON FUNCTION public.record_wallet_initial_income(jsonb, text, bigint) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.record_wallet_initial_income(jsonb, text, bigint) TO authenticated;
COMMIT;
