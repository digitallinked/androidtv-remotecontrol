# Protocol reference

Source of truth: androidtvremote2 (`src/androidtvremote2/polo.proto`, `remotemessage.proto`, `pairing.py`, `remote.py`). Field numbers below follow that repo; **re-verify against it** when generating Dart protobufs, and copy the `.proto` files (Apache-2.0, keep the licence header) into `packages/atv_remote/proto/`.

## Pairing (port 6467) — `polo.proto`

`OuterMessage { protocol_version = 2; status (200 = OK); oneof payload }`

| Step | Client sends | TV replies |
|---|---|---|
| 1 | `PairingRequest { service_name: "atvremote", client_name: <device name> }` | `PairingRequestAck` |
| 2 | `Options { input_encodings: [{ type: ENCODING_TYPE_HEXADECIMAL, symbol_length: 6 }], preferred_role: ROLE_TYPE_INPUT }` | `Options` |
| 3 | `Configuration { encoding: { HEXADECIMAL, 6 }, client_role: ROLE_TYPE_INPUT }` | `ConfigurationAck` → **TV shows the code** |
| 4 | `Secret { secret: <32-byte hash> }` | `SecretAck` → paired; close the socket |

Status ≠ 200 → abort and surface an error (`BAD_SECRET`, `ERROR`). The TV times out the code after ~60 s.

## Control (port 6466) — `remotemessage.proto`

`RemoteMessage` is a oneof; the main members:

| Field | Direction | Purpose |
|---|---|---|
| `remote_configure` | both | TV sends first; client replies with `code1` (feature bitmask; androidtvremote2 uses **622**) and `device_info { model, vendor, unknown1: 1, unknown2: "1", package_name, app_version }` |
| `remote_set_active` | both | TV sends; client replies `active: 622` |
| `remote_error` | TV→client | log + surface |
| `remote_ping_request` / `remote_ping_response` | TV→client / client→TV | keep-alive: echo `val1` |
| `remote_key_inject` | client→TV | `key_code` (Android `KeyEvent` code), `direction` SHORT / START_LONG / END_LONG |
| `remote_ime_key_inject` | TV→client | `app_info.app_package` = foreground app; text field state |
| `remote_ime_batch_edit` | client→TV | type text into the focused field (`ime_counter`, `field_counter`, edit info) |
| `remote_ime_show_request` | TV→client | the TV keyboard opened → auto-open our keyboard sheet |
| `remote_voice_begin` / `_payload` / `_end` | client→TV | voice search audio (post-v1; unverified) |
| `remote_start` | TV→client | `started` = screen on/off |
| `remote_set_volume_level` | TV→client | `volume_max`, `volume_level`, `volume_muted`, `player_model` |
| `remote_adjust_volume_level` | client→TV | relative volume (optional) |
| `remote_app_link_launch_request` | client→TV | `app_link` string |

## Key codes used by the UI (Android `KeyEvent`)

| Button | Code |
|---|---|
| DPAD_UP / DOWN / LEFT / RIGHT / CENTER | 19 / 20 / 21 / 22 / 23 |
| BACK / HOME / MENU | 4 / 3 / 82 |
| POWER | 26 |
| VOLUME_UP / DOWN / MUTE | 24 / 25 / 164 |
| CHANNEL_UP / DOWN | 166 / 167 |
| MEDIA_PLAY_PAUSE / NEXT / PREVIOUS / REWIND / FAST_FORWARD / STOP | 85 / 87 / 88 / 89 / 90 / 86 |
| 0–9 | 7–16 |
| PROG_RED / GREEN / YELLOW / BLUE | 183 / 184 / 185 / 186 |
| TV_INPUT / SETTINGS / GUIDE / INFO / CAPTIONS | 178 / 176 / 172 / 165 / 175 |
| SEARCH / ASSIST | 84 / 219 |

## Wake-on-LAN
Magic packet = 6×`0xFF` + 16× the 6-byte MAC, UDP broadcast to `255.255.255.255:9` (also try the subnet broadcast). The Bluetooth MAC from the TXT record is **not** the network MAC. Apps cannot read the ARP cache on Android 10+ or iOS. Ask the user to enter the TV's Wi-Fi/Ethernet MAC (TV Settings → About → Status), with a "where to find it" helper, and store it per device. Mark WoL as "may not work" when the TV is on Wi-Fi in deep standby.
