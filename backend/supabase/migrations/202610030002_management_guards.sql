-- Apply after schema.sql and 202610030001_transaction_reference_guard.sql.
-- No service role is required by the API. These guards also protect direct SDK writes.
BEGIN;

CREATE OR REPLACE FUNCTION public.guard_management_references()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  record_data jsonb := pg_catalog.to_jsonb(NEW);
  owner_id uuid;
  reference_id bigint;
  reference_owner uuid;
  reference_income boolean;
  parent_id bigint;
  visited bigint[] := ARRAY[]::bigint[];
  field_name text;
BEGIN
  IF TG_TABLE_NAME = 'ai_chat_messages' THEN
    SELECT user_id INTO owner_id FROM public.ai_chat_sessions
      WHERE id = NEW.session_id FOR SHARE;
    IF owner_id IS NULL OR owner_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'Session unavailable' USING ERRCODE = '42501';
    END IF;
  ELSIF TG_TABLE_NAME = 'transaction_tags' THEN
    SELECT user_id INTO owner_id FROM public.transactions
      WHERE id = NEW.transaction_id FOR SHARE;
    IF owner_id IS NULL OR owner_id IS DISTINCT FROM auth.uid() THEN
      RAISE EXCEPTION 'Transaction unavailable' USING ERRCODE = '42501';
    END IF;
    SELECT user_id INTO reference_owner FROM public.tags WHERE id = NEW.tag_id FOR SHARE;
    IF reference_owner IS DISTINCT FROM owner_id THEN
      RAISE EXCEPTION 'Tag unavailable' USING ERRCODE = '23514';
    END IF;
    RETURN NEW;
  ELSE
    owner_id := NEW.user_id;
    IF TG_OP = 'UPDATE' AND NEW.user_id IS DISTINCT FROM OLD.user_id THEN
      RAISE EXCEPTION 'Owner cannot change' USING ERRCODE = '23514';
    END IF;
    -- System categories can be maintained by trusted SQL migrations.
    IF TG_TABLE_NAME = 'categories' AND owner_id IS NULL THEN RETURN NEW; END IF;
  END IF;

  FOREACH field_name IN ARRAY ARRAY['account_id', 'category_id', 'parent_id'] LOOP
    reference_id := (record_data ->> field_name)::bigint;
    IF reference_id IS NULL THEN CONTINUE; END IF;
    IF field_name = 'account_id' THEN
      SELECT user_id INTO reference_owner FROM public.accounts WHERE id = reference_id FOR SHARE;
      IF reference_owner IS DISTINCT FROM owner_id THEN
        RAISE EXCEPTION 'Account unavailable' USING ERRCODE = '23514';
      END IF;
    ELSE
      SELECT user_id, is_income INTO reference_owner, reference_income
        FROM public.categories WHERE id = reference_id FOR SHARE;
      IF NOT FOUND OR (reference_owner IS NOT NULL AND reference_owner <> owner_id) THEN
        RAISE EXCEPTION 'Category unavailable' USING ERRCODE = '23514';
      END IF;
      IF TG_TABLE_NAME = 'budgets' AND reference_income THEN
        RAISE EXCEPTION 'Budget requires expense category' USING ERRCODE = '23514';
      END IF;
      IF TG_TABLE_NAME = 'recurring_transactions' AND
         reference_income IS DISTINCT FROM ((record_data ->> 'transaction_type') = 'income') THEN
        RAISE EXCEPTION 'Category type mismatch' USING ERRCODE = '23514';
      END IF;
      IF TG_TABLE_NAME = 'categories' AND reference_income IS DISTINCT FROM (record_data ->> 'is_income')::boolean THEN
        RAISE EXCEPTION 'Parent category type mismatch' USING ERRCODE = '23514';
      END IF;
    END IF;
  END LOOP;

  IF TG_TABLE_NAME = 'categories' THEN
    -- Serialize hierarchy edits for this owner before reading the ancestor chain.
    PERFORM 1 FROM public.profiles WHERE id = owner_id FOR UPDATE;
    parent_id := NEW.parent_id;
    visited := ARRAY[NEW.id];
    WHILE parent_id IS NOT NULL LOOP
      IF parent_id = ANY(visited) THEN
        RAISE EXCEPTION 'Category cycle' USING ERRCODE = '23514';
      END IF;
      visited := pg_catalog.array_append(visited, parent_id);
      SELECT c.parent_id INTO parent_id FROM public.categories c WHERE c.id = visited[pg_catalog.array_length(visited, 1)];
    END LOOP;
    IF TG_OP = 'UPDATE' AND NEW.is_income IS DISTINCT FROM OLD.is_income AND (
      EXISTS(SELECT 1 FROM public.transactions WHERE category_id = OLD.id) OR
      EXISTS(SELECT 1 FROM public.budgets WHERE category_id = OLD.id) OR
      EXISTS(SELECT 1 FROM public.recurring_transactions WHERE category_id = OLD.id) OR
      EXISTS(SELECT 1 FROM public.categories WHERE parent_id = OLD.id)
    ) THEN RAISE EXCEPTION 'Category type is in use' USING ERRCODE = 'P0001'; END IF;
  END IF;
  RETURN NEW;
END;
$$;

