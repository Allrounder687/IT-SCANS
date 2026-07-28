---
name: flutter-release-build
description: Use when building a release/production APK or App Bundle, setting up signing, or preparing a Play Store submission. Covers keystore setup, build commands, and the pre-submission checklist.
---

# Flutter Release Build (Android)

## One-time signing setup

1. Generate a keystore (do this once, back it up somewhere durable — losing
   it means you can never update the app under the same listing again):

```bash
keytool -genkey -v -keystore ~/itscans-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias itscans
```

2. Create `android/key.properties` (this file is gitignored — never commit it):

```
storePassword=<password>
keyPassword=<password>
keyAlias=itscans
storeFile=/absolute/path/to/itscans-release.jks
```

3. Confirm `android/app/build.gradle` reads `key.properties` for the release
   signing config (standard Flutter template does this — verify it's wired,
   don't assume).

## Build commands

```bash
flutter build appbundle --release   # what you upload to Play Console
flutter build apk --release         # for sideloading/manual testing only
./scripts/build-release.sh          # wraps the above with a clean + version bump prompt
```

Play Store requires an **App Bundle (.aab)**, not a raw APK, for new
submissions — use `appbundle`, not `apk`, as your actual release artifact.

## Version bumping

Bump `version:` in `pubspec.yaml` (format `X.Y.Z+buildNumber`) before every
release build — the build number must strictly increase for every Play
Console upload, even for the same version string.

## Pre-submission checklist

- [ ] `flutter analyze` clean, `flutter test` green
- [ ] Version bumped in `pubspec.yaml`
- [ ] `CHANGELOG.md` — move `[Unreleased]` entries under a new dated version
      heading
- [ ] Privacy policy URL ready (required even for a simple app — Play
      Console will reject submission without one)
- [ ] Data safety form filled out in Play Console (what data the app
      collects — for this app: none beyond the scan counter, if using
      Firebase, disclose that)
- [ ] Screenshots + store listing text ready
- [ ] Tested the actual signed release build on a real device, not just
      debug build — release mode can behave differently (obfuscation,
      performance)

## Common failure modes

| Symptom | Cause |
|---|---|
| "keystore was tampered with" | Wrong password in `key.properties` |
| Play Console rejects: "You need to use a different version code" | Forgot to bump build number |
| App crashes in release but not debug | Usually a missing ProGuard/R8 keep rule for a plugin — check plugin's docs for required `proguard-rules.pro` entries |
