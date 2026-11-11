---
name: device-testing
description: Use when testing on the owner's real phone or TV - connecting over ADB Wi-Fi, installing a build, reading the screen with uiautomator, tapping safely, checking what the TV shows, or recording a device-matrix (DM-xxx) result.
---

# Device testing (the owner's phone and TV)

## Overview
The owner lets agents use their phone and TV for testing (granted 2026-11-11). They are the owner's own devices, in use at home. **Every tap reaches a real TV in a real room**, so check before acting, and leave things as you found them.

| Device | Notes |
|---|---|
| Phone | Samsung Note10+ (SM-N975F), Android 12, ADB over Wi-Fi |
| TV | "Living Room TV 3", a KTC 4K Smart TV with Google TV. Its IP changes now and then; the app finds it again by itself |
| Apps on the phone | the dev build `my.newy.remotely.dev` ("Remotely Dev"), paired with the TV. The prod id is `my.newy.remotely` (decision #61) |

## Safety rules (non-negotiable)
- **Never press Power** on the TV, and never send Wake-on-LAN, without asking the owner first.
- **Look before every tap:** `uiautomator dump` (or a screenshot) first, and tap only when exactly one control matches what you mean. A blind tap once opened Prime Video on the TV and clicked an ad.
- **Restore what you change:** volume, input, the app on the TV, phone settings. Note the starting state first.
- **Don't keep screenshots** that show the phone's home screen, notifications, contacts or the share sheet. Delete them after use, and never commit them.
- **Pairing the TV needs the owner:** the TV shows a code only they can read. A reinstall under a new application id loses the pairing.
- **Never commit** a temporary diagnostic build or patch.

## Connecting
1. `adb` is not on the PATH: use `"$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"`.
2. **In Git Bash, set `MSYS_NO_PATHCONV=1`**, or `/sdcard/...` arguments become `C:/Program Files/Git/sdcard/...`.
3. The phone's mDNS name (`adb-<serial>-…._adb-tls-connect._tcp`) often isn't found after it sleeps. Ask the owner for the **IP address & port** on Settings → Developer options → Wireless debugging, then `adb connect <ip>:<port>`. If the PC isn't paired anymore, they also send the code and the port from **Pair device with pairing code** (a different port): `adb pair <ip>:<pairport> <code>`.
4. Always pin the device: `adb -s <serial>`. The phone can show up twice (mDNS and IP).
5. Check the screen is on before UI work: `adb shell dumpsys power | grep mWakefulness` (`Awake`, not `Dozing`).

## Install and check a build
```bash
flutter build apk --release --flavor dev -t lib/main_dev.dart   # from app/; the first build after a namespace change takes ~15 min
adb -s $S install -r build/app/outputs/flutter-apk/app-dev-release.apk
adb -s $S shell pm list packages | grep remotely
adb -s $S shell monkey -p my.newy.remotely.dev -c android.intent.category.LAUNCHER 1
adb -s $S shell uiautomator dump /sdcard/u.xml && adb -s $S shell cat /sdcard/u.xml   # Flutter semantics labels appear as content-desc
adb -s $S logcat -d -t 500 | grep -i "FATAL\|AndroidRuntime"
```
Report the build's SHA-1 (`app-dev-release.apk.sha1`) with what you installed.

## Seeing what the TV does
- **The app reports the TV's foreground app.** A quick tile's label becomes "<app>, now on TV", which `uiautomator dump` reads. No TV code is needed.
- **A screensaver** (`com.google.android.apps.tv.dreamx`) hides what a tap opened: press Back first.
- **For raw protocol messages**, use the debug-build recipe in `docs/knowledge/learnings.md` ("Real TV, app links"): a temporary build that logs every message and takes links over `adb forward tcp:8765`, installed over the dev build (same key, so pairing survives), then the real build put back.
- **A refused app link drops the connection** (decision #60). Never send a link form the TV hasn't been seen to accept.

## Recording results
Write each result into `docs/knowledge/device-matrix.md` (Result, Device, Date, Notes), only for what you observed. A claim you didn't see is labelled "(unverified)". Then add an activity-log entry (project-knowledge skill).
