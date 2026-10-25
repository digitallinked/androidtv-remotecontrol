# atv_remote

Pure-Dart client for the Android TV Remote Service v2 protocol: pairing
(port 6467), the remote control channel (port 6466), a reconnecting
connection state machine, Wake-on-LAN and a discovery model. No Flutter
imports. The Flutter app imports only `package:atv_remote/atv_remote.dart`;
mDNS discovery itself is implemented in the app against the `TvDiscovery`
interface.

## Attribution

The `.proto` files in `proto/` and the wire behaviour follow
[androidtvremote2](https://github.com/tronikos/androidtvremote2) by tronikos
(Apache-2.0).

## Tests

This workspace contains a Flutter member, so `dart test` cannot resolve it.
Run from `packages/atv_remote`:

```
flutter test
```

Static checks: `dart analyze --fatal-infos`. The whole workspace is checked
with `powershell -File tool/check.ps1` from the repository root.

## Command-line tool

`bin/atv_cli.dart` talks to a real TV on the same network. From
`packages/atv_remote`:

```
dart run bin/atv_cli.dart pair <host>             # type the code shown on the TV
dart run bin/atv_cli.dart key <host> <keyName>    # e.g. home, volumeUp, playPause, 5
dart run bin/atv_cli.dart watch <host>            # print TV events until Ctrl+C
dart run bin/atv_cli.dart --help
```

`dart run` works here even though `dart test` does not. The client identity
is stored in `~/.atv_cli/identity.json` (`%USERPROFILE%` on Windows); delete
it to start over (the TV then asks to pair again). `key` exits with
"Not paired - run: pair <host>" when the TV rejects the identity.
