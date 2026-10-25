# TV Remote App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and ship a production Flutter remote for Android TV / Google TV on Google Play and the App Store, beating Remote ATV on reliability and UX.

**Architecture:** A pure-Dart package `packages/atv_remote` implements discovery interfaces, pairing (TLS 6467), the control channel (TLS 6466, varint-framed protobuf), connection management and Wake-on-LAN, verified against an in-process fake TV. The Flutter app in `app/` is feature-first with Riverpod + go_router; vendor services (Firebase, AdMob, UMP, RevenueCat) sit behind interfaces in `app/lib/core/`.

**Tech Stack:** Flutter stable + Dart 3 (pub workspaces), Riverpod 3 (codegen), go_router, freezed, drift, flutter_secure_storage, nsd, protobuf/protoc_plugin, pointycastle, basic_utils, google_mobile_ads, purchases_flutter, Firebase (core, analytics, crashlytics, remote_config), very_good_analysis, mocktail.

**Spec:** `docs/superpowers/specs/2026-10-25-tv-remote-app-design.md`. Read the project skills before each phase: `atv-remote-protocol`, `flutter-app-architecture`, `remote-design-system`, `app-services`, `store-release`, `project-knowledge`.

## How this plan is structured
Phase 1 is fully detailed (TDD steps). Phases 0 and 2–9 list every task with files, interfaces and named tests. **Before starting Phases 2–9, run `superpowers:writing-plans` on that phase** to expand it into step-level detail in `docs/superpowers/plans/2026-10-25-phase-N-<name>.md`, keeping these interfaces. After each task, apply the `project-knowledge` skill (update `docs/knowledge/status.md`).

