import 'dart:async';

import 'package:atv_remote/atv_remote.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/haptics/haptics.dart';
import 'package:tv_remote/core/session/not_connected_notices.dart';
import 'package:tv_remote/core/session/remote_session.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/storage/device_repository.dart';
import 'package:tv_remote/core/storage/settings_controller.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';
import 'package:tv_remote/core/wake/wake_on_lan_service.dart';
import 'package:tv_remote/features/remote/application/remote_actions.dart';

part 'power_controller.g.dart';

/// What the power action did, for the screen to say so.
enum PowerOutcome {
  /// The TV is connected: `KEYCODE_POWER` went out. The TV reacting is the
  /// feedback; the screen says nothing more.
  sentPowerKey,

  /// The TV is not connected: the wake-up signal was sent and the app is
  /// reconnecting.
  waking,

  /// Every send of the wake-up signal failed.
  wakeFailed,

  /// The TV is not connected and its MAC address is not known yet: ask for it.
  needsMac,

  /// The TV is not connected and this platform can't wake it (iOS until the
  /// multicast entitlement): the user turns it on with the TV's own remote.
  cannotWake,

  /// Nothing could be done: no session, the TV needs pairing, or it is the
  /// demo TV. The not-connected notice has been raised.
  notConnected,
}

/// The power key (Rulings P4-R5, P4-R6, P4-R10): sends `KEYCODE_POWER` while
/// the TV is connected, otherwise wakes it with Wake-on-LAN and reconnects.
///
/// Exactly one heavy haptic per power action, whichever path it takes: the
/// connected path gets it from [RemoteActions.tap]; the Wake-on-LAN path sends
/// no key, so this class fires it itself, gated by `hapticsEnabled` (the
/// setting [RemoteActions] reads on its own).
///
/// An instance belongs to one session and one set of settings, like
/// [RemoteActions].
class PowerController {
  /// Creates the controller for `session`.
  ///
  /// `session` is `null` when there is no TV or the session is reloading (a
  /// TV switch). `onRefused` is called when the power action can't go
  /// anywhere because the TV isn't reachable and can't be woken.
  PowerController({
    required this.session,
    required this.actions,
    required this.devices,
    required this.wakeOnLan,
    required this.wakeOnLanAvailable,
    required this.haptics,
    required this.hapticsEnabled,
    required this.onRefused,
  });

  /// The session the power action targets, or `null` while there is none.
  final RemoteSession? session;

  /// Sends the power key while connected.
  final RemoteActions actions;

  /// Where the TV's MAC address lives.
  final DeviceRepository devices;

  /// Sends the wake-up signal.
  final WakeOnLanService wakeOnLan;

  /// Whether this platform can send Wake-on-LAN at all.
  final bool wakeOnLanAvailable;

  /// The haptic feedback.
  final Haptics haptics;

  /// Whether the user wants haptic feedback.
  final bool hapticsEnabled;

  /// Called when the action is refused (it raises the not-connected notice).
  final VoidCallback onRefused;

  /// The power action for the TV of [session].
  Future<PowerOutcome> press() async {
    final session = this.session;
    if (session == null) {
      onRefused();
      return PowerOutcome.notConnected;
    }
    // Includes a TV in standby that still holds the socket: only the key can
    // wake its screen, and the Wake-on-LAN packet is for a TV that is gone.
    if (session.current.status == ConnectionStatus.connected) {
      // `actions` has raised the notice itself when it refuses.
      return actions.tap(KeyCodes.power)
          ? PowerOutcome.sentPowerKey
          : PowerOutcome.notConnected;
    }
    final target = session.pairingTarget;
    if (session.current.status == ConnectionStatus.needsPairing ||
        target == null) {
      onRefused();
      return PowerOutcome.notConnected;
    }
    if (hapticsEnabled) unawaited(haptics.heavy());
    return _wake(session, target);
  }

  /// Stores [mac] (already normalised by `parseMac`) for the TV and wakes it,
  /// without a second haptic. Rethrows a storage error, so the setup sheet
  /// can say the MAC wasn't saved and stay open.
  Future<PowerOutcome> saveMacAndWake(String mac) async {
    final session = this.session;
    final target = session?.pairingTarget;
    if (session == null || target == null) {
      onRefused();
      return PowerOutcome.notConnected;
    }
    await devices.setWolMac(target.serviceName, mac);
    return _wake(session, target);
  }

  Future<PowerOutcome> _wake(RemoteSession session, DiscoveredTv target) async {
    if (!wakeOnLanAvailable) return PowerOutcome.cannotWake;
    try {
      // Fresh from the repository: the MAC may have been saved a moment ago.
      final device = await devices.find(target.serviceName);
      final mac = device?.wolMac;
      if (device == null || mac == null) return PowerOutcome.needsMac;
      if (!await wakeOnLan.wake(mac: mac, tvHost: device.lastHost)) {
        return PowerOutcome.wakeFailed;
      }
    } on Object {
      // A broken lookup or a malformed stored MAC: nothing went out. The
      // details are not logged, they hold the user's addresses.
      return PowerOutcome.wakeFailed;
    }
    // Fresh backoff and a re-resolved host, so the TV is found as it boots.
    session.reconnect();
    return PowerOutcome.waking;
  }
}

/// The [PowerController] for the active TV and the current settings.
///
/// AutoDispose, like [remoteActions] (whose instance it uses): the remote
/// screen keeps it alive with a listener. Rebuilt when the session or the
/// haptics setting changes.
@riverpod
PowerController powerController(Ref ref) {
  final session = ref.watch(
    remoteSessionProvider.select(
      (s) => s.isLoading || s.hasError ? null : s.value,
    ),
  );
  final hapticsEnabled = ref.watch(
    settingsControllerProvider.select((s) => s.hapticsEnabled),
  );
  return PowerController(
    session: session,
    actions: ref.watch(remoteActionsProvider),
    devices: ref.watch(deviceRepositoryProvider),
    wakeOnLan: ref.watch(wakeOnLanServiceProvider),
    wakeOnLanAvailable: ref.watch(wakeOnLanAvailableProvider),
    haptics: ref.watch(hapticsProvider),
    hapticsEnabled: hapticsEnabled,
    onRefused: ref.read(notConnectedNoticesProvider.notifier).notify,
  );
}
