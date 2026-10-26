import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/tv/server_key_pin.dart';
import 'package:tv_remote/features/pairing/application/pairing_state.dart';
import 'package:tv_remote/features/pairing/data/pairing_providers.dart';
import 'package:tv_remote/features/pairing/domain/pairing_code.dart';

part 'pairing_controller.g.dart';

/// How long the user has to enter the code.
const pairingCodeLifetime = Duration(seconds: 60);

/// The name the TV shows for this phone while pairing.
const String pairingClientName = kRemoteClientName;

/// Pairs this phone with one TV while the pairing screen is open.
///
/// It owns the [PairingClient]; the client is closed on every way out
/// (leaving the screen, an error, the code expiring, success, a restart).
/// No error text is kept: the state carries only a [PairingErrorKind], so a
/// code or key can't reach the UI or a log.
@riverpod
class PairingController extends _$PairingController {
  late DiscoveredTv _tv;
  PairingClient? _client;
  Timer? _timer;
  int _secondsLeft = 0;

  // When the code runs out. The ticks only redraw: the time left comes from
  // this, because a suspended app (iOS) stops its timers but not the clock.
  DateTime _deadline = DateTime.fromMillisecondsSinceEpoch(0);

  // Bumped by every start; a start that finds it changed has been replaced
  // and must not touch the state.
  int _run = 0;

  @override
  PairingState build(DiscoveredTv tv) {
    _tv = tv;
    ref.onDispose(() {
      // Makes a start or submit that is still running ignore its result.
      _run++;
      _release();
    });
    unawaited(Future.microtask(_start));
    return const PairingStarting();
  }

  /// Sends the code the user entered. Anything that isn't a complete code is
  /// ignored, as is a call while no code is being asked for.
  Future<void> submit(String rawCode) async {
    final code = normalizePairingCode(rawCode);
    final client = _client;
    if (state is! PairingWaitingForCode ||
        client == null ||
        !isCompletePairingCode(code)) {
      return;
    }
    final run = _run;
    // Read before the first await: the providers live as long as the app, so
    // saving and activating work even if the screen goes away meanwhile.
    final devices = ref.read(deviceRepositoryProvider);
    final container = ref.container;
    state = const PairingVerifying();

    try {
      await client.submitCode(code);
    } on PairingException catch (e) {
      if (!ref.mounted || run != _run) return;
      if (e.reason == PairingFailure.invalidCode) {
        _backToWaiting(codeMismatch: true);
      } else {
        _end(PairingFailed(_kindOf(e.reason)));
      }
      return;
    } on Object {
      // Whatever else the client throws is a bug, not something to show.
      if (!ref.mounted || run != _run) return;
      _end(const PairingFailed(PairingErrorKind.pairingError));
      return;
    }

    final SavedDevice device;
    try {
      final digest = client.serverPublicKeySha256;
      if (digest == null) {
        throw StateError('Paired without seeing the TV key');
      }
      final existing = await devices.find(_tv.serviceName);
      device = SavedDevice(
        serviceName: _tv.serviceName,
        displayName: _tv.displayName,
        lastHost: _tv.host,
        port: _tv.port,
        nickname: existing?.nickname,
        wolMac: existing?.wolMac,
        serverKeyPin: serverKeyPinFromSha256(digest),
        lastConnectedAt: DateTime.now().toUtc(),
      );
      await devices.upsert(device);
    } on Object {
      if (ref.mounted && run == _run) {
        _end(const PairingFailed(PairingErrorKind.saveFailed));
      }
      return;
    }
    // The pin is stored either way: the TV trusts this phone now.
    final stayed = ref.mounted && run == _run;
    final activeTarget = container.read(activeTargetProvider);
    // The session has to be rebuilt, because the old one holds the pin it
    // started with. When the user left meanwhile, that must not switch the
    // remote from another TV to this one.
    if (stayed ||
        activeTarget == null ||
        activeTarget == DeviceTarget(device.serviceName)) {
      container
          .read(activeTargetProvider.notifier)
          .activateDevice(device.serviceName);
    }
    if (stayed) _end(PairingSucceeded(device));
  }

  /// Starts again with a new client: "Get a new code" and "Try again".
  Future<void> restart() async {
    if (!ref.mounted) return;
    _release();
    state = const PairingStarting();
    await _start();
  }

  Future<void> _start() async {
    final run = ++_run;
    bool stale() => !ref.mounted || run != _run;
    if (stale()) return;

    final ClientIdentity identity;
    try {
      identity = await ref.read(identityStoreProvider).loadOrCreate();
    } on Object {
      if (!stale()) {
        _end(const PairingFailed(PairingErrorKind.identityUnavailable));
      }
      return;
    }
    if (stale()) return;

    try {
      final client = ref.read(pairingClientFactoryProvider)(
        host: _tv.host,
        identity: identity,
      );
      _client = client;
      await client.start(clientName: pairingClientName);
    } on PairingException catch (e) {
      if (!stale()) _end(PairingFailed(_kindOf(e.reason)));
      return;
    } on Object {
      if (!stale()) _end(const PairingFailed(PairingErrorKind.pairingError));
      return;
    }
    if (stale()) return;

    _deadline = clock.now().add(pairingCodeLifetime);
    _secondsLeft = _remaining();
    state = PairingWaitingForCode(secondsLeft: _secondsLeft);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    if (!ref.mounted) return;
    _secondsLeft = _remaining();
    final current = state;
    if (current is! PairingWaitingForCode) return;
    if (_secondsLeft == 0) {
      _end(const PairingCodeExpired());
    } else {
      state = PairingWaitingForCode(
        secondsLeft: _secondsLeft,
        codeMismatch: current.codeMismatch,
      );
    }
  }

  /// Whole seconds until [_deadline], rounded up, never below 0.
  int _remaining() {
    final ms = _deadline.difference(clock.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms + 999) ~/ 1000;
  }

  void _backToWaiting({required bool codeMismatch}) {
    _secondsLeft = _remaining();
    // The clock ran out while the TV was checking the code.
    if (_secondsLeft == 0) {
      _end(const PairingCodeExpired());
    } else {
      state = PairingWaitingForCode(
        secondsLeft: _secondsLeft,
        codeMismatch: codeMismatch,
      );
    }
  }

  /// Releases the client and the clock, then publishes [next].
  void _end(PairingState next) {
    _release();
    state = next;
  }

  void _release() {
    _timer?.cancel();
    _timer = null;
    final client = _client;
    _client = null;
    if (client != null) unawaited(client.close());
  }

  static PairingErrorKind _kindOf(PairingFailure reason) => switch (reason) {
    PairingFailure.connectionFailed => PairingErrorKind.cantReachTv,
    PairingFailure.timeout => PairingErrorKind.tvDidNotRespond,
    PairingFailure.badSecret => PairingErrorKind.codeRejectedByTv,
    PairingFailure.protocolError ||
    PairingFailure.invalidCode => PairingErrorKind.pairingError,
  };
}
