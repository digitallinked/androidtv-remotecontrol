---
name: flutter-app-architecture
description: Use when creating or changing Flutter code in app/ — new screens, widgets, providers, routes, storage, platform channels, dependencies, tests, lints, flavors or build config for this TV remote app.
---

# Flutter app architecture

## Overview
Feature-first Flutter app on top of a pure-Dart protocol package. The UI reads state from Riverpod providers; providers talk to `packages/atv_remote`. Nothing in `app/` touches sockets.

## Layout
```
app/lib/
  main.dart / bootstrap.dart        flavors, Firebase init, error zones
  app/              router.dart, theme/ (tokens → ThemeData), l10n/
  core/             storage/, analytics/, ads/, purchases/, config/ (Remote Config), haptics/
  features/
    discovery/      scan + device list
    pairing/        code entry wizard
    remote/         remote screen: touchpad, dpad, numpad, rockers, quick-access row
    keyboard/       text-entry sheet
    apps/           app catalogue, shortcuts, recommendations
    devices/        saved TVs, rename, delete, Wake-on-LAN MAC
    settings/       layout, behaviour, theme, about, legal, FAQ
    paywall/        premium screen
    onboarding/
    demo/           simulated TV implementing the same connection interface (store review + try-before-pairing)
  each feature:     data/ (repos), domain/ (models), presentation/ (screens, widgets, controllers)
packages/atv_remote/lib/   discovery, pairing, remote_client, certs, keycodes, wol, src/proto (generated)
```

## Stack (pin exact versions in pubspec.yaml; record upgrades in decisions.md)
| Need | Package |
|---|---|
| State | `flutter_riverpod`, `riverpod_annotation` + `riverpod_generator` |
| Routing | `go_router` |
| Models | `freezed`, `json_serializable` |
| Local data | `drift` (devices, shortcuts, usage counts), `shared_preferences` (simple settings) |
| Secrets | `flutter_secure_storage` (client cert + private key) |
| Discovery | `nsd` (Android NSD / iOS Bonjour) |
| Protocol | `protobuf` + `protoc_plugin`, `pointycastle`, `basic_utils` (X.509), `dart:io SecureSocket` |
| UI | `flutter_svg`, `cached_network_image` (`home_widget` only in v1.1, not now) |
| Device | `wakelock_plus`, `screen_brightness`, Flutter's built-in `HapticFeedback` (no extra package) |
| Services | see the `app-services` skill |
| Tests | `flutter_test`, `mocktail`, `integration_test`, a fake TV server in `packages/atv_remote/test/fake_tv/` |

## Platform floors
Android minSdk 24, targetSdk ≥ 35; iOS 13.0. The Flutter version is pinned in `decisions.md`. The app catalogue is a bundled asset (`app/assets/catalogue/apps_v1.json`); the `catalogue_version` Remote Config key is reserved for a future remote catalogue.

## Conventions
- Providers expose immutable state (`freezed`); side effects go in controller methods (`AsyncNotifier`).
- The connection is a single `remoteSessionProvider` (keepAlive) wrapping `RemoteClient`; widgets watch `connectionStateProvider`.
- Every tap on a remote control goes through `RemoteActions` (adds haptics, analytics, Smooth Press repeat logic) and never calls the client directly.
- Strings go in ARB files (`app/lib/app/l10n/`), English first; no hard-coded UI text.
- Lints: `very_good_analysis`. `flutter analyze` must be clean.
- Tests: TDD for `atv_remote` and controllers (`superpowers:test-driven-development`); golden tests for key widgets (remote pad, dpad, paywall) in light + dark; one integration test per critical flow (discover → pair → press key) against the fake TV.
- Flavors: `dev` (test ad IDs, debug Firebase project) and `prod`. Run with `--flavor dev -t lib/main_dev.dart`.

## Common mistakes
- Putting socket or protobuf code in a widget or provider file.
- Showing state from the paired-devices table as live connection state.
- Forgetting `ref.onDispose` for streams → leaked sockets after hot reload.
- Adding a package without checking iOS support and licence.
