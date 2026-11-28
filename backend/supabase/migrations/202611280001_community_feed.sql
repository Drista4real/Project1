-- Community social feed tables, RLS policies and author-profile sync trigger.
--
-- Keeps private tables (`public.profiles`, `public.budget_plans`) strictly
-- owner-scoped while allowing any authenticated user to read, like and comment
-- on plans that owners explicitly shared to the community.
BEGIN;

CREATE TABLE IF NOT EXISTS public.community_posts (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  plan_id           BIGINT REFERENCES public.budget_plans(id) ON DELETE SET NULL,
  author_name       TEXT NOT NULL CHECK (char_length(trim(author_name)) BETWEEN 1 AND 120),
  author_avatar_url TEXT,
  title             TEXT NOT NULL DEFAULT 'Kế hoạch chi tiêu',
  caption           TEXT CHECK (caption IS NULL OR char_length(caption) <= 500),
  total_income      NUMERIC(15, 2) NOT NULL CHECK (total_income >= 0),
  fixed_expenses    NUMERIC(15, 2) NOT NULL DEFAULT 0 CHECK (fixed_expenses >= 0),
  savings_target    NUMERIC(15, 2) NOT NULL DEFAULT 0 CHECK (savings_target >= 0),
  spendable_budget  NUMERIC(15, 2) NOT NULL CHECK (spendable_budget >= 0),
  daily_allowance   NUMERIC(15, 2) NOT NULL CHECK (daily_allowance >= 0),
  duration_days     INT NOT NULL CHECK (duration_days BETWEEN 1 AND 365),
  start_date        DATE NOT NULL,
  groups_snapshot   JSONB NOT NULL DEFAULT '[]'::jsonb,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_community_posts_user_plan_unique
  ON public.community_posts(user_id, plan_id)
  WHERE plan_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_community_posts_created
  ON public.community_posts(created_at DESC, id DESC);

CREATE TABLE IF NOT EXISTS public.community_post_likes (
  post_id    BIGINT NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (post_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_community_post_likes_user
  ON public.community_post_likes(user_id, post_id);

CREATE TABLE IF NOT EXISTS public.community_post_comments (
  id                BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  post_id           BIGINT NOT NULL REFERENCES public.community_posts(id) ON DELETE CASCADE,
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  author_name       TEXT NOT NULL CHECK (char_length(trim(author_name)) BETWEEN 1 AND 120),
  author_avatar_url TEXT,
  content           TEXT NOT NULL CHECK (char_length(trim(content)) BETWEEN 1 AND 1000),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_community_post_comments_post
  ON public.community_post_comments(post_id, created_at ASC, id ASC);

ALTER TABLE public.community_posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_post_comments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "community_posts_select_authenticated" ON public.community_posts;
CREATE POLICY "community_posts_select_authenticated" ON public.community_posts
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "community_posts_insert_own" ON public.community_posts;
CREATE POLICY "community_posts_insert_own" ON public.community_posts
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "community_posts_update_own" ON public.community_posts;
CREATE POLICY "community_posts_update_own" ON public.community_posts
  FOR UPDATE TO authenticated
  USING ((SELECT auth.uid()) = user_id)
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "community_posts_delete_own" ON public.community_posts;
CREATE POLICY "community_posts_delete_own" ON public.community_posts
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "community_likes_select_authenticated" ON public.community_post_likes;
CREATE POLICY "community_likes_select_authenticated" ON public.community_post_likes
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "community_likes_insert_own" ON public.community_post_likes;
CREATE POLICY "community_likes_insert_own" ON public.community_post_likes
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "community_likes_delete_own" ON public.community_post_likes;
CREATE POLICY "community_likes_delete_own" ON public.community_post_likes
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "community_comments_select_authenticated" ON public.community_post_comments;
CREATE POLICY "community_comments_select_authenticated" ON public.community_post_comments
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS "community_comments_insert_own" ON public.community_post_comments;
CREATE POLICY "community_comments_insert_own" ON public.community_post_comments
  FOR INSERT TO authenticated
  WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "community_comments_delete_own" ON public.community_post_comments;
CREATE POLICY "community_comments_delete_own" ON public.community_post_comments
  FOR DELETE TO authenticated
  USING ((SELECT auth.uid()) = user_id);

DROP TRIGGER IF EXISTS trg_community_posts_updated_at ON public.community_posts;
CREATE TRIGGER trg_community_posts_updated_at
  BEFORE UPDATE ON public.community_posts
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE OR REPLACE FUNCTION public.sync_community_author_profile()
RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  v_name TEXT;
BEGIN
  v_name := COALESCE(
    NULLIF(pg_catalog.btrim(NEW.full_name), ''),
    NULLIF(pg_catalog.split_part(COALESCE(NEW.email, ''), '@', 1), ''),
    'Người dùng Kakeibo'
  );

  UPDATE public.community_posts
     SET author_name = v_name,
         author_avatar_url = NEW.avatar_url
   WHERE user_id = NEW.id;

  UPDATE public.community_post_comments
     SET author_name = v_name,
         author_avatar_url = NEW.avatar_url
   WHERE user_id = NEW.id;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.sync_community_author_profile() FROM PUBLIC, anon;

DROP TRIGGER IF EXISTS trg_profiles_sync_community_author ON public.profiles;
CREATE TRIGGER trg_profiles_sync_community_author
  AFTER UPDATE OF full_name, avatar_url ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.sync_community_author_profile();

COMMIT;
