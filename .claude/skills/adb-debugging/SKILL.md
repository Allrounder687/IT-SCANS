---
name: adb-debugging
description: Use whenever running the app on a physical Android device, debugging via USB or wireless ADB, or troubleshooting "device not found" / "unauthorized" issues. Covers first-time wireless pairing and daily reconnects.
---

# ADB Debugging (USB + Wireless)

## USB (first time, or when in doubt)

```bash
adb devices
```

- Device listed as `unauthorized` → check the phone screen for an "Allow USB
  debugging?" prompt, tap Allow (and "always allow from this computer").
- Device not listed at all → check: USB debugging enabled in Developer
  Options, cable is data-capable (not charge-only), `adb kill-server && adb
  start-server` to reset the daemon.

## Wireless ADB — first-time pairing (Android 11+)

1. On the phone: Settings → Developer options → Wireless debugging → ON.
2. Tap "Pair device with pairing code" — note the IP:port and 6-digit code shown.
3. On the computer:

```bash
adb pair <ip>:<pairing-port>
# enter the 6-digit code when prompted
```

4. Back on the phone's Wireless debugging screen, note the main IP:port
   (different from the pairing port).

```bash
adb connect <ip>:<connect-port>
adb devices     # should now show the device over wifi
```

5. From here on, `flutter run` targets it like any other device.

## Wireless ADB — daily reconnect

Phone and computer must be on the same network. If the phone's IP changed
(common after router restarts):

```bash
adb connect <new-ip>:<connect-port>
```

The pairing step (step 3 above) is **one-time** — you don't re-pair unless
you toggle Wireless debugging off/on or change networks in a way that
invalidates it.

## Use the helper script instead of typing this every time

`scripts/adb-wireless.sh` wraps the connect step and prompts for IP/port if
not cached. Prefer it over manual `adb connect` once pairing is done.

## Common failure modes

| Symptom | Cause | Fix |
|---|---|---|
| `device unauthorized` | USB debugging prompt not accepted on phone | Check phone screen, tap Allow |
| `no devices/emulators found` | Wireless debugging toggled off, or IP changed | Re-check phone's Wireless debugging screen for current IP:port |
| Connect works, `flutter run` hangs | Multiple devices connected, ambiguous target | `flutter devices` then `flutter run -d <device-id>` |
| Works then silently drops mid-session | Phone screen locked/network sleep killed wifi radio | Disable Wi-Fi power saving for debugging sessions |
