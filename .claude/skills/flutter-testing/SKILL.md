---
name: flutter-testing
description: Use before considering any service, provider, or critical-path screen "done" — covers what must be tested, test file conventions, and the commands to run them. Also use when a test is failing and you need the standard troubleshooting steps.
---

# Flutter Testing

## What requires a test (per docs/ARCHITECTURE.md boundaries)

- **`services/`** — unit test all non-trivial logic (file naming, scan-count
  math, PDF page ordering, purchase-state handling). Mock platform plugins;
  don't hit real ML Kit/VisionKit or real IAP in unit tests.
- **`providers/`** — unit test state transitions (e.g. "adding a document
  updates the library list and persists it").
- **`screens/`** — widget tests only for the critical path: scan→save flow
  renders correctly, paywall appears exactly at the free-scan limit. Don't
  chase 100% widget coverage on every screen — that's low value here.
- **`models/`** — test serialization round-trips if the model is persisted.

## File convention

Mirror `lib/` structure under `test/`:

```
lib/services/scan_counter_service.dart
test/services/scan_counter_service_test.dart
```

## Commands

```bash
flutter test                        # run all tests
flutter test test/services/         # run one directory
flutter test --coverage             # generate coverage/lcov.info
./scripts/run-tests.sh              # wraps the above with sane defaults
```

## Mocking plugins

Use `mockito` or hand-written fakes for `flutter_doc_scanner`,
`in_app_purchase`, and any platform-channel plugin — never call real
native code in a unit test. If a test needs to exercise real plugin
behavior, that's an integration/manual-QA concern, not a unit test.

## Before marking a feature done

1. `flutter analyze` — zero warnings.
2. `flutter test` — all green.
3. If you touched a service/provider with no existing test, write one before
   moving on — don't defer it to "later," later doesn't come.
