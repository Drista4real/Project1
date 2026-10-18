# Shared domain glossary

- **Guest**: a Supabase anonymous user with a private UID and server-stored finance
  data. It requires a network connection and a retained session until linked.
- **Email linking**: verifying an email on the current guest identity, retaining
  its UID and financial records. It does not merge two existing accounts.
- **Recovery OTP**: an email code verified for password recovery before setting
  a new password. It is distinct from the code used for passwordless sign-in.

- **Generated finance data**: cashflow forecasts, cashflow alerts, AI consultations,
  chat sessions and chat messages produced by the system. The app exposes reading;
  generic manual CRUD is unavailable. Alert read/resolve are separate user actions.
- **App lock**: a device authentication gate protecting the visible finance app
  after startup or loss of focus. It is distinct from signing in to an account.
- **Daily reminder**: an opt-in notification on the current device reminding the
  signed-in account to record transactions at a selected local time.
- **Filtered report**: an XLSX or PDF containing every transaction matching the
  selected date range, search query and tags. A wallet transfer is not income or
  spending when calculating report totals.
