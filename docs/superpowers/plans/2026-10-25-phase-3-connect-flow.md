# Phase 3 — Connect Flow Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A user can find their TV on the network (or type its IP), pair it with the on-screen code, and land on a minimal remote screen whose status pill shows the live socket state and recovers by itself after backgrounding or a network change. Demo mode runs the same UI without a TV.

**Architecture:** The UI talks to one app-side interface, `RemoteSession`. `TvRemoteSession` wraps the library's `TvConnection`: it checks the TOFU pin, re-resolves the host through mDNS and records the host and connect time. `DemoRemoteSession` simulates a TV. A keepAlive Riverpod provider owns the active session. A pure-Dart `SessionSupervisor` turns app-lifecycle and connectivity signals into `disconnect`/`connect`/`notify*` calls, with a 60 s background grace and a debounce. Discovery is `NsdTvDiscovery` (the `nsd` plugin) behind the library's `TvDiscovery` interface. Pairing is a Riverpod controller over `PairingClient`. App tests never open sockets: they use fakes that `implements` the library classes.

**Tech Stack:** Flutter 3.44.1 / Dart 3.12.1, Riverpod 3.3.2 (codegen, riverpod_generator 4.0.4), go_router 18.1.1, drift 2.34.0. New: nsd 5.0.1, connectivity_plus 7.3.2, network_info_plus 8.2.2, fake_async 1.3.3 (dev). very_good_analysis 10.3.0.

**Spec:** `docs/superpowers/specs/2026-10-25-tv-remote-app-design.md` (binding). This plan expands Phase 3 of `docs/superpowers/plans/2026-10-25-tv-remote-app.md` and keeps its interfaces except where a **Ruling** below says otherwise. Before starting, read:
- the `atv-remote-protocol`, `flutter-app-architecture` and `remote-design-system` skills
- `docs/knowledge/decisions.md` #9–#12 and `learnings.md`
- `packages/atv_remote/lib/atv_remote.dart` and the files it exports.

## Global Constraints

- Flutter 3.44.1 / Dart 3.12.1, `environment.sdk: ^3.12.1`. Lints: `very_good_analysis` 10.3.0 with `public_member_api_docs`, so every public `lib/` member gets a `///` doc. Keep pubspec dependencies sorted.
- Pin each new app dependency to the **exact** version its task gives. These were checked together with `flutter pub add --dry-run` against this workspace on 2026-10-25: `nsd:5.0.1`, `connectivity_plus:7.3.2`, `network_info_plus:8.2.2`, `dev:fake_async:1.3.3`.
- No socket, TLS or protobuf code in `app/`. The app imports only `package:atv_remote/atv_remote.dart`. `dart:io` types (`InternetAddress`) are allowed for addresses.
- Library changes stay pure Dart (no Flutter imports), with tests in `packages/atv_remote/test`.
- No analytics in this phase. Never log TV names, IPs or MACs.
- English strings go in `app/lib/app/l10n/app_en.arb`, each with an `@key` description. No hard-coded UI text. The iOS `Info.plist` purpose string is the one exception.
- Touch targets: ≥ 56 dp for remote keys, ≥ 48 dp for everything else. Text scaling to 200% reflows without overflow. No ads anywhere in this phase.
- Every failure the user can see comes with an action: retry, troubleshooting, enter the code again, get a new code, pair again, or back to TVs.
- Riverpod 3:
  - `Override` and `ProviderException` come from `package:flutter_riverpod/misc.dart`.
  - Check `ref.mounted` after every `await` in a notifier before touching `state`.
  - Watch every dependency **before** the first `await` in an async provider.
  - Riverpod 3 retries failed providers by default. Providers whose errors the UI must show pass `retry: noRetry` (Task 3.4).
