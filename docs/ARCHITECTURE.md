# Architecture

## Layering — strict one-way dependency

```
screens/    (UI, widgets — no business logic, no plugin calls)
   ↓ calls
providers/  (state holders — expose data + actions to screens)
   ↓ calls
services/   (business logic, wraps plugins/platform APIs, pure Dart otherwise)
   ↓ calls
models/     (plain data classes, no logic beyond serialization)
```

**Rule:** a screen never imports a plugin package directly (no
`import 'package:flutter_doc_scanner/...'` inside `screens/`). It always goes
through a service. This keeps plugin swaps (e.g. changing the scanner
package) contained to one file.

## Directory layout

```
lib/
  main.dart                      entrypoint, sets up providers
  app.dart                       MaterialApp, theme, route table

  core/
    theme.dart                   design tokens (see docs/DESIGN_SYSTEM.md)
    constants.dart                scan limits, product/purchase IDs
    router.dart                  route definitions

  models/
    scan_document.dart           id, title, pageCount, filePath, createdAt

  services/
    scanner_service.dart         wraps flutter_doc_scanner
    storage_service.dart         local file + DB read/write
    pdf_service.dart             page merge / PDF export
    purchase_service.dart        in_app_purchase wrapper
    scan_counter_service.dart    free-tier usage tracking

  providers/
    library_provider.dart        list of saved documents, CRUD
    scan_session_provider.dart   in-progress scan session state

  screens/
    home/ scan/ export/ settings/ paywall/   (one folder per screen)

  widgets/                       shared, reusable, presentation-only widgets
```

## State management

Not yet chosen — see `docs/DECISIONS.md` once decided (Provider is the
default assumption for a project this size; escalate to Riverpod only if
provider-tree complexity actually becomes a problem).

## Secrets

Never commit: `android/app/google-services.json`, keystore files (`*.jks`,
`*.keystore`), `key.properties`, or any `.env` file. All are listed in
`.gitignore` already — if you add a new secret-bearing file type, add it
there too, in the same change.

## Testing boundaries

- `services/` and `models/`: unit tests required for all non-trivial logic.
- `providers/`: unit tests for state transitions.
- `screens/`: widget tests only for the critical path (scan → save, paywall
  gate showing at the right count) — not exhaustive UI tests for every screen.

See `.claude/skills/flutter-testing/SKILL.md` for commands and conventions.
