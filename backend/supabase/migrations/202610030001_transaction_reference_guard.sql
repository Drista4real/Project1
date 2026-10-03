-- Apply once after frontend/supabase/schema.sql, using the Supabase SQL editor.
-- RLS on transactions checks user_id but does not check ownership of foreign keys.
-- This guard also protects direct PostgREST writes before the balance trigger runs.
BEGIN;

CREATE OR REPLACE FUNCTION public.guard_transaction_references()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
  referenced_id bigint;
  referenced_owner uuid;
  category_owner uuid;
  category_income boolean;
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.user_id IS DISTINCT FROM OLD.user_id THEN
    RAISE EXCEPTION 'Transaction owner cannot change' USING ERRCODE = '23514';
  END IF;
  -- An existing invalid reference must not let UPDATE/DELETE reverse another
  -- user's balance through the existing SECURITY DEFINER balance trigger.
  IF TG_OP IN ('UPDATE', 'DELETE') THEN
    FOREACH referenced_id IN ARRAY ARRAY[OLD.account_id, OLD.to_account_id] LOOP
      IF referenced_id IS NOT NULL THEN
        SELECT user_id INTO referenced_owner FROM public.accounts
        WHERE id = referenced_id FOR SHARE;
        IF FOUND AND referenced_owner IS DISTINCT FROM OLD.user_id THEN
          RAISE EXCEPTION 'Invalid existing account reference' USING ERRCODE = '23514';
        END IF;
      END IF;
    END LOOP;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;

  FOREACH referenced_id IN ARRAY ARRAY[NEW.account_id, NEW.to_account_id] LOOP
    IF referenced_id IS NOT NULL THEN
      SELECT user_id INTO referenced_owner FROM public.accounts
      WHERE id = referenced_id FOR SHARE;
      IF NOT FOUND OR referenced_owner IS DISTINCT FROM NEW.user_id THEN
        RAISE EXCEPTION 'Invalid account reference' USING ERRCODE = '23514';
      END IF;
    END IF;
  END LOOP;

  IF NEW.transaction_type = 'transfer' THEN
    IF NEW.account_id IS NULL OR NEW.to_account_id IS NULL
      OR NEW.account_id = NEW.to_account_id OR NEW.category_id IS NOT NULL THEN
      RAISE EXCEPTION 'Invalid transfer' USING ERRCODE = '23514';
    END IF;
  ELSIF NEW.to_account_id IS NOT NULL THEN
    RAISE EXCEPTION 'Unexpected destination account' USING ERRCODE = '23514';
  END IF;

  IF NEW.category_id IS NOT NULL THEN
    SELECT user_id, is_income INTO category_owner, category_income
    FROM public.categories WHERE id = NEW.category_id FOR SHARE;
    IF NOT FOUND OR (category_owner IS NOT NULL AND category_owner <> NEW.user_id)
      OR category_income <> (NEW.transaction_type = 'income') THEN
      RAISE EXCEPTION 'Invalid category reference' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

CREATE OR REPLACE TRIGGER trg_guard_transaction_references
BEFORE INSERT OR UPDATE OR DELETE ON public.transactions
FOR EACH ROW EXECUTE FUNCTION public.guard_transaction_references();

COMMIT;
