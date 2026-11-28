-- B14: the spending views must run with the caller's RLS and stay closed to
-- anon. Read-only; raises once with every failure.
DO $$
DECLARE
  v_failures text[] := '{}';
  v_view text;
  v_privilege text;
BEGIN
  FOREACH v_view IN ARRAY ARRAY[
    'public.v_current_month_spending_by_category',
    'public.v_kakeibo_monthly_summary',
    'public.v_monthly_budget_progress'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_class
       WHERE oid = v_view::regclass
         AND 'security_invoker=true' = ANY (reloptions)
    ) THEN
      v_failures := v_failures || (v_view || ' does not run as security invoker');
    END IF;
    IF has_table_privilege('anon', v_view, 'SELECT') THEN
      v_failures := v_failures || ('anon can select ' || v_view);
    END IF;
    IF NOT has_table_privilege('authenticated', v_view, 'SELECT') THEN
      v_failures := v_failures || ('authenticated lost select on ' || v_view);
    END IF;
    -- Read-only for signed-in users, in case a view is ever rewritten into an updatable one.
    FOREACH v_privilege IN ARRAY ARRAY['INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'] LOOP
      IF has_table_privilege('authenticated', v_view, v_privilege) THEN
        v_failures := v_failures || ('authenticated has ' || v_privilege || ' on ' || v_view);
      END IF;
    END LOOP;
  END LOOP;

  IF cardinality(v_failures) > 0 THEN
    RAISE EXCEPTION 'B14 view checks failed:%', E'\n  - ' || array_to_string(v_failures, E'\n  - ');
  END IF;
END;
$$;
