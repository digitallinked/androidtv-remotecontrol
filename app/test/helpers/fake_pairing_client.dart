import 'dart:async';
import 'dart:typed_data';

import 'package:atv_remote/atv_remote.dart';

import 'test_devices.dart';

/// A deterministic [PairingClient] for app tests: no sockets, works under
/// `fakeAsync` and `testWidgets`.
///
/// It uses `implements`: the private members of the library's
/// `PairingClient` aren't part of its interface, so only the public API has
/// to be provided here.
class FakePairingClient implements PairingClient {
  /// Creates a client for [host].
  FakePairingClient({
    required this.host,
    required this.identity,
    List<int> serverKey = testServerKey,
  }) : serverKey = Uint8List.fromList(serverKey);

  @override
  final String host;

  @override
  final ClientIdentity identity;

  @override
  int get port => 6467;

  @override
  Duration get timeout => const Duration(seconds: 10);

  /// The only code the fake TV accepts, compared exactly: a code that
  /// wasn't normalised first is refused.
  String validCode = 'AB12CD';

  /// The TV key this client reports once started.
  final Uint8List serverKey;

  /// Thrown by [start] when set.
  PairingException? startError;

  /// Thrown by [submitCode] for a code that [validCode] would accept, when
  /// set.
  PairingException? submitError;

  /// When set, [start] waits for it before it ends.
  Completer<void>? holdStart;

  /// When set, [submitCode] waits for it before the TV judges the code.
  Completer<void>? holdSubmit;

  /// Every code passed to [submitCode], in order.
  final List<String> submittedCodes = [];

  /// Whether [close] was called, or the session ended by itself.
  bool closed = false;

  bool _started = false;

  @override
  Uint8List? get serverPublicKeySha256 => _started ? serverKey : null;

  @override
  Future<void> start({required String clientName}) async {
    await Future<void>.value();
    await holdStart?.future;
    if (closed) {
      throw const PairingException(PairingFailure.connectionFailed, 'closed');
    }
    final error = startError;
    if (error != null) {
      closed = true;
      throw error;
    }
    _started = true;
  }

  @override
  Future<void> submitCode(String code) async {
    submittedCodes.add(code);
    await Future<void>.value();
    await holdSubmit?.future;
    if (code != validCode) {
      throw const PairingException(PairingFailure.invalidCode);
    }
    final error = submitError;
    if (error != null) {
      closed = true;
      throw error;
    }
    closed = true;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}

/// Hands out [FakePairingClient]s; [create] is a `PairingClientFactory`.
class FakePairingClients {
  /// Every client created so far, in order.
  final List<FakePairingClient> created = [];

  /// Called with each new client, so a test can script it.
  void Function(FakePairingClient client)? onCreate;

  /// Creates and records a client for [host]; matches `PairingClientFactory`.
  PairingClient create({
    required String host,
    required ClientIdentity identity,
  }) {
    final client = FakePairingClient(host: host, identity: identity);
    created.add(client);
    onCreate?.call(client);
    return client;
  }
}
