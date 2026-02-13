# Repository Guidelines

## Project Structure & Module Organization
Current layout:

- `Apps/HijriCalendarApp/` — SwiftUI iOS app.
- `Sources/HijriCalendarCore/` — shared calendar logic and parsers.
- `Tests/` — core module tests and fixtures.
- `platform/` — Convex-backed authority console (web UI + API).
- `docs/` — specs and design notes.
- `REQUIREMENTS.md` — product requirements baseline.
- `AGENTS.md` — contributor and automation guidelines.

## Build, Test, and Development Commands
Common commands:

- `xcodebuild -project Apps/HijriCalendarApp/HijriCalendarApp.xcodeproj -scheme HijriCalendarApp -configuration Debug -destination 'id=<DEVICE_ID>' install` — build and install to a device.
- `cd platform && npm run dev` — start the authority console.
- `cd platform && npx convex dev` — run Convex backend locally.

## Coding Style & Naming Conventions
No style guide is enforced yet. Once you choose a formatter/linter, document it here (for example, Prettier/ESLint or Black/ruff). Until then:

- Use consistent indentation (2 or 4 spaces) and line endings.
- Prefer descriptive names for files, modules, and functions.
- Match file names to component or module names (e.g., `HijriCalendar.tsx`).

## Testing Guidelines
There is no configured test framework yet. When you add tests, specify:

- the framework (e.g., Jest, Vitest, pytest)
- naming conventions (e.g., `*.test.ts`, `test_*.py`)
- how to run the suite and any coverage expectations

## Commit & Pull Request Guidelines
There is no commit history yet, so no established message convention. Once you start committing, adopt a clear style (e.g., Conventional Commits) and document it here. For pull requests, include:

- a brief summary of changes
- test results or a note if not run
- screenshots for UI changes, when applicable

## Security & Configuration Tips
Do not commit secrets. Add local configuration to `.env` or similar files and ignore them via `.gitignore`. Document required environment variables once they exist.

## Agent-Specific Instructions
Keep this file up to date as the project grows. If you add new scripts or directories, reflect them here so contributors and automation have accurate guidance.