DO $$
DECLARE table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY['categories', 'budgets', 'saving_goals',
    'recurring_transactions', 'transaction_tags', 'ai_chat_messages'] LOOP
    EXECUTE pg_catalog.format('DROP TRIGGER IF EXISTS management_reference_guard ON public.%I', table_name);
    EXECUTE pg_catalog.format('CREATE TRIGGER management_reference_guard BEFORE INSERT OR UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.guard_management_references()', table_name);
  END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.guard_management_delete()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  -- Allow the auth.users cascade to clean up a deleted identity.
  IF NOT EXISTS(SELECT 1 FROM auth.users WHERE id = OLD.user_id) THEN RETURN OLD; END IF;
  IF TG_TABLE_NAME = 'accounts' AND (
    EXISTS(SELECT 1 FROM public.transactions WHERE account_id = OLD.id OR to_account_id = OLD.id) OR
    EXISTS(SELECT 1 FROM public.saving_goals WHERE account_id = OLD.id) OR
    EXISTS(SELECT 1 FROM public.recurring_transactions WHERE account_id = OLD.id)
  ) THEN RAISE EXCEPTION 'Account is in use' USING ERRCODE = 'P0001'; END IF;
  IF TG_TABLE_NAME = 'categories' AND (
    EXISTS(SELECT 1 FROM public.transactions WHERE category_id = OLD.id) OR
    EXISTS(SELECT 1 FROM public.budgets WHERE category_id = OLD.id) OR
    EXISTS(SELECT 1 FROM public.recurring_transactions WHERE category_id = OLD.id) OR
    EXISTS(SELECT 1 FROM public.categories WHERE parent_id = OLD.id)
  ) THEN RAISE EXCEPTION 'Category is in use' USING ERRCODE = 'P0001'; END IF;
  RETURN OLD;
END;
$$;

DROP TRIGGER IF EXISTS management_delete_guard ON public.accounts;
CREATE TRIGGER management_delete_guard BEFORE DELETE ON public.accounts
  FOR EACH ROW EXECUTE FUNCTION public.guard_management_delete();
DROP TRIGGER IF EXISTS management_delete_guard ON public.categories;
CREATE TRIGGER management_delete_guard BEFORE DELETE ON public.categories
  FOR EACH ROW EXECUTE FUNCTION public.guard_management_delete();

CREATE OR REPLACE FUNCTION public.sync_account_profile_total()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE owner_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN owner_id := OLD.user_id; ELSE owner_id := NEW.user_id; END IF;
  PERFORM 1 FROM public.profiles WHERE id = owner_id FOR UPDATE;
  UPDATE public.profiles SET current_balance = COALESCE((
    SELECT SUM(balance) FROM public.accounts WHERE user_id = owner_id AND is_included_in_total
  ), 0) WHERE id = owner_id;
  RETURN NULL;
END;
$$;
DROP TRIGGER IF EXISTS account_profile_total ON public.accounts;
CREATE TRIGGER account_profile_total AFTER INSERT OR DELETE OR UPDATE OF balance, is_included_in_total
  ON public.accounts FOR EACH ROW EXECUTE FUNCTION public.sync_account_profile_total();

UPDATE public.profiles p SET current_balance = COALESCE((
  SELECT SUM(a.balance) FROM public.accounts a WHERE a.user_id = p.id AND a.is_included_in_total
), 0);

-- Add cross-field checks without failing installation on existing legacy records.
-- NOT VALID still enforces these constraints on subsequent inserts and updates.
DO $$ BEGIN
  IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_constraint WHERE conname = 'management_budget_month' AND conrelid = 'public.budgets'::regclass) THEN
    ALTER TABLE public.budgets ADD CONSTRAINT management_budget_month CHECK (EXTRACT(DAY FROM month_year) = 1) NOT VALID;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_constraint WHERE conname = 'management_debt_amount' AND conrelid = 'public.debts_loans'::regclass) THEN
    ALTER TABLE public.debts_loans ADD CONSTRAINT management_debt_amount CHECK (paid_amount >= 0 AND paid_amount <= amount AND interest_rate >= 0) NOT VALID;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_constraint WHERE conname = 'management_recurring_dates' AND conrelid = 'public.recurring_transactions'::regclass) THEN
    ALTER TABLE public.recurring_transactions ADD CONSTRAINT management_recurring_dates CHECK (next_execution_date >= start_date AND (end_date IS NULL OR end_date >= next_execution_date)) NOT VALID;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_constraint WHERE conname = 'management_goal_amount' AND conrelid = 'public.saving_goals'::regclass) THEN
    ALTER TABLE public.saving_goals ADD CONSTRAINT management_goal_amount CHECK (current_amount >= 0) NOT VALID;
  END IF;
  IF NOT EXISTS(SELECT 1 FROM pg_catalog.pg_constraint WHERE conname = 'management_forecast_bounds' AND conrelid = 'public.cashflow_forecasts'::regclass) THEN
    ALTER TABLE public.cashflow_forecasts ADD CONSTRAINT management_forecast_bounds CHECK (predicted_income >= 0 AND predicted_expense >= 0 AND (lower_bound IS NULL OR upper_bound IS NULL OR lower_bound <= upper_bound)) NOT VALID;
  END IF;
END; $$;

COMMIT;
