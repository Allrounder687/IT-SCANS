#!/usr/bin/env bash
# Builds a signed release App Bundle. Requires android/key.properties to
# already exist — see .claude/skills/flutter-release-build/SKILL.md for
# one-time signing setup.
set -euo pipefail

if [[ ! -f "android/key.properties" ]]; then
  echo "ERROR: android/key.properties not found."
  echo "See .claude/skills/flutter-release-build/SKILL.md for setup."
  exit 1
fi

echo "Current version in pubspec.yaml:"
grep "^version:" pubspec.yaml
read -rp "Continue with this version? (y/n) " CONFIRM
if [[ "$CONFIRM" != "y" ]]; then
  echo "Bump the version in pubspec.yaml first, then re-run."
  exit 1
fi

flutter clean
flutter pub get
flutter build appbundle --release

echo "Build complete: build/app/outputs/bundle/release/app-release.aab"
