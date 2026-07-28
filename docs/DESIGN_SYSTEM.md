# Design System

Source of truth for the visual design approved in the wireframe prototype.
Any screen implementation should match these tokens exactly rather than
improvising new ones — if a new token is genuinely needed, add it here first,
then use it, so this file stays authoritative.

## Design principle

**Zero cognitive load.** One primary action per screen. One decision at a
time (e.g. filter choice is separate from the save action). The accent color
appears *only* on the primary action and the scan animation, so the user's
eye always knows where to tap next. No tab bar, no competing CTAs.

## Colors

| Token | Value | Usage |
|---|---|---|
| `background` | `#121214` | app background (graphite) |
| `surface` | `#1B1C1F` | cards, sheets, segmented controls |
| `line` | `#2A2B2F` | borders, dividers |
| `accent` | `#FFB020` | primary action only — "scanner beam" amber |
| `paper` | `#F5F4F0` | document preview surfaces only, never app chrome |
| `textMuted` | `#8B8D93` | secondary text, metadata |

## Typography

- **Display / headers:** Space Grotesk — screen titles, primary buttons, the
  "scanner beam" numeric/label moments.
- **Body:** Inter (system default is fine as fallback) — descriptions, empty
  states.
- **Data / metadata:** monospace — page counts, dates, file sizes, price
  strings. This is a deliberate signature detail (evokes a receipt/scanner
  readout) — don't replace with body font.

## Signature interaction

The beam sweep (amber line + glow) **cannot overlay the native ML Kit/
VisionKit scanner UI** — that activity is closed and unstyleable (see
`docs/DECISIONS.md`). So the motif lives entirely in screens we control,
always tied to a genuine "just captured/saved" moment — never decorative:

- **Hand-off transition**, in and out of the native scanner: a brief beam
  sweep on our own screen masks the load and signals "processing."
- **Review:** one sweep across a page's thumbnail the moment it's added.
- **Home:** one sweep across a document's card the first time it renders
  after save.
- **App launch (see "Instant eye-catcher" below):** the one place the beam
  gets to be the whole show, since there's no competing content yet.

## Instant eye-catcher

The thing a screenshot or a 3-second first-open needs to sell is the launch
moment and the home screen's *depth*, not more chrome. Two additions:

**1. Native splash → beam wipe → home.**
Use `flutter_native_splash` for the OS-level splash (background color +
static icon, since native splash can't run custom animation), then
immediately transition into an in-Flutter beam-wipe: the amber line sweeps
once, full-width, top to bottom, revealing the home screen underneath as it
passes — like the app itself is being "scanned into existence." ~500-600ms,
never longer; this runs once per cold start, not on every screen.

**2. Home screen: stacked depth, not a flat grid.**
Documents render as a loosely fanned stack (slight rotation ±2-4°,
increasing shadow/offset for more recent items) rather than a uniform grid —
evokes a physical stack of papers, and is the single detail most likely to
make a screenshot look distinctive instead of templated. Tapping a card
un-fans it into a straight list (a light spring animation) for actual
browsing/selection; multi-select mode also flattens the stack, since fanned
cards read poorly once checkboxes are involved.

**3. Shared-element transition into the PDF viewer.**
Tapping a document's thumbnail should morph (Hero animation) directly into
the full PDF viewer — the thumbnail grows into the first page rather than a
generic screen push. This is cheap in Flutter (`Hero` widget) and reads as
noticeably more polished than a slide transition.

**4. Haptic tied to the beam, not just visual.**
A light haptic tick (`HapticFeedback.lightImpact()`) timed to the beam
passing over a thumbnail/card — small, but it's the kind of tactile detail
that makes an app feel considered rather than templated. Don't add haptics
anywhere else (buttons, taps) — reserve it for this one motif so it stays a
signature, not a tic.

## Screen-specific rules

- **Home:** single fixed-position "Scan document" button, amber, always
  visible above the fold. Fanned stack of past scans below it (see
  "Instant eye-catcher" above), muted, secondary until tapped.
- **Review:** segmented filter control (color/gray/B&W) is the only decision
  before save — no other options surfaced here.
- **Export:** exactly two actions (Share, Save PDF). Do not add more without
  updating this doc and getting explicit sign-off — this screen's minimalism
  is load-bearing for the "zero cognitive load" goal.
- **Paywall:** one price, one CTA, one dismiss ("Not now"). No tier
  comparison tables.
- **PDF viewer:** entered via shared-element transition from the thumbnail
  (see above). Keep its own chrome minimal — page indicator + the same two
  actions as Export (Share, Save), nothing else competing for attention.
- **Rename / delete / multi-select (QoL additions):** these are *utility*
  moments, not brand moments — no beam, no fanned cards. Use `surface`/
  `line` tokens for sheets and dialogs (never default `AlertDialog` white),
  and the same "one decision, one primary button" rule as everywhere else.
  Multi-select: entering it flattens the fanned stack into a plain grid with
  checkboxes — don't try to keep the fan effect once selection state exists.

Reference implementation: see the interactive prototype delivered in chat
(scanner-wireframe.jsx) for exact spacing/sizing if ambiguous.
