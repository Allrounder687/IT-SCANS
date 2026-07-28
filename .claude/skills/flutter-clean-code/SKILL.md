---
name: flutter-clean-code
description: Use whenever writing or reviewing Dart/Flutter code in this repo — covers the lint config, layering rules, and naming/structure conventions specific to this project so code stays consistent as it grows.
---

# Clean Code Conventions

## Enforced automatically

`analysis_options.yaml` at the repo root enables `flutter_lints` plus a few
stricter rules. Run `flutter analyze` before considering any change done —
zero warnings is the bar, not a suggestion.

## Layering (see docs/ARCHITECTURE.md for full detail)

`screens/` → `providers/` → `services/` → `models/`, one direction only. If
you're tempted to import a plugin package inside `screens/`, stop — wrap it
in a service instead, even if it feels like overkill for a one-line call.
This is what keeps plugin swaps and testing feasible later.

## Naming

- Files: `snake_case.dart`
- Classes: `UpperCamelCase`
- Private members: `_leadingUnderscore`
- Service classes end in `Service` (`ScannerService`), provider classes end
  in `Provider` (`LibraryProvider`) — the suffix should tell you the layer at
  a glance.

## File size

If a file crosses ~200 lines, that's a signal to split it — usually a
screen file that's grown its own sub-widgets should extract them into
`widgets/` rather than staying inline.

## Comments

Prefer self-explanatory code + doc comments (`///`) on public service
methods over inline `//` narration. Reserve inline comments for genuinely
non-obvious reasoning (e.g. "why this workaround exists for this plugin
version") — not for restating what the code already says.

## Before opening a PR / finishing a session

1. `dart format .`
2. `flutter analyze` — zero warnings
3. `flutter test` — all green
4. Check the `CLAUDE.md` session checklist (docs/changelog updates)
