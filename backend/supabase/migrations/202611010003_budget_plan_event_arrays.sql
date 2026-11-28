-- Ticket A, round 3: the audit trail stores allocation lists.
--
-- `budget_plan_events.proposal` and `accepted` hold the allocation list, so
-- the column must accept an array. The original migration created them as an
-- unconstrained JSONB, which is fine, but the type has to be stated so a
-- later write cannot slip a scalar into it.
--
-- The version conflict needs no migration here: the optimistic lock in
-- `rebalance_plan` raises the PostgREST error code PT409 from the start. The
-- SQL state 40001 would mean "serialization failure", which PostgREST treats
-- as a transient error and retries forever, so the caller would see a hung
-- request and a gateway timeout instead of a conflict.
--
-- Apply after 202611010001.
BEGIN;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'budget_plan_events_proposal_array'
    ) THEN
        ALTER TABLE public.budget_plan_events
            ADD CONSTRAINT budget_plan_events_proposal_array
            CHECK (jsonb_typeof(proposal) = 'array');
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'budget_plan_events_accepted_array'
    ) THEN
        ALTER TABLE public.budget_plan_events
            ADD CONSTRAINT budget_plan_events_accepted_array
            CHECK (jsonb_typeof(accepted) = 'array');
    END IF;
END;
$$;

COMMIT;
