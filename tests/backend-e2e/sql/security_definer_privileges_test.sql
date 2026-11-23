-- B13: catalog checks that HTTP tests cannot see. Read-only; raises once with
-- every failure so one run shows the whole picture.
DO $$
DECLARE
  v_failures text[] := '{}';
  v_fn text;
BEGIN
  FOREACH v_fn IN ARRAY ARRAY[
    'public.validate_envelope_capacity(uuid, date)',
    'public.rebalance_plan(bigint, int, jsonb, jsonb, uuid)',
    'public.handle_new_user()',
    'public.sync_auth_profile_email()',
    'public.update_account_and_profile_balance()',
    'public.sync_account_profile_total()',
    'public.guard_transaction_references()',
    'public.guard_management_references()',
    'public.guard_management_delete()'
  ] LOOP
    IF has_function_privilege('anon', v_fn, 'EXECUTE') THEN
      v_failures := v_failures || ('anon can execute ' || v_fn);
    END IF;
  END LOOP;

  -- The app still calls these two as a signed-in user.
  FOREACH v_fn IN ARRAY ARRAY[
    'public.validate_envelope_capacity(uuid, date)',
    'public.rebalance_plan(bigint, int, jsonb, jsonb, uuid)'
  ] LOOP
    IF NOT has_function_privilege('authenticated', v_fn, 'EXECUTE') THEN
      v_failures := v_failures || ('authenticated lost execute on ' || v_fn);
    END IF;
  END LOOP;

  IF EXISTS (
    SELECT 1
      FROM pg_default_acl d, aclexplode(d.defaclacl) a
     WHERE d.defaclnamespace = 'public'::regnamespace
       AND d.defaclobjtype = 'f'
       AND a.grantee = 'anon'::regrole
  ) THEN
    v_failures := v_failures || 'pg_default_acl still grants functions in public to anon'::text;
  END IF;

  FOREACH v_fn IN ARRAY ARRAY[
    'public.handle_new_user()',
    'public.update_account_and_profile_balance()',
    'public.handle_updated_at()'
  ] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM pg_proc
       WHERE oid = v_fn::regprocedure
         AND 'search_path=""' = ANY (proconfig)
    ) THEN
      v_failures := v_failures || ('search_path is not empty on ' || v_fn);
    END IF;
  END LOOP;

  IF cardinality(v_failures) > 0 THEN
    RAISE EXCEPTION 'B13 privilege checks failed:%', E'\n  - ' || array_to_string(v_failures, E'\n  - ');
  END IF;
END;
$$;
