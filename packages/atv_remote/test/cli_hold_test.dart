import 'dart:async';
import 'dart:io';

import 'package:atv_remote/src/cli/hold.dart';
import 'package:atv_remote/src/identity.dart';
import 'package:atv_remote/src/key_codes.dart';
import 'package:atv_remote/src/pairing_client.dart';
import 'package:atv_remote/src/proto/remotemessage.pb.dart';
import 'package:atv_remote/src/remote_client.dart';
import 'package:atv_remote/testing.dart';
import 'package:test/test.dart';

import 'support/wait_for.dart';

/// The budget for setup that is not under test (pairing and connecting to
/// the in-process fake TV).
const Duration _setup = Duration(seconds: 20);

const DeviceInfo _deviceInfo = DeviceInfo(
  model: 'atv_cli test',
  vendor: 'atvremote',
  packageName: 'atv_cli',
  appVersion: '1.0.0',
);

// RSA keygen is slow: generate each identity once per test run.
late ClientIdentity _paired;
late ClientIdentity _unpaired;

Future<FakeTvServer> _pairedTv() async {
  final tv = await FakeTvServer.start(sendPings: false);
  addTearDown(tv.close);
  final pairing = PairingClient(
    host: InternetAddress.loopbackIPv4.address,
    port: tv.pairingPort,
    identity: _paired,
    timeout: _setup,
  );
  addTearDown(pairing.close);
  await pairing.start(clientName: 'atv_cli test');
  await pairing.submitCode(tv.displayedCode!);
  return tv;
}

RemoteClient _client(FakeTvServer tv, ClientIdentity identity) {
  final client = RemoteClient(
    host: InternetAddress.loopbackIPv4.address,
    port: tv.remotePort,
    identity: identity,
    deviceInfo: _deviceInfo,
    connectTimeout: _setup,
  );
  addTearDown(client.close);
  return client;
}

/// The directions the TV received for [keyCode], in order.
List<RemoteDirection> _directionsFor(FakeTvServer tv, int keyCode) => [
  for (var i = 0; i < tv.receivedKeyCodes.length; i++)
    if (tv.receivedKeyCodes[i] == keyCode) tv.receivedKeyDirections[i],
];

void main() {
  setUpAll(() {
    _paired = ClientIdentity.generate(commonName: 'cli-hold-paired');
    _unpaired = ClientIdentity.generate(commonName: 'cli-hold-unpaired');
    FakeTvServer.trustClient(_paired);
    FakeTvServer.trustClient(_unpaired);
  });

  test('hold_sends_start_long_then_end_long_after_the_hold', () async {
    final tv = await _pairedTv();
    final out = StringBuffer();
    final err = StringBuffer();

    final code = await holdKey(
      client: _client(tv, _paired),
      keyCode: KeyCodes.home,
      keyName: 'home',
      hold: const Duration(milliseconds: 200),
      interrupted: Completer<void>().future,
      out: out,
      err: err,
    ).timeout(_setup);

    expect(code, 0, reason: '$err');
    await waitFor(
      () => _directionsFor(tv, KeyCodes.home).length >= 2,
      reason: 'startLong and endLong at the TV',
    );
    expect(_directionsFor(tv, KeyCodes.home), [
      RemoteDirection.START_LONG,
      RemoteDirection.END_LONG,
    ]);
    expect('$out', contains('Held home for 200 ms.'));
    expect('$err', isEmpty);
  });

  test('hold_releases_the_key_when_interrupted', () async {
    final tv = await _pairedTv();
    final interrupted = Completer<void>();
    final out = StringBuffer();
    final err = StringBuffer();

    final result = holdKey(
      client: _client(tv, _paired),
      keyCode: KeyCodes.home,
      keyName: 'home',
      hold: const Duration(seconds: 30),
      interrupted: interrupted.future,
      out: out,
      err: err,
    );
    await waitFor(
      () => _directionsFor(tv, KeyCodes.home).isNotEmpty,
      reason: 'startLong at the TV',
    );
    interrupted.complete();

    final code = await result.timeout(const Duration(seconds: 2));
    expect(code, 130, reason: '$err');
    await waitFor(
      () => _directionsFor(tv, KeyCodes.home).length >= 2,
      reason: 'endLong at the TV',
    );
    expect(_directionsFor(tv, KeyCodes.home).last, RemoteDirection.END_LONG);
    expect('$out', contains('Interrupted; released home.'));
  });

  test('hold_reports_a_dropped_connection_instead_of_throwing', () async {
    final tv = await _pairedTv();
    final interrupted = Completer<void>();
    final out = StringBuffer();
    final err = StringBuffer();
    final uncaught = <Object>[];

    final code = await runZonedGuarded(
      () async {
        final result = holdKey(
          client: _client(tv, _paired),
          keyCode: KeyCodes.home,
          keyName: 'home',
          hold: const Duration(seconds: 30),
          interrupted: interrupted.future,
          out: out,
          err: err,
        );
        await waitFor(
          () => _directionsFor(tv, KeyCodes.home).isNotEmpty,
          reason: 'startLong at the TV',
        );
        await tv.dropConnections();
        Timer(const Duration(milliseconds: 100), interrupted.complete);
        return result.timeout(_setup);
      },
      (error, stack) => uncaught.add(error),
    );

    expect(code, 1);
    expect('$err', contains('closed during the hold'));
    expect(uncaught, isEmpty);
  });

  test('hold_reports_an_unpaired_identity', () async {
    final tv = await _pairedTv();
    final out = StringBuffer();
    final err = StringBuffer();

    final code = await holdKey(
      client: _client(tv, _unpaired),
      keyCode: KeyCodes.home,
      keyName: 'home',
      hold: const Duration(milliseconds: 200),
      interrupted: Completer<void>().future,
      out: out,
      err: err,
    ).timeout(_setup);

    expect(code, 1);
    expect('$err', contains('Not paired - run: pair 127.0.0.1'));
    expect(tv.receivedKeyCodes, isEmpty);
  });
}
