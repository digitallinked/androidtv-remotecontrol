import 'dart:io';

import 'package:atv_remote/atv_remote.dart';
import 'package:atv_remote/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/tv/server_key_pin.dart';

import 'test_identity.dart';

/// A fake TV that [testIdentity] has paired with, and the saved TV the app
/// would have stored for it: its loopback address, its remote port and the
/// pin of its key.
///
/// For plain `test()`s in real time (widget tests use `FakeTvHarness`, which
/// pairs through the app's own screens). The TV is closed when the test ends.
Future<({FakeTvServer tv, SavedDevice device})> startPairedFakeTv() async {
  FakeTvServer.trustClient(testIdentity());
  final tv = await FakeTvServer.start();
  addTearDown(tv.close);

  final host = InternetAddress.loopbackIPv4.address;
  final pairing = PairingClient(
    host: host,
    port: tv.pairingPort,
    identity: testIdentity(),
  );
  addTearDown(pairing.close);
  await pairing.start(clientName: 'Remotely test');
  await pairing.submitCode(tv.displayedCode!);

  final device = SavedDevice(
    serviceName: 'Fake TV',
    displayName: 'Fake TV',
    lastHost: host,
    port: tv.remotePort,
    serverKeyPin: serverKeyPinFromSha256(pairing.serverPublicKeySha256!),
    lastConnectedAt: DateTime.utc(2026, 10, 30),
  );
  return (tv: tv, device: device);
}
