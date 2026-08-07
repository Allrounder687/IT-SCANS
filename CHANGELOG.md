# Changelog

All notable changes to this project are documented here. Format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Every change that
alters app behavior gets an entry under `[Unreleased]` at the time it's
made — not batched later.

## [Unreleased]

### Added
- **Zero Cognitive Load - Auto-Download Magic:** App silently listens for incoming documents via Firestore, downloads them from Google Drive, and instantly adds them to the library without manual intervention.
- **Zero Cognitive Load - Unread Badges:** Inbox icon displays a red notification badge for unread documents.
- **Zero Cognitive Load - Recent Contacts:** Direct sending now displays a sliding bottom sheet with recent contacts to avoid re-typing email addresses.
- **Zero Cognitive Load - Social Media Sharing:** One-tap export to native OS share sheet for social media platforms (WhatsApp, Telegram, etc).
- **Delightful UX - Instant AI Naming:** ML Kit OCR now runs instantly in the background after scanning to automatically rename documents without needing to press an "Auto-Name" button.
- **Delightful UX - Long-Press Quick Actions:** Removed 3-dot menus in favor of intuitive, Apple-style long-press quick action menus for Open/Share, Rename, and Delete.
- **Delightful UX - Instant Deletion & Undo:** Removed deletion confirmation dialogs. Deletions are now instant with a satisfying haptic thud, followed by a non-intrusive Snackbar allowing a quick "Undo".
- **Unsigned iOS Build Pipeline**: Implemented a fully automated GitHub Actions workflow (`build_ios.yml`) that bypasses Xcode codesigning requirements. This allows building and packaging an unsigned `.ipa` for jailbroken devices directly from the repository without a paid Apple Developer account.
- **3-Tier Monetization Model**: Pivoted from a single premium unlock to a flexible Freemium model featuring 100 free scans, followed by a choice of Ad-Supported access, a 400 Scan Pack, or a 1-Year VIP Subscription.
- **AdMob Integration**: Added Google Mobile Ads SDK. Ad-supported users now see a banner on the home screen and an interstitial ad every 2 scans.
- **Custom Promo Codes**: Added an internal coupon system to the Paywall, allowing the redemption of secret codes (e.g., `FREE`, `SYEDS`) for instant Premium unlocks or discounts.
- **ML Kit OCR Auto-Naming**: Scans are now automatically named based on the most prominent text found on the first page using offline machine learning.
- **Swipe Actions**: Added Apple-style swipe-to-delete with red backgrounds and heavy haptics.
- **Dynamic Greetings**: The Home Screen header now greets the user based on their local time and connected Google account.
- **Kebab Menus**: Added explicit 3-dot menus to all document cards to improve discoverability for renaming and deleting.
- **Immersive Scrolling**: The top header and bottom scan button now smoothly animate away when scrolling down to maximize screen real estate.
- **Google Drive Sync**: Complete backup and restore functionality using the private `appDataFolder` in Google Drive.
- **Smart Deduplication**: Upgraded SQLite database to v3 to store Drive IDs, allowing the app to perfectly anchor and rename conflicting files upon restoration without duplicating them.
- **Haptic Grouping**: Deployed granular tactile feedback across the entire app interface.
- **Fanned Stack Layout**: A visually striking, overlapping stack layout for recent documents.

### Changed
- Moved the main "Scan Document" button to the `bottomNavigationBar` for easier one-handed reachability.
- Upgraded `compileSdk` to 36 and `minSdk` to 24 to support modern ML Kit libraries.
- Removed the Settings View Mode popup in favor of a zero-cognitive-load instant toggle button.
- Removed manual Auto-Name buttons from Document Cards as naming is now handled automatically.
- Completely removed Kebab (3-dot) menus from Document Cards to reduce UI clutter, replaced by Long-Press.

### Fixed
- Fixed build failures caused by outdated Kotlin Gradle Plugins in external dependencies by injecting a global SDK override script.

---

<!--
Template for a release entry, when the time comes:

## [0.1.0] - YYYY-MM-DD
### Added
- ...
### Changed
- ...
### Fixed
- ...
-->
