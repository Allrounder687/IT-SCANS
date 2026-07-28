#!/usr/bin/env bash
# Regenerates all Android launcher icon densities/variants (adaptive icon
# foreground/background, legacy flat icon, Android 13+ monochrome) from the
# master files in assets/icon/. Re-run this any time those source files
# change — never hand-edit the generated android/app/src/.../mipmap-* files.
set -euo pipefail

flutter pub get
dart run flutter_launcher_icons

echo "Icons regenerated under android/app/src/main/res/"
