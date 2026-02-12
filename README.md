# Islamic Calendar Reminder (iOS)

Hijri-based reminders with a familiar Reminders-style UI. The app focuses on user-owned content and manual moonsighting adjustments, so you can track important dates without relying on fragile external feeds.

## Highlights
- Hijri-only reminders with annual or one-time recurrence.
- Manual moonsighting overrides by Hijri month + Gregorian start date.
- Calendar view showing Hijri + Gregorian dates, plus source attribution.
- Notes and attachments (photos, files, links) stored locally on device.
- iOS 16+ with SwiftUI and a shared core module for date logic.

## Project Structure
- `Apps/HijriCalendarApp/` — iOS app (SwiftUI).
- `Sources/HijriCalendarCore/` — shared calendar logic + parsers.
- `docs/ENGINEERING_SPEC.md` — technical spec and diagrams.
- `REQUIREMENTS.md` — product requirements baseline.
- `AGENTS.md` — contributor and automation guidelines.

## Build & Run
Requirements: Xcode 15+, iOS 16+.

Open the project in Xcode:
- `Apps/HijriCalendarApp/HijriCalendarApp.xcodeproj`

Or build/install via CLI:
```sh
xcodebuild \
  -project Apps/HijriCalendarApp/HijriCalendarApp.xcodeproj \
  -scheme HijriCalendarApp \
  -configuration Debug \
  -destination 'id=<DEVICE_ID>' \
  install
```

## Manual Moonsighting Data
Overrides are stored locally and applied on top of the calculated calendar.
- Overrides: `Documents/ManualMoonsightingOverrides.json`
- Attachments: `Documents/Attachments/`

## Contributing
See `AGENTS.md` for repo guidelines, structure expectations, and contributor notes.