- Code generation: `flutter pub run build_runner build --delete-conflicting-outputs`, then `dart format lib test`, both from `app/`. `dart run build_runner` fails in this workspace.
- Goldens: one `*_golden_test.dart` per subject, `@Tags(['golden'])`, baselines in `goldens/` next to the test, generated on Windows with `flutter test --update-goldens --tags golden <path>`.
- App tests need no TV, network or platform channel. Platform-backed providers are overridden in the shared test helpers (Tasks 3.2–3.5 add them to `pumpRouterApp`'s defaults).
- `flutter`/`dart` commands in steps run from `app/`. Library commands run from `packages/atv_remote/`. `check.ps1` and `git` run from the repo root. Before every commit, `powershell -File tool/check.ps1` must print `All checks passed.`
- Commits end with the trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Don't edit `docs/knowledge/*` or `CLAUDE.md`. Put knowledge updates in your task report; the controller applies them.

## Rulings (conflicts and open questions resolved for this phase)

1. **The UI consumes `RemoteSession`, not `TvConnection`.**
   - `RemoteSession` is an app interface (Task 3.3). `TvRemoteSession` implements it by wrapping `TvConnection`. `DemoRemoteSession` implements it by simulating a TV (master Task 3.4's `demo_tv_connection.dart` becomes `demo_remote_session.dart`).
   - Widgets never branch on demo for behaviour. `RemoteSession.isDemo` may be read only to show the demo badge, the TV preview card and the localised "Demo TV" name.
2. **No exported fake TV server.**
   - `FakeTvServer` stays in `packages/atv_remote/test/fake_tv/`. It needs real loopback sockets, which don't fit `testWidgets`' fake clock.
   - App tests use `FakeRemoteClient implements RemoteClient` and `FakePairingClient implements PairingClient` in `app/test/helpers/`. These are deterministic and run under fake async.
   - Phase 8.1's integration test decides whether to export the server as `package:atv_remote/testing.dart`.
3. **Library changes (Task 3.1):**
   - `TvConnection.disconnect()` lets the session close the socket after 60 s in the background and later `connect()` again on the same object.
   - `TvConnection.host` exposes the re-resolved address.
   - Re-check the generation after `verifyServerKey` and route the rejection through `_handleFailure` (Phase 1 carry-over).
   - `PairingClient` reports an unloadable identity by exception type only (Phase 1 carry-over).
4. **Multicast lock:** `nsd_android` 2.2.0 acquires a reference-counted `WifiManager.MulticastLock` on every `startDiscovery` and releases it on `stopDiscovery` (checked in its `NsdAndroidPlugin.kt`). `CHANGE_WIFI_MULTICAST_STATE` is already declared (Phase 2). So there is no native code in this phase.
5. **Pins** (decision #11):
   - Stored as lower-case hex of `PairingClient.serverPublicKeySha256` (64 chars).
   - A device with `serverKeyPin == null` is `needsPairing` and the app never opens a socket to it.
   - A pin mismatch (`serverKeyChanged`) clears the stored pin.
   - `certificateRejected` keeps the pin; re-pairing overwrites it.
6. **No automatic navigation to pairing.**
   - `needsPairing` shows a "Pair again" action in the status pill.
   - `serverKeyChanged` also opens the "This TV's identity changed" dialog, once per session.
   - Both lead to `/pair/:serviceName` with the TV as `extra`.
   - Master test names `needs_pairing_routes_to_pairing_screen` and `identity_changed_routes_to_pairing` are kept and tap the action.
7. **Status pill copy** (Phase 2 carry-over): the needsPairing label becomes `Needs pairing`. The new action button is `Pair again`.
8. **Manual-IP TVs** use `serviceName = 'manual:<ipv4>'`, `displayName = <ipv4>` and port 6466. They are never re-resolved through mDNS. If mDNS later finds the same TV, it appears as a second entry; Phase 5's devices screen handles merges.
9. **Timing values:**
   - Background grace: 60 s (the skill).
   - Nudge debounce: 500 ms, trailing (Claude's call).
   - Connectivity: the first event is a baseline. Duplicates and all-`none` results are ignored.
   - On resume, the wall-clock time since backgrounding is checked, because iOS suspends timers. ≥ 60 s forces a reconnect even if the grace timer never fired.
10. **Reconnect action** = `RemoteSession.reconnect()`: from `disconnected` it calls `connect()`, otherwise `notifyNetworkChanged()` (Phase 1 carry-over: re-resolves the host).
11. **Troubleshooting is an in-app sheet.** There's no hosted page or `url_launcher` yet. Phase 5's Help screen reuses the sheet, and Phase 9 can add a link.
12. **Host re-resolution:** `resolveHostByServiceName` gives up after 4 s, inside `TvConnection`'s 5 s `reResolveTimeout`, and always stops its discovery.
13. **Wake-on-LAN:**
    - The service sends to `255.255.255.255`, the Wi-Fi subnet broadcast from `network_info_plus` `getWifiBroadcast()` (needs no location permission), and the `/24` broadcast of the TV's last IPv4 as a fallback.
    - UI wiring is Phase 4.
    - On iOS, broadcast needs Apple's multicast entitlement (owner action).
14. **Client name and device info:**
    - Pairing `clientName` is `'Remotely'`.
    - `DeviceInfo(model: 'Remotely', vendor: 'digitallinked', packageName: flavor.applicationId, appVersion: kAppVersion)`, where `kAppVersion = '1.0.0'` is held equal to the pubspec version by a test. Phase 6 may replace it with `package_info_plus`.
15. **Identity-store read retry** (Phase 2 carry-over): a throwing secure-storage read is retried once after 200 ms before the identity counts as missing.
16. **Out of scope:**
    - The full remote UI, `RemoteActions`, Smooth Press and power/WoL buttons (Phase 4).
    - Device rename/delete (Phase 5) and the iOS local-network pre-prompt (Phase 7).
    - CLI hardening and the protoc URL carry-overs (not app wiring).

## Review Focus

1. **iOS suspends the app for minutes, so the 60 s grace timer never fires.** On resume the socket is dead, but `TvConnection` still says `connected`. The pill must not keep showing "Connected": the supervisor compares wall-clock time and forces `disconnect()` + `connect()` (Task 3.5 `resume_after_suspension_longer_than_grace_reconnects_even_if_timer_never_fired`).
2. **Bursts of signals.** A network flap (Wi-Fi → none → Wi-Fi), or a resume that arrives together with connectivity events, must produce exactly one reconnect nudge after the burst. One nudge per event would keep abandoning the attempt in flight (Task 3.5 `burst_of_resume_and_network_changes_is_coalesced_into_one_nudge`, `connectivity` tests `ignores_none_and_duplicates`).
3. **A pairing code typed or pasted messily.** Inputs like `" ab12cd\n"`, `"AB-12-CD"`, `"ab 12 cd"`, or 7+ characters are normalised to `AB12CD` and submitted exactly once. Non-hex characters never reach `submitCode` (Task 3.9 `code_is_trimmed_and_upper_cased_before_submit`, `pasted_code_with_spaces_and_dashes_is_normalised`).
4. **The TV's IP changes, or mDNS can't find it.** Reconnect re-resolves by `serviceName`. If nothing answers within 4 s, it keeps the old host, carries on with backoff, and always stops the discovery it started (Task 3.2 `returns_null_after_timeout_and_stops_discovery`, Task 3.3 `re_resolves_host_on_reconnect`).
5. **Leaving or switching mid-flow.** Back during "Connecting…" or while waiting for the code must close the pairing client with no state update after dispose. Switching TVs in the device switcher must dispose the old session, so only one socket is ever live (Task 3.9 `leaving_during_start_does_not_update_state_after_dispose`, Task 3.4 `activate_device_switches_the_session_and_disposes_the_old_one`).

---

## File Structure

```
packages/atv_remote/lib/src/tv_connection.dart        disconnect(), host, verify re-check        (3.1)
packages/atv_remote/lib/src/pairing_client.dart       identity-load message                      (3.1)
app/
  pubspec.yaml                                        nsd, connectivity_plus, network_info_plus, fake_async
  ios/Runner/Info.plist                               NSLocalNetworkUsageDescription, NSBonjourServices (3.2)
  lib/
    app/app.dart, app/app_shell.dart                  builder with the demo badge                (3.7)
    app/router.dart                                   /remote → RemoteScreen (3.6), /pair → PairingScreen (3.9)
    app/widgets/status_pill.dart                      onPairAgain, new label                     (3.6)
    bootstrap.dart                                    @visibleForTesting overrides               (3.8)
    core/tv/manual_tv.dart, server_key_pin.dart, saved_device_x.dart, host_resolver.dart (3.2, 3.3)
    core/storage/device_repository.dart               find, markConnected, clearServerKeyPin     (3.3)
    core/storage/identity_store.dart                  one read retry                             (3.3)
    core/storage/storage_providers.dart               savedDevicesProvider                       (3.4)
    core/session/remote_session.dart                  RemoteSession interface                    (3.3)
    core/session/tv_remote_session.dart               TvConnection wrapper                       (3.3)
    core/session/remote_client_factory.dart           factory, DeviceInfo, kAppVersion           (3.3, provider 3.4)
    core/session/session_target.dart                  DeviceTarget (3.4), DemoTarget (3.7)
    core/session/session_providers.dart               activeTarget, remoteSession, state/volume/power/app (3.4)
    core/session/lifecycle_observer.dart, connectivity_observer.dart, session_signals.dart, session_supervisor.dart (3.5)
    core/wake/wake_on_lan_service.dart                                                           (3.10)
    features/discovery/data/nsd_tv_discovery.dart, discovery_providers.dart                      (3.2)
    features/discovery/application/discovery_controller.dart                                      (3.8)
    features/discovery/presentation/discovery_screen.dart, manual_ip_sheet.dart                  (3.8)
    features/discovery/presentation/widgets/discovery_empty_state.dart, tv_list_tile.dart,
        legacy_service_sheet.dart, troubleshooting_sheet.dart                                    (3.8)
    features/remote/presentation/remote_screen.dart, key_labels.dart,
        widgets/device_switcher.dart, widgets/basic_controls.dart                                (3.6)
    features/demo/demo_remote_session.dart, demo_providers.dart,
        presentation/demo_badge.dart, presentation/tv_preview_card.dart                          (3.7)
    features/onboarding/presentation/onboarding_screen.dart   "Try demo"                         (3.7)
    features/pairing/domain/pairing_code.dart, application/pairing_state.dart,
        application/pairing_controller.dart, data/pairing_providers.dart,
        presentation/pairing_screen.dart, presentation/widgets/pairing_code_field.dart           (3.9)
  test/
    fixtures/client.pem, client_key.pem               copied from packages/atv_remote/test/fixtures (3.3)
    helpers/test_identity.dart, test_devices.dart, fake_remote_client.dart, fake_remote_session.dart (3.3)
    helpers/fake_tv_discovery.dart (3.2), manual_session_signals.dart (3.5), fake_pairing_client.dart (3.9)
    helpers/pump_router_app.dart                      default overrides grow per task
```

| Task | Master task | Deliverable |
|---|---|---|
| 3.1 | 1.7 carry-over | `TvConnection.disconnect`/`host`/verify re-check; `PairingClient` message |
| 3.2 | 3.1 | `NsdTvDiscovery`, host resolver, iOS Bonjour keys |
| 3.3 | 3.3 | `RemoteSession`, `TvRemoteSession`, repository/identity additions, test fakes |
| 3.4 | 3.3 | Session providers (active target, session, state/volume/power/current app) |
| 3.5 | 3.3 | Lifecycle + connectivity observers, `SessionSupervisor` |
| 3.6 | 3.3 | `StatusPill` actions, minimal `RemoteScreen`, device switcher |
| 3.7 | 3.4 | Demo session, badge, TV preview, onboarding entry |
| 3.8 | 3.1 | Discovery screen, manual IP, legacy help, troubleshooting |
| 3.9 | 3.2 | Pairing controller + screen |
| 3.10 | carry-over | `WakeOnLanService` |

Run the tasks in order, 3.1 → 3.10. Each one builds only on earlier tasks.

---

### Task 3.1: Library — `TvConnection.disconnect`, `host`, verify re-check; pairing identity message

**Files:**
- Modify: `packages/atv_remote/lib/src/tv_connection.dart`, `packages/atv_remote/lib/src/pairing_client.dart`
- Create: `packages/atv_remote/test/support/unloadable_identity.dart` (move `_UnloadableIdentity` out of `remote_client_test.dart` as public `UnloadableIdentity`)
- Test: `packages/atv_remote/test/tv_connection_test.dart`, `packages/atv_remote/test/pairing_client_test.dart`, `packages/atv_remote/test/remote_client_test.dart` (import the moved helper)

**Interfaces:**
- Consumes: the existing `TvConnection`, `PairingClient` and the test rig `_rig(...)` / `_until(...)` in `tv_connection_test.dart`.
- Produces:
  - `Future<void> TvConnection.disconnect()`:
    - Bumps the generation, cancels a scheduled retry and closes the current client (`_detachClient`), then emits `disconnected`.
    - Idempotent. A no-op after `dispose()`.
    - Afterwards `connect()` starts afresh. `notifyAppResumed()` and `notifyNetworkChanged()` do nothing while `disconnected`, which is already true of `_retryNow`.
  - `String get TvConnection.host`: the address the current or next attempt uses, updated when `reResolveHost` returns a non-null value.
  - Behaviour fix in `_runAttempt`:
    - Compute `final accepted = _serverKeyAccepted(client);`, then `if (generation != _generation) return;` before acting on it.
    - On rejection call `_handleFailure(RemoteCloseReason.serverKeyChanged)`, which already drops the client, cancels the timer and sets `needsPairing`, instead of the inline duplicate.
  - `PairingClient._connect`:
    - Build `clientSecurityContext(identity)` in its own `try` before calling the connector.
    - On any error throw `PairingException(PairingFailure.connectionFailed, 'could not load the client identity (${e.runtimeType})')`.

- [ ] **Step 1: Write the failing tests** (in the existing groups, using `_rig`):

```dart
// tv_connection_test.dart
test('disconnect_closes_the_client_and_emits_disconnected', () async {
  final rig = await _rig(); await rig.connection.connect();
  await rig.connection.disconnect();
  expect(rig.connection.current.status, ConnectionStatus.disconnected);
  expect(() => rig.connection.sendKey(KeyCodes.home), throwsA(isA<NotConnectedException>()));
});
test('connect_after_disconnect_connects_again', ...)            // disconnect → connect() → connected; rig.clients.length == 2
test('disconnect_cancels_a_scheduled_retry', ...)               // tv.dropConnections() + rig.unreachable = true → reconnecting → disconnect → wait 3× fast backoff → still disconnected, no new client
test('disconnect_abandons_an_attempt_in_flight', ...)           // rig.hold = Completer() during reconnect → disconnect → complete hold → never connected, status disconnected
test('resume_and_network_change_do_nothing_after_disconnect', ...) // disconnect → notifyAppResumed(), notifyNetworkChanged() → no new client after 200 ms
test('host_reports_the_re_resolved_address', ...)               // reResolveHost returns '127.0.0.1' after a drop → connection.host == '127.0.0.1'; initially the constructor host
test('dispose_inside_verify_server_key_never_reports_connected', () async {
  late TvConnection c; final seen = <ConnectionStatus>[];
  final rig = await _rig(verifyServerKey: (_) { unawaited(c.dispose()); return true; });
  c = rig.connection; c.states.listen((s) => seen.add(s.status));
  await c.connect(); await pumpEventQueue();
  expect(seen, isNot(contains(ConnectionStatus.connected)));
  expect(c.current.status, ConnectionStatus.disconnected);
});
// existing 'a_rejected_key_routes_to_pairing_and_never_connects' must still pass unchanged.

// pairing_client_test.dart
test('unloadable_identity_fails_without_tls_library_text', () async {
  final client = PairingClient(host: '127.0.0.1', port: tv.pairingPort, identity: UnloadableIdentity(paired));
  await expectLater(client.start(clientName: 'x'), throwsA(isA<PairingException>()
      .having((e) => e.reason, 'reason', PairingFailure.connectionFailed)
      .having((e) => e.message, 'message', allOf(contains('could not load the client identity'), isNot(contains('BoringSSL')), isNot(contains('PEM'))))));
});
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/tv_connection_test.dart test/pairing_client_test.dart`
Expected: FAIL. Compilation errors: no `disconnect`, `host` or `UnloadableIdentity`.

- [ ] **Step 3: Implement** `disconnect()`, `host`, the verify re-check and fold, and the `PairingClient` identity try-block. Move `_UnloadableIdentity` to `test/support/unloadable_identity.dart` and import it in both tests. Update the `TvConnection` class doc's transition list with `disconnect`.
- [ ] **Step 4: Run the package tests and confirm they pass**

Run: `flutter test`
Expected: all PASS. `dart analyze --fatal-infos` is clean.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add packages/atv_remote
git commit -m "feat(atv_remote): disconnect, current host and safer key verification" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: update `status.md` to tick off the carry-overs "re-check the generation after `verifyServerKey`" and "`PairingClient` BoringSSL text".

---

### Task 3.2: NSD discovery, host resolver, iOS Bonjour keys

**Files:**
- Modify: `app/pubspec.yaml` (dep `nsd: 5.0.1`), `app/ios/Runner/Info.plist`
- Create: `app/lib/features/discovery/data/nsd_tv_discovery.dart`, `app/lib/features/discovery/data/discovery_providers.dart` (+ `.g.dart`), `app/lib/core/tv/host_resolver.dart`, `app/lib/core/tv/manual_tv.dart`, `app/test/helpers/fake_tv_discovery.dart`
- Modify: `app/test/helpers/pump_router_app.dart` (default override `tvDiscoveryFactoryProvider.overrideWithValue(FakeTvDiscoveries().create)`)
- Test: `app/test/features/discovery/data/nsd_tv_discovery_test.dart`, `app/test/core/tv/host_resolver_test.dart`, `app/test/core/tv/manual_tv_test.dart`, `app/test/platform/ios_local_network_test.dart`

**Interfaces:**
- Consumes: `TvDiscovery`, `DiscoveredTv`, `parseServiceRecord` from `atv_remote`. From `package:nsd/nsd.dart`: `startDiscovery`, `stopDiscovery`, `Discovery`, `Service`, `IpLookupType`.
- Produces:
  - `typedef NsdStart = Future<Discovery> Function(String serviceType, {bool autoResolve, IpLookupType ipLookupType});` and `typedef NsdStop = Future<void> Function(Discovery discovery);`
  - `class NsdTvDiscovery implements TvDiscovery`:
    - Constructor: `NsdTvDiscovery({NsdStart start = startDiscovery, NsdStop stop = stopDiscovery})`.
    - `static const List<String> serviceTypes = ['_androidtvremote2._tcp', '_androidtvremote._tcp']`.
    - `watch()` may be called once per instance; a second call throws `StateError`.
      - It starts one discovery per type with `autoResolve: true, ipLookupType: IpLookupType.v4`.
      - It emits `[]` first, then the merged list on every found/lost event.
      - Each `Service` becomes a TV with `parseServiceRecord(serviceType: service.type ?? requestedType, name: service.name!, host: <first IPv4 in service.addresses, else service.host>, port: service.port!)`.
      - Services missing a name, host or port are skipped.
      - When the same `serviceName` comes from both types, the v2 record wins.
      - If any `start` throws, every started discovery is stopped and the error goes to the stream.
    - `stop()` is idempotent: it stops every discovery and closes the stream.
  - `typedef TvDiscoveryFactory = TvDiscovery Function();`
  - `@Riverpod(keepAlive: true) TvDiscoveryFactory tvDiscoveryFactory(Ref ref) => NsdTvDiscovery.new;` → `tvDiscoveryFactoryProvider`.
  - In `core/tv/host_resolver.dart`:
    - `typedef HostResolver = Future<String?> Function(String serviceName);`
    - `Future<String?> resolveHostByServiceName(TvDiscoveryFactory createDiscovery, String serviceName, {Duration timeout = const Duration(seconds: 4)})` returns the host of the first non-legacy TV whose `serviceName` matches, or `null` on timeout or stream error. It always awaits `stop()` (in `finally`).
  - `@Riverpod(keepAlive: true) HostResolver hostResolver(Ref ref)` (in `discovery_providers.dart`) → `(name) => resolveHostByServiceName(ref.read(tvDiscoveryFactoryProvider), name)`.
  - In `core/tv/manual_tv.dart`:
    - `const manualServiceNamePrefix = 'manual:';`
    - `String? parseIpv4(String input)` trims, then accepts a dotted quad (each octet 0–255, no leading zeros) whose first octet is 1–223 and not 127. It returns the canonical string, or `null`.
    - `bool isManualServiceName(String serviceName)`.
    - `DiscoveredTv manualTv(String ipv4)` returns `DiscoveredTv(serviceName: 'manual:$ipv4', displayName: ipv4, host: ipv4, port: 6466, isLegacyService: false)`.
  - Test helper `FakeTvDiscovery implements TvDiscovery`:
    - `emit(List<DiscoveredTv>)`, `fail(Object error)`.
    - `bool get stopped`, `int watchCalls`.
    - `watch()` returns a broadcast stream.
  - Test helper `FakeTvDiscoveries`: `TvDiscovery create()`, `List<FakeTvDiscovery> created`, and `void Function(FakeTvDiscovery)? onCreate` for scripting each new instance.
- `Info.plist` additions:
  - `NSLocalNetworkUsageDescription` = `Remotely uses your local network to find and control your Android TV.`
  - `NSBonjourServices` = array `_androidtvremote2._tcp`, `_androidtvremote._tcp`.

- [ ] **Step 1: Write the failing tests**

```dart
// nsd_tv_discovery_test.dart: fake start/stop record calls and hand back Discovery objects the test mutates.
final discoveries = <String, Discovery>{}; final stopped = <Discovery>[]; final starts = <(String, bool, IpLookupType)>[];
Future<Discovery> start(String type, {bool autoResolve = true, IpLookupType ipLookupType = IpLookupType.none}) async {
  starts.add((type, autoResolve, ipLookupType)); return discoveries[type] = Discovery(type);
}
Service svc(String name, String type, {String? ip = '192.168.0.20', int? port = 6466}) => Service(name: name, type: type, port: port,
    host: 'tv.local', addresses: ip == null ? null : [InternetAddress(ip)]);

test('browses_both_service_types_with_auto_resolve_and_ipv4_lookup', ...) // starts == [('_androidtvremote2._tcp', true, v4), ('_androidtvremote._tcp', true, v4)]
test('emits_resolved_tvs_from_both_service_types', () async {
  final d = NsdTvDiscovery(start: start, stop: (x) async => stopped.add(x));
  final lists = <List<DiscoveredTv>>[]; d.watch().listen(lists.add); await pumpEventQueue();
  discoveries['_androidtvremote2._tcp']!.add(svc('Living Room TV 3', '_androidtvremote2._tcp'));
  discoveries['_androidtvremote._tcp']!.add(svc('Old Bravia', '_androidtvremote._tcp', ip: '192.168.0.30'));
  await pumpEventQueue();
  expect(lists.first, isEmpty);
  expect(lists.last.map((t) => (t.serviceName, t.host, t.isLegacyService)),
      unorderedEquals([('Living Room TV 3', '192.168.0.20', false), ('Old Bravia', '192.168.0.30', true)]));
});
test('prefers_ipv4_address_over_host_name', ...)       // addresses [IPv6 '::1'-like, IPv4] → host is the IPv4; no addresses → 'tv.local'
test('skips_unresolved_services', ...)                 // port null → not listed
test('removes_lost_services', ...)                     // Discovery.remove(svc) → TV gone from the next list
test('v2_record_wins_over_legacy_with_same_name', ...) // same name on both types → one entry, isLegacyService false
test('start_failure_surfaces_as_stream_error_and_stops_started_discoveries', ...) // legacy start throws NsdError → stream emits error; stopped contains the v2 discovery
test('stop_stops_every_discovery_and_closes_the_stream', ...) // stop() twice → stopped.length == 2, stream done
test('watch_twice_throws', ...)

// host_resolver_test.dart (FakeTvDiscoveries; fakeAsync for the timeout)
test('returns_host_of_matching_service', ...)          // emit [tv('Other'), tv('Living Room TV 3', host: '192.168.0.99')] → '192.168.0.99'; discovery stopped
test('ignores_legacy_records_with_the_same_name', ...)
test('returns_null_after_timeout_and_stops_discovery', () => fakeAsync((async) {
  final f = FakeTvDiscoveries(); String? result = 'unset';
  resolveHostByServiceName(f.create, 'Living Room TV 3').then((h) => result = h);
  async.elapse(const Duration(seconds: 3)); expect(result, 'unset');
  async.elapse(const Duration(seconds: 2)); expect(result, isNull); expect(f.created.single.stopped, isTrue);
}));
test('stream_error_returns_null_and_stops', ...)

// manual_tv_test.dart
test('manual_ip_parsing_accepts_only_usable_ipv4', () {
  for (final ok in ['192.168.1.20', ' 10.0.0.5 ', '172.16.254.1', '1.2.3.4']) expect(parseIpv4(ok), ok.trim());
  for (final bad in ['', '192.168.1', '192.168.1.256', '192.168.01.2', '127.0.0.1', '0.1.2.3', '224.0.0.1', '255.255.255.255', 'tv.local', '::1', '1.2.3.4.5']) expect(parseIpv4(bad), isNull);
});
test('manual_tv_uses_prefixed_service_name_and_control_port', ...) // manualTv('192.168.1.20') → ('manual:192.168.1.20', '192.168.1.20', 6466, false); isManualServiceName true

// ios_local_network_test.dart (cwd app/)
test('ios_declares_local_network_usage_and_bonjour_services', () {
  final plist = File('ios/Runner/Info.plist').readAsStringSync();
  expect(plist, contains('<key>NSLocalNetworkUsageDescription</key>'));
  expect(plist, contains('<string>_androidtvremote2._tcp</string>'));
  expect(plist, contains('<string>_androidtvremote._tcp</string>'));
});
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/discovery/data test/core/tv test/platform/ios_local_network_test.dart`
Expected: FAIL. Compilation errors, and the plist test fails.

- [ ] **Step 3: Add the dependencies**

Run: `flutter pub add nsd:5.0.1 dev:fake_async:1.3.3`
(`fake_async` is needed here for the resolver timeout test, and later for Task 3.5.)

- [ ] **Step 4: Implement** the discovery, providers, resolver, manual-TV helpers, the test fakes and the plist keys. Add the `pumpRouterApp` default override. Run build_runner, then `dart format lib test`.
- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test test/features/discovery/data test/core/tv test/platform`
Expected: all PASS.

- [ ] **Step 6: Build the dev APK** (catches Gradle or Kotlin issues from the new plugin)

Run: `flutter build apk --debug --flavor dev -t lib/main_dev.dart`
Expected: build succeeds.

- [ ] **Step 7: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml pubspec.lock app/ios/Runner/Info.plist app/lib app/test
git commit -m "feat(app): mDNS TV discovery and host re-resolution" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision "nsd_android owns the multicast lock (Ruling 4)" and the pinned versions. Note for the owner: on a Mac, the first `flutter build ios` creates a `Podfile` that must map the six flavor configurations (Phase 2 note).

---

### Task 3.3: `RemoteSession`, `TvRemoteSession`, storage additions, test fakes

**Files:**
- Modify: `app/lib/core/storage/device_repository.dart`, `app/lib/core/storage/identity_store.dart`, `app/test/helpers/in_memory_secure_store.dart` (add `int failNextReads = 0`)
- Create: `app/lib/core/session/remote_session.dart`, `app/lib/core/session/tv_remote_session.dart`, `app/lib/core/session/remote_client_factory.dart` (typedef, `deviceInfoFor`, constants; its provider comes in Task 3.4), `app/lib/core/tv/server_key_pin.dart`, `app/lib/core/tv/saved_device_x.dart`
- Create (tests): `app/test/fixtures/client.pem`, `app/test/fixtures/client_key.pem` (copies of `packages/atv_remote/test/fixtures/`), `app/test/helpers/test_identity.dart`, `test_devices.dart`, `fake_remote_client.dart`, `fake_remote_session.dart`
- Test: `app/test/core/session/tv_remote_session_test.dart`, `app/test/core/tv/server_key_pin_test.dart`, `app/test/core/session/remote_client_factory_test.dart`, plus additions to `app/test/core/storage/device_repository_test.dart` and `identity_store_test.dart`

**Interfaces:**
- Consumes: `TvConnection` (with Task 3.1's `disconnect`/`host`), `RemoteClient`, `Backoff`, `ClientIdentity`, `DeviceInfo`, `RemoteEvent`s; `SavedDevice`, `DeviceRepository`; `HostResolver`, `isManualServiceName` (Task 3.2); `Flavor` (Phase 2).
- Produces:
  - `DeviceRepository` gains these methods (implemented in `DriftDeviceRepository` with targeted `update(...).write(DevicesCompanion(...))` so other columns are never overwritten; all are no-ops for unknown names):
    - `Future<SavedDevice?> find(String serviceName)`
    - `Future<void> markConnected(String serviceName, {required String host, required DateTime at})`
    - `Future<void> clearServerKeyPin(String serviceName)`
  - `IdentityStore({..., Duration readRetryDelay = const Duration(milliseconds: 200)})`: a read that throws is retried once after `readRetryDelay` before it counts as missing (Ruling 15).
  - `String serverKeyPinFromSha256(List<int> sha256)`: lower-case hex, throws `ArgumentError` unless 32 bytes. `bool matchesServerKeyPin(List<int> sha256, String? pin)`: false for `null`, case-insensitive.
  - `extension SavedDeviceX on SavedDevice { String get label /* nickname ?? displayName */; DiscoveredTv toDiscoveredTv() /* serviceName, label, lastHost, port, isLegacyService: false */; }`
  - In `remote_client_factory.dart`:
    - `typedef RemoteClientFactory = RemoteClient Function({required String host, required int port, required ClientIdentity identity});`
    - `const kAppVersion = '1.0.0';` and `const kRemoteClientName = 'Remotely';`
    - `DeviceInfo deviceInfoFor(Flavor flavor)` (Ruling 14).
  - `abstract interface class RemoteSession` (every member gets a `///` doc saying what it means for the UI):

    ```dart
    String get tvName;                       // SavedDevice label; '' for demo (UI shows l10n.demoTvName)
    bool get isDemo;
    DiscoveredTv? get pairingTarget;         // where "Pair again" goes; null for demo
    TvConnectionState get current;
    Stream<TvConnectionState> get states;    // replays `current` to every new listener, then each change
    Stream<RemoteEvent> get events;          // broadcast TV pushes (volume, power, app, IME, errors)
    VolumeChanged? get volume;  bool? get isPowerOn;  String? get currentApp;   // last reported values
    Future<void> connect();  Future<void> disconnect();
    void notifyAppResumed();  void notifyNetworkChanged();
    void reconnect();                        // Ruling 10
    void sendKey(int keyCode, {KeyDirection direction = KeyDirection.short});   // NotConnectedException unless connected
    void launchAppLink(String link);  void sendText(String text);              // same
    Future<void> dispose();
    ```
  - `class TvRemoteSession implements RemoteSession`. Constructor: `TvRemoteSession({required SavedDevice device, required ClientIdentity identity, required DeviceRepository devices, required RemoteClientFactory clientFactory, required HostResolver resolveHost, Backoff? backoff, DateTime Function() now = DateTime.now})`. Rules:
    - It holds the pin in memory.
    - With `device.serverKeyPin == null` it never creates a `TvConnection`: `current` is `TvConnectionState(status: needsPairing)`, and `connect`, `reconnect` and `notify*` are no-ops.
    - Otherwise it builds `TvConnection(host: device.lastHost, clientFactory: (h) => clientFactory(host: h, port: device.port, identity: identity), backoff: backoff, reResolveHost: isManualServiceName(device.serviceName) ? null : () => resolveHost(device.serviceName), verifyServerKey: (sha) => matchesServerKeyPin(sha, _pin))`.
    - On each transition to `connected`: `devices.markConnected(device.serviceName, host: connection.host, at: now().toUtc())`. Errors are caught and ignored; a DB failure never breaks the session.
    - On `needsPairing` with `lastError == serverKeyChanged`: set `_pin = null`, then `devices.clearServerKeyPin(...)` (errors ignored).
    - `events` are forwarded, and `volume`, `isPowerOn` and `currentApp` are updated from them.
    - `reconnect()`: from `disconnected` → `connect()`, otherwise → `notifyNetworkChanged()`.
    - `dispose()` disposes the connection and closes its own controllers. Idempotent.
  - Test helpers:
    - `ClientIdentity testIdentity()` (memoised, from `test/fixtures/*.pem`) and `IdentityStore testIdentityStore()` (an in-memory store whose `generate` returns `testIdentity()`).
    - `const List<int> testServerKey = <int>[for (var i = 0; i < 32; i++) 7]`; `final String testPin = serverKeyPinFromSha256(testServerKey)`.
    - `SavedDevice savedTv({String name = 'Living Room TV 3', String host = '192.168.0.20', String? pin /* defaults to testPin; pass null with noPin: true */, bool noPin = false, String? nickname, String? wolMac, DateTime? at})`: `serviceName` and `displayName` are both `name`, `port` is 6466, and `at` defaults to `DateTime.utc(2026, 10, 25)`.
    - `enum FakeConnect { succeed, networkError, certificateRejected, hang }`.
    - `class FakeRemoteClient implements RemoteClient`:
      - `connect()` follows its outcome. `succeed` → ready + `RemoteReady`. Errors → emit `RemoteClosed(reason)` and throw `RemoteConnectException(reason)`. `hang` → waits until `close()`.
      - Records `sentKeys` (`List<(int, KeyDirection)>`), `sentLinks` and `sentTexts`.
      - `push(RemoteEvent)`, `drop([RemoteCloseReason reason = RemoteCloseReason.remoteClosed])`, `bool closed`. `serverPublicKeySha256` comes from its factory.
    - `class FakeRemoteClients`:
      - `FakeRemoteClients({List<int> serverKey = testServerKey})`.
      - `Map<String, FakeConnect> outcomes`, keyed by host; `FakeConnect defaultOutcome = FakeConnect.succeed`.
      - `List<FakeRemoteClient> created`, and `RemoteClient create({required String host, required int port, required ClientIdentity identity})` (tear-off matches `RemoteClientFactory`).
    - `class FakeRemoteSession implements RemoteSession`:
      - Constructor params: `tvName`, `isDemo`, `pairingTarget`, and an initial state.
      - `emit(TvConnectionState)`, `push(RemoteEvent)`.
      - Records `sentKeys` and the counters `connectCalls`, `disconnectCalls`, `resumeCalls`, `networkCalls`, `reconnectCalls`, plus `bool disposed`.
      - `sendKey` throws `NotConnectedException` unless `current.status == connected`.

- [ ] **Step 1: Write the failing tests** (`tv_remote_session_test.dart`: plain `test()` with an in-memory `AppDatabase`, `Backoff(initial: const Duration(milliseconds: 1), max: const Duration(milliseconds: 1))`, a fixed `now`, and the helper `Future<void> until(RemoteSession s, ConnectionStatus st)`)

```dart
test('connects_with_the_stored_pin_and_marks_the_device_connected', () async {
  await repo.upsert(savedTv(at: DateTime.utc(2026)));
  final s = session(savedTv()); await s.connect(); await until(s, ConnectionStatus.connected);
  final d = (await repo.find('Living Room TV 3'))!;
  expect(d.lastConnectedAt, fixedNow.toUtc()); expect(d.lastHost, '192.168.0.20'); expect(d.serverKeyPin, testPin);
});
test('re_resolves_host_on_reconnect', () async {   // master test name
  clients.outcomes['192.168.0.20'] = FakeConnect.networkError;
  await repo.upsert(savedTv());
  final s = session(savedTv(), resolveHost: (name) async => name == 'Living Room TV 3' ? '192.168.0.99' : null);
  await s.connect(); await until(s, ConnectionStatus.connected);
  expect(clients.created.map((c) => c.host), ['192.168.0.20', '192.168.0.99']);
  expect((await repo.find('Living Room TV 3'))!.lastHost, '192.168.0.99');
});
test('identity_changed_clears_pin_and_reports_server_key_changed', ...) // clients = FakeRemoteClients(serverKey: List.filled(32, 9)) → state (needsPairing, serverKeyChanged); repo pin null; a later connect() creates no client
test('missing_pin_needs_pairing_without_connecting', ...)    // savedTv(noPin: true) → current.status needsPairing; connect() → clients.created isEmpty
test('certificate_rejection_needs_pairing_and_keeps_pin', ...) // outcome certificateRejected → (needsPairing, certificateRejected); repo pin == testPin
test('manual_device_is_never_re_resolved', ...)              // savedTv(name: 'manual:192.168.0.5', host: '192.168.0.5') + networkError → resolveHost never called
test('events_update_volume_power_and_current_app', ...)      // created.last.push(VolumeChanged(8, 20, false)) / PowerStateChanged(true) / CurrentAppChanged('com.netflix.ninja') → getters updated and forwarded on events
test('states_replays_current_to_new_listeners', ...)         // after connected, s.states.first → connected
test('reconnect_from_disconnected_connects_and_otherwise_notifies', ...) // disconnect() → reconnect() → connected again (2 clients)
test('commands_while_not_connected_throw_not_connected', ...)
test('dispose_is_idempotent_and_closes_the_client', ...)

// device_repository_test.dart (additions)
test('find_returns_device_or_null', ...)
test('mark_connected_updates_only_host_and_time', ...)    // nickname, wolMac, pin unchanged; host + time updated
test('clear_server_key_pin_keeps_other_fields', ...)
test('updates_on_unknown_device_are_no_ops', ...)

// identity_store_test.dart (additions)
test('transient_read_failure_is_retried_once_before_regenerating', () async {
  final storage = InMemorySecureKeyValueStore()..values.addAll({IdentityStore.certificateKey: fixture.certificatePem, IdentityStore.privateKeyKey: fixture.privateKeyPem})..failNextReads = 1;
  var n = 0; final id = await IdentityStore(storage, generate: () async { n++; return fixture2; }, readRetryDelay: Duration.zero).loadOrCreate();
  expect(n, 0); expect(id.certificatePem, fixture.certificatePem);
});
// existing regenerates_when_storage_read_throws (persistent throwOnRead) must still pass.

// server_key_pin_test.dart
test('pin_is_lower_case_hex_of_32_bytes', ...)  // [0xAB, 0x01, ...] → 'ab01…', length 64; 31 bytes → ArgumentError
test('pin_comparison_is_case_insensitive_and_null_safe', ...)

// remote_client_factory_test.dart
test('app_version_matches_pubspec', () {
  final v = RegExp(r'^version: (\S+)\+', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
  expect(kAppVersion, v);
});
test('device_info_uses_flavor_application_id', ...) // deviceInfoFor(Flavor.dev).packageName == 'com.digitallinked.atvremote.dev'; model 'Remotely'
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core`
Expected: FAIL. Compilation errors.

- [ ] **Step 3: Implement** the repository methods, the identity retry, the pin helpers, `SavedDeviceX`, `remote_client_factory.dart`, `RemoteSession`, `TvRemoteSession` and the helpers and fixtures. `FakeRemoteClient`/`FakePairingClient` use `implements`; private members of the library classes aren't part of the interface, so this compiles. Leave a comment saying so.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test test/core`
Expected: all PASS.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): remote session over TvConnection with TOFU pin and host updates" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Rulings 1, 2, 5 and 15. Learning: library classes can be faked in app tests with `implements`.

---

### Task 3.4: Session providers

**Files:**
- Create: `app/lib/core/session/session_target.dart`, `app/lib/core/session/session_providers.dart` (+ `.g.dart`)
- Modify: `app/lib/core/session/remote_client_factory.dart` (add the provider, + `.g.dart`), `app/lib/core/storage/storage_providers.dart` (`savedDevicesProvider`)
- Modify: `app/test/helpers/pump_router_app.dart`:
  - new optional `AppDatabase? database` (used instead of the fresh in-memory one; the caller closes it)
  - default overrides `identityStoreProvider.overrideWithValue(testIdentityStore())`, `remoteClientFactoryProvider.overrideWithValue(FakeRemoteClients().create)` and `hostResolverProvider.overrideWithValue((_) async => null)`
- Test: `app/test/core/session/session_providers_test.dart`

**Interfaces:**
- Consumes: Task 3.3's types; `deviceRepositoryProvider`, `identityStoreProvider` (Phase 2); `hostResolverProvider` (3.2); `flavorProvider` (Phase 2).
- Produces:
  - `sealed class SessionTarget { const SessionTarget(); }` and `final class DeviceTarget extends SessionTarget { const DeviceTarget(this.serviceName); final String serviceName; }`, with value `==`/`hashCode`.
  - `Duration? noRetry(int retryCount, Object error) => null;` (top-level, documented).
  - `@Riverpod(keepAlive: true) RemoteClientFactory remoteClientFactory(Ref ref)` builds `RemoteClient(host:, port:, identity:, deviceInfo: deviceInfoFor(ref.watch(flavorProvider)))`.
  - `@riverpod Stream<List<SavedDevice>> savedDevices(Ref ref)` → `deviceRepositoryProvider.watchAll()`.
  - `@Riverpod(keepAlive: true) class ActiveTarget extends _$ActiveTarget`:
    - `SessionTarget? build() => null` (`null` = follow the most recently connected TV).
    - `void activateDevice(String serviceName)` sets `DeviceTarget(serviceName)` **and** calls `ref.invalidate(remoteSessionProvider)`, so re-pairing the same TV rebuilds the session with its new pin.
    - `void clear()`.
    - → `activeTargetProvider`.
  - `@Riverpod(keepAlive: true, retry: noRetry) Future<RemoteSession?> remoteSession(Ref ref)`:
    1. Watch `activeTargetProvider`, `deviceRepositoryProvider`, `identityStoreProvider`, `remoteClientFactoryProvider` and `hostResolverProvider` before any await.
    2. Find the device: `DeviceTarget` → `repo.find(name)`; `null` → `repo.lastUsed()`. If there's none, return `null`.
    3. `identity = await identityStore.loadOrCreate()`. An `IdentityStoreException` propagates as the provider error.
    4. Build `TvRemoteSession`, register `ref.onDispose(session.dispose)`, call `unawaited(session.connect())` and return the session.
  - `@riverpod Stream<TvConnectionState> connectionState(Ref ref)`: awaits `remoteSessionProvider.future`. With no session it yields `const TvConnectionState(status: ConnectionStatus.disconnected)`; otherwise it yields from `session.states`.
  - `@riverpod Stream<VolumeChanged?> volume(Ref ref)`, `@riverpod Stream<bool?> powerState(Ref ref)` and `@riverpod Stream<String?> currentApp(Ref ref)`: each yields the session's cached value, then the matching events (`whereType`). `null` without a session.

- [ ] **Step 1: Write the failing tests** (`ProviderContainer.test(overrides: [appDatabaseProvider.overrideWithValue(db), identityStoreProvider.overrideWithValue(testIdentityStore()), remoteClientFactoryProvider.overrideWithValue(clients.create), hostResolverProvider.overrideWithValue((_) async => null), flavorProvider.overrideWithValue(Flavor.dev)])`)

```dart
test('session_follows_the_last_used_device_by_default', ...)  // upsert savedTv(name: 'a', at: 12:01), savedTv(name: 'b', at: 12:03) → (await c.read(remoteSessionProvider.future))!.tvName == 'b'
test('no_saved_device_gives_no_session_and_disconnected_state', ...) // session null; connectionState first value status disconnected
test('session_connects_when_created', ...)                    // connectionState emits connected; clients.created.length == 1
test('activate_device_switches_the_session_and_disposes_the_old_one', () async {
  await repo.upsert(savedTv(name: 'a')); await repo.upsert(savedTv(name: 'b', host: '192.168.0.21'));
  c.listen(remoteSessionProvider, (_, _) {});
  final first = (await c.read(remoteSessionProvider.future))!;
  c.read(activeTargetProvider.notifier).activateDevice('a');
  final second = (await c.read(remoteSessionProvider.future))!;
  expect(second.tvName, 'a'); expect(identical(first, second), isFalse);
  await pumpEventQueue(); expect(clients.created.first.closed, isTrue);   // exactly one live client
  expect(clients.created.where((x) => !x.closed), hasLength(1));
});
test('activating_the_same_device_again_rebuilds_the_session', ...) // activateDevice('a') twice → two distinct session instances
test('identity_failure_surfaces_as_error_without_retry', ...)       // IdentityStore(InMemorySecureKeyValueStore()..throwOnWrite = PlatformException(code: 'x'), generate: counting) → future throws IdentityStoreException; wait 500 ms (Riverpod's default first retry is at 200 ms) → generate called once
test('volume_power_and_current_app_follow_session_events', ...)     // push events on clients.created.last → providers' latest values
test('disposing_the_container_disposes_the_session', ...)           // c.dispose() → client closed
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/session/session_providers_test.dart`
Expected: FAIL. Compilation errors.

- [ ] **Step 3: Implement** the target, providers and factory provider. Update `pumpRouterApp`. Run build_runner, then `dart format lib test`.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS, including the Phase 2 router tests.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): session providers for the active TV" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3.5: Lifecycle, connectivity and `SessionSupervisor`

**Files:**
- Modify: `app/pubspec.yaml` (dep `connectivity_plus: 7.3.2`)
- Create: `app/lib/core/session/lifecycle_observer.dart`, `connectivity_observer.dart`, `session_signals.dart` (+ `.g.dart`), `session_supervisor.dart`, `app/test/helpers/manual_session_signals.dart`
- Modify: `app/lib/core/session/session_providers.dart`. In `remoteSession`, watch `sessionSignalsProvider` and `sessionTimingProvider` before the first await. Once the session exists, create `SessionSupervisor(session: session, signals: signals, backgroundGrace: timing.backgroundGrace, nudgeDebounce: timing.nudgeDebounce)` and register `ref.onDispose(supervisor.dispose)` **before** `ref.onDispose(session.dispose)`, so the supervisor stops first. A `null` session gets no supervisor.
- Modify: `app/test/helpers/pump_router_app.dart` (default `sessionSignalsProvider.overrideWithValue(ManualSessionSignals())`)
- Test: `app/test/core/session/session_supervisor_test.dart`, `lifecycle_observer_test.dart`, `connectivity_observer_test.dart`, plus additions to `session_providers_test.dart`

**Interfaces:**
- Consumes: `RemoteSession` (3.3), `remoteSessionProvider` (3.4).
- Produces:
  - `enum AppVisibility { foreground, background }`
  - `class LifecycleObserver`:
    - Constructor: `LifecycleObserver({WidgetsBinding? binding})`. It wraps `AppLifecycleListener(onStateChange:)`.
    - `Stream<AppVisibility> get changes` (broadcast) emits `background` on the first transition to `hidden` or `paused`, and `foreground` on `resumed` after a background. `inactive` alone emits nothing.
    - `void dispose()`.
  - `class ConnectivityObserver`:
    - Constructor: `ConnectivityObserver(Stream<List<ConnectivityResult>> source)`.
    - `Stream<void> get changes` (broadcast). The first event is the baseline. After that it emits when the result set differs from the previous one **and** contains anything other than `none`. Source errors are swallowed.
    - `void dispose()`.
  - `abstract interface class SessionSignals { Stream<AppVisibility> get visibility; Stream<void> get networkChanges; }`
  - `class PlatformSessionSignals implements SessionSignals`: `PlatformSessionSignals({LifecycleObserver? lifecycle, ConnectivityObserver? connectivity})`, whose defaults are `LifecycleObserver()` and `ConnectivityObserver(Connectivity().onConnectivityChanged)`. Plus `void dispose()`.
  - `@Riverpod(keepAlive: true) SessionSignals sessionSignals(Ref ref)` → `PlatformSessionSignals` with `ref.onDispose(dispose)`.
  - `@immutable class SessionTiming { const SessionTiming({this.backgroundGrace = const Duration(seconds: 60), this.nudgeDebounce = const Duration(milliseconds: 500)}); final Duration backgroundGrace; final Duration nudgeDebounce; }` and `@Riverpod(keepAlive: true) SessionTiming sessionTiming(Ref ref) => const SessionTiming();`. This is a test seam; production always uses the defaults.
  - `class SessionSupervisor`:
    - Constructor: `SessionSupervisor({required RemoteSession session, required SessionSignals signals, Duration backgroundGrace = const Duration(seconds: 60), Duration nudgeDebounce = const Duration(milliseconds: 500), DateTime Function() now = DateTime.now})`.
    - `void dispose()`.
  - Test helper `ManualSessionSignals implements SessionSignals` with `background()`, `foreground()` and `networkChanged()`.
- **Supervisor rules** (Ruling 9):
  1. `background` (while in the foreground): record `_backgroundSince = now()`, start the grace timer, cancel any pending nudge.
  2. Grace timer fires: `_closedInBackground = true; session.disconnect()`.
  3. `foreground` (while in the background): cancel the grace timer.
     - If `_closedInBackground`, or `now() - _backgroundSince >= backgroundGrace`, and `session.current.status != needsPairing`: run `await session.disconnect(); await session.connect();` (unawaited chain) and clear the flag.
     - Otherwise schedule a nudge.
  4. Network change: ignored in the background. In the foreground, schedule a nudge marked "network".
  5. Scheduling a nudge restarts one `nudgeDebounce` timer. When it fires, call `session.notifyNetworkChanged()` if any event in the burst was a network change, otherwise `session.notifyAppResumed()`. Exactly one call per burst.
  6. `dispose()` cancels the timers and subscriptions. Signals after dispose do nothing.

- [ ] **Step 1: Write the failing tests** (`session_supervisor_test.dart` uses `fakeAsync` with `FakeRemoteSession` and `ManualSessionSignals`. A mutable `var clock = DateTime.utc(2026);` is passed as `now: () => clock`.)

```dart
test('closes_socket_after_60s_in_background', () => fakeAsync((a) {   // master name
  signals.background(); a.elapse(const Duration(seconds: 59)); expect(s.disconnectCalls, 0);
  a.elapse(const Duration(seconds: 1)); expect(s.disconnectCalls, 1);
}));
test('returning_within_60s_keeps_the_socket', ...)      // background, 30 s, foreground, 60 s more → disconnectCalls 0; one resumeCalls after 500 ms
test('resume_triggers_reconnect', () => fakeAsync((a) { // master name
  signals.background(); clock = clock.add(const Duration(seconds: 61)); a.elapse(const Duration(seconds: 61));
  signals.foreground(); a.flushMicrotasks();
  expect(s.connectCalls, 1); expect(s.resumeCalls + s.networkCalls, 0);
}));
test('resume_after_suspension_longer_than_grace_reconnects_even_if_timer_never_fired', () => fakeAsync((a) {
  signals.background(); clock = clock.add(const Duration(minutes: 10));   // wall clock jumps, no fake time passes
  signals.foreground(); a.flushMicrotasks();
  expect((s.disconnectCalls, s.connectCalls), (1, 1));
}));
test('no_forced_reconnect_while_needs_pairing', ...)    // s.emit(needsPairing); long background → connectCalls 0
test('burst_of_resume_and_network_changes_is_coalesced_into_one_nudge', () => fakeAsync((a) {
  signals.background(); a.elapse(const Duration(seconds: 5)); signals.foreground();
  for (var i = 0; i < 3; i++) { a.elapse(const Duration(milliseconds: 150)); signals.networkChanged(); }
  a.elapse(const Duration(milliseconds: 499)); expect(s.networkCalls + s.resumeCalls, 0);
  a.elapse(const Duration(milliseconds: 1)); expect((s.networkCalls, s.resumeCalls), (1, 0));
}));
test('network_changes_in_background_are_ignored', ...)
test('dispose_cancels_pending_timers_and_ignores_later_signals', ...)

// connectivity_observer_test.dart (StreamController<List<ConnectivityResult>>)
test('first_event_is_a_baseline', ...)                  // [wifi] → no emission
test('emits_on_change_to_a_connected_network', ...)     // [wifi] then [mobile] → 1
test('ignores_none_and_duplicates', ...)                // [wifi], [none], [wifi], [wifi] → exactly 1 (none→wifi)
test('source_errors_are_swallowed', ...)                // addError → no error on changes; later change still emits

// lifecycle_observer_test.dart (testWidgets; drive tester.binding.handleAppLifecycleStateChanged
// through legal transitions: resumed→inactive→hidden→paused and back)
testWidgets('hidden_emits_background_once_and_resumed_emits_foreground', ...) // events == [background, foreground]
testWidgets('inactive_alone_emits_nothing', ...)        // resumed→inactive→resumed → []

// session_providers_test.dart (addition, real async: overrides ManualSessionSignals and
// sessionTimingProvider → SessionTiming(backgroundGrace: Duration(milliseconds: 20), nudgeDebounce: Duration(milliseconds: 5)))
test('session_disconnects_after_background_grace', ...)  // connected → signals.background() → wait 50 ms → clients.created.single.closed, state disconnected
test('foreground_after_grace_connects_again', ...)       // then signals.foreground() → connected with a second client
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/core/session`
Expected: FAIL. Compilation errors.

- [ ] **Step 3: Add the dependency**

Run: `flutter pub add connectivity_plus:7.3.2`

- [ ] **Step 4: Implement** the observers, signals, supervisor and provider wiring. Update `pumpRouterApp`. Run build_runner, then `dart format lib test`.
- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 6: Build the dev APK**

Run: `flutter build apk --debug --flavor dev -t lib/main_dev.dart`
Expected: build succeeds.

- [ ] **Step 7: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml pubspec.lock app/lib app/test
git commit -m "feat(app): background grace and debounced reconnect nudges" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Ruling 9's values. Learning: iOS suspends Dart timers, so resume logic must compare wall-clock time.

---

### Task 3.6: Status pill actions and the minimal remote screen

**Files:**
- Modify: `app/lib/app/widgets/status_pill.dart`, `app/lib/app/l10n/app_en.arb`, `app/lib/app/router.dart` (`/remote` → `RemoteScreen`)
- Create: `app/lib/features/remote/presentation/remote_screen.dart`, `key_labels.dart`, `widgets/device_switcher.dart`, `widgets/basic_controls.dart`
- Modify (tests):
  - `app/test/app/widgets/status_pill_test.dart`: the label is now `Needs pairing`.
  - `status_pill_golden_test.dart`: add a `needsPairing` + `onPairAgain` row; re-baseline.
  - `app/test/app/router_test.dart`: drop `/remote` from `every_route_renders_its_titled_screen`.
- Test: `app/test/features/remote/remote_screen_test.dart`, `remote_screen_golden_test.dart`, `app/test/features/remote/key_labels_test.dart`

**Interfaces:**
- Consumes: `remoteSessionProvider`, `connectionStateProvider`, `savedDevicesProvider`, `activeTargetProvider` (3.4); `RemoteSession` (3.3); `SavedDeviceX` (3.3); `AppKeyButton`, `Rocker`, `showAppSheet`, `showAppDialog` (Phase 2).
- Produces:
  - `StatusPill({required ConnectionStatus status, VoidCallback? onReconnect, VoidCallback? onPairAgain, super.key})`. A `TextButton` labelled `statusPairAgainAction` shows only when `status == needsPairing && onPairAgain != null`. Same layout rules as Reconnect (≥ 48 dp, inside the pill).
  - `String keyLabel(AppLocalizations l10n, int keyCode)` covers every `KeyCodes` constant; digits 7–16 → `keyNumber(n)`; anything else → `keyUnknown(code)`. Phase 4 reuses it for semantic labels.
  - `class RemoteScreen extends ConsumerStatefulWidget`:
    - **AppBar:** `title` = `DeviceSwitcher`; `actions` = `StatusPill`.
      - Status comes from `connectionStateProvider`; loading counts as `connecting`.
      - `onReconnect` → `session.reconnect()`.
      - `onPairAgain` → `context.push(AppRoutes.pair(target.serviceName), extra: target)`, where `target = session.pairingTarget`.
    - **Body:** `BasicControls`.
    - **Session states:**
      - Session `null` → a centred "No TV selected" view with a `FilledButton` "Choose a TV" → `context.go(AppRoutes.discover)`.
      - Provider error → "Couldn't prepare a secure connection" with "Try again" → `ref.invalidate(remoteSessionProvider)`.
    - **Identity changed:** when the state becomes `needsPairing` with `lastError == serverKeyChanged`, show `showAppDialog<bool>` once per session instance. Title `remoteIdentityChangedTitle`, message `remoteIdentityChangedMessage(tvName)`, actions `remoteNotNow` (false) and primary `statusPairAgainAction` (true). `true` → the same push as `onPairAgain`.
  - `class DeviceSwitcher extends StatelessWidget`:
    - Constructor: `DeviceSwitcher({required String currentName, required String? currentServiceName, required List<SavedDevice> devices, required ValueChanged<String> onSelect, required VoidCallback onAddTv})`.
    - A ≥ 48 dp `TextButton` showing the name and `Icons.expand_more`, with tooltip `remoteSwitchTv`.
    - Tapping opens `showAppSheet(title: remoteSwitchTv)`: a `ListTile` per device (label; a check icon on the current one), then "Add a TV" (`Icons.add`).
    - Selecting pops the sheet and calls `onSelect(serviceName)`, which the screen maps to `activateDevice`. "Add a TV" → `context.push(AppRoutes.discover)`.
  - `class BasicControls extends StatelessWidget`:
    - Constructor: `BasicControls({required bool enabled, required ValueChanged<int> onKey})`.
    - A D-pad cross of `AppKeyButton`s (up/left/OK/right/down; OK = `dpadCenter`), a row Back · Home · Mute, and a volume `Rocker` (label `volumeLabel`, up/down → `volumeUp`/`volumeDown`).
    - Every key's `semanticLabel` comes from `keyLabel`. `Opacity(0.4)` when not `enabled`, but taps still reach `onKey`.
    - Phase 4 replaces this widget.
  - `RemoteScreen._press(int code)`: if the status isn't `connected`, or `sendKey` throws `NotConnectedException`, show `SnackBar(remoteNotConnected)` and send nothing.
  - TV name shown: `session.isDemo ? l10n.demoTvName : session.tvName`. The `demoTvName` ARB key is added here so Task 3.7 only fills in behaviour.
- **ARB keys** (exact copy):
  - Changed: `statusNeedsPairing` → `Needs pairing`.
  - New:

    | Key | Copy |
    |---|---|
    | `statusPairAgainAction` | `Pair again` |
    | `remoteNotConnected` | `Not connected to your TV` |
    | `remoteSwitchTv` | `Switch TV` |
    | `remoteAddTv` | `Add a TV` |
    | `remoteNoTvTitle` | `No TV selected` |
    | `remoteNoTvAction` | `Choose a TV` |
    | `remoteIdentityChangedTitle` | `This TV's identity changed` |
    | `remoteIdentityChangedMessage` | `{tvName} presented a different security key than when you paired it. If the TV was reset or replaced, pair it again.` |
    | `remoteNotNow` | `Not now` |
    | `remoteSessionErrorTitle` | `Couldn't prepare a secure connection` |
    | `remoteSessionErrorBody` | `Something went wrong while loading this phone's security key.` |
    | `remoteRetry` | `Try again` |
    | `demoTvName` | `Demo TV` |
    | `volumeLabel` | `VOL` |
    | `keyNumber` | `Number {digit}` (int) |
    | `keyUnknown` | `Key {code}` (int) |

  - Key labels: `keyUp` Up, `keyDown` Down, `keyLeft` Left, `keyRight` Right, `keyOk` OK, `keyBack` Back, `keyHome` Home, `keyMenu` Menu, `keyPower` Power, `keyVolumeUp` Volume up, `keyVolumeDown` Volume down, `keyMute` Mute, `keyChannelUp` Channel up, `keyChannelDown` Channel down, `keyPlayPause` Play or pause, `keyNext` Next, `keyPrevious` Previous, `keyRewind` Rewind, `keyFastForward` Fast forward, `keyStop` Stop, `keyRed` Red, `keyGreen` Green, `keyYellow` Yellow, `keyBlue` Blue, `keyTvInput` TV input, `keySettings` Settings, `keyGuide` Guide, `keyInfo` Info, `keyCaptions` Captions, `keySearch` Search.

- [ ] **Step 1: Write the failing tests** (`remote_screen_test.dart`: `pumpRouterApp(initialLocation: AppRoutes.remote, overrides: [remoteSessionProvider.overrideWith((ref) async => fake), savedDevicesProvider.overrideWith((ref) => Stream.value([savedTv(), savedTv(name: 'Bedroom TV', host: '192.168.0.21')]))])`. `fake = FakeRemoteSession(tvName: 'Living Room TV 3', pairingTarget: savedTv().toDiscoveredTv())`. Read the router location with `final r = container.read(appRouterProvider); r.routerDelegate.currentConfiguration` (`.uri.path`, `.extra`); get the container with `ProviderScope.containerOf(t.element(find.byType(RemoteScreen)))`.)

```dart
testWidgets('status_pill_reflects_socket_state_not_saved_state', (t) async {   // master name
  fake.emit(const TvConnectionState(status: ConnectionStatus.reconnecting, attempt: 1)); await pumpRemote(t);
  expect(find.text('Reconnecting…'), findsOneWidget);   // a saved, pinned TV is not "Connected"
  fake.emit(const TvConnectionState(status: ConnectionStatus.connected)); await t.pump();
  expect(find.text('Connected'), findsOneWidget);
});
testWidgets('offline_reconnect_calls_session_reconnect', ...)   // offline → tap 'Reconnect' → fake.reconnectCalls == 1
testWidgets('needs_pairing_routes_to_pairing_screen', ...)      // needsPairing → tap 'Pair again' → path == AppRoutes.pair('Living Room TV 3'), extra == savedTv().toDiscoveredTv()
testWidgets('identity_changed_routes_to_pairing', ...)          // emit (needsPairing, serverKeyChanged) → dialog 'This TV's identity changed' → tap 'Pair again' → pair path; emitting the same state again shows no second dialog
testWidgets('identity_changed_not_now_keeps_the_remote', ...)   // 'Not now' → still RemoteScreen, pill shows 'Pair again'
testWidgets('keys_send_when_connected', ...)                    // connected → tap bySemanticsLabel('Home') → fake.sentKeys == [KeyCodes.home]; 'Volume up' → 24
testWidgets('keys_show_not_connected_snackbar_when_offline', ...) // offline → tap 'Home' → sentKeys empty, text 'Not connected to your TV'
testWidgets('device_switcher_lists_saved_tvs_and_switches', ...) // tap tooltip 'Switch TV' → 'Bedroom TV' listed → tap → container.read(activeTargetProvider) == const DeviceTarget('Bedroom TV')
testWidgets('device_switcher_add_tv_opens_discover', ...)       // 'Add a TV' → path '/discover'
testWidgets('no_tv_shows_choose_a_tv_action', ...)              // override session → null → 'No TV selected'; tap 'Choose a TV' → '/discover'
testWidgets('identity_store_failure_offers_retry', ...)         // override throws IdentityStoreException → 'Try again' visible; tap → provider re-runs (counter)
testWidgets('remote_screen_reflows_at_200_percent_text', ...)   // offline + textScale 2 → takeException() isNull

// key_labels_test.dart
test('every_key_code_has_a_specific_label', ...) // for each KeyCodes constant (list them) keyLabel != keyUnknown(code); keyLabel(l, 7) == 'Number 0'; keyLabel(l, 999) == 'Key 999'

// status_pill_test.dart (additions)
testWidgets('pair_again_button_only_when_needs_pairing_and_callback_given', ...)
testWidgets('pair_again_tap_calls_callback_and_is_48dp', ...)

// remote_screen_golden_test.dart (@Tags(['golden'])): connected FakeRemoteSession, Size(390, 844), light + dark → goldens/remote_basic_{light,dark}.png
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/remote test/app/widgets/status_pill_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the pill changes, ARB keys, `keyLabel`, `DeviceSwitcher`, `BasicControls`, `RemoteScreen` and the route. Run `flutter pub get` (regenerates l10n), then `dart format lib test`.
- [ ] **Step 4: Regenerate the goldens**

Run: `flutter test --update-goldens --tags golden test/app/widgets/status_pill_golden_test.dart test/features/remote`
Inspect `status_pill_all_states_*` (one extra row) and `remote_basic_*`.

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): remote screen with live status, device switcher and pair-again flow" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Rulings 6 and 7. Carry-over done: the status label was renamed.

---

### Task 3.7: Demo mode

**Files:**
- Create: `app/lib/features/demo/demo_remote_session.dart`, `app/lib/features/demo/demo_providers.dart` (+ `.g.dart`), `app/lib/features/demo/presentation/demo_badge.dart`, `app/lib/features/demo/presentation/tv_preview_card.dart`, `app/lib/app/app_shell.dart`
- Modify:
  - `app/lib/core/session/session_target.dart` (`DemoTarget`) and `session_providers.dart` (`ActiveTarget.startDemo`; `remoteSession` builds `DemoRemoteSession` for `DemoTarget`).
  - `app/lib/app/app.dart` (`builder: buildAppShell`) and `app/test/helpers/pump_router_app.dart` (the same `builder`).
  - `app/lib/features/remote/presentation/remote_screen.dart` (shows `TvPreviewCard` above `BasicControls` when `session.isDemo`).
  - `app/lib/features/onboarding/presentation/onboarding_screen.dart` ("Try demo"), `app_en.arb`.
- Test: `app/test/features/demo/demo_remote_session_test.dart`, `app/test/features/demo/demo_mode_test.dart`

**Interfaces:**
- Consumes: `RemoteSession` (3.3), `ActiveTarget`/`remoteSessionProvider`/`volumeProvider`/`powerStateProvider` (3.4), `RemoteScreen` and `keyLabel` (3.6), `appRouterProvider`, `showAppDialog`.
- Produces:
  - `final class DemoTarget extends SessionTarget { const DemoTarget(); }`, with value `==`.
  - `ActiveTarget.startDemo()` sets `const DemoTarget()`.
  - `sealed class DemoAction` with `DemoKeyPressed(int keyCode, KeyDirection direction)`, `DemoAppOpened(String link)` and `DemoTextTyped(String text)`.
  - `class DemoRemoteSession implements RemoteSession`. Constructor: `DemoRemoteSession({Duration connectDelay = const Duration(milliseconds: 600)})`.
    - `isDemo` is true, `tvName` is `''` and `pairingTarget` is `null`.
    - `connect()` goes `connecting` → (after `connectDelay`) `connected`, then emits `PowerStateChanged(true)` and `VolumeChanged(8, 20, false)`.
    - `sendKey`:
      - records a `DemoKeyPressed`
      - `volumeUp`/`volumeDown` change the level by 1 within 0..20 and emit `VolumeChanged`
      - `mute` toggles muted
      - `power` toggles power and emits `PowerStateChanged`
    - `launchAppLink` records `DemoAppOpened`; a `market://launch?id=<pkg>` link sets `currentApp = pkg` and emits `CurrentAppChanged`.
    - `sendText` records `DemoTextTyped`.
    - `disconnect()` → `disconnected`. `notify*` do nothing (it never goes offline). `reconnect()` → `connect()` when disconnected.
    - Commands throw `NotConnectedException` unless connected, like the real session.
    - `Stream<DemoAction> get actions` (broadcast) and `DemoAction? get lastAction`.
  - In `demo_providers.dart`:
    - `@riverpod bool isDemoActive(Ref ref) => ref.watch(activeTargetProvider) is DemoTarget;`
    - `@riverpod Stream<DemoAction?> demoActivity(Ref ref)` yields `lastAction`, then `actions`, from the session when it is a `DemoRemoteSession`, otherwise `null`. This is the only place that type-checks the session (Ruling 1).
  - `Future<void> leaveDemo(WidgetRef ref)` → `activeTarget.clear()`, then `ref.read(appRouterProvider).go(AppRoutes.discover)`.
  - `class DemoBadgeOverlay extends ConsumerWidget { const DemoBadgeOverlay({required Widget child}); }`:
    - When `isDemoActiveProvider` is true, it shows a 48 dp strip above `child`, inside the top safe area, on `surfaceRaised`: label `demoBadgeLabel`, plus a `TextButton(demoLeaveAction)`. The `child` gets `MediaQuery.removePadding(removeTop: true)`.
    - The button opens `showAppDialog<bool>` with the router's `navigatorKey.currentContext`, because the builder sits above the Navigator. Actions: `demoStay` / primary `demoLeaveConfirm`. Confirm → `leaveDemo`.
    - Semantics: the strip is a container labelled `demoBadgeLabel`.
  - `Widget buildAppShell(BuildContext context, Widget? child) => DemoBadgeOverlay(child: child ?? const SizedBox.shrink());`
  - `class TvPreviewCard extends ConsumerWidget`: a `surface` card with radius 16 and an `outline` border.
    - Title `tvPreviewTitle`.
    - Last action from `demoActivityProvider`:
      - `null` → `tvPreviewIdle`
      - key `short` → `tvPreviewPressed(keyLabel)`, `startLong` → `tvPreviewHolding`, `endLong` → `tvPreviewReleased`
      - `DemoAppOpened` → `tvPreviewOpened(link)`, `DemoTextTyped` → `tvPreviewTyped(text)`
    - A status line from `powerStateProvider`/`volumeProvider`: `tvPreviewScreenOn|Off` · `tvPreviewVolume(level, max)`, or `tvPreviewMuted` when muted.
    - The text is a live region.
  - Onboarding: a `TextButton(onboardingTryDemo)` under "Get started" → `setOnboardingComplete(true)`, then `startDemo()`, then `context.go(AppRoutes.remote)`.
- **ARB keys** (exact copy):

  | Key | Copy |
  |---|---|
  | `demoBadgeLabel` | `Demo mode` |
  | `demoLeaveAction` | `Leave` |
  | `demoLeaveTitle` | `Leave demo?` |
  | `demoLeaveMessage` | `You'll go back to the list of TVs.` |
  | `demoLeaveConfirm` | `Leave demo` |
  | `demoStay` | `Stay` |
  | `tvPreviewTitle` | `TV preview` |
  | `tvPreviewIdle` | `Press a button to see what the TV would do.` |
  | `tvPreviewPressed` | `Pressed {key}` |
  | `tvPreviewHolding` | `Holding {key}` |
  | `tvPreviewReleased` | `Released {key}` |
  | `tvPreviewOpened` | `Opened {link}` |
  | `tvPreviewTyped` | `Typed "{text}"` |
  | `tvPreviewScreenOn` | `Screen on` |
  | `tvPreviewScreenOff` | `Screen off` |
  | `tvPreviewVolume` | `Volume {level} of {max}` (ints) |
  | `tvPreviewMuted` | `Muted` |
  | `onboardingTryDemo` | `Try demo` |

- [ ] **Step 1: Write the failing tests**

```dart
// demo_remote_session_test.dart (fakeAsync)
test('connects_after_the_delay_and_reports_tv_state', ...) // connecting → (600 ms) connected; volume == VolumeChanged(8, 20, false); isPowerOn true
test('volume_keys_change_the_simulated_volume_within_bounds', ...) // 15× volumeUp → level 20; volumeDown → 19; mute → muted true
test('power_key_toggles_power_state', ...)
test('launch_app_link_sets_current_app', ...)              // 'market://launch?id=com.netflix.ninja' → currentApp 'com.netflix.ninja'; lastAction DemoAppOpened
test('commands_throw_until_connected', ...)
test('disconnect_and_reconnect_cycle', ...)

// demo_mode_test.dart (pumpRouterApp)
testWidgets('demo_mode_shows_pressed_keys_in_preview', (t) async {   // master name
  await pumpRouterApp(t, initialLocation: AppRoutes.onboarding);
  await t.tap(find.text('Try demo')); await t.pump(const Duration(milliseconds: 700)); await t.pumpAndSettle();
  expect(find.text('TV preview'), findsOneWidget); expect(find.text('Connected'), findsOneWidget);
  await t.tap(find.bySemanticsLabel('Home')); await t.pump();
  expect(find.text('Pressed Home'), findsOneWidget);
  await t.tap(find.bySemanticsLabel('Volume up')); await t.pump();
  expect(find.textContaining('Volume 9 of 20'), findsOneWidget);
});
testWidgets('demo_badge_visible_everywhere', ...)  // after Try demo: for each of remote, apps, settings, devices, discover (router.go) → find.text('Demo mode') findsOneWidget
testWidgets('leave_demo_returns_to_discover_and_hides_badge', ...) // tap 'Leave' → 'Leave demo' → title 'Choose your TV', 'Demo mode' findsNothing, activeTarget null
testWidgets('stay_keeps_demo', ...)
testWidgets('real_session_shows_no_badge_or_preview', ...) // FakeRemoteSession(isDemo: false) at /remote → no 'Demo mode', no 'TV preview'
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/demo`
Expected: FAIL.

- [ ] **Step 3: Implement** the demo session, providers, badge, shell builder, preview card, onboarding button and ARB. Run build_runner, `flutter pub get`, then `dart format lib test`.
- [ ] **Step 4: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS. The Phase 2 `app_test.dart` still passes with the shell builder.

- [ ] **Step 5: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): demo mode with simulated TV, badge and TV preview" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3.8: Discovery screen, manual IP, legacy help, troubleshooting

**Files:**
- Create: `app/lib/features/discovery/application/discovery_controller.dart` (+ `.g.dart`), `presentation/manual_ip_sheet.dart`, `presentation/widgets/tv_list_tile.dart`, `presentation/widgets/legacy_service_sheet.dart`, `presentation/widgets/troubleshooting_sheet.dart`
- Modify:
  - `app/lib/features/discovery/presentation/discovery_screen.dart` (becomes a `ConsumerWidget`), `widgets/discovery_empty_state.dart`, `app_en.arb`.
  - `app/lib/bootstrap.dart`: `buildRootWidget` gets `@visibleForTesting List<Override> overrides = const []`, appended to the container's overrides.
  - `app/test/app/app_test.dart`: pass `overrides: [tvDiscoveryFactoryProvider.overrideWithValue(FakeTvDiscoveries().create)]`; `app_opens_discover_after_onboarding` now expects `Choose your TV`.
  - `app/test/features/discovery/discovery_screen_test.dart` and `discovery_screen_golden_test.dart`: replace the `discovery_empty_*` goldens with `discovery_found_*` and `discovery_troubleshooting_*`, and delete the two old PNGs.
- Test: `app/test/features/discovery/discovery_controller_test.dart`, `discovery_screen_test.dart`, `manual_ip_sheet_test.dart`, `discovery_screen_golden_test.dart`

**Interfaces:**
- Consumes: `tvDiscoveryFactoryProvider` (3.2), `parseIpv4`/`manualTv` (3.2), `savedDevicesProvider`, `ActiveTarget.activateDevice`/`startDemo` (3.4, 3.7), `showAppSheet`, `AppRoutes`.
- Produces:
  - `const discoveryEmptyTimeout = Duration(seconds: 10);`
  - `@immutable class DiscoveryState`: `List<DiscoveredTv> tvs`, `bool showTroubleshooting`, `bool failed`, with value `==`.
  - `@riverpod class DiscoveryController extends _$DiscoveryController` (autoDispose):
    - `DiscoveryState build()` creates a discovery from `tvDiscoveryFactoryProvider`, listens to `watch()`, and starts a `discoveryEmptyTimeout` timer. `ref.onDispose` cancels the timer and the subscription and calls `stop()`.
    - `tvs` are sorted by `displayName.toLowerCase()`, then by `serviceName`.
    - `showTroubleshooting` = (timer elapsed && `tvs.isEmpty`) || `failed`. A stream error sets `failed`.
    - `void rescan()` → `ref.invalidateSelf()`.
  - `DiscoveryScreen`:
    - `AppBar(discoverTitle)`.
    - Body:
      - Not failed, no TVs, before the timeout → `CircularProgressIndicator` + `discoverSearching`.
      - TVs → a list of `TvListTile`.
      - `showTroubleshooting` with no TVs → `DiscoveryEmptyState`: `discoverEmptyTitle`/`discoverEmptyBody`, or `discoverErrorTitle`/`discoverErrorBody` when failed; then `FilledButton(discoverScanAgain)` → `rescan()` and `TextButton(discoverTroubleshooting)` → `showTroubleshootingSheet`.
    - A bottom action row is always visible: `TextButton(discoverEnterIp)` → `showManualIpSheet` and `TextButton(discoverTryDemo)` → `startDemo()` + `context.go(AppRoutes.remote)`.
  - `class TvListTile extends StatelessWidget`:
    - Constructor: `TvListTile({required DiscoveredTv tv, required bool isPaired, required VoidCallback onTap})`.
    - `Icons.tv` leading, `displayName` title, `host` subtitle, ≥ 56 dp tall.
    - Trailing text: `discoverUpdateNeeded` for legacy TVs, `discoverPaired` for paired ones.
  - Tap rules:
    - Legacy → `showLegacyServiceSheet(context, tvName)`.
    - A saved device with a non-null pin (`isPaired`) → `activateDevice(serviceName)` + `context.go(AppRoutes.remote)`.
    - Otherwise → `context.push(AppRoutes.pair(tv.serviceName), extra: tv)`.
    - `isPaired` is computed from `savedDevicesProvider`; an error or loading state counts as not paired.
  - `Future<DiscoveredTv?> showManualIpSheet(BuildContext context)`:
    - An `AppSheet(manualIpTitle)` with a `TextField` (label `manualIpLabel`, hint `manualIpHint`, helper `manualIpHelp`, `keyboardType: TextInputType.numberWithOptions(decimal: true)`, autofocus, `textInputAction: done`) and `FilledButton(manualIpContinue)`.
    - Submit runs `parseIpv4`. `null` → `errorText: manualIpError`, and the sheet stays open. Otherwise it pops `manualTv(ip)`, and the caller pushes the pair route with it as `extra`.
  - `Future<void> showLegacyServiceSheet(BuildContext context, String tvName)` shows `legacyBody(tvName)` and a `FilledButton(discoverScanAgain)` that pops.
  - `Future<void> showTroubleshootingSheet(BuildContext context)`: an `AppSheet(troubleshootTitle)` with numbered steps:
    1. `troubleshootSameWifi`
    2. `troubleshootTvOn`
    3. `troubleshootRemoteService`
    4. `troubleshootLocalNetwork` (only when `defaultTargetPlatform == TargetPlatform.iOS`)
    5. `troubleshootRestart`
    6. `troubleshootManualIp`

    Pairing (3.9) reuses it.
- **ARB keys** (exact copy; `discoverEmptyTitle`/`discoverEmptyBody` stay):

  | Key | Copy |
  |---|---|
  | `discoverSearching` | `Looking for TVs on this Wi-Fi…` |
  | `discoverScanAgain` | `Scan again` |
  | `discoverEnterIp` | `Enter IP address` |
  | `discoverTryDemo` | `Try demo` |
  | `discoverTroubleshooting` | `Troubleshooting` |
  | `discoverPaired` | `Paired` |
  | `discoverUpdateNeeded` | `Update needed` |
  | `discoverErrorTitle` | `Couldn't search for TVs` |
  | `discoverErrorBody` | `Check that Wi-Fi is on, then scan again.` |
  | `troubleshootTitle` | `Can't find your TV?` |
  | `troubleshootSameWifi` | `Connect your phone and TV to the same Wi-Fi network (not a guest network).` |
  | `troubleshootTvOn` | `Turn the TV on. Some TVs can't be found while in standby.` |
  | `troubleshootRemoteService` | `On the TV, make sure "Android TV Remote Service" is installed and up to date in the Play Store.` |
  | `troubleshootLocalNetwork` | `On iPhone, allow Local Network access for this app in Settings → Privacy & Security → Local Network.` |
  | `troubleshootRestart` | `Still nothing? Restart the TV and your router, then scan again.` |
  | `troubleshootManualIp` | `You can also enter the TV's IP address. Find it on the TV under Settings → Network & Internet.` |
  | `legacyTitle` | `Update needed on this TV` |
  | `legacyBody` | `{tvName} uses an older remote service. On the TV, open the Play Store, search for "Android TV Remote Service", update it, then scan again.` |
  | `manualIpTitle` | `Enter IP address` |
  | `manualIpLabel` | `TV IP address` |
  | `manualIpHint` | `192.168.1.20` |
  | `manualIpHelp` | `Find it on the TV under Settings → Network & Internet → your network.` |
  | `manualIpError` | `Enter an address like 192.168.1.20` |
  | `manualIpContinue` | `Continue` |

- [ ] **Step 1: Write the failing tests** (`FakeTvDiscoveries` overrides `tvDiscoveryFactoryProvider`; `tv(name, {host, legacy})` builds a `DiscoveredTv`)

```dart
// discovery_controller_test.dart (ProviderContainer.test + fakeAsync)
test('sorts_tvs_by_display_name_case_insensitively', ...)   // emit [b, 'A', c] → ['A', 'b', 'c']
test('troubleshooting_after_10s_without_tvs', ...)          // 9.9 s → false; 10 s → true
test('no_troubleshooting_once_a_tv_is_found', ...)
test('start_failure_sets_failed_and_troubleshooting', ...)  // fail(NsdError…) → failed true
test('rescan_restarts_discovery_and_the_timer', ...)        // rescan → created.length 2, first.stopped true, showTroubleshooting false until 10 s more
test('dispose_stops_discovery', ...)

// discovery_screen_test.dart (pumpRouterApp('/discover', overrides: [tvDiscoveryFactoryProvider…]))
testWidgets('shows_found_tvs_sorted_by_name', ...)          // master name; ListTile titles in order
testWidgets('legacy_tv_shows_update_service_help', ...)     // master name; 'Update needed' trailing; tap → 'Update needed on this TV' sheet; no navigation
testWidgets('empty_state_after_10s_shows_troubleshooting', (t) async {   // master name
  await pumpDiscover(t); expect(find.text('Looking for TVs on this Wi-Fi…'), findsOneWidget);
  await t.pump(const Duration(seconds: 10)); await t.pump();
  expect(find.text('No TVs found yet'), findsOneWidget); expect(find.text('Scan again'), findsOneWidget);
  await t.tap(find.text('Troubleshooting')); await t.pumpAndSettle();
  expect(find.textContaining('same Wi-Fi network'), findsOneWidget);
  expect(find.textContaining('Android TV Remote Service'), findsOneWidget);
  expect(find.textContaining('Turn the TV on'), findsOneWidget);
});
testWidgets('tapping_a_tv_opens_pairing_with_the_tv_as_extra', ...)   // path AppRoutes.pair(name), extra == tv
testWidgets('tapping_a_paired_tv_opens_the_remote', ...)              // seed db with savedTv(name) → tap → '/remote', activeTarget DeviceTarget(name)
testWidgets('discovery_error_offers_scan_again', ...)                 // fail → 'Couldn't search for TVs'; tap 'Scan again' → second discovery created
testWidgets('try_demo_starts_demo_and_opens_remote', ...)             // tap 'Try demo' → '/remote' and 'Demo mode'
testWidgets('discovery_screen_reflows_at_200_percent_text', ...)      // troubleshooting state + list state at textScale 2 → no exception (replaces the Phase 2 test)

// manual_ip_sheet_test.dart
testWidgets('manual_ip_validates_ipv4', (t) async {         // master name
  // open the sheet from /discover via 'Enter IP address'
  await t.enterText(find.byType(TextField), '192.168.1.300'); await t.tap(find.text('Continue')); await t.pump();
  expect(find.text('Enter an address like 192.168.1.20'), findsOneWidget);
  await t.enterText(find.byType(TextField), ' 192.168.1.30 '); await t.tap(find.text('Continue')); await t.pumpAndSettle();
  // router path == AppRoutes.pair('manual:192.168.1.30'), extra == manualTv('192.168.1.30')
});

// discovery_screen_golden_test.dart (@Tags(['golden'])), Size(390, 844), light + dark:
//   discovery_found_{b}: two TVs (one legacy) → goldens/discovery_found_{light,dark}.png
//   discovery_troubleshooting_{b}: after 10 s → goldens/discovery_troubleshooting_{light,dark}.png
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/discovery test/app/app_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the controller, screen, sheets, tile, ARB and the `buildRootWidget` overrides. Run build_runner, `flutter pub get`, then `dart format lib test`.
- [ ] **Step 4: Regenerate the goldens**

Delete `test/features/discovery/goldens/discovery_empty_*.png`. Then run `flutter test --update-goldens --tags golden test/features/discovery` and inspect the four new PNGs.

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add -A app/lib app/test
git commit -m "feat(app): discovery screen with manual IP, legacy help and troubleshooting" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: decision for Rulings 8 and 11.

---

### Task 3.9: Pairing controller and screen

**Files:**
- Create:
  - `app/lib/features/pairing/domain/pairing_code.dart`, `application/pairing_state.dart`, `application/pairing_controller.dart` (+ `.g.dart`)
  - `data/pairing_providers.dart` (+ `.g.dart`), `presentation/pairing_screen.dart`, `presentation/widgets/pairing_code_field.dart`
  - `app/test/helpers/fake_pairing_client.dart`
- Modify:
  - `app/lib/app/router.dart`: `/pair/:serviceName` → `PairingScreen(serviceName: state.pathParameters['serviceName']!, tv: state.extra is DiscoveredTv ? state.extra! as DiscoveredTv : null)`.
  - `app_en.arb`.
  - `app/test/helpers/pump_router_app.dart`: default `pairingClientFactoryProvider.overrideWithValue(FakePairingClients().create)`.
  - `app/test/app/router_test.dart`: `pair_route_round_trips_service_names` now reads `t.widget<PairingScreen>(...).serviceName`.
- Test: `app/test/features/pairing/pairing_code_test.dart`, `pairing_controller_test.dart`, `pairing_screen_test.dart`, `pairing_screen_golden_test.dart`

**Interfaces:**
- Consumes:
  - `PairingClient` (`start`, `submitCode`, `close`, `serverPublicKeySha256`), `PairingException`, `PairingFailure`, `DiscoveredTv`.
  - `identityStoreProvider`, `IdentityStoreException`, `deviceRepositoryProvider` (`find`, `upsert`), `serverKeyPinFromSha256`, `SavedDeviceX.toDiscoveredTv`, `isManualServiceName`/`manualTv`, `hostResolverProvider`.
  - `ActiveTarget.activateDevice`, `showTroubleshootingSheet`, `AppRoutes`.
- Produces:
  - `String normalizePairingCode(String raw)` removes every character outside `[0-9A-Fa-f]`, upper-cases, and keeps at most 6 characters. `bool isCompletePairingCode(String code)` is true for exactly 6 upper-case hex characters.
  - `class PairingCodeFormatter extends TextInputFormatter` applies `normalizePairingCode` and puts the caret at the end.
  - Constants: `const pairingCodeLifetime = Duration(seconds: 60);` and `const pairingClientName = kRemoteClientName;`
  - `typedef PairingClientFactory = PairingClient Function({required String host, required ClientIdentity identity});`
  - `@Riverpod(keepAlive: true) PairingClientFactory pairingClientFactory(Ref ref)` → `({required host, required identity}) => PairingClient(host: host, identity: identity)`.
  - `@Riverpod(retry: noRetry) Future<DiscoveredTv?> pairingTarget(Ref ref, String serviceName)` tries, in order:
    1. the saved device → `toDiscoveredTv()`
    2. a manual name → `manualTv(ip)`, when the part after the prefix passes `parseIpv4`
    3. `hostResolverProvider` → `DiscoveredTv(serviceName: name, displayName: name.trim(), host: host, port: 6466, isLegacyService: false)`
    4. otherwise `null`.
  - `enum PairingErrorKind { cantReachTv, tvDidNotRespond, codeRejectedByTv, pairingError, identityUnavailable, saveFailed }`
  - `sealed class PairingState`:
    - `PairingStarting`
    - `PairingWaitingForCode({required int secondsLeft, bool codeMismatch = false})`
    - `PairingVerifying`
    - `PairingCodeExpired`
    - `PairingSucceeded(SavedDevice device)`
    - `PairingFailed(PairingErrorKind kind)`

    All have value `==`.
  - `@riverpod class PairingController extends _$PairingController` (autoDispose family):
    - `PairingState build(DiscoveredTv tv)`: returns `PairingStarting`, schedules `_start()`, and registers `ref.onDispose` (close the client, cancel the timer).
    - `Future<void> submit(String rawCode)`.
    - `Future<void> restart()`.
  - **Controller rules:**
    - `_start`:
      1. `identity = await identityStore.loadOrCreate()`. `IdentityStoreException` → `failed(identityUnavailable)`.
      2. `client = factory(host: tv.host, identity: identity)`, then `await client.start(clientName: pairingClientName)`.
      3. Then `waitingForCode(secondsLeft: 60)` with a 1 s periodic timer. At 0, if not verifying: close the client → `codeExpired`.
      4. A `PairingException` maps by reason: `connectionFailed` → `cantReachTv`, `timeout` → `tvDidNotRespond`, `badSecret` → `codeRejectedByTv`, `protocolError` (and an unexpected `invalidCode`) → `pairingError`.
      5. Check `ref.mounted` after every await.
    - `submit`:
      1. `code = normalizePairingCode(raw)`. Ignore it unless the state is `waitingForCode` and the code is complete.
      2. Set `verifying`, then `await client.submitCode(code)`.
      3. `invalidCode` → `waitingForCode(secondsLeft: <current>, codeMismatch: true)` on the **same** client.
      4. Other failures → `failed(kind)`.
      5. Success:
         - `existing = await repo.find(tv.serviceName)`.
         - `upsert(SavedDevice(serviceName, displayName: tv.displayName, lastHost: tv.host, port: tv.port, nickname: existing?.nickname, wolMac: existing?.wolMac, serverKeyPin: serverKeyPinFromSha256(client.serverPublicKeySha256!), lastConnectedAt: now.toUtc()))`. A repo error → `failed(saveFailed)`.
         - Then `activeTarget.activateDevice(tv.serviceName)` → `PairingSucceeded(device)`.
    - `restart`: close the current client, cancel the timer, set `PairingStarting`, run `_start()`. This is "Get a new code" and "Try again".
  - `class PairingScreen extends ConsumerWidget`:
    - Constructor: `PairingScreen({required String serviceName, DiscoveredTv? tv, super.key})`. The AppBar is `pageTitlePair`.
    - `tv == null` → watch `pairingTargetProvider(serviceName)`: loading → spinner; `null` or error → `pairNotFoundTitle`/`pairNotFoundBody` with `FilledButton(routeNotFoundAction)` → `context.go(AppRoutes.discover)`.
    - Otherwise it renders the controller state:
      - `starting` → spinner + `pairStarting(tvName)`.
      - `waitingForCode`:
        - `pairEnterCode(tvName)`, then `PairingCodeField`, then `pairExpiresIn(secondsLeft)`, then `TextButton.icon(Icons.content_paste, pairPaste)`.
        - Paste reads `Clipboard.getData(Clipboard.kTextPlain)` and normalises it. Complete → fill the field and `submit`; otherwise `SnackBar(pairNothingToPaste)`.
        - `codeMismatch` → the field shows `errorText: pairCodeMismatch` and is cleared.
      - `verifying` → `pairVerifying` with the field disabled.
      - `codeExpired` → `pairExpiredTitle`/`pairExpiredBody` + `FilledButton(pairNewCode)` → `restart`.
      - `failed(kind)`:

        | Kind | Title / body | Actions |
        |---|---|---|
        | `cantReachTv` | `pairCantReachTitle(tvName)` / `pairCantReachBody` | `pairTryAgain` + `pairTroubleshooting` (opens `showTroubleshootingSheet`) |
        | `tvDidNotRespond` | `pairNoResponseTitle(tvName)` / `pairCantReachBody` | `pairTryAgain` + `pairTroubleshooting` |
        | `codeRejectedByTv` | `pairRejectedTitle` / `pairRejectedBody` | `pairNewCode` |
        | `pairingError` | `pairErrorTitle` / `pairErrorBody` | `pairTryAgain` |
        | `identityUnavailable` | `pairIdentityTitle` / `pairErrorBody` | `pairTryAgain` |
        | `saveFailed` | `pairSaveFailedTitle` / `pairErrorBody` | `pairTryAgain` |

        Every action calls `restart`, except Troubleshooting.
      - `ref.listen` on the controller: `PairingSucceeded` → `context.go(AppRoutes.remote)`.
  - `class PairingCodeField extends StatefulWidget`:
    - Constructor: `PairingCodeField({required ValueChanged<String> onCompleted, required bool enabled, String? errorText, super.key})`.
    - One `TextField`: autofocus, `PairingCodeFormatter`, `textCapitalization: characters`, `keyboardType: TextInputType.visiblePassword` (letters and digits), `autocorrect: false`, `enableSuggestions: false`, monospace `displaySmall` with letter spacing, `labelText: pairCodeLabel`.
    - When the text becomes complete, it calls `onCompleted` once per distinct value.
    - Exposes `static void clear(BuildContext)` (or uses a `GlobalKey<PairingCodeFieldState>` with `clear()`) for the mismatch case.
  - Test helpers:
    - `FakePairingClient implements PairingClient` with `validCode = 'AB12CD'`, `serverKey = testServerKey`, `PairingException? startError`, `PairingException? submitError` and `Completer<void>? holdStart`.
      - Records `submittedCodes` and `bool closed`.
      - `submitCode` throws `PairingException(PairingFailure.invalidCode)` for any code other than `validCode` (compared exactly, so normalisation is tested).
      - `serverPublicKeySha256` is `null` until `start` completes.
    - `FakePairingClients`: `List<FakePairingClient> created`, `void Function(FakePairingClient)? onCreate`, and `PairingClient create({required String host, required ClientIdentity identity})`.
- **ARB keys** (exact copy):

  | Key | Copy |
  |---|---|
  | `pairStarting` | `Connecting to {tvName}…` |
  | `pairEnterCode` | `Enter the code shown on {tvName}` |
  | `pairCodeLabel` | `Pairing code` |
  | `pairExpiresIn` | `Code expires in {seconds} s` (int) |
  | `pairPaste` | `Paste code` |
  | `pairNothingToPaste` | `There's no 6-character code on the clipboard.` |
  | `pairCodeMismatch` | `That code doesn't match. Check the code on your TV and enter it again.` |
  | `pairVerifying` | `Checking the code…` |
  | `pairExpiredTitle` | `The code expired` |
  | `pairExpiredBody` | `Ask the TV for a new code and enter it within 60 seconds.` |
  | `pairNewCode` | `Get a new code` |
  | `pairTryAgain` | `Try again` |
  | `pairTroubleshooting` | `Troubleshooting` |
  | `pairCantReachTitle` | `Can't reach {tvName}` |
  | `pairCantReachBody` | `Make sure the TV is on and on the same Wi-Fi network as your phone.` |
  | `pairNoResponseTitle` | `{tvName} didn't respond` |
  | `pairRejectedTitle` | `The TV didn't accept the code` |
  | `pairRejectedBody` | `Get a new code and enter it exactly as shown.` |
  | `pairErrorTitle` | `Pairing didn't work` |
  | `pairErrorBody` | `Something unexpected happened. Try again.` |
  | `pairIdentityTitle` | `Couldn't prepare a secure connection` |
  | `pairSaveFailedTitle` | `Couldn't save this TV` |
  | `pairNotFoundTitle` | `We couldn't find this TV` |
  | `pairNotFoundBody` | `Go back to the list of TVs and choose it again.` |

- [ ] **Step 1: Write the failing tests**

```dart
// pairing_code_test.dart
test('normalises_case_whitespace_and_separators', () {
  for (final raw in [' ab12cd\n', 'AB-12-CD', 'ab 12 cd', 'aB12cD9F']) expect(normalizePairingCode(raw), 'AB12CD');
  expect(normalizePairingCode('zz12'), '12'); expect(isCompletePairingCode('AB12CD'), isTrue); expect(isCompletePairingCode('AB12C'), isFalse);
});

// pairing_controller_test.dart (ProviderContainer.test with in-memory db, testIdentityStore, FakePairingClients;
// keep alive with c.listen(pairingControllerProvider(tv), ...); fakeAsync where timers matter)
test('code_is_trimmed_and_upper_cased_before_submit', ...)   // submit(' ab12cd\n') → created.single.submittedCodes == ['AB12CD']
test('incomplete_or_non_hex_codes_are_not_submitted', ...)   // submit('ab12') and submit('zzzzzz') → submittedCodes isEmpty
test('bad_checksum_keeps_the_same_client_and_flags_mismatch', ...) // submit('000000') → WaitingForCode(codeMismatch: true); created.length 1; closed false
test('success_saves_pin_and_activates_the_tv', ...)          // repo.find(tv).serverKeyPin == testPin; activeTarget == DeviceTarget(tv.serviceName); state PairingSucceeded
test('re_pairing_keeps_nickname_and_wol_mac', ...)           // seed savedTv(nickname: 'Lounge', wolMac: 'AA:BB:CC:DD:EE:FF', pin: 'old') → after success both kept, pin == testPin
test('code_expires_after_60s_and_closes_the_client', ...)    // fakeAsync: 59 s → WaitingForCode(secondsLeft: 1); 60 s → PairingCodeExpired; closed true
test('restart_starts_a_fresh_client', ...)                   // after expiry → restart() → created.length 2, waiting again
test('maps_pairing_failures_to_error_kinds', ...)            // startError connectionFailed/timeout/protocolError; submitError badSecret → kinds
test('identity_failure_offers_try_again', ...)               // store throwOnWrite → PairingFailed(identityUnavailable)
test('save_failure_offers_try_again', ...)                   // repo whose upsert throws → PairingFailed(saveFailed)
test('leaving_during_start_does_not_update_state_after_dispose', ...) // holdStart pending → close listener subscription (autoDispose) → complete hold → no error; client closed

// pairing_screen_test.dart (pumpRouterApp(initialLocation: AppRoutes.pair(tv.serviceName)) with the router's extra set by
// first pumping '/discover' and calling router.push(AppRoutes.pair(name), extra: tv), or by overriding pairingTargetProvider)
testWidgets('six_char_field_accepts_hex_only_and_autosubmits', (t) async {   // master name
  await t.enterText(find.byType(TextField), 'zz12ab'); await t.pump();
  expect(find.text('12AB'), findsOneWidget); expect(fakes.created.single.submittedCodes, isEmpty);
  await t.enterText(find.byType(TextField), '12ab9f'); await t.pump();
  expect(fakes.created.single.submittedCodes, ['12AB9F']);
});
testWidgets('paste_code_from_clipboard', ...)        // master name; mock SystemChannels.platform 'Clipboard.getData' → {'text': 'ab-12-cd'} → tap 'Paste code' → submittedCodes ['AB12CD']
testWidgets('pasted_code_with_spaces_and_dashes_is_normalised', ...) // clipboard ' ab 12 cd ' → ['AB12CD']; clipboard 'hello' → snackbar 'There's no 6-character code on the clipboard.'
testWidgets('bad_checksum_shows_inline_error_without_network_call', ...) // master name; enter '000000' → 'That code doesn't match…' visible, field empty, created.length 1, closed false; then 'AB12CD' → '/remote'
testWidgets('timeout_offers_new_code', ...)          // master name; pump 60 s → 'The code expired'; tap 'Get a new code' → created.length 2, 'Enter the code shown on …'
testWidgets('success_saves_device_and_navigates_to_remote', ...) // master name; enter 'AB12CD' → path '/remote'; repo has the TV with testPin
testWidgets('tv_rejecting_code_offers_new_code', ...)
testWidgets('unreachable_tv_offers_retry_and_troubleshooting', ...) // startError connectionFailed → 'Can't reach …', 'Try again', 'Troubleshooting' (opens sheet)
testWidgets('leaving_the_screen_closes_the_pairing_client', ...)  // while waiting, router.pop() → created.single.closed
testWidgets('missing_extra_uses_the_saved_device', ...)           // no extra, seeded savedTv → pairs with host '192.168.0.20'
testWidgets('unknown_tv_without_extra_offers_back_to_tvs', ...)   // no extra, nothing saved, resolver null → 'We couldn't find this TV'; tap 'Back to TVs' → '/discover'
testWidgets('pairing_screen_reflows_at_200_percent_text', ...)    // waiting + failed states at textScale 2 → no exception
// pairing_screen_golden_test.dart (@Tags(['golden'])): waiting state, Size(390, 844), light + dark → goldens/pairing_waiting_{light,dark}.png
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `flutter test test/features/pairing test/app/router_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement** the domain, state, controller, providers, screen, field, route, ARB and fakes. Run build_runner, `flutter pub get`, then `dart format lib test`.
- [ ] **Step 4: Generate the goldens**

Run: `flutter test --update-goldens --tags golden test/features/pairing`, then inspect them.

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `flutter test`
Expected: all PASS.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/lib app/test
git commit -m "feat(app): pairing wizard with code entry, paste, countdown and TOFU pin" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report: carry-over done: the code is trimmed and upper-cased before `submitCode`.

---

### Task 3.10: Wake-on-LAN service

**Files:**
- Modify: `app/pubspec.yaml` (dep `network_info_plus: 8.2.2`)
- Create: `app/lib/core/wake/wake_on_lan_service.dart` (+ `.g.dart`)
- Test: `app/test/core/wake/wake_on_lan_service_test.dart`

**Interfaces:**
- Consumes: `sendWakeOnLan`, `buildMagicPacket` (atv_remote); `NetworkInfo().getWifiBroadcast()` (network_info_plus).
- Produces:
  - `typedef WakeOnLanSender = Future<void> Function(String mac, {List<InternetAddress>? broadcastAddresses, int port});`
  - `List<InternetAddress> wakeOnLanTargets({String? subnetBroadcast, String? tvHost})`:
    - Always starts with `255.255.255.255`.
    - Adds `subnetBroadcast` when it parses as IPv4.
    - Adds `a.b.c.255` when `tvHost` parses as IPv4.
    - Removes duplicates and keeps that order.
  - `class WakeOnLanService`:
    - Constructor: `WakeOnLanService({Future<String?> Function()? subnetBroadcast, WakeOnLanSender send = sendWakeOnLan, Duration lookupTimeout = const Duration(seconds: 2)})`. The default `subnetBroadcast` is `NetworkInfo().getWifiBroadcast`.
    - `Future<bool> wake({required String mac, String? tvHost})`:
      1. Validate first with `buildMagicPacket(mac)`, so a malformed MAC throws `FormatException`.
      2. Look up the subnet broadcast. Errors and the timeout count as `null`.
      3. `await send(mac, broadcastAddresses: wakeOnLanTargets(...))`.
      4. Return `true` when sent, `false` on a `SocketException`/`OSError`. Never log the MAC or the IPs.
  - `@Riverpod(keepAlive: true) WakeOnLanService wakeOnLanService(Ref ref) => WakeOnLanService();` → `wakeOnLanServiceProvider`. Phase 4's power button consumes it with `SavedDevice.wolMac` and `lastHost`.

- [ ] **Step 1: Write the failing tests**

```dart
test('targets_include_limited_and_subnet_broadcast', () => expect(
    wakeOnLanTargets(subnetBroadcast: '192.168.0.255', tvHost: '10.0.0.7').map((a) => a.address),
    ['255.255.255.255', '192.168.0.255', '10.0.0.255']));
test('falls_back_to_slash_24_of_tv_host_when_subnet_unknown', ...) // (null, '192.168.0.20') → ['255.255.255.255', '192.168.0.255']
test('deduplicates_and_ignores_non_ipv4_values', ...)              // ('192.168.0.255', '192.168.0.20') → 2 entries; ('garbage', 'tv.local') → only limited
test('wake_sends_to_every_target', ...)                            // recording sender gets mac + 3 targets; returns true
test('lookup_failure_or_timeout_still_sends_limited_broadcast', ...) // subnetBroadcast throws / never completes (fakeAsync 2 s) → targets ['255.255.255.255', tv /24]
test('send_failure_returns_false', ...)                            // sender throws SocketException → false
test('malformed_mac_throws_format_exception_without_sending', ...)
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/core/wake`
Expected: FAIL.

- [ ] **Step 3: Add the dependency**

Run: `flutter pub add network_info_plus:8.2.2`

- [ ] **Step 4: Implement** the service and provider. Run build_runner, then `dart format lib test`.
- [ ] **Step 5: Run the test and confirm it passes; build the dev APK**

Run `flutter test test/core/wake`, then `flutter build apk --debug --flavor dev -t lib/main_dev.dart`.
Expected: PASS, and the build succeeds.

- [ ] **Step 6: Run the full check and commit**

```bash
powershell -File tool/check.ps1
git add app/pubspec.yaml pubspec.lock app/lib app/test
git commit -m "feat(app): wake-on-lan service with subnet broadcast" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Report:
- Carry-over done: WoL sends to the subnet broadcast.
- Decision for Ruling 13.
- Owner action: request Apple's multicast entitlement, otherwise WoL stays Android-only.

---

## Phase exit checklist

- [ ] `powershell -File tool/check.ps1` → `All checks passed.` (goldens included). `tool/check.sh` passes with goldens excluded.
- [ ] New or re-baselined golden PNGs, each in light and dark:
  - re-baselined: `status_pill_all_states`
  - new: `remote_basic`, `discovery_found`, `discovery_troubleshooting`, `pairing_waiting`
  - `discovery_empty_*` is deleted.
- [ ] **Real-device run (owner + Claude; this is the exit criterion).** Phone: Note10+ over ADB Wi-Fi. TV: "Living Room TV 3". Run `flutter run --flavor dev -t lib/main_dev.dart`.
  1. Onboarding → the TV appears within 10 s → pair with the on-screen code → the remote shows **Connected**.
     - If "This TV's identity changed" appears right after pairing, the TV presents different keys on 6467 and 6466. Record this in `learnings.md`: it invalidates decision #11.
  2. Home, Back, D-pad and Volume act on the TV.
  3. Open another app for 70 s, then return → "Connecting…" → "Connected" within ~3 s. Return after 20 s instead → still connected, or reconnects by itself.
  4. Wi-Fi off for 10 s, then on → "Reconnecting…"/"Offline" → "Connected", or Reconnect works.
  5. Unplug the TV → the pill leaves "Connected" within the idle timeout (15 s, decision #10) and shows "Offline" with Reconnect.
  6. Manual IP entry pairs the same TV.
  7. Back on Discovery, "Try demo" → demo badge + TV preview; "Leave" returns to the TV list.

  If no device is available, say so in the report; don't claim the check passed.
- [ ] The task reports collectively carry these knowledge updates:
  - **decisions:** Rulings 1, 2, 4, 5, 6, 9, 10, 13 and 14, plus the pinned versions nsd 5.0.1, connectivity_plus 7.3.2, network_info_plus 8.2.2 and fake_async 1.3.3.
  - **learnings:** nsd_android handles the multicast lock; iOS timers stop while suspended; `implements`-fakes of library classes.
  - **status:** carry-overs closed (verify re-check, `PairingClient` message, code normalisation, debounce, Reconnect → `notifyNetworkChanged`, WoL subnet broadcast, iOS Bonjour keys, status label rename, identity read retry).

## Needs the owner

- The real-device run above. It also covers most of the Phase 1 CLI smoke test. Record the TV's ping interval for decision #10 and the "same key on both ports" check.
- **On a Mac:**
  - `flutter build ios --flavor dev -t lib/main_dev.dart --no-codesign` (and prod). The first run creates a `Podfile` for the new plugins; map the six configurations in it.
  - On an iPhone, confirm the Local Network prompt appears and discovery finds the TV.
- Request Apple's `com.apple.developer.networking.multicast` entitlement for Wake-on-LAN on iOS, before Phase 4 wires the power button.
- Phase 9 lead time from the master plan: create the Play Console account and recruit 12 testers, so the 14-day closed test can start at the end of Phase 4.
