-- B15/B16: catalog checks for the budget plan engine. Read-only; raises once
-- with every failure so one run shows the whole picture.
--
-- A fresh stack applies every migration, so this passes from the start. It
-- guards against a later migration bringing back the 40001 body or dropping
-- the array checks; drift on the live database is caught by
-- backend/scripts/check_function_drift.py instead.
DO $$
DECLARE
  v_failures text[] := '{}';
  -- to_regprocedure returns NULL instead of raising, so a missing function is
  -- one failure and the CHECK constraints are still inspected.
  v_fn constant regprocedure :=
    to_regprocedure('public.rebalance_plan(bigint, int, jsonb, jsonb, uuid)');
  v_body text;
  v_check text;
BEGIN
  IF v_fn IS NULL THEN
    v_failures := v_failures || 'missing function public.rebalance_plan(bigint, int, jsonb, jsonb, uuid)'::text;
  ELSE
    SELECT prosrc INTO v_body FROM pg_proc WHERE oid = v_fn;
    -- The body also says "not 40001" in a comment, so match the raise itself.
    IF position('ERRCODE = ''PT409''' IN v_body) = 0 THEN
      v_failures := v_failures || 'rebalance_plan does not raise PT409'::text;
    END IF;
    IF position('ERRCODE = ''40001''' IN v_body) > 0 THEN
      v_failures := v_failures || 'rebalance_plan still raises 40001'::text;
    END IF;
    IF has_function_privilege('anon', v_fn, 'EXECUTE') THEN
      v_failures := v_failures || ('anon can execute ' || v_fn::text);
    END IF;
  END IF;

  FOREACH v_check IN ARRAY ARRAY[
    'budget_plan_events_proposal_array',
    'budget_plan_events_accepted_array'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_constraint
       WHERE conrelid = to_regclass('public.budget_plan_events')
         AND contype = 'c'
         AND conname = v_check
    ) THEN
      v_failures := v_failures || ('missing CHECK ' || v_check);
    END IF;
  END LOOP;

  IF cardinality(v_failures) > 0 THEN
    RAISE EXCEPTION 'budget plan catalog checks failed:%', E'\n  - ' || array_to_string(v_failures, E'\n  - ');
  END IF;
END;
$$;
