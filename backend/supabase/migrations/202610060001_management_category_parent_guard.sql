-- Fix the category guard without rewriting an already applied migration.
-- Its parent_id variable collided with the categories.parent_id column,
-- causing INSERT/UPDATE to fail with SQLSTATE 42702.
BEGIN;

CREATE OR REPLACE FUNCTION public.guard_management_references()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  record_data jsonb := pg_catalog.to_jsonb(NEW);
  owner_id uuid;
  reference_id bigint;
  reference_owner uuid;
  reference_income boolean;
  ancestor_id bigint;
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
    ancestor_id := NEW.parent_id;
    visited := ARRAY[NEW.id];
    WHILE ancestor_id IS NOT NULL LOOP
      IF ancestor_id = ANY(visited) THEN
        RAISE EXCEPTION 'Category cycle' USING ERRCODE = '23514';
      END IF;
      visited := pg_catalog.array_append(visited, ancestor_id);
      SELECT c.parent_id INTO ancestor_id FROM public.categories c WHERE c.id = visited[pg_catalog.array_length(visited, 1)];
    END LOOP;
    IF TG_OP = 'UPDATE' AND NEW.is_income IS DISTINCT FROM OLD.is_income AND (
      EXISTS(SELECT 1 FROM public.transactions WHERE category_id = OLD.id) OR
      EXISTS(SELECT 1 FROM public.budgets WHERE category_id = OLD.id) OR
      EXISTS(SELECT 1 FROM public.recurring_transactions WHERE category_id = OLD.id) OR
      EXISTS(SELECT 1 FROM public.categories c WHERE c.parent_id = OLD.id)
    ) THEN RAISE EXCEPTION 'Category type is in use' USING ERRCODE = 'P0001'; END IF;
  END IF;
  RETURN NEW;
END;
$$;

COMMIT;
