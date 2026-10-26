// Thin command-line tool for trying the protocol against a real TV.
//
//   atv_cli pair <host>
//   atv_cli key <host> <keyName>
//   atv_cli text <host> <text>
//   atv_cli hold <host> <keyName> <ms>
//   atv_cli watch <host>
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:atv_remote/src/cli/identity_store.dart';
import 'package:atv_remote/src/cli/key_names.dart';

const String _usage = '''
Usage:
  atv_cli pair <host>             pair with the TV (type the code it shows)
  atv_cli key <host> <keyName>    send one key press (e.g. home, volumeUp, 5)
  atv_cli text <host> <text>      type text into the TV's focused text field
  atv_cli hold <host> <keyName> <ms>
                                  press and hold a key for <ms> (1-30000)
  atv_cli watch <host>            print events from the TV until Ctrl+C
''';

const DeviceInfo _deviceInfo = DeviceInfo(
  model: 'atv_cli',
  vendor: 'atvremote',
  packageName: 'atv_cli',
  appVersion: '1.0.0',
);

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && (args.first == '--help' || args.first == '-h')) {
    stdout.write(_usage);
    exit(0);
  }
  final command = args.isEmpty ? '' : args.first;
  final int code;
  switch ((command, args.length)) {
    case ('pair', 2):
      code = await _pair(args[1]);
    case ('key', 3):
      code = await _key(args[1], args[2]);
    case ('text', 3):
      code = await _text(args[1], args[2]);
    case ('hold', 4):
      code = await _hold(args[1], args[2], args[3]);
    case ('watch', 2):
      code = await _watch(args[1]);
    default:
      stderr.write(_usage);
      code = 1;
  }
  await stdout.flush();
  exit(code);
}

Future<ClientIdentity> _identity() => loadOrCreateIdentity(cliIdentityFile());

Future<int> _pair(String host) async {
  final identity = await _identity();
  final client = PairingClient(host: host, identity: identity);
  try {
    await client.start(clientName: 'atv_cli');
    while (true) {
      stdout.writeln('Enter the code shown on the TV:');
      final line = stdin.readLineSync(encoding: utf8)?.trim();
      if (line == null) {
        stderr.writeln('No input.');
        return 1;
      }
      try {
        await client.submitCode(line);
        stdout.writeln('Paired.');
        return 0;
      } on PairingException catch (e) {
        if (e.reason != PairingFailure.invalidCode) rethrow;
        stdout.writeln('That code is not valid. Try again.');
      }
    }
  } on PairingException catch (e) {
    stderr.writeln(
      'Pairing failed: ${e.reason.name}'
      '${e.message == null ? '' : ' (${e.message})'}',
    );
    return 1;
  } finally {
    await client.close();
  }
}

Future<int> _key(String host, String keyName) async {
  final keyCode = parseKeyName(keyName);
  if (keyCode == null) {
    stderr.writeln('Unknown key "$keyName". Valid keys: ${validKeyNames()}');
    return 1;
  }
  final client = RemoteClient(
    host: host,
    identity: await _identity(),
    deviceInfo: _deviceInfo,
  );
  try {
    await client.connect();
    client.sendKey(keyCode);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    stdout.writeln('Sent $keyName.');
    return 0;
  } on RemoteConnectException catch (e) {
    _printConnectError(e, host);
    return 1;
  } finally {
    await client.close();
  }
}

/// Types [text] into the TV's focused text field. Prints only the length.
Future<int> _text(String host, String text) async {
  final client = RemoteClient(
    host: host,
    identity: await _identity(),
    deviceInfo: _deviceInfo,
  );
  try {
    await client.connect();
    client.sendText(text);
    await Future<void>.delayed(const Duration(milliseconds: 500));
    stdout.writeln('sent ${text.runes.length} characters');
    return 0;
  } on RemoteConnectException catch (e) {
    _printConnectError(e, host);
    return 1;
  } finally {
    await client.close();
  }
}

/// Presses [keyName] down, keeps it down for [rawMillis], then releases it.
Future<int> _hold(String host, String keyName, String rawMillis) async {
  final keyCode = parseKeyName(keyName);
  if (keyCode == null) {
    stderr.writeln('Unknown key "$keyName". Valid keys: ${validKeyNames()}');
    return 1;
  }
  final millis = parseHoldMillis(rawMillis);
  if (millis == null) {
    stderr.writeln('Invalid hold time "$rawMillis". Use 1 to 30000 ms.');
    return 1;
  }
  final client = RemoteClient(
    host: host,
    identity: await _identity(),
    deviceInfo: _deviceInfo,
  );
  try {
    await client.connect();
    client.sendKey(keyCode, direction: KeyDirection.startLong);
    try {
      await Future<void>.delayed(Duration(milliseconds: millis));
    } finally {
      // Never leave the key down on the TV, even if the wait was interrupted.
      if (client.isReady) {
        client.sendKey(keyCode, direction: KeyDirection.endLong);
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    stdout.writeln('Held $keyName for $millis ms.');
    return 0;
  } on RemoteConnectException catch (e) {
    _printConnectError(e, host);
    return 1;
  } finally {
    await client.close();
  }
}

Future<int> _watch(String host) async {
  final client = RemoteClient(
    host: host,
    identity: await _identity(),
    deviceInfo: _deviceInfo,
  );
  final done = Completer<int>();
  client.events.listen((event) {
    stdout.writeln('${DateTime.now().toIso8601String()}  $event');
    if (event is RemoteClosed && !done.isCompleted) {
      done.complete(event.reason == RemoteCloseReason.closedByClient ? 0 : 1);
    }
  });
  final sigint = ProcessSignal.sigint.watch().listen((_) {
    if (!done.isCompleted) done.complete(0);
  });
  try {
    await client.connect();
    return await done.future;
  } on RemoteConnectException catch (e) {
    _printConnectError(e, host);
    return 1;
  } finally {
    await sigint.cancel();
    await client.close();
  }
}

void _printConnectError(RemoteConnectException e, String host) {
  if (e.reason == RemoteCloseReason.certificateRejected) {
    stderr.writeln('Not paired - run: pair $host');
  } else {
    stderr.writeln(
      'Could not connect: ${e.reason.name}'
      '${e.message == null ? '' : ' (${e.message})'}',
    );
  }
}
