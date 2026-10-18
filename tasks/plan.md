# Authentication, guests and Android branding

The user approved specs #45, #46 and #47 and requested execution on 2026-10-18.
Tasks are tracked in GitHub Issues in Drista4real/Project1; this file is the plan,
not another task tracker. Existing ADRs 0001 and 0002 remain applicable.

The user requested publication on a new feature branch based on GitHub develop.
Local develop was fast-forwarded to 232bc08 and the work transferred without
conflicts to feat/email-otp-guest-auth. Credentials and build output are excluded
from feature commits. The existing unrelated stash is retained.

## Sequence and verification

1. Auth state machine: password signup/login, OTP, resend and recovery. Test with
   the actual GoTrueClient and an isolated HTTP transport before adding UI.
2. Forms and session gate: no finance requests without a session; recovery does
   not accidentally unlock normal finance navigation. Widget tests and analyze.
3. Anonymous guests: retain UID on email linking, handle email conflicts and
   confirm before abandoning a guest; sync profile email in an additive migration.
   Test guest/link state transitions, session restoration, RLS and record identity.
4. Logo: editable vector, raster exports, legacy/adaptive/monochrome Android icons
   and shared brand display. Inspect rendered artwork and build debug APK.

## Task index

- [#48](https://github.com/Drista4real/Project1/issues/48): Implement email authentication and recovery state machine
- [#49](https://github.com/Drista4real/Project1/issues/49): Integrate authentication screens and session gate
- [#50](https://github.com/Drista4real/Project1/issues/50): Implement anonymous guest access and email linking
- [#51](https://github.com/Drista4real/Project1/issues/51): Create Kakeibo Zen logo and Android launcher assets

## Checkpoints and boundaries

Run focused tests after each slice, then full Flutter analyze/test and Android
debug build. Record results in the tracker. Keep integration specs open until
actual Auth/email/device evidence exists; do not equate mocks with mail delivery.
No deployment, paid service purchase, production Auth changes or secrets in logs.
Use Supabase Auth for delivery and verification. Anonymous users use their own UID
and authenticated JWT; backend bearer checks and RLS remain enabled.
Recovery verification must precede password mutation. Capture session ownership
so an old screen cannot sign out or mutate a replacement account.
Email linking keeps the UID; conflicting existing accounts are never auto-merged.
Migration rollback removes only the new sync trigger/function, retaining data.

## Integration commands

Frontend: `flutter analyze`, `flutter test`, `flutter build apk --debug`.
The existing Java stack is CI-only (tests/backend-e2e/README.md): generate
disposable credentials with `python docker/generate_env.py`, then configure
COMPOSE_FILE=compose.yaml and COMPOSE_ENV_FILES=.env.ci before invoking Compose.
Docker availability is checked before claiming integration execution. Real mail
requires SMTP, OTP templates, anonymous sign-ins and linking enabled in Supabase.

## Validation recorded on 2026-10-18

Implementation tasks #48–#51 are complete in the workspace. Flutter analyze has
no issues; all 137 Flutter tests pass, including 16 auth/guest tests. Compiled
web release passes all 7 Chrome Selenium smoke scenarios. Android debug APK
build passes, and aapt2 confirms adaptive foreground/background/monochrome layers.
The logo masks and actual web login screenshot were visually inspected.
The new Java integration sources compile targeting Java 21; Compose structure
validates. Docker daemon is unavailable locally, so the actual Auth/SMTP/RLS
suite has not executed. Specs #45–#47 and umbrella #44 retain hosted-service and
device acceptance. See frontend/supabase/README.md for configuration/migration.
