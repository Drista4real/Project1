-- B13: signed-out clients must not run SECURITY DEFINER functions.
--
-- The default privileges of schema `public` grant EXECUTE on every new
-- function to `anon`, and the earlier migrations only revoked it FROM PUBLIC.
-- `validate_envelope_capacity` also trusted its `p_user_id`, so any caller
-- could probe another user's envelopes with the owner's BYPASSRLS rights.
--
-- Independent of 202611010003 and safe to run again: every statement is a
-- CREATE OR REPLACE, a REVOKE or a guarded loop. Signatures do not change.
-- Rollback is a new forward migration that grants EXECUTE back to anon.
BEGIN;

-- A caller may only check their own envelopes. Body otherwise as in
-- 202611010001; rebalance_plan already passes auth.uid().
CREATE OR REPLACE FUNCTION public.validate_envelope_capacity(
  p_user_id uuid, p_month date
) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_total numeric;
  v_pillar record;
  v_categories numeric;
BEGIN
  IF p_user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'Không được kiểm tra ngân sách của người dùng khác.'
      USING ERRCODE = '42501';
  END IF;

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

-- Pin an empty search_path (lint 0011). Bodies as in schema.sql with every
-- reference schema-qualified.
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  NEW.updated_at = pg_catalog.now();
  RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  new_account_id BIGINT;
BEGIN
  INSERT INTO public.profiles (id, email, full_name, avatar_url, current_balance)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', pg_catalog.split_part(NEW.email, '@', 1)),
    NEW.raw_user_meta_data->>'avatar_url',
    0.00
  )
  ON CONFLICT (id) DO NOTHING;

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
$$;

CREATE OR REPLACE FUNCTION public.update_account_and_profile_balance()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_user_id UUID;
  v_delta DECIMAL(15, 2);
BEGIN
  IF TG_OP = 'INSERT' THEN
    v_user_id := NEW.user_id;
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

  ELSIF TG_OP = 'DELETE' THEN
    v_user_id := OLD.user_id;
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

  ELSIF TG_OP = 'UPDATE' THEN
    v_user_id := NEW.user_id;
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

  UPDATE public.profiles
  SET current_balance = COALESCE((
    SELECT pg_catalog.sum(balance)
    FROM public.accounts
    WHERE user_id = v_user_id AND is_included_in_total = true
  ), 0.00)
  WHERE id = v_user_id;

  RETURN NULL;
END;
$$;

-- anon inherits EXECUTE through PUBLIC as well as its own grant. authenticated
-- and service_role keep their explicit grants; triggers need none to fire.
REVOKE EXECUTE ON FUNCTION
  public.validate_envelope_capacity(uuid, date),
  public.rebalance_plan(bigint, int, jsonb, jsonb, uuid),
  public.handle_new_user(),
  public.sync_auth_profile_email(),
  public.update_account_and_profile_balance(),
  public.sync_account_profile_total(),
  public.guard_transaction_references(),
  public.guard_management_references(),
  public.guard_management_delete()
FROM PUBLIC, anon;

-- Stop new functions in public from granting EXECUTE to anon, for every role
-- whose default privileges do so. A role the migrating user cannot act for
-- (supabase_admin on a hosted project) is reported instead of failing.
DO $$
DECLARE
  v_role name;
BEGIN
  FOR v_role IN
    SELECT DISTINCT pg_catalog.pg_get_userbyid(d.defaclrole)
      FROM pg_catalog.pg_default_acl d, pg_catalog.aclexplode(d.defaclacl) a
     WHERE d.defaclnamespace = 'public'::regnamespace
       AND d.defaclobjtype = 'f'
       AND a.grantee = 'anon'::regrole
  LOOP
    BEGIN
      EXECUTE pg_catalog.format(
        'ALTER DEFAULT PRIVILEGES FOR ROLE %I IN SCHEMA public REVOKE EXECUTE ON FUNCTIONS FROM anon',
        v_role);
    EXCEPTION WHEN insufficient_privilege THEN
      RAISE WARNING 'B13: cannot change default privileges of role %; new functions it creates in public stay executable by anon', v_role;
    END;
  END LOOP;
END;
$$;

COMMIT;