## Global Constraints
- Android minSdk 24; targetSdk ≥ 35 (Play's current requirement). iOS deployment target 13.0.
- Bundle/application id placeholder `com.digitallinked.atvremote`; display name placeholder `Remotely for Android TV`. Never "Google" in the name or icon.
- Protocol ports 6467 (pairing) and 6466 (control); mDNS `_androidtvremote2._tcp` and legacy `_androidtvremote._tcp`.
- No socket or protobuf code outside `packages/atv_remote`.
- No analytics parameter may contain a TV name, IP address or MAC address.
- No ad on the remote screen; nothing within 48 dp of navigation controls; banner only on the Apps and Settings screens.
- The remote works with Firebase, ads and RevenueCat all failing or offline.
- Secrets (`*.jks`, `key.properties`, `google-services.json`, `GoogleService-Info.plist`, `.env`) are git-ignored.
- `flutter analyze` / `dart analyze` clean and all tests green before every commit.
- English strings in ARB files only; Malay translation added in Phase 8.

## Review Focus
1. **App backgrounded and resumed after minutes** → the socket is dead; on resume the app must show "Reconnecting…" and recover without user action (test in Task 1.7 `reconnects_after_resume`).
2. **TV goes to standby or loses power mid-session** → the status becomes Offline within 10 s with a Reconnect/Wake action, and no key press is silently dropped while the UI claims to be connected (Task 1.7 `marks_lost_when_socket_closes`).
3. **User enters a wrong or expired pairing code** → a clear error and a re-entry field. The checksum is validated locally before sending, and the TV's 60 s timeout returns to "Request new code" (Task 1.3 `rejects_code_with_bad_checksum`, Task 1.5 `surfaces_bad_secret_status`).
4. **TV was reset or forgot our certificate** → the TLS handshake on 6466 fails with an unknown-cert alert; the app must route to pairing instead of looping on reconnect (Task 1.7 `routes_to_pairing_on_cert_rejection`).
5. **Phone switches Wi-Fi network or the TV's IP changes (DHCP)** → reconnect re-resolves the host via mDNS by stored service name before giving up (Task 3.3 `re_resolves_host_on_reconnect`).

---

## Phase 0 — Foundations

### Task 0.1: Monorepo scaffold, lints, CI
**Files:**
- Create: `pubspec.yaml` (workspace root: `workspace: [app, packages/atv_remote]`), `.gitignore` (Flutter + secrets list from Global Constraints), `analysis_options.yaml` (`include: package:very_good_analysis/analysis_options.yaml`)
- Create: `app/` via `flutter create --org com.digitallinked --project-name tv_remote --platforms android,ios app`
- Create: `packages/atv_remote/` via `dart create -t package packages/atv_remote`
- Create: `tool/check.ps1` and `tool/check.sh` (format check, analyze, test both packages)
- Create: `.github/workflows/ci.yml` (Flutter stable pinned; runs `tool/check.sh`)
- Test: `app/test/smoke_test.dart`, `packages/atv_remote/test/smoke_test.dart`

- [ ] **Step 1:** Run the scaffolding commands; add `resolution: workspace` to both member pubspecs; set app `minSdk 24`, iOS 13.0.
- [ ] **Step 2:** Replace the generated counter app with a placeholder `MaterialApp` showing "TV Remote". Smoke test: `expect(find.text('TV Remote'), findsOneWidget)`.
- [ ] **Step 3:** Run `pwsh tool/check.ps1`. Expected: format OK, `No issues found!`, all tests pass.
- [ ] **Step 4:** Record the pinned Flutter version in `docs/knowledge/decisions.md` (#8). Commit `chore: scaffold flutter workspace with app and atv_remote package`.

---

## Phase 1 — Protocol library `packages/atv_remote` (detailed)

All commands run from `packages/atv_remote/`. The reference implementation is androidtvremote2; cite the file in a code comment wherever wire behaviour comes from it.

### Task 1.1: Protobuf definitions and generated code
**Files:**
- Create: `proto/polo.proto`, `proto/remotemessage.proto` (copied from androidtvremote2 with the Apache-2.0 header kept), `proto/LICENSE-androidtvremote2`
- Create: `lib/src/proto/` (generated, committed), `tool/gen_proto.sh`
- Test: `test/proto_roundtrip_test.dart`

**Interfaces:**
- Produces: generated classes `OuterMessage`, `PairingRequest`, `Options`, `Configuration`, `Secret` (polo) and `RemoteMessage`, `RemoteConfigure`, `RemoteDeviceInfo`, `RemoteSetActive`, `RemotePingRequest`, `RemotePingResponse`, `RemoteKeyInject`, `RemoteDirection`, `RemoteImeKeyInject`, `RemoteImeBatchEdit`, `RemoteImeShowRequest`, `RemoteStart`, `RemoteSetVolumeLevel`, `RemoteAppLinkLaunchRequest`, `RemoteError`.

- [ ] **Step 1: Write the failing test**
```dart
test('RemoteKeyInject round-trips', () {
  final msg = RemoteMessage(remoteKeyInject: RemoteKeyInject(keyCode: RemoteKeyCode.KEYCODE_DPAD_UP, direction: RemoteDirection.SHORT));
  final decoded = RemoteMessage.fromBuffer(msg.writeToBuffer());
  expect(decoded.remoteKeyInject.keyCode, RemoteKeyCode.KEYCODE_DPAD_UP);
  expect(decoded.remoteKeyInject.direction, RemoteDirection.SHORT);
});
test('OuterMessage defaults protocol_version 2 status OK when set', () {
  final m = OuterMessage(protocolVersion: 2, status: OuterMessage_Status.STATUS_OK, pairingRequest: PairingRequest(serviceName: 'atvremote', clientName: 'Phone'));
  expect(OuterMessage.fromBuffer(m.writeToBuffer()).pairingRequest.clientName, 'Phone');
});
```
- [ ] **Step 2:** Run `dart test test/proto_roundtrip_test.dart`. Expected: FAIL (imports missing).
- [ ] **Step 3:** Install `protoc` + `dart pub global activate protoc_plugin`; `tool/gen_proto.sh` runs `protoc --dart_out=lib/src/proto -Iproto proto/*.proto`. Add the `protobuf` dependency. Adjust the enum/field names in the test to whatever the generated code exposes, keeping the assertions' meaning.
- [ ] **Step 4:** Run the test. Expected: PASS.
- [ ] **Step 5:** Commit `feat(atv_remote): add protocol protobufs`.

### Task 1.2: Varint framing codec
**Files:** Create `lib/src/framing.dart`; Test `test/framing_test.dart`

**Interfaces:**
- Produces: `Uint8List encodeFrame(List<int> payload)`; `class FrameDecoder { List<Uint8List> add(List<int> chunk); }` (buffers partial input and returns zero or more complete payloads).

- [ ] **Step 1: Write the failing tests**
```dart
test('encodes short payload with 1-byte varint', () => expect(encodeFrame([1, 2, 3]), [3, 1, 2, 3]));
test('encodes 300-byte payload with 2-byte varint', () {
  final f = encodeFrame(List.filled(300, 7));
  expect(f.sublist(0, 2), [0xAC, 0x02]); expect(f.length, 302);
});
test('decoder reassembles frames split across chunks', () {
  final d = FrameDecoder();
  expect(d.add([3, 1]), isEmpty);
  expect(d.add([2, 3, 2, 9]), [[1, 2, 3]]);
  expect(d.add([9]), [[9, 9]]);
});
test('decoder returns multiple frames from one chunk', () => expect(FrameDecoder().add([1, 5, 1, 6]), [[5], [6]]));
test('decoder rejects frames larger than 1 MiB', () => expect(() => FrameDecoder().add([0x80, 0x80, 0x80, 0x01]), throwsA(isA<FrameTooLargeException>())));
```
- [ ] **Step 2:** `dart test test/framing_test.dart` → FAIL.
- [ ] **Step 3:** Implement in `lib/src/framing.dart`, with `FrameTooLargeException` and a max frame size of 1 MiB.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5:** Commit `feat(atv_remote): varint framing codec`.

### Task 1.3: Client identity (certificate) and pairing secret
**Files:** Create `lib/src/identity.dart`, `lib/src/pairing_secret.dart`; Test `test/identity_test.dart`, `test/pairing_secret_test.dart`

**Interfaces:**
- Produces:
  - `class ClientIdentity { final String certificatePem; final String privateKeyPem; static ClientIdentity generate({String commonName = 'atvremote'}); factory ClientIdentity.fromPem({required String certificatePem, required String privateKeyPem}); RsaPublicParts get publicParts; }`
  - `class RsaPublicParts { final Uint8List modulus; final Uint8List exponent; }` (unsigned big-endian, no leading zero)
  - `RsaPublicParts rsaPublicPartsFromCertificateDer(Uint8List der)`
  - `Uint8List computePairingSecret({required RsaPublicParts client, required RsaPublicParts server, required String code})`; throws `InvalidPairingCodeException` when the code isn't 6 hex chars or its checksum byte doesn't match.

- [ ] **Step 1: Write the failing tests**
```dart
test('generate produces RSA-2048 self-signed cert usable by SecurityContext', () {
  final id = ClientIdentity.generate();
  expect(id.publicParts.modulus.length, 256);
  expect(id.publicParts.exponent, [0x01, 0x00, 0x01]);
  final ctx = SecurityContext()..useCertificateChainBytes(utf8.encode(id.certificatePem))..usePrivateKeyBytes(utf8.encode(id.privateKeyPem));
  expect(ctx, isNotNull);
});
test('fromPem round-trips', () { final a = ClientIdentity.generate(); final b = ClientIdentity.fromPem(certificatePem: a.certificatePem, privateKeyPem: a.privateKeyPem); expect(b.publicParts.modulus, a.publicParts.modulus); });
test('computes secret matching reference vector', () { /* vector: fixed client/server parts + code; expected bytes produced once by androidtvremote2 and pasted here (document how in a comment) */ });
test('rejects_code_with_bad_checksum', () => expect(() => computePairingSecret(client: c, server: s, code: '00ABCD'), throwsA(isA<InvalidPairingCodeException>())));
test('rejects non-hex or wrong-length codes', () { for (final code in ['12345', 'ZZZZZZ', '1234567']) { expect(() => computePairingSecret(client: c, server: s, code: code), throwsA(isA<InvalidPairingCodeException>())); } });
test('code is case-insensitive', () => expect(computePairingSecret(client: c, server: s, code: good.toLowerCase()), computePairingSecret(client: c, server: s, code: good.toUpperCase())));
```
- [ ] **Step 2:** Run both test files → FAIL.
- [ ] **Step 3:** Implement with `pointycastle` (RSA keygen, SHA-256) and `basic_utils` (X.509 self-signed, PEM, parsing DER). Algorithm: `SHA256(client.modulus ‖ client.exponent ‖ server.modulus ‖ server.exponent ‖ hexToBytes(code.substring(2)))`; valid iff `hash[0] == int.parse(code.substring(0, 2), radix: 16)`. Generate the reference vector by running androidtvremote2's `get_pairing_secret`-equivalent once in Python with fixed keys; store the keys as test fixtures in `test/fixtures/`.
- [ ] **Step 4:** Run → PASS.
- [ ] **Step 5:** Commit `feat(atv_remote): client identity and pairing secret`.

### Task 1.4: Fake TV server (test harness)
**Files:** Create `test/fake_tv/fake_tv_server.dart`, `test/fake_tv/fake_tv_identity.dart`; Test `test/fake_tv/fake_tv_server_test.dart`

**Interfaces:**
- Produces: `class FakeTvServer { static Future<FakeTvServer> start({bool sendPings = true, Duration pingInterval = const Duration(milliseconds: 200), bool rejectUnknownClients = true}); int get pairingPort; int get remotePort; String? get displayedCode; List<int> get receivedKeyCodes; List<String> get receivedAppLinks; String get receivedText; bool get clientAnsweredLastPing; void sendVolume({required int level, required int max, required bool muted}); void sendCurrentApp(String package); void sendImeShow(); void setPowerOn(bool on); Future<void> dropConnections(); void forgetClients(); Future<void> close(); }`
- Behaviour: pairing on `pairingPort` follows the polo flow and generates a random valid code exposed via `displayedCode`; the control port requires a paired client cert (TLS client cert compared by public key), sends `RemoteConfigure` then `RemoteSetActive`, pings every `pingInterval`, and closes the client if a ping isn't answered within 3 intervals.

- [ ] **Step 1:** Test: start the server; connect a raw `SecureSocket` to `pairingPort` with a fresh identity; send a framed `PairingRequest`; expect a framed `OuterMessage` with `pairingRequestAck` and status OK.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement with `SecureServerSocket.bind(..., requestClientCertificate: true)` using a generated server identity. **Step 4:** PASS. **Step 5:** Commit `test(atv_remote): fake TV server`.

### Task 1.5: PairingClient
**Files:** Create `lib/src/pairing_client.dart`, `lib/src/socket_connector.dart`; Test `test/pairing_client_test.dart`

**Interfaces:**
- Consumes: Tasks 1.1–1.4.
- Produces:
  - `typedef SocketConnector = Future<SecureSocket> Function(String host, int port, SecurityContext context);` with a `defaultSocketConnector` that accepts any server certificate and returns the socket (the caller reads `peerCertificate`).
  - `class PairingClient { PairingClient({required String host, int port = 6467, required ClientIdentity identity, SocketConnector connector = defaultSocketConnector, Duration timeout = const Duration(seconds: 10)}); Future<void> start({required String clientName}); Future<void> submitCode(String code); Future<void> close(); }`; `start` completes when the TV displays the code (after `ConfigurationAck`); `submitCode` completes on `SecretAck`.
  - `class PairingException implements Exception { final PairingFailure reason; }` with `enum PairingFailure { connectionFailed, timeout, badSecret, protocolError, invalidCode }`.

- [ ] **Step 1: Write the failing tests** (against `FakeTvServer`): `pairs_successfully` (start → server.displayedCode non-null → submitCode(displayedCode) completes; subsequent control connection accepted); `surfaces_bad_secret_status` (submit a code with a valid checksum but the wrong value → `PairingException(badSecret)`); `invalid_code_never_sent` (bad checksum → `PairingException(invalidCode)` and the server received no `Secret` message); `times_out_when_server_silent` (server that accepts but never replies, timeout 200 ms → `PairingException(timeout)`); `connection_refused` (closed port → `connectionFailed`).
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement the polo flow from the `atv-remote-protocol` skill. **Step 4:** PASS. **Step 5:** Commit `feat(atv_remote): pairing client`.

### Task 1.6: RemoteClient (control channel)
**Files:** Create `lib/src/remote_client.dart`, `lib/src/remote_events.dart`, `lib/src/key_codes.dart`; Test `test/remote_client_test.dart`

**Interfaces:**
- Produces:
  - `abstract final class KeyCodes { static const dpadUp = 19, dpadDown = 20, dpadLeft = 21, dpadRight = 22, dpadCenter = 23, back = 4, home = 3, menu = 82, power = 26, volumeUp = 24, volumeDown = 25, mute = 164, channelUp = 166, channelDown = 167, playPause = 85, next = 87, previous = 88, rewind = 89, fastForward = 90, stop = 86, red = 183, green = 184, yellow = 185, blue = 186, tvInput = 178, settings = 176, guide = 172, info = 165, captions = 175, search = 84; static int digit(int n); }`
  - `enum KeyDirection { short, startLong, endLong }`
  - `sealed class RemoteEvent` with `RemoteReady()`, `PowerStateChanged(bool isOn)`, `VolumeChanged(int level, int max, bool muted)`, `CurrentAppChanged(String package)`, `ImeShowRequested()`, `RemoteErrorReceived(String message)`, `RemoteClosed(RemoteCloseReason reason)`; `enum RemoteCloseReason { remoteClosed, pingTimeout, certificateRejected, networkError, closedByClient }`
  - `class DeviceInfo { final String model; final String vendor; final String packageName; final String appVersion; }`
  - `class RemoteClient { RemoteClient({required String host, int port = 6466, required ClientIdentity identity, required DeviceInfo deviceInfo, SocketConnector connector = defaultSocketConnector}); Future<void> connect(); Stream<RemoteEvent> get events; bool get isReady; Uint8List? get serverPublicKeySha256 /* SHA-256 of the TV cert's public key, set after TLS handshake; used for TOFU pinning */; void sendKey(int keyCode, {KeyDirection direction = KeyDirection.short}); void launchAppLink(String link); void sendText(String text); Future<void> close(); }`. `connect` completes on the first `RemoteSetActive` exchange (then emits `RemoteReady`); it throws `RemoteConnectException(certificateRejected)` when the TLS handshake fails because the TV doesn't know the cert.

- [ ] **Step 1: Write the failing tests** (pair first via `PairingClient` in `setUp`): `becomes_ready_after_configure_and_set_active`; `answers_pings` (after 1 s with 200 ms pings, `server.clientAnsweredLastPing` is true and the connection is still open); `sends_short_key` (`sendKey(KeyCodes.dpadUp)` → `server.receivedKeyCodes` contains 19); `sends_long_press_pair` (startLong then endLong recorded in order); `emits_volume_events` (`server.sendVolume(level: 7, max: 100, muted: false)` → `VolumeChanged(7, 100, false)`); `emits_current_app` and `emits_ime_show`; `launches_app_link` (`launchAppLink('market://launch?id=com.netflix.ninja')` recorded); `sends_text` (`sendText('hello')` → `server.receivedText == 'hello'`); `certificate_rejected_for_unpaired_identity` (fresh identity → `RemoteConnectException` with reason `certificateRejected`); `emits_closed_on_server_drop` (`server.dropConnections()` → `RemoteClosed(remoteClosed)`); `sendKey_before_ready_throws_StateError`.
- [ ] **Step 2:** Run → FAIL. **Step 3:** Implement per `protocol-reference.md` (feature code 622; echo ping `val1`; ignore unknown messages but log them). **Step 4:** PASS. **Step 5:** Commit `feat(atv_remote): remote control client`.

### Task 1.7: TvConnection (state machine, reconnect, backoff)
**Files:** Create `lib/src/tv_connection.dart`, `lib/src/backoff.dart`; Test `test/tv_connection_test.dart`, `test/backoff_test.dart`

**Interfaces:**
- Produces:
  - `enum ConnectionStatus { disconnected, connecting, connected, reconnecting, needsPairing, offline }`
  - `class ConnectionState { final ConnectionStatus status; final int attempt; final RemoteCloseReason? lastError; }`
  - `class Backoff { Backoff({Duration initial = const Duration(seconds: 1), Duration max = const Duration(seconds: 30), int maxAttempts = 6}); Duration? next(); void reset(); }`
  - `class TvConnection { TvConnection({required RemoteClient Function() clientFactory, Backoff? backoff, Future<String?> Function()? reResolveHost}); Stream<ConnectionState> get states; ConnectionState get current; Stream<RemoteEvent> get events; Future<void> connect(); void notifyAppResumed(); void notifyNetworkChanged(); void sendKey(int keyCode, {KeyDirection direction}); void launchAppLink(String link); void sendText(String text); Future<void> dispose(); }`. Commands while not `connected` throw `NotConnectedException` (the UI disables controls instead of dropping presses silently).

- [ ] **Step 1: Write the failing tests:** `backoff_sequence_1_2_4_8_16_30_then_null`; `connects_and_emits_connecting_then_connected`; `marks_lost_when_socket_closes` (server drop → `reconnecting` within 100 ms, then `connected` again); `goes_offline_after_max_attempts` (server closed → `offline` with `attempt == 6`, using a fake fast backoff); `routes_to_pairing_on_cert_rejection` (`server.forgetClients()` + drop → `needsPairing`, no further attempts); `reconnects_after_resume` (drop while "backgrounded", then `notifyAppResumed()` → immediate attempt and `connected`); `commands_throw_when_not_connected`.
- [ ] **Step 2:** FAIL. **Step 3:** Implement. **Step 4:** PASS. **Step 5:** Commit `feat(atv_remote): connection state machine with reconnect`.

### Task 1.8: Wake-on-LAN, discovery model, public API, real-TV CLI
**Files:** Create `lib/src/wake_on_lan.dart`, `lib/src/discovery.dart`, `lib/atv_remote.dart` (exports), `bin/atv_cli.dart`; Test `test/wake_on_lan_test.dart`, `test/discovery_test.dart`

**Interfaces:**
- Produces:
  - `Uint8List buildMagicPacket(String mac)` (accepts `AA:BB:CC:DD:EE:FF` or `-` separators; throws `FormatException`); `Future<void> sendWakeOnLan(String mac, {List<InternetAddress>? broadcastAddresses, int port = 9})`
  - `class DiscoveredTv { final String serviceName; final String displayName; final String host; final int port; final bool isLegacyService; }`; `abstract interface class TvDiscovery { Stream<List<DiscoveredTv>> watch(); Future<void> stop(); }`; `DiscoveredTv parseServiceRecord({required String serviceType, required String name, required String host, required int port})` maps `_androidtvremote._tcp` → `isLegacyService: true`.
  - CLI: `dart run bin/atv_cli.dart pair <host>` (prompts for the code, saves identity to `~/.atv_cli/identity.json`), `dart run bin/atv_cli.dart key <host> <keyName>`, `dart run bin/atv_cli.dart watch <host>` (prints events).

- [ ] **Step 1:** Tests: `magic_packet_is_102_bytes_with_6xFF_prefix_and_16_mac_repeats`; `rejects_malformed_mac`; `parses_legacy_service`; `parses_v2_service`.
- [ ] **Step 2:** FAIL → **Step 3:** implement → **Step 4:** PASS.
- [ ] **Step 5: Real-TV smoke test (owner's TV, same LAN):** run `pair`, enter the TV code, then `key <host> home` and `watch <host>` for 5 minutes. Expected: the TV goes Home; volume/app events print; no disconnect for 5 min (pings answered). Record results and any surprises in `docs/knowledge/learnings.md`.
- [ ] **Step 6:** Commit `feat(atv_remote): wake-on-lan, discovery model, cli`.

---

## Phase 2 — App shell
**Exit criteria:** the app launches into an empty-state Discovery screen with the themed design system, routing, localisation and storage wired; golden tests pass in light and dark.

### Task 2.1: Theme tokens and design-system widgets
- **Files:** `app/lib/app/theme/tokens.dart`, `app_theme.dart` (light, dark, dynamic), `app/lib/app/widgets/{app_key_button.dart, rocker.dart, status_pill.dart, app_dialog.dart, app_sheet.dart}`
- **Interfaces:** `ThemeData buildAppTheme({required Brightness brightness, ColorScheme? dynamicScheme})`; `AppKeyButton({required String semanticLabel, required Widget icon, required VoidCallback onTap, VoidCallback? onLongPressStart, VoidCallback? onLongPressEnd})`; `Rocker({required String label, String? value, required VoidCallback onUp, required VoidCallback onDown, ...})`; `StatusPill({required ConnectionStatus status, VoidCallback? onReconnect})`
- **Tests:** goldens `app_key_button_{light,dark}.png`, `status_pill_all_states.png`; `text_secondary_contrast_at_least_4_5` (compute the contrast ratio of tokens); `key_button_min_size_56dp`.

### Task 2.2: Router, l10n, bootstrap, error handling
- **Files:** `app/lib/main_dev.dart`, `main_prod.dart`, `bootstrap.dart`, `app/lib/app/router.dart`, `app/lib/app/l10n/app_en.arb`, Android flavors (`dev`, `prod`) in `android/app/build.gradle(.kts)`, iOS schemes `dev`/`prod`
- **Interfaces:** routes `/onboarding`, `/discover`, `/pair/:serviceName`, `/remote`, `/apps`, `/devices`, `/settings/*`, `/paywall?source=`; `Future<void> bootstrap(Flavor flavor)` installs `FlutterError.onError` + `PlatformDispatcher.onError` to `CrashReporter` (a no-op until Phase 6)
- **Tests:** `router_starts_at_onboarding_on_first_run`, `router_starts_at_remote_when_device_saved`.

### Task 2.3: Local storage and secure identity
- **Files:** `app/lib/core/storage/app_database.dart` (drift: tables `devices`, `shortcuts`, `app_usage`), `identity_store.dart`, `settings_store.dart`
- **Interfaces:** `class SavedDevice { String serviceName; String displayName; String lastHost; int port; String? nickname; String? wolMac; String serverKeyPin /* hex SHA-256 */; DateTime lastConnectedAt; }`; `DeviceRepository { Stream<List<SavedDevice>> watchAll(); Future<void> upsert(SavedDevice d); Future<void> delete(String serviceName); Future<SavedDevice?> lastUsed(); }`; `IdentityStore { Future<ClientIdentity> loadOrCreate(); }` (flutter_secure_storage); `SettingsStore` with typed getters/setters for every setting in spec goal 7
- **Tests:** `identity_is_created_once_and_reused`, `device_upsert_and_watch`, `settings_defaults_match_spec` (touchpad, apps row, haptics on, smooth press on, keep awake on, theater off, theme system).

---

## Phase 3 — Connect flow
**Exit criteria:** on a real phone and TV, the user discovers, pairs and lands on a remote screen showing a live status; demo mode works without a TV.

### Task 3.1: Discovery (nsd) + manual IP
- **Files:** `app/lib/features/discovery/data/nsd_tv_discovery.dart` (implements `TvDiscovery`), `presentation/discovery_screen.dart`, `manual_ip_sheet.dart`; Android `CHANGE_WIFI_MULTICAST_STATE` + multicast lock; iOS `NSLocalNetworkUsageDescription`, `NSBonjourServices`
- **Tests:** `shows_found_tvs_sorted_by_name`, `legacy_tv_shows_update_service_help`, `manual_ip_validates_ipv4`, `empty_state_after_10s_shows_troubleshooting` (copy explains same Wi-Fi, TV on, Remote Service installed; link to our troubleshooting page).

### Task 3.2: Pairing wizard
- **Files:** `app/lib/features/pairing/presentation/pairing_screen.dart`, `pairing_controller.dart`
- **Interfaces:** `PairingController.start(DiscoveredTv tv)`, `.submit(String code)`; state `idle | waitingForCode | verifying | success | failure(PairingFailure)`; the 60 s countdown shows "Request new code"
- **Tests:** `six_char_field_accepts_hex_only_and_autosubmits`, `paste_code_from_clipboard`, `bad_checksum_shows_inline_error_without_network_call`, `timeout_offers_new_code`, `success_saves_device_and_navigates_to_remote`.

### Task 3.3: Session provider, lifecycle, status UI
- **Files:** `app/lib/core/session/remote_session.dart` (keepAlive provider wrapping `TvConnection`), `lifecycle_observer.dart`, `connectivity_observer.dart`
- **Interfaces:** `remoteSessionProvider`, `connectionStateProvider` (`Stream<ConnectionState>`), `volumeProvider`, `powerStateProvider`, `currentAppProvider`; `reResolveHost` uses discovery to find the stored `serviceName` and returns its current host
- **Rules:** in the background, keep the socket for 60 s, then close it; reconnect on resume. After connecting, compare `serverPublicKeySha256` with `SavedDevice.serverKeyPin` (set at first successful connect); on mismatch → "This TV's identity changed — pair again", clear the pin, route to pairing.
- **Tests:** `re_resolves_host_on_reconnect` (the stored host is unreachable, discovery returns a new IP → connects and updates `lastHost`); `resume_triggers_reconnect`; `closes_socket_after_60s_in_background`; `identity_changed_routes_to_pairing`; `needs_pairing_routes_to_pairing_screen`; `status_pill_reflects_socket_state_not_saved_state`.

### Task 3.4: Demo mode (simulated TV)
- **Files:** `app/lib/features/demo/demo_tv_connection.dart` (implements the same interface as `TvConnection`, logging presses to an on-screen "TV preview" card), entries in onboarding and the empty discovery state ("Try demo")
- **Tests:** `demo_mode_shows_pressed_keys_in_preview`, `demo_badge_visible_everywhere`.

> **Owner action now (Phase 9 lead time):** create the Play Console account and the internal + closed test tracks, and recruit 12 testers so the 14-day clock starts at the end of Phase 4.

---

## Phase 4 — Remote experience
**Exit criteria:** all controls work on the real TV; usability check passes (control without looking, no mis-taps); golden tests for each layout.

### Task 4.1: RemoteActions (haptics, Smooth Press, analytics hook)
- **Files:** `app/lib/features/remote/application/remote_actions.dart`
- **Interfaces:** `RemoteActions { void tap(int keyCode); void holdStart(int keyCode); void holdEnd(int keyCode); void launch(AppEntry app); void typeText(String s); }`. With Smooth Press on, hold sends `startLong`/`endLong` for volume, channel and D-pad keys; with it off, hold repeats `short` every 120 ms. Haptic light on tap, medium on hold start, heavy for power. Disabled (no-op + "Not connected" snackbar) when not connected.
- **Tests:** `smooth_press_sends_start_and_end_long`, `repeat_mode_sends_short_every_120ms` (fake async), `haptics_respect_setting`, `not_connected_shows_snackbar_and_sends_nothing`.

### Task 4.2: Remote screen layout + bottom cluster
- **Files:** `remote_screen.dart`, `widgets/bottom_cluster.dart`, `widgets/top_bar.dart` (device switcher + status pill + power), `widgets/pad_pager.dart`
- **Rules:** the `remote-design-system` screen spec; power = long-press 600 ms (tap shows a hint); when power state is off and the device has `wolMac`, the power button sends WoL then connects.
- **Tests:** goldens `remote_portrait_{light,dark}`, `remote_landscape`, `remote_tablet`; `power_requires_long_press`; `wol_sent_when_tv_off_and_mac_known`; `semantics_labels_present_for_all_controls`.

### Task 4.3: Touchpad
- **Files:** `widgets/touchpad.dart`
- **Rules:** swipe ≥ 24 dp → one D-pad step in that direction; continuous drag repeats steps every 40 dp travelled; tap → center; long-press → hold center; two-finger tap → back. Visual: subtle trail + edge glow in the swipe direction.
- **Tests:** `swipe_right_sends_dpad_right`, `long_drag_sends_multiple_steps`, `tap_sends_center`, `two_finger_tap_sends_back`, `small_jitter_sends_nothing`.

### Task 4.4: D-pad and number pad
- **Files:** `widgets/dpad.dart`, `widgets/number_pad.dart` (digits, TV input, Menu, Info, Guide)
- **Tests:** `dpad_hit_regions_map_to_directions`, `center_button_is_56dp_minimum`, `numpad_digit_sends_keycode_7_plus_n`, goldens.

### Task 4.5: Quick-access row variants
- **Files:** `widgets/quick_access_row.dart` (apps | colour keys | media keys | none)
- **Tests:** `colour_keys_send_183_to_186`, `media_row_sends_media_codes`, `none_expands_pad_area`.

### Task 4.6: Keyboard sheet
- **Files:** `app/lib/features/keyboard/keyboard_sheet.dart`
- **Rules:** opens on button tap, or automatically on `ImeShowRequested` (setting: on); live typing via `sendText` with debounce 150 ms; Enter → `KeyCodes` enter (66); clear button.
- **Tests:** `auto_opens_on_ime_show`, `typing_sends_text_debounced`, `enter_sends_66`.

### Task 4.7: Behaviour features
- **Files:** `app/lib/core/device/keep_awake.dart`, `theater_mode.dart`
- **Rules:** Keep Screen Awake = wakelock while the remote screen is visible; Theater Mode = after 30 s idle, dim to 5% and switch to an extra-dark palette; the first touch restores and is **not** forwarded as a key.
- **Tests:** `theater_dims_after_30s_idle`, `first_touch_restores_without_sending_key`, `wakelock_only_on_remote_screen`.

---

## Phase 5 — Apps, devices, settings, help
**Exit criteria:** feature-complete free app (no services yet).

### Task 5.1: App catalogue + launcher
- **Files:** `app/assets/catalogue/apps_v1.json` (our own data: `package`, `name`, `deepLink`, `iconUrl` optional, `regions`), `features/apps/data/catalogue_repository.dart`, `apps_screen.dart`, `widgets/app_tile.dart`
- **Interfaces:** `AppEntry { String package; String name; String launchLink; String? iconUrl; bool isCustom; Color? customColor; String? customIcon; }`; launch link default `market://launch?id=<package>`
- **Tests:** `catalogue_parses_and_has_unique_packages`, `default_row_uses_device_region` (MY → Netflix, YouTube, Viu, Prime Video, iQIYI, Disney+ Hotstar), `tile_launch_calls_remote_actions`.

### Task 5.2: Shortcuts management + recommendations
- **Files:** `features/apps/presentation/manage_apps_screen.dart`, `add_app_sheet.dart`, `custom_shortcut_editor.dart`, `data/recommendations.dart`
- **Rules:** reorder by drag; add from catalogue search or "Recently used on your TV" (from `CurrentAppChanged`, counted in `app_usage`); system packages filtered (`android`, `com.google.android.tvlauncher`, `com.google.android.apps.tv.launcherx`, `com.android.tv.settings`, `com.mediatek.*`, `*.launcher*`, `com.google.android.tv.remote.service`); unknown packages show a prettified name ("com.foo.bar" → "Bar") with a generic icon; reset with confirmation.
- **Tests:** `filters_system_packages`, `unknown_package_gets_pretty_name`, `reorder_persists`, `reset_restores_region_defaults`.

### Task 5.3: Devices screen
- **Files:** `features/devices/devices_screen.dart`, `edit_device_screen.dart`, `wol_mac_help_sheet.dart`
- **Tests:** `rename_updates_switcher`, `delete_requires_confirmation_and_clears_identity_pairing_flag`, `mac_field_validates_format`.

### Task 5.4: Settings, FAQ/troubleshooting, legal, feedback
- **Files:** `features/settings/...` pages: Appearance, Remote layout (with live preview), Remote behaviour, Apps, Devices, Help (FAQ accordion + troubleshooting steps), About (version, licences via `showLicensePage`), Legal (privacy, terms URLs via url_launcher), Feedback (themed dialog → mailto with app/OS version, **no TV identifiers**)
- **Tests:** `each_settings_page_title_names_the_page`, `feedback_mail_body_excludes_tv_name_and_ip`, `theme_switch_applies_immediately`.

---

## Phase 6 — Services & monetisation
**Exit criteria:** dev flavor shows test ads in allowed places only; purchase + restore work in sandbox on both platforms; consent/ATT flows pass; events visible in Firebase DebugView.

### Task 6.1: Firebase + Crashlytics + Remote Config wrappers
- **Files:** `app/lib/core/analytics/analytics_service.dart`, `core/crash/crash_reporter.dart`, `core/config/app_config.dart`; flutterfire config per flavor (files git-ignored; setup in `docs/knowledge/learnings.md`)
- **Tests:** `config_defaults_match_app_services_skill`, `analytics_rejects_params_with_ip_or_mac_pattern` (the guard throws in debug), `app_starts_when_firebase_init_fails`.

### Task 6.2: Consent (UMP) + ATT pre-prompt
- **Files:** `core/ads/consent_service.dart`, `features/onboarding/tracking_preprompt.dart`; Settings → Privacy choices
- **Tests:** `ads_not_initialised_before_consent_resolved`, `att_prompt_only_after_preprompt_accept`.

### Task 6.3: Ads
- **Files:** `core/ads/ads_service.dart`, `core/ads/banner_slot.dart`
- **Interfaces:** `BannerSlot(placement: AdPlacement.apps | AdPlacement.settings)`; interstitial `maybeShow(trigger)` gated by Remote Config + premium + 600 s pacing
- **Tests:** `no_banner_on_remote_screen` (widget test asserts there's no `BannerSlot` in the tree), `banner_hidden_for_premium`, `interstitial_respects_min_interval`, `banner_has_48dp_clearance_from_nav_controls` (layout test).

### Task 6.4: RevenueCat + paywall + premium gating
- **Files:** `core/purchases/purchase_service.dart`, `features/paywall/paywall_screen.dart`, `premium_provider.dart`
- **Rules:** the `remote-design-system` paywall rules; products `premium_monthly`, `premium_yearly`, `premium_lifetime`, entitlement `premium`; premium unlocks no ads + premium themes; ✕ returns to the source route
- **Tests:** `paywall_shows_terms_restore_privacy`, `close_returns_to_source_route`, `premium_stream_drives_ads_off`, `offline_uses_cached_entitlement`.

### Task 6.5: Review prompt + forced update
- **Files:** `core/review/review_prompter.dart`, `core/config/update_gate.dart`
- **Tests:** `review_prompt_after_150_presses_and_2_sessions_never_after_error`, `below_min_version_shows_blocking_update`.

---

## Phase 7 — Polish & differentiators (v1.0 scope only)
- **Task 7.1: Onboarding** (3 cards: connect, control, apps; permission explainers; "Try demo"). Tests: `onboarding_shown_once`, `skip_goes_to_discover`.
- **Task 7.2: Motion & micro-interactions** (key press scale, status pill transitions, pad swipe trail), all respecting reduce motion. Tests: `reduce_motion_disables_animations`.
- **Task 7.3: App icon, splash, branding** (original icon; `flutter_launcher_icons`, `flutter_native_splash`). Check: no Google/Android TV marks.
- _v1.1 backlog (do not build now): home-screen widget, notification remote, voice search, iOS App Intents, watch apps._

## Phase 8 — Quality & hardening
- **Task 8.1: Integration tests** in `app/integration_test/`: `discover_pair_press_key_flow` against `FakeTvServer` (run on an emulator via `flutter test integration_test`), `demo_mode_flow`, `purchase_flow_sandbox` (manual checklist).
- **Task 8.2: Accessibility audit:** TalkBack + VoiceOver pass over every screen; `meetsGuideline(textContrastGuideline)`, `androidTapTargetGuideline`, `iOSTapTargetGuideline`, `labeledTapTargetGuideline` tests per screen.
- **Task 8.3: Real-device matrix:** phones (Android 8, 12, 14/15; iPhone iOS 16+) × TVs (owner's MediaTek TV, plus a Google TV/Chromecast if available). Scripted checklist in `docs/knowledge/device-matrix.md`; record results.
- **Task 8.4: Performance & battery:** cold start < 1.5 s on a mid-range phone; key-press-to-send < 30 ms; idle connected battery drain measured over 30 min; no socket leaks after 50 background/resume cycles (test `no_leak_after_50_resume_cycles`).
- **Task 8.5: Malay translation** (`app_ms.arb`) + pseudo-locale overflow check.

## Phase 9 — Release
- **Task 9.1: Legal & listing assets:** privacy policy + terms pages (hosted, URL in app and stores), store copy (EN + MS), screenshots (8 phone, 2 tablet per store; framed), feature graphic, demo video for Apple review.
- **Task 9.2: Android release:** upload keystore, `key.properties`, Play App Signing, AAB build `flutter build appbundle --flavor prod -t lib/main_prod.dart`, Data safety form, ads declaration, content rating, internal test → **closed test (12 testers × 14 days)** → production with a staged rollout of 10% → 50% → 100%.
- **Task 9.3: iOS release:** bundle id, capabilities, Info.plist purpose strings, App Privacy labels, StoreKit products in App Store Connect + RevenueCat, `flutter build ipa --flavor prod`, TestFlight internal → external, App Review submission with demo video + demo mode notes.
- **Task 9.4: Launch ops:** Crashlytics alerts, Remote Config kill switches verified (`ads_banner_enabled`, `ads_interstitial_enabled`), first-week review response plan, v1.1 backlog groomed in `docs/knowledge/status.md`.

---

## Milestones
| Milestone | Phases | Outcome |
|---|---|---|
| M1 Protocol proven | 0–1 | CLI controls the owner's TV; ping-stable for 5 min |
| M2 Connect & control | 2–4 | Installable dev build; full remote on a real TV; closed-test clock starts |
| M3 Feature complete | 5–6 | Apps, devices, settings, ads, premium |
| M4 Release candidate | 7–8 | Polished, accessible, tested on the device matrix |
| M5 Live | 9 | Published on Google Play and the App Store |
