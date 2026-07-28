# CLAUDE.md — Agent Steering Doc

This file is the entry point for any AI agent working in this repo. Read this
first, every session, before touching code. It links out to everything else
you need — do not skip the linked docs when they're relevant to your task.

## What this project is

A Flutter document-scanner app for Android and iOS (CamScanner-style): scan → crop/
enhance (via ML Kit Document Scanner) → save/export as PDF → optional OCR and
cloud sync behind a paid tier. Full product context: `docs/PRODUCT.md`.

## CI/CD & iOS Builds

The project uses GitHub Actions (`.github/workflows/build_ios.yml`) to automatically build and package unsigned `.ipa` files for jailbroken devices.
- **DO NOT** try to code-sign the iOS app or add a `DEVELOPMENT_TEAM` to `project.pbxproj` (which will fail in CI).
- The workflow intentionally bypasses Flutter's internal Xcode validator by building the Dart AOT via `flutter build ios --release --no-codesign || true` and then compiling the native app via `xcodebuild` directly with `CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGNING_IDENTITY=""`.

## Golden rules for any agent working here

1. **Never guess project state — read it.** `docs/STATE.md` holds the current
   phase, what's done, what's in progress, and known issues. Read it before
   planning work. Update it before you finish, if anything changed.
2. **Every code change that alters behavior gets a CHANGELOG entry.** Unreleased
   changes go under `## [Unreleased]` in `CHANGELOG.md`. Don't batch silently.
3. **Every new architectural decision gets logged.** If you pick a package,
   a state-management approach, a data model shape, or reverse an earlier
   decision — add an entry to `docs/DECISIONS.md`. Future-you (or another
   agent) needs the *why*, not just the *what*.
4. **README stays a truthful, current entry point.** If setup steps, run
   commands, or the feature list change, update `README.md` in the same PR/
   session — not "later."
5. **Skills before code.** Check `.claude/skills/` for a matching skill before
   writing code in an area it covers (testing, release builds, ADB debugging,
   architecture conventions). If you find yourself repeating a non-trivial
   procedure a second time, turn it into a skill instead of re-explaining it
   inline next time.
6. **This steering system is meant to evolve.** If you notice the docs are
   missing something a future agent would need (a gotcha, a convention, a
   decision), add it. Don't wait to be asked. Treat gaps in this system as
   bugs.

## Session checklist

- [ ] Read `docs/STATE.md`
- [ ] Check `.claude/skills/` for anything relevant to the task
- [ ] Make the change
- [ ] Run tests (`.claude/skills/flutter-testing/SKILL.md` has the commands)
- [ ] Update `CHANGELOG.md` under `[Unreleased]`
- [ ] Update `docs/STATE.md` if project phase/status changed
- [ ] Update `docs/DECISIONS.md` if you made a non-obvious technical choice
- [ ] Update `README.md` if setup/run/feature-list facts changed

## Non-negotiable engineering standards

- **Clean code:** follow `analysis_options.yaml` lint rules — no warnings
  merged. Prefer small, single-responsibility widgets and services over large
  files. See `docs/ARCHITECTURE.md` for the layer boundaries (screens →
  providers → services → models) — don't let screens call platform plugins
  directly; go through a service.
- **No feature is "done" without a test** for its core logic (service/model
  layer). UI can rely on widget tests for critical flows only (scan → save,
  paywall gate). See `.claude/skills/flutter-testing/SKILL.md`.
- **Debug builds must run seamlessly over both USB and wireless ADB.** See
  `.claude/skills/adb-debugging/SKILL.md` — this is a solved, scripted
  procedure in `scripts/`, don't reinvent it per-session.
- **Release builds are scripted, not manual.** See
  `.claude/skills/flutter-release-build/SKILL.md` and `scripts/build-release.sh`.
- **Never commit secrets.** API keys, signing configs, and `google-services.json`
  stay out of git — see `.gitignore` and `docs/ARCHITECTURE.md#secrets`.

## Directory map

```
lib/            application code (see docs/ARCHITECTURE.md for layout)
test/           unit + widget tests, mirrors lib/ structure
docs/           living project docs (state, decisions, architecture, roadmap)
.claude/skills/ procedures agents should follow rather than reinvent
scripts/        one-command scripts for build/test/debug tasks
.github/        CI workflows
```
