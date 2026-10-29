# Local synthetic data and explicit hashtag search

Date: 2026-10-22. Status: accepted.
Ticket: [#71](https://github.com/Drista4real/Project1/issues/71).

Manual app testing uses a separate persistent Docker project with local Supabase
Auth, PostgREST, PostgreSQL and the real backend. Synthetic records are seeded
through user-scoped HTTP APIs, including wallet income and transaction-tag links.
This exercises the same relationships, triggers and ownership checks as the app.
Production account settings and `backend/.env` are not used to seed data.

The local overlay reuses the integration stack, publishes loopback-only ports
18000/18001/18025 and generates ignored local credentials plus complete Flutter
configuration for browser/desktop and Android emulator. Schema installation runs
once; a migration journal detects changed applied migrations. Restarts preserve
the database, identity and user edits. Reset explicitly deletes only the named
demo project's volume. The seeder resumes partial setup by stable names/descriptions
and marks completion by user identity; it does not continuously overwrite edits.

Tags are user-owned labels; transaction_tags stores the actual assignments.
Settings hashtag searches match assigned tag names, normalizing Vietnamese tone
marks and ignoring spaces. Thus #dulich, #du lich and #Du lịch select the same
linked transactions. A note containing those words without a tag does not match
a hashtag search. Plain search includes notes, category, amount and tag names.
Selected chips and date range still intersect the search results. Report exports
use the same filtered transaction set.

A running backend's missing wallet-income endpoint is a deployment mismatch,
distinct from a deleted record. The reported localhost:8000 image was confirmed
to omit the route in OpenAPI despite updated source and database migration.
Rebuilding that API restored the route. The client displays actionable guidance
for the missing operation and retains missing-record messages for real 404s.

Local setup and expected seed totals are documented in dev/local/README.md.

Validation on 2026-10-22: 154 Flutter tests and 57 Docker Java integration/E2E
tests passed; Flutter analyze and the demo Python lint passed. The Docker suite
includes deletion/recreation of a same-named wallet followed by income recording,
plus tag link CRUD and ownership isolation. API/Auth browser CORS preflights
passed. Fresh seeding and full stop/start preserved 12 transactions, 5 tags,
11 links and assets of 38,795,000 against income 40,000,000 and expenses
3,205,000. The demo stack is left running for manual testing, with reports under
dev/local/runtime/reports/ (ignored). The existing backend API at port 8000 was
rebuilt without changing its database records.
