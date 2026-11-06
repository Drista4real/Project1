# Conversational home canvas with a server-side chat agent

Date: 2026-11-01. Status: accepted.
Ticket: Ticket C of `docs/DYNAMIC_BUDGET_SPEC.md`.
Related: ADR 0001 (device settings and generated data), ADR 0004 (three tiers
and modality fallback), ADR 0005 (envelope capacity and wallet totals),
ADR 0009 (deterministic budget engine).

## Context

ADR 0001 states that generated finance data — cashflow forecasts, alerts,
consultations, chat sessions and chat messages — is exposed for reading only,
and that generic manual CRUD is unavailable.

The conversational assistant needs the opposite of that for a narrow purpose.
It must read the slots the user already gave in an earlier turn, keep them
across an interrupted session, and record which tool it invoked with which
arguments and which result. Without that, a multi-turn slot filling
conversation has to ask for the same four inputs again after the app is
killed, and there is no audit trail of what the assistant proposed.

The home screen also has to change shape. It currently shows the ledger
balance, the calendar and the transaction list. The product intent for the
home screen is a conversational canvas: a greeting, a message input and a set
of quick question suggestions.

## Decision

The assistant is allowed to write chat sessions and chat messages, and nothing
else. Its writes are server-side, scoped to the authenticated owner by row level
security, and limited to three columns on two existing tables:

- `ai_chat_sessions.budget_slots` and `ai_chat_sessions.budget_slots_updated_at`
- `ai_chat_messages.tool_name`, `ai_chat_messages.tool_args` and
  `ai_chat_messages.tool_result`

Slot state lives on the server so an interrupted session resumes without
re-asking, and so the audit trail records which inputs the assistant already
collected. The server reloads the slots into every turn, so the model cannot
lose a collected value by forgetting it.

The tool trace keeps what actually ran: the validated arguments, and the
result the deterministic service returned. A failed call records the error and
its code instead of a result, so the trail never shows a figure that was never
computed.

ADR 0001 is not weakened. The agent still does not offer generic CRUD over
generated finance data. Reading and clearing chat sessions remains a user
action; the agent only appends to the conversation it is answering in.

The language model performs conversation, slot extraction and tool invocation
only. It never computes money. Every number a user sees comes from a
deterministic tool result, exactly as ADR 0009 requires. The tools are
`create_budget_plan`, `simulate_purchase_impact`,
`search_nearby_similar_places`, `confirm_and_rebalance_budget` and
`ask_user_question`; they are invoked through one registry that validates
arguments with Pydantic before any
service runs, checks plan ownership from the server-side user id, and refuses
to call a writing tool more than once per turn.

User input, extracted media data and tool results are separated regions. The
system prompt never contains user text. Media data reaches a tool only as a
normalized number that already passed validation. The instruction text inside
media is data, never an instruction.

The places tool is named `search_nearby_similar_places`. Google Places exposes
a coarse price level and no price, so the tool filters by rating, price level
and open state and returns similar places; it never claims to find somewhere
cheaper. A deterministic fake implementation backs the tool contract in tests
and in a deployment without a Places key.

The home screen becomes the conversational canvas. The ledger moves to its own
route and keeps its own navigation entry, so no existing capability is lost.

The canvas talks to five endpoints: `GET /api/v1/chat/tools`,
`POST /api/v1/chat/sessions`, `GET /api/v1/chat/sessions/{id}`,
`GET /api/v1/chat/sessions/{id}/messages` and `POST /api/v1/chat/turn`. The
client never writes the slots and never stores a plan; it renders what the
server returns.

## Consequences

Chat sessions are now written by the server, which changes the retention and
audit posture described in ADR 0001. The slot columns hold financial context
about the user and inherit the retention policy of the chat tables.

The conversational quality depends on the language model. The money does not:
when the model proposes a wrong number, the tool rejects the arguments and no
row is written. When the model hallucinates a tool result, the recorded
`tool_result` column shows what was actually executed.

Without a Places key the places tool reports that it is unavailable and the
rest of the conversation continues. Without a Gemini key the assistant reports
that it is not configured and returns no invented figures.

The home screen no longer shows the balance at a glance. The ledger keeps that
view, and the conversational canvas can open it.

## Amendment: a missing migration must not lock the canvas

A provider failure and a missing migration are different problems, and both
must leave the user with a way forward.

The provider failure is a `ChatError` with status 503 and an actionable
Vietnamese message. It is not an opaque 500: the user learns that the
assistant is not configured or is busy, and can retry.

A missing migration is a schema state, not a provider state. Until
migration `202611010002` is applied, the slot columns and the tool trace do
not exist. The repository detects the missing column and degrades: the
conversation still reads and writes its messages, the slots are dropped and
the tool trace is left out. The composer stays usable. A migration that has
not been applied must never be reported as a broken assistant.

The client keeps the composer enabled as soon as a session exists. Reading
the message history is a convenience, not a precondition: a failure to read
it shows the error and leaves the input field enabled, so the user is never
locked out of the canvas by a read that failed.

The canvas offers a retry on the unavailable state. Without it the only way
out was to leave the screen.

## Amendment: the tool schema must match the Gemini dialect

The function-calling API accepts a narrower dialect than JSON Schema. It has
no `exclusiveMinimum`, no `exclusiveMaximum`, no `pattern` and no `anyOf`.
A Pydantic JSON schema carries all four, so a declaration built straight
from `model_json_schema()` is rejected by the SDK before the request leaves
the process, and the assistant answers nothing at all.

The registry therefore converts the schema instead of passing it through. A
nullable field becomes one schema with `nullable: true`; a field that accepts
a number or a numeric string keeps the number, because the model sends a
number and the argument model parses both. The JSON-schema types are mapped
to the names the API uses (`INTEGER`, `NUMBER`, `STRING`, `OBJECT`, …). The
argument validation is unchanged: the model still receives the strict
Pydantic model, so the schema the model sees may be wider than the schema
the registry enforces.

## Amendment: the choices are a tool, not a rendering

A user answering "one month, three months or six months?" has to type the
answer. The canvas can offer the choices as tappable chips instead, but only
if the assistant actually proposes them.

The choices are therefore a fifth tool, `ask_user_question`. It carries a
question and two to four short options and writes nothing: it exists so the
client can render the options as chips labelled `A.`, `B.`, `C.`, `D.`, plus a
`Khác` chip that lets the user type an answer of their own. The server reads
the options out of the tool result and returns them with the turn; the client
never invents an option.

The tool is only useful if the model calls it. A prompt that merely names the
tool leaves the model free to answer in prose, and the user then sees no
options at all without any error. The system prompt therefore states the rule
plainly: a question whose answer is two to four discrete choices must go
through the tool, and the choices must not be listed in prose. A question that
needs a free-form number the user has to type — income, fixed expenses — is
still asked in text, because there is nothing to tap.

## Amendment: a spent allowance is not an outage

The provider refuses a request whose daily allowance is used up with HTTP 429
and the status `RESOURCE_EXHAUSTED`. That is not a transient outage: the
allowance for the day is spent, and an immediate retry fails the same way.

The provider failure is therefore not one status. A quota refusal answers
**429** with its own message, so the user learns that waiting is the fix
instead of being told to retry a service that is not busy. Every other
provider failure stays a **503**, because the assistant is genuinely
unavailable and a later retry may succeed. The client passes the chat
message through for both, so the Vietnamese text reaches the screen unchanged.
