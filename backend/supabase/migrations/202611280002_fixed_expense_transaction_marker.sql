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
-- a no-op. Safe to run again: IF NOT EXISTS only.
-- Rollback is a new forward migration.
BEGIN;

ALTER TABLE public.transactions
  ADD COLUMN IF NOT EXISTS fixed_expense_plan_id BIGINT
  REFERENCES public.budget_plans(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_transactions_fixed_expense_plan_id
  ON public.transactions(fixed_expense_plan_id);

COMMIT;
