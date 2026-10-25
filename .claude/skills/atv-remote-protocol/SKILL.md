---
name: atv-remote-protocol
description: Use when working on TV discovery (mDNS/NSD/Bonjour), pairing, TLS client certificates, the remote control channel, key codes, volume, app launching, power state, voice, Wake-on-LAN, connection drops or reconnect logic in packages/atv_remote.
---

# Android TV Remote protocol v2

## Overview
Google TV / Android TV devices running **Android TV Remote Service** accept remote control over the LAN: mDNS discovery → one-time pairing over TLS (port 6467) → a persistent TLS control channel (port 6466) carrying length-prefixed protobuf messages. The open-source Python implementation **androidtvremote2** (tronikos, Apache-2.0) is the reference. Read its `pairing.py`, `remote.py` and `.proto` files before changing wire behaviour, and cite it in code comments.

Full message reference: `protocol-reference.md` in this directory.

## Quick reference

| Concern | Fact |
|---|---|
| Discovery | mDNS `_androidtvremote2._tcp` (TXT has `bt` = Bluetooth MAC). Legacy `_androidtvremote._tcp` = old service, tell the user to update "Android TV Remote Service" on the TV |
| Pairing port | 6467 (TLS, client cert required) |
| Control port | 6466 (TLS, same client cert) |
| Client identity | self-signed RSA-2048 X.509 cert + key, generated once per install, stored in secure storage; the TV remembers it |
| Server cert | self-signed; accept it, but pin its public key per TV after pairing (TOFU) |
| Framing | each protobuf message is prefixed by its length as a **varint** |
| Pairing code | 6 hex chars on the TV. Byte 0 is a checksum, bytes 1–2 are entered into the secret hash |
| Keep-alive | the TV sends `RemotePingRequest`; you **must** reply `RemotePingResponse` with the same value, or the TV drops you |
| Power state | `RemoteStart.started` (true = screen on) |
| Volume | `RemoteSetVolumeLevel` from the TV (max, level, muted); send `KEYCODE_VOLUME_UP/DOWN/MUTE` to change it |
| Current app | `RemoteImeKeyInject.app_info.app_package` from the TV |
| Launch app | `RemoteAppLinkLaunchRequest.app_link` = deep link (`https://www.netflix.com/title`) or `market://launch?id=<package>` |
| Press-and-hold | `RemoteKeyInject` direction `START_LONG` … `END_LONG`; normal tap = `SHORT` |
| Power on from off | not possible over 6466 when the TV is fully off; send Wake-on-LAN magic packet (UDP 9) to the TV's Ethernet/Wi-Fi MAC. Works only if the TV has WoL enabled |

## Pairing secret (the part people get wrong)
```
secret = SHA256( client_modulus || client_exponent || server_modulus || server_exponent || hexToBytes(code[2..6]) )
valid  = secret[0] == int(code[0..2], 16)   // check before sending; wrong code → ask again
```
Moduli and exponents are unsigned big-endian bytes with no leading zero byte. Take the server key from the TLS peer certificate of the pairing socket.

## Connection state machine (UI depends on this)
`disconnected → connecting → (needsPairing → pairing) → connected → (lost → reconnecting with backoff 1s,2s,4s… max 30s) → connected`. Expose it as a `Stream<ConnectionState>`. **"Connected"** means: on 6466 the TV sent `RemoteConfigure` and we replied, then the TV sent `RemoteSetActive` and we replied. Before that, controls stay disabled.

- **App lifecycle:** when the app goes to the background, keep the socket for up to 60 s (quick app switches stay instant), then close it. On resume, reconnect immediately. Don't try to keep a background connection in v1.
- **Server key changed (TOFU mismatch):** the TV was reset or replaced. Never silently accept. Show "This TV's identity changed — pair again", delete the stored pin and pairing flag for that device, and route to pairing.
- **Client cert lost** (app data cleared or reinstalled; Android restores of secure storage aren't guaranteed): treat it as a new install, and the TV will ask to pair again. Explain this in the FAQ; there's nothing to warn about at runtime.

## Platform notes
- **iOS:** `Info.plist` needs `NSLocalNetworkUsageDescription` and `NSBonjourServices = [_androidtvremote2._tcp, _androidtvremote._tcp]`. Wake-on-LAN broadcast needs Apple's multicast entitlement (`com.apple.developer.networking.multicast`, request it from Apple), otherwise ship WoL as Android-only.
- **Android:** `CHANGE_WIFI_MULTICAST_STATE` + acquire a `MulticastLock` while discovering.

## Common mistakes
- Not answering pings → disconnects after ~a few minutes (the competitor's bug).
- Treating "paired" as "connected".
- Regenerating the client cert on reinstall without warning → the TV asks to pair again.
- Opening sockets from UI code. All I/O stays in `packages/atv_remote`.
- Trusting any constant here without checking androidtvremote2. Mark anything you couldn't verify as "(unverified)" in `docs/knowledge/learnings.md`.
