# Email OTP, password recovery and guests

The Flutter client calls Supabase Auth directly. FastAPI continues validating
the resulting bearer token and accessing finance data under that user's RLS.
Adding SMTP settings to backend/.env does not configure hosted Supabase Auth.

## Hosted project setup

In the Supabase project used by the app:

1. Enable the Email provider and email confirmation. Set email OTP length to 6
   and expiry to 600 seconds. The server enforces expiry, reuse and rate limits;
   the client's 60-second resend countdown is only a convenience.
2. Configure custom SMTP and a verified sender in Authentication settings to
   deliver to ordinary user addresses. The default sender has recipient and
   quota restrictions. Keep SMTP credentials only in the service configuration.
3. Copy the supplied templates into their corresponding email templates:
   `email-templates/confirm-signup.html` → Confirm signup;
   `email-templates/magic-link.html` → Magic link;
   `email-templates/reset-password.html` → Reset password;
   `email-templates/change-email.html` → Change email address.
   Every template includes `{{ .Token }}` so users can enter the code in the app.
   This app's primary flows use typed codes and do not require a mobile redirect.
4. Enable Anonymous Sign-Ins. Check identity-linking settings against the
   [Supabase anonymous account guide](https://supabase.com/docs/guides/auth/auth-anonymous).
   Keep ownership policies using auth.uid(); anonymous users still have the
   authenticated role, not a shared guest identity. If CAPTCHA is required by the
   project, its client challenge/token must also be integrated before these
   requests can succeed; configuration errors are shown without losing the form.
5. For an existing database, apply
   `backend/supabase/migrations/202610180001_auth_profile_email_sync.sql` using a
   database owner in the SQL editor. Do not reset an existing schema. New
   disposable databases include the trigger in schema.sql. This migration repairs
   stale profile emails but never changes financial ownership or amounts.

Application implementation does not automatically apply these hosted settings.
Use a disposable project and inbox to verify configuration before switching users.

## User behavior

- Sign up with email and password (at least eight characters in the app) and enter
  the confirmation code. Existing six-character passwords still work for sign-in.
- Email OTP sign-in does not create an account automatically; use registration
  for a new account. Failed/expired codes keep the form available for retry.
- Forgot password sends a recovery code. Verify it, set and confirm the new
  password, then sign in again. Recovery verification is not normal navigation.
- Guests can enter real finance data through the existing backend. Link a new
  email from Settings before signing out, clearing app data or moving devices.
  Data remains under the same UID and no new wallet is created. A conflicting
  existing email keeps the guest session; account merging is not supported.
- After linking, password creation is optional; email OTP can be used immediately.
  With email confirmation disabled in a test project, already-confirmed linking
  skips the code step. Production should use email confirmation.

## Verification

From frontend:

```powershell
flutter analyze
flutter test
flutter test test/features/auth --reporter expanded
flutter build apk --debug
```

Auth tests run the actual locked GoTrueClient against an isolated HTTP transport.
They exercise request contracts, errors, UI, recovery and guest identity handling;
they do not establish actual email delivery or an Android launcher outcome.
The disposable Docker/Java stack in tests/backend-e2e includes a Mailpit inbox
and real OTP/recovery/guest/RLS tests. It runs in the repository's existing CI.

Before accepting a deployed configuration, receive signup/login/recovery/link
emails in a test inbox, verify codes and replay rejection, sign in with the new
password, and compare wallet/transaction IDs and balances before/after linking.
Verify guest restoration after app restart and launcher/themed icons on Android.
Do not use production credentials or private financial data in test fixtures.

Rollback of only the email-sync migration:

```sql
DROP TRIGGER IF EXISTS on_auth_user_email_updated ON auth.users;
DROP FUNCTION IF EXISTS public.sync_auth_profile_email();
```

References: [Email OTP](https://supabase.com/docs/guides/auth/auth-email-passwordless),
[SMTP](https://supabase.com/docs/guides/auth/auth-smtp),
[email templates](https://supabase.com/docs/guides/auth/auth-email-templates).
