# Device settings and generated finance data

Date: 2026-10-18. Status: accepted. Implementation ticket: [#37](https://github.com/Drista4real/Project1/issues/37).

The Flutter app exposes generated forecasts, alerts, consultations, chat sessions
and messages for reading. Generic create/edit/delete controls are removed for
these five resources. Alert read/resolve actions remain in the forecast screen.
This is an app navigation decision; existing backend contracts and stored data
are retained for producers and other consumers.

Dark mode, device authentication and daily reminder opt-ins use local
SharedPreferences keys scoped to the authenticated user ID. A profile's legacy
`biometrics_enabled` default or `reminder_time` must not enroll a new device.
The generic profile form excludes these device settings. Enabling or disabling
the app lock requires successful device authentication; biometric authentication
can fall back to the device passcode. Locking covers all routes when the app
loses focus and after startup. Account changes recreate the app widget tree;
asynchronous authentication from the previous account cannot unlock the next.
This UI lock does not encrypt the local store or replace Supabase authentication.
Signing out from the lock screen resets this device's biometric opt-in; the user
must authenticate with their account again before re-enrolling, providing recovery
when device credentials become unavailable.

Daily reminders are supported on Android, iOS and macOS. Web, Windows and Linux
show unavailable controls. Permission is requested only after user interaction.
Scheduling uses the device's IANA zone, restores without permission prompts at
startup, and uses one notification ID so changing the time replaces the schedule.
Signing out cancels the active reminder. Android uses inexact scheduling and boot
receivers, without requiring exact-alarm access. Operating-system restrictions
can delay delivery.

XLSX/PDF export runs locally using every transaction matching the settings
query, date range and selected tags, independent of the 12-row preview limit.
Transfers appear in the report but are excluded from total income/expense.
Totals accumulate integer hundredths of VND. PDF embeds bundled Vietnamese fonts.
Web downloads the file, desktop opens a save dialog, and mobile opens the system
share/save sheet. No export data is uploaded to a reporting service.

Validation must cover device permission rejection, authentication cancellation,
account isolation, lifecycle locking, filtering beyond the preview limit, report
contents and native integration. Real-device biometric, notification delivery,
reboot and OS save/share behavior require a device smoke check; unit/widget tests
alone do not establish these outcomes.
