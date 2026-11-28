-- Fixed expense marker on transactions.
--
-- A user marks an expense as one of the fixed expenses a budget plan already
-- deducted, so the plan's spending E does not count it twice (draft
-- docs/large-purchase-rebalance, section 3). Only the user sets the marker;
-- a matching category or recurring item is a suggestion, never a write.
--
-- budget_plans.id is BIGINT, so the marker is BIGINT too. The column lives
-- only here: frontend/supabase/schema.sql has no budget_plans table, and a
-- column added there without the foreign key would make the ADD COLUMN below
-- a no-op.
--
-- The foreign key alone accepts another user's plan: its check runs with the
-- owner's rights. guard_transaction_references therefore also checks the
-- plan, with the same error as a foreign account or category. Its body is
-- the one of 202610030001 plus the last IF block; signature, SECURITY
-- DEFINER and search_path do not change.
--
-- Safe to run again: IF NOT EXISTS, CREATE OR REPLACE and REVOKE only.
-- Rollback is a new forward migration.
BEGIN;

ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS fixed_expense_plan_id BIGINT
  REFERENCES public.budget_plans(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_fixed_expense_plan_id
  ON public.transactions(fixed_expense_plan_id);

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

  -- Only an expense can be a fixed expense, and only of the owner's plan.
  IF NEW.fixed_expense_plan_id IS NOT NULL THEN
    SELECT user_id INTO referenced_owner FROM public.budget_plans
    WHERE id = NEW.fixed_expense_plan_id FOR SHARE;
    IF NOT FOUND OR referenced_owner IS DISTINCT FROM NEW.user_id
      OR NEW.transaction_type <> 'expense' THEN
      RAISE EXCEPTION 'Invalid fixed expense plan reference' USING ERRCODE = '23514';
    END IF;
  END IF;
  RETURN NEW;
END;
$$;

-- As after 202611230001: no EXECUTE for PUBLIC or anon. A trigger needs none.
REVOKE EXECUTE ON FUNCTION public.guard_transaction_references() FROM PUBLIC, anon;

COMMIT;
