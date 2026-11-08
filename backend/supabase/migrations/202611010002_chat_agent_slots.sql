-- Ticket C: server-side conversation slots and tool-call trace for the chat
-- agent. Apply after 202611010001_budget_plan_engine.sql.
--
-- ADR 0010 lets the agent append to the conversation it answers in and store
-- the slots it collected, and nothing else. It still cannot write generated
-- finance data generically (ADR 0001) and it never writes money: every budget
-- figure comes from the deterministic services of ADR 0009.
BEGIN;

-- Slots collected across turns. The server reloads them into every turn so a
-- multi-turn slot filling conversation survives an interrupted session.
ALTER TABLE public.ai_chat_sessions
    ADD COLUMN IF NOT EXISTS budget_slots JSONB,
    ADD COLUMN IF NOT EXISTS budget_slots_updated_at TIMESTAMPTZ;

-- Tool-call trace. `tool_args` and `tool_result` record what was executed,
-- so the audit trail shows the real numbers instead of the model's narration.
ALTER TABLE public.ai_chat_messages
    ADD COLUMN IF NOT EXISTS tool_name TEXT,
    ADD COLUMN IF NOT EXISTS tool_args JSONB,
    ADD COLUMN IF NOT EXISTS tool_result JSONB;

-- A slot set is either absent or a JSON object; anything else is a bug.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ai_chat_sessions_budget_slots_object'
    ) THEN
        ALTER TABLE public.ai_chat_sessions
            ADD CONSTRAINT ai_chat_sessions_budget_slots_object
            CHECK (budget_slots IS NULL OR jsonb_typeof(budget_slots) = 'object');
    END IF;
END $$;

-- The trace columns are only meaningful together: a named tool carries its
-- arguments, and a tool result always names the tool that produced it.
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint WHERE conname = 'ai_chat_messages_tool_trace_shape'
    ) THEN
        ALTER TABLE public.ai_chat_messages
            ADD CONSTRAINT ai_chat_messages_tool_trace_shape
            CHECK (
                (tool_name IS NULL AND tool_args IS NULL AND tool_result IS NULL)
                OR (tool_name IS NOT NULL AND tool_result IS NOT NULL)
            );
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_ai_chat_sessions_user_updated
    ON public.ai_chat_sessions(user_id, updated_at DESC);

-- The agent reads and writes rows through the Supabase client with the user's
-- own token, so the existing owner-scoped policies already apply. These
-- policies are restated for the new columns so a future policy change cannot
-- silently widen access to the collected slots.
DROP POLICY IF EXISTS "chat_sessions_all_own" ON public.ai_chat_sessions;
CREATE POLICY "chat_sessions_all_own" ON public.ai_chat_sessions FOR ALL
    USING ((SELECT auth.uid()) = user_id)
    WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "chat_messages_all_own" ON public.ai_chat_messages;
CREATE POLICY "chat_messages_all_own" ON public.ai_chat_messages FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.ai_chat_sessions s
            WHERE s.id = session_id AND s.user_id = (SELECT auth.uid())
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.ai_chat_sessions s
            WHERE s.id = session_id AND s.user_id = (SELECT auth.uid())
        )
    );

COMMIT;
