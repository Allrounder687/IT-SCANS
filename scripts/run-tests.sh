#!/usr/bin/env bash
set -euo pipefail

echo "==> flutter analyze"
flutter analyze --fatal-infos

echo "==> dart format check"
dart format --output=none --set-exit-if-changed .

echo "==> flutter test"
flutter test --coverage

echo "All checks passed."
