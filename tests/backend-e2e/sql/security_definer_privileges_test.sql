-- B13: catalog checks that HTTP tests cannot see. Read-only; raises once with
-- every failure so one run shows the whole picture.
--
-- Every SECURITY DEFINER function in public is scanned, so a new one that a
-- later migration forgets to REVOKE fails here without editing this file.
DO $$
DECLARE
  v_failures text[] := '{}';
  v_fn regprocedure;
  v_scanned int := 0;
BEGIN
  FOR v_fn IN
    SELECT p.oid::regprocedure
      FROM pg_proc p
     WHERE p.pronamespace = 'public'::regnamespace
       AND p.prosecdef
     ORDER BY 1
  LOOP
    v_scanned := v_scanned + 1;
    -- has_function_privilege also counts EXECUTE inherited through PUBLIC.
    IF has_function_privilege('anon', v_fn, 'EXECUTE') THEN
      v_failures := v_failures || ('anon can execute ' || v_fn::text);
    END IF;
    IF NOT has_function_privilege('service_role', v_fn, 'EXECUTE') THEN
      v_failures := v_failures || ('service_role cannot execute ' || v_fn::text);
    END IF;
  END LOOP;
  IF v_scanned = 0 THEN
    v_failures := v_failures || 'no SECURITY DEFINER function found in public'::text;
  END IF;
  RAISE NOTICE 'B13 scanned % SECURITY DEFINER functions in public', v_scanned;

  -- The app still calls these two as a signed-in user.
  FOREACH v_fn IN ARRAY ARRAY[
    'public.validate_envelope_capacity(uuid, date)',
    'public.rebalance_plan(bigint, int, jsonb, jsonb, uuid)'
  ]::regprocedure[] LOOP
    IF NOT has_function_privilege('authenticated', v_fn, 'EXECUTE') THEN
      v_failures := v_failures || ('authenticated cannot execute ' || v_fn::text);
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1
      FROM pg_default_acl d, aclexplode(d.defaclacl) a
     WHERE d.defaclrole = 'postgres'::regrole
       AND d.defaclnamespace = 'public'::regnamespace
       AND d.defaclobjtype = 'f'
       AND a.grantee = 'anon'::regrole
  ) THEN
    v_failures := v_failures || 'default privileges of postgres in public still grant EXECUTE to anon'::text;
  END IF;

  FOREACH v_fn IN ARRAY ARRAY[
    'public.handle_new_user()',
    'public.update_account_and_profile_balance()',
    'public.handle_updated_at()'
  ]::regprocedure[] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_proc
       WHERE oid = v_fn
         AND 'search_path=""' = ANY (proconfig)
    ) THEN
      v_failures := v_failures || ('search_path is not empty on ' || v_fn::text);
    END IF;
  END LOOP;

  IF cardinality(v_failures) > 0 THEN
    RAISE EXCEPTION 'B13 privilege checks failed:%', E'\n  - ' || array_to_string(v_failures, E'\n  - ');
  END IF;
END;
$$;
