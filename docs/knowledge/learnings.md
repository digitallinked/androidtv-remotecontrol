# Learnings

Facts we discovered the hard way: protocol quirks, device bugs, tooling gotchas. Newest first. Format: **title**, then what happened, the fix or rule, and the source (test, device, link).

---

### Competitor connection silently drops; "Connected" badge lies
- Remote ATV lost the TV connection after a few minutes with no indicator, and its picker kept showing "Connected". Users had to tap the TV again to reconnect.
- **Rule for us:** answer every `RemotePingRequest`, show real-time connection state, and auto-reconnect with backoff. The UI badge must reflect socket state, not "paired" state.
- Source: live test, 2026-10-25 (teardown §4.1).

### TV-reported "current app" packages are raw and noisy
- The TV reports packages like `android` and `com.mediatek.wwtv.tvcenter`. Remote ATV showed them unfiltered as "recommendations".
- **Rule:** filter system packages, and map known packages to names and icons from our catalogue.
- Source: live test, 2026-10-25.

### Ads next to close buttons cause accidental clicks
- In Remote ATV the banner sits under the ✕ of Settings and the paywall; one double-tap produced an ad click.
- **Rule:** no ad within 48 dp of any navigation control; never place an ad on the remote screen's top bar.
- Source: live test, 2026-10-25.

### ADB screenshots from PowerShell
- `adb exec-out screencap -p > file.png` corrupts the PNG in PowerShell (text encoding). Use `adb shell screencap -p /sdcard/x.png` + `adb pull`, or REA `capture_adb_screen`.
