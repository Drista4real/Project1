# Email authentication and anonymous guest ownership

Date: 2026-10-18. Status: accepted by the user's implementation request.
Specs: [identity #45](https://github.com/Drista4real/Project1/issues/45),
[guests #46](https://github.com/Drista4real/Project1/issues/46).

Supabase Auth issues and verifies credentials and sends email. Flutter handles
password sign-in, registration confirmation, existing-account email OTP, and
recovery OTP. OTP issuance alone never opens finance screens. Registration and
login codes use the SDK's email verification type; recovery uses recovery;
linking an email uses email_change. Signup resend uses the SDK's signup type.
Verification types must not be substituted across flows. Password entry is
never trimmed and password/OTP values are not persisted by application code.

The auth form remains mounted when verification creates a session. The finance
tree is entered only on completion of that form. In particular passwordRecovery
opens the new-password step, not finance. Recovery completion/cancellation signs
out only the local session it owns. Captured access-token ownership guards
sensitive mutations/sign-out against a replacement account. A refreshed token
that no longer matches requires verification again rather than guessing identity.

A guest is a real Supabase anonymous user with an authenticated JWT and its own
UID. Data is stored through the existing backend/RLS. Guest use requires network;
it is not a local/offline ledger. Restoring a persisted session retains the UID.
Losing the session before linking an email can make the data inaccessible.
Leaving an unlinked guest requires confirmation, including from the app lock.

Linking updates the current user and verifies the new email, preserving UID,
profile, wallets, transactions, balances, references and device preferences. A
linked user may set a password or use email OTP. Password setup failure does not
undo successful email verification. Conflicting existing accounts are not merged;
the guest keeps its session and can choose another email. A database trigger
synchronizes profile.email only when auth.users.email actually changes; it does
not re-run the new-user wallet trigger. The additive migration also repairs stale
profile emails and can be safely re-applied.

Same-UID auth updates refresh account labels without recreating navigation.
Changing UID recreates the finance tree and maintains the isolation/app lock
rules in ADR 0001. Auth and generated-data permissions are not weakened.

SMTP, templates, OTP expiry/length and anonymous provider enablement are Supabase
service settings. Code changes or backend/.env alone do not apply those settings.
See frontend/supabase/README.md for setup and verification limits.

Migration rollback removes on_auth_user_email_updated and
sync_auth_profile_email(); it preserves every stored profile and financial record.
Reverting the UI can retain the additive email-sync trigger safely.
