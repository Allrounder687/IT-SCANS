#!/usr/bin/env bash
# Connects to a device over wireless ADB. Assumes you've already paired once
# (see .claude/skills/adb-debugging/SKILL.md for first-time pairing steps).
set -euo pipefail

CACHE_FILE=".adb-wireless-target"

if [[ -f "$CACHE_FILE" ]]; then
  TARGET=$(cat "$CACHE_FILE")
  echo "Trying cached target: $TARGET"
  if adb connect "$TARGET" | grep -q "connected"; then
    echo "Connected."
    adb devices
    exit 0
  fi
  echo "Cached target didn't respond — it may have changed IP."
fi

read -rp "Enter device IP:PORT (from phone's Wireless debugging screen): " TARGET
adb connect "$TARGET"
echo "$TARGET" > "$CACHE_FILE"
adb devices
