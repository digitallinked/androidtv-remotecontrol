import 'dart:async';
import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:atv_remote/testing.dart';
import 'package:test/test.dart';

import 'support/wait_for.dart';

/// Ruling P8-R5: key-press-to-send stays under 30 ms at the 95th
/// percentile, measured from `RemoteClient.sendKey` to the fake TV reading
/// the key over loopback TLS. It measures our code path (framing and the TLS
/// write), not Wi-Fi.
const Duration _budget = Duration(milliseconds: 30);
const int _warmUps = 5;
const int _measured = 50;

const DeviceInfo _deviceInfo = DeviceInfo(
  model: 'Test Phone',
  vendor: 'Test Vendor',
  packageName: 'com.example.remote',
  appVersion: '1.2.3',
);

/// The median and the 95th percentile (nearest rank) of [samples].
///
/// A copy of the app's `latencyStats` (the two packages share no test code).
({Duration median, Duration p95}) latencyStats(List<Duration> samples) {
  if (samples.isEmpty) throw ArgumentError.value(samples, 'samples', 'empty');
  final sorted = [...samples]..sort();
  final n = sorted.length;
  final median = n.isOdd
      ? sorted[n ~/ 2]
      : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) ~/ 2;
  final p95 = sorted[(n * 0.95).ceil() - 1];
  return (median: median, p95: p95);
}

/// The fixture identity from `test/fixtures/`; parsing it is much faster than
/// generating a key.
ClientIdentity _fixtureIdentity() => ClientIdentity.fromPem(
  certificatePem: File('test/fixtures/client.pem').readAsStringSync(),
  privateKeyPem: File('test/fixtures/client_key.pem').readAsStringSync(),
);

void main() {
  test('latency_stats_takes_the_median_and_the_nearest_rank_p95', () {
    final samples = [
      for (var ms = 20; ms >= 1; ms--) Duration(milliseconds: ms),
    ];
    final s = latencyStats(samples);
    expect(s.median, const Duration(microseconds: 10500));
    expect(s.p95, const Duration(milliseconds: 19));
    expect(
      latencyStats(const [Duration(milliseconds: 3)]),
      (
        median: const Duration(milliseconds: 3),
        p95: const Duration(milliseconds: 3),
      ),
    );
  });

  test(
    'key_press_reaches_the_fake_tv_within_30ms',
    () async {
      final identity = _fixtureIdentity();
      FakeTvServer.trustClient(identity);
      final tv = await FakeTvServer.start();
      addTearDown(tv.close);

      final pairing = PairingClient(
        host: InternetAddress.loopbackIPv4.address,
        port: tv.pairingPort,
        identity: identity,
      );
      addTearDown(pairing.close);
      await pairing.start(clientName: 'latency test');
      await pairing.submitCode(tv.displayedCode!);

      final client = RemoteClient(
        host: InternetAddress.loopbackIPv4.address,
        port: tv.remotePort,
        identity: identity,
        deviceInfo: _deviceInfo,
      );
      addTearDown(client.close);
      await client.connect();
      await tv.waitForActiveClient();

      // The TV's key stream is synchronous: the listener stops the clock the
      // moment the TV has read the key.
      final watch = Stopwatch();
      Completer<Duration>? arrival;
      final keys = tv.keyCodes.listen((_) => arrival?.complete(watch.elapsed));
      addTearDown(keys.cancel);

      Future<Duration> press() async {
        final arrived = arrival = Completer<Duration>();
        watch
          ..reset()
          ..start();
        client.sendKey(KeyCodes.dpadUp);
        return arrived.future.timeout(const Duration(seconds: 5));
      }

      for (var i = 0; i < _warmUps; i++) {
        await press();
      }
      final samples = [for (var i = 0; i < _measured; i++) await press()];
      await waitFor(
        () => tv.receivedKeyCodes.length == _warmUps + _measured,
        reason: 'the TV to record every press',
      );

      final s = latencyStats(samples);
      // The figures are for the report; they are host numbers, not device
      // numbers.
      // ignore: avoid_print
      print(
        'key latency median=${s.median.inMicroseconds}us '
        'p95=${s.p95.inMicroseconds}us',
      );
      expect(s.p95, lessThan(_budget));
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
