# Hijri Calendar Reminders – v1 Requirements (February 2, 2026)

## Overview
An iOS app that lets users create Hijri‑date–based reminders with their own notes and attachments. The app uses calculated dates by default and can optionally switch to moonsighting updates from the Central Hilal Committee (CHC).

## Scope (v1)
- Hijri‑based reminders only (no Gregorian reminders).
- Reminders app–style UI: single list view + Hijri calendar view.
- English only.

## Core UX
- Calendar shows Hijri dates with corresponding Gregorian dates.
- Tap a date to create a reminder.
- Dates with reminders show visual indicators.
- Single list view (no folders/lists in v1).

## Reminders
- Recurrence: annual Hijri recurrence and one‑time (specific Hijri year).
- Time: user‑selected time; default 12:00am if none.
- Multi‑day events: notify every day at chosen time.
- Notes: plain text.
- Attachments: photos, files, links (via Photos/Files/URL).
- Notes/attachments persist across all occurrences.

## Hijri Date Sources & Rules
- Calculated baseline: https://fiqhcouncil.org/calendar/
- Moonsighting authority: Central Hilal Committee (CHC).
- Moonsighting source: https://hilalcommittee.org/ (scrape latest month PDF from site).
- Moonsighting is off by default and must be enabled by the user.
- If moonsighting enabled:
  - Use CHC data when available.
  - Otherwise use calculated dates.
  - When CHC updates arrive, remap affected dates and notify the user.
- If moonsighting disabled: calculated dates only.
- Users see only the active date source (no side‑by‑side comparison).

## Calendar Refresh
- Refresh calendar data once every hour.

## Notifications
- Standard iOS sound.
- Local notifications only.
- If CHC updates change dates: reschedule silently and send a notification:
  - “New data available for month <X>; calendar updated.”

## Data & Backup
- All data stored on‑device.
- iCloud restore (not real‑time sync).
- Export/backup: single .zip containing JSON plus separate attachment files; JSON references attachment paths.

## Out of Scope (v1)
- Templates/presets for occasions.
- Curated religious content or suggested acts of worship.
- Multiple reminders per occasion.
- Custom sounds.
- Rich text notes.
- Cloud sync or sharing with other users.
