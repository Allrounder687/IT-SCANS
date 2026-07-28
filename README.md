# IT SCANS

A premium, CamScanner-style document scanner for Android, built in Flutter. Scan → auto-crop/enhance (Google ML Kit Document Scanner) → contextual auto-name (ML Kit OCR) → save to local SQLite → sync to Google Drive.

Designed around **Zero Cognitive Load**: one obvious action per screen, immersive scrolling, discoverable kebab menus, Apple-style swipe gestures, and tactile haptic feedback.

> **For AI agents:** read `CLAUDE.md` first, not this file. This README is
> for humans; `CLAUDE.md` is the steering doc with the rules and checklist.

## Premium Features
- **Flexible Monetization**: Offers 100 free scans before gracefully transitioning to a 3-tier choice (Ad-Supported, 400 Consumable Scans, or 1-Year VIP) to support the dev team.
- **Contextual Auto-Naming**: Uses offline ML Kit Text Recognition to read the first page of a scan and automatically names the document based on its content (e.g. "Invoice 2023").
- **Private Cloud Sync**: Securely backs up documents to the user's hidden Google Drive `appDataFolder` (zero external servers used).
- **Smart Deduplication**: Restores files with surgical precision by anchoring cloud IDs to local SQLite IDs, renaming conflicts instead of duplicating them.
- **Immersive UI**: Features a custom Fanned Stack layout, dynamic time-aware greetings, and UI elements that hide on scroll for maximum reading space.

## Current status

See `docs/STATE.md` — this is the living source of truth for what phase the
project is in and what's done vs. in progress.

## Prerequisites

- Flutter SDK (stable channel) — [install guide](https://docs.flutter.dev/get-started/install)
- Android Studio or VS Code with the Flutter/Dart extensions
- An Android device or emulator running API 24+
- `adb` available on your PATH (ships with Android SDK platform-tools)

Verify your setup:

```bash
flutter doctor -v
```

Fix anything it flags before proceeding — especially Android toolchain and
license acceptance issues.

## Getting started

**First time only** — this repo is Dart source + config; the platform
folders aren't generated yet:

```bash
flutter create --org com.syeds --project-name itscans .
flutter pub get
./scripts/generate-icons.sh   # materializes assets/icon/ into android/app/src/main/res/
```

Then, day to day:

```bash
flutter pub get
flutter run
```

## Running on a real device

### USB

```bash
adb devices          # confirm the device shows up as "device", not "unauthorized"
flutter run
```

### Wireless (no cable needed after initial pairing)

See `scripts/adb-wireless.sh` — one command handles pairing and connecting.
Full explanation in `.claude/skills/adb-debugging/SKILL.md` if anything
doesn't "just work."

```bash
./scripts/adb-wireless.sh
```

## Common tasks

| Task | Command |
|---|---|
| Run in debug | `flutter run` |
| Run tests | `./scripts/run-tests.sh` |
| Analyze / lint | `flutter analyze` |
| Format | `dart format .` |
| Build release APK | `./scripts/build-release.sh` |
| Connect wireless ADB | `./scripts/adb-wireless.sh` |

## Project structure

See `docs/ARCHITECTURE.md` for the full layout and layering rules.

## Design

See `docs/DESIGN_SYSTEM.md` for color/type tokens and screen-specific rules —
implementations should match this exactly.

## Documentation map

```
CLAUDE.md               agent steering doc — read this first if you're an AI
docs/STATE.md           current phase, what's done, known issues
docs/PRODUCT.md         what this app is, target user, monetization, roadmap
docs/ARCHITECTURE.md    layering rules, directory layout, secrets handling
docs/DESIGN_SYSTEM.md   colors, type, screen-specific design rules
docs/DECISIONS.md       why non-obvious technical choices were made
.claude/skills/         step-by-step procedures (testing, release, ADB, etc.)
CHANGELOG.md            what shipped, in Keep a Changelog format
```

## Contributing

See `CONTRIBUTING.md`.
