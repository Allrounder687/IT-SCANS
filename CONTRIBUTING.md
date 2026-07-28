# Contributing

This applies equally to human contributors and AI agents working in this
repo — if you're an AI agent, read `CLAUDE.md` first for the full steering
system; this file is the short version.

## Workflow

1. Check `docs/STATE.md` for current project phase before starting.
2. Make your change, following `docs/ARCHITECTURE.md` layering and
   `.claude/skills/flutter-clean-code/SKILL.md` conventions.
3. Add/update tests per `.claude/skills/flutter-testing/SKILL.md`.
4. Run `./scripts/run-tests.sh` — must pass clean.
5. Update `CHANGELOG.md` under `[Unreleased]`.
6. Update `docs/STATE.md` if phase/status changed.
7. Update `docs/DECISIONS.md` if you made a non-obvious technical choice.
8. Commit with a clear message; open a PR against `main`.

## Commit messages

Short imperative summary line, e.g. `Add scan counter service` not `Added
scan counter service` or `stuff`. Body explaining *why* if the change isn't
self-evident from the diff.

## Don't

- Don't commit generated files (`build/`, `.dart_tool/`) or secrets
  (keystores, `key.properties`, `google-services.json`) — see `.gitignore`.
- Don't skip the CHANGELOG/STATE update "because it's a small change" — small
  changes are exactly what gets lost without this habit.
- Don't add a new top-level dependency without a corresponding entry in
  `docs/DECISIONS.md` explaining why.
