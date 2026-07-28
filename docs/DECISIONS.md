# Decisions Log (lightweight ADR)

> One entry per non-obvious technical decision. Newest at top. Don't log
> trivial choices (variable names); do log: package choices, architecture
> patterns, data model shape, anything you reversed a prior decision on, and
> anything a reasonable person might have done differently.

Template for a new entry:

```
## YYYY-MM-DD — <short title>
**Decision:** what was chosen
**Why:** the reasoning, alternatives considered, and why they lost
**Reversible?** yes/no — and what it would cost to change later
```

---

## 2026-07-28 — Added "instant eye-catcher" design pass: launch beam-wipe, fanned home stack, shared-element PDF transition, beam-synced haptic
**Decision:** Added four specific polish items to differentiate the app from
a "default Material widgets" look: (1) a one-time beam-wipe transition on
cold launch, (2) home screen documents rendered as a loosely fanned stack
(not a flat grid) that flattens on tap/multi-select, (3) a Hero
shared-element transition from thumbnail into the PDF viewer, (4) a light
haptic tick synced to the beam passing over a card. QoL screens (rename,
delete, multi-select) explicitly excluded from the beam/fan treatment —
they're utility moments, not brand moments.
**Why:** App was functionally complete (scan, PDF view, delete, multi-
delete, rename) but felt "basic" — the actual causes were default Material
chrome, no motion, and a flat list with no depth, not a lack of features.
These four items target first-open impression and screenshot appeal
specifically, at low implementation cost (Flutter's `Hero` and implicit
animation APIs cover most of it).
**Reversible?** Yes, each item is independent and can be dialed back without
touching the others.

## 2026-07-28 — Beam motif moved off the native scanner UI
**Decision:** The "scan beam" sweep animation cannot overlay the native ML
Kit (Android) / VisionKit (iOS) document scanner activity — it's a closed,
unstyleable system UI. The motif is relocated entirely to screens we
control: the hand-off transition around the native scanner call, a one-time
sweep on a freshly-added page in Review, on a freshly-saved card on Home, and
as the app's launch animation. See `docs/DESIGN_SYSTEM.md` for the current
list — treat that list as authoritative, not this entry.
**Why:** Discovered when implementing — native scanner SDKs don't expose a
view hierarchy to inject into. Rather than dropping the motif, moved it to
the "just captured/saved" moments we do own, which is arguably a better fit
anyway (rarer = reads as deliberate, not decorative).
**Reversible?** N/A — not a preference, a platform constraint.

## 2026-07-28 — App identity: name, package ID, icon
**Decision:** App name "IT SCANS," Android package ID `com.syeds.itscans`.
Icon is a generated adaptive icon (separate foreground/background layers
plus an Android 13+ monochrome variant) built from a document-with-scan-beam
glyph matching `docs/DESIGN_SYSTEM.md` tokens — source files in
`assets/icon/`, wired via `flutter_launcher_icons` in `pubspec.yaml`.
**Why:** Package ID needed to be locked before the first real build since
Android treats it as a permanent identifier. Adaptive icon (vs. a single flat
PNG) is required for the icon to render correctly across OEM launcher shapes
(circle, squircle, rounded square) rather than being cropped or padded
oddly on some devices.
**Reversible?** Display name: yes, trivially. Package ID: no — changing it
post-launch means losing all reviews/install history and shipping as a new
listing. Icon: yes, regenerate via `scripts/generate-icons.sh`.

## 2026-07-28 — State management: Provider
**Decision:** Use `package:provider` for the `providers/` layer, not Riverpod
or Bloc.
**Why:** The app has a small, shallow widget tree (~5 screens, a handful of
services) with no complex cross-cutting async dependency graph. Provider is
the lowest-ceremony option that still enforces the screens→providers→
services layering in `docs/ARCHITECTURE.md`. Riverpod's compile-time safety
and Bloc's strict event/state separation solve problems this app doesn't
have yet.
**Reversible?** Yes — the layering rule (services never called directly from
screens) means the state-management library is swappable later without
touching the service layer.

## 2026-07-28 — Backend for scan counter: Firebase
**Decision:** Firebase (Firestore or Realtime Database + a minimal Cloud
Function or direct client write) for persisting the 400-scan free-tier
counter across reinstalls, tied to a device/account identifier.
**Why:** It's the only backend need in the whole product (see the
local-first storage decision above) — a managed serverless option avoids
standing up and maintaining real infrastructure for a single counter. Free
tier comfortably covers expected early-stage usage.
**Reversible?** Yes — this is an isolated service (`scan_counter_service.dart`)
behind the architecture's layering; swapping the backend later doesn't touch
the rest of the app.

## 2026-07-28 — Document scanning via flutter_doc_scanner (ML Kit / VisionKit)
**Decision:** Use the `flutter_doc_scanner` plugin, which wraps Google ML Kit
Document Scanner on Android and Apple VisionKit on iOS, instead of a custom
OpenCV/ML pipeline.
**Why:** Both underlying SDKs are free, on-device, and maintained by the
platform owner (used inside Google Drive's own scanner and iOS's native
scanner). Building custom edge-detection/perspective-correction would be
weeks of tuning work to match what's already free and production-grade.
**Reversible?** Yes, but costly — the scan capture flow is the core of the
app; swapping it later means rebuilding the Scan and Review screens' data
contracts.

## 2026-07-28 — Monetization model: 400-scan cap + one-time $2 unlock, subscription reserved for ongoing-cost features only
**Decision:** Free tier caps at 400 scans (functionally unlimited for casual
use). One-time $2 purchase removes the cap. A separate subscription tier is
reserved *only* for features with genuine recurring cost/value: OCR, cloud
sync, batch export — never for "more scans."
**Why:** Scanning itself has ~$0 marginal cost (on-device processing), so
gating it behind a subscription would be extracting rent without matching
cost. Cloud sync has real recurring infra cost, so subscription pricing is
justified there. Splitting by feature type (not volume) avoids the
"nickel-and-dimed" perception that hurts CamScanner-style apps' reviews.
**Reversible?** Partially — raising the $2 unlock price later is easy;
walking back a "lifetime unlock" promise to existing purchasers is not.

## 2026-07-28 — Local-first storage for v1, no backend until the paywall needs one
**Decision:** Scans are stored locally (`sqflite`/`hive` + filesystem) with no
account system or cloud sync in Phases 1-2. A minimal serverless backend
(leaning Firebase) is introduced in Phase 3 solely to persist the scan
counter across reinstalls.
**Why:** Avoids building/maintaining a backend before the core product is
validated. The only thing that *needs* to survive a reinstall is the free-
scan counter (to prevent trivial cap-reset abuse) — everything else is fine
staying on-device for v1.
**Reversible?** Yes — cloud sync can be added later as an opt-in without
changing the local-first data model, just adding a sync layer on top.
