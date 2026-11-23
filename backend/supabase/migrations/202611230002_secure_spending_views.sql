-- B14: the spending views ran with their owner's rights, which bypass RLS,
-- and anon could read them, so anyone saw every user's spending.
--
-- security_invoker makes each view apply the caller's RLS on transactions,
-- categories and budgets. anon loses every privilege on them; the app does
-- not read these views. authenticated keeps SELECT only, so the views stay
-- read-only even if one is later rewritten into an updatable view.
--
-- Independent of 202611010003 and safe to run again. No view is dropped.
-- Rollback is a new forward migration that sets security_invoker = false.
BEGIN;

ALTER VIEW public.v_current_month_spending_by_category SET (security_invoker = true);
ALTER VIEW public.v_kakeibo_monthly_summary SET (security_invoker = true);
ALTER VIEW public.v_monthly_budget_progress SET (security_invoker = true);

REVOKE ALL ON
  public.v_current_month_spending_by_category,
  public.v_kakeibo_monthly_summary,
  public.v_monthly_budget_progress
FROM anon;

REVOKE ALL ON
  public.v_current_month_spending_by_category,
  public.v_kakeibo_monthly_summary,
  public.v_monthly_budget_progress
FROM authenticated;
GRANT SELECT ON
  public.v_current_month_spending_by_category,
  public.v_kakeibo_monthly_summary,
  public.v_monthly_budget_progress
TO authenticated;

COMMIT;
