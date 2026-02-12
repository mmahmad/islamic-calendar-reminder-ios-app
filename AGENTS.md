# Repository Guidelines

## Project Structure & Module Organization
This repository currently contains documentation only; source code has not been added yet. As you add code, keep a predictable layout and document it here. A common pattern is:

- `src/` for application code
- `tests/` or `__tests__/` for automated tests
- `assets/` or `public/` for static files
- `scripts/` for dev utilities
- `docs/` for specs and design notes
- `Apps/` for iOS app sources (SwiftUI shell and views)
- `REQUIREMENTS.md` for the product requirements baseline
- `docs/ENGINEERING_SPEC.md` for the technical spec

If you choose a different structure, update this section with the actual paths and a short description of each top-level directory.

## Build, Test, and Development Commands
No build, test, or dev commands are defined yet. When you add tooling, list the exact commands and what they do. Example format:

- `npm run dev` — start the local dev server
- `npm test` — run the test suite
- `npm run build` — create a production build

Replace the examples with the real commands for this project.

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
