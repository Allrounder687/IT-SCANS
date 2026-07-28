# Product Context

## What it is

A CamScanner-style document scanner for Android (Flutter). Scan a document
with the camera, get automatic edge detection/cropping/enhancement, save as
PDF/image, share it. Designed around "zero cognitive load" — one obvious
action per screen, minimal decisions.

## Target user

Someone who occasionally needs to digitize a physical document (form,
receipt, ID, note) and wants it done in seconds without an account, tutorial,
or subscription wall in the way.

## Monetization

- Free: 400 scans (functionally unlimited for casual users), no watermark.
- One-time $2 unlock: removes the scan cap entirely.
- Subscription add-on (future, Phase 5): OCR/searchable text, cloud sync
  across devices, batch export — reserved for features with real ongoing
  cost/value, never for "more scans." See `docs/DECISIONS.md` for the
  reasoning.

## Non-goals for v1

- No accounts/login.
- No cloud sync or backend beyond the scan counter.
- No OCR.
- No iOS build (Android first; the scanner plugin supports both, so iOS is a
  smaller lift later, but out of scope until Android ships and validates).

## Roadmap

See `docs/STATE.md` for current phase and status — this section only holds
things not yet scheduled into a phase:

- iOS port (post-Android-launch)
- OCR tier
- Cloud sync tier
- Localization beyond English, if usage data supports it
