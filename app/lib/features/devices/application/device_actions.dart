import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/core/session/session_providers.dart';
import 'package:tv_remote/core/session/session_target.dart';
import 'package:tv_remote/core/storage/device_repository.dart';
import 'package:tv_remote/core/storage/storage_providers.dart';

part 'device_actions.g.dart';

/// Changes to the saved TVs. Storage errors propagate to the caller, which
/// shows the "couldn't save" message.
///
/// Nothing watches the provider, so it can be disposed while a caller still
/// holds these actions across an await (the edit page saves a name and then
/// a MAC address). Everything a later call needs is therefore taken when the
/// actions are created, not read from the provider's `Ref` at call time.
class DeviceActions {
  /// Creates the actions over [ref].
  DeviceActions(Ref ref)
    : _repository = ref.read(deviceRepositoryProvider),
      _container = ref.container;

  final DeviceRepository _repository;

  /// Where the session and the target live; both are kept alive there.
  final ProviderContainer _container;

  /// Shows [nickname] instead of the TV's own name. It is trimmed; an empty
  /// one clears the nickname.
  Future<void> rename(String serviceName, String? nickname) {
    final trimmed = nickname?.trim();
    return _repository.setNickname(
      serviceName,
      trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
  }

  /// Stores the Wake-on-LAN MAC address of [serviceName] (already normalised
  /// by `parseMac`); `null` clears it.
  Future<void> setWolMac(String serviceName, String? mac) =>
      _repository.setWolMac(serviceName, mac);

  /// Forgets the TV [serviceName] and its trusted key (Ruling P5-R9).
  ///
  /// When it is the TV the session controls, the session is closed and
  /// rebuilt: the remote moves to the next saved TV (by last use), or to "No
  /// TV selected" when none is left. The phone's client identity is shared
  /// by every TV and is never touched.
  Future<void> delete(String serviceName) async {
    // Everything is taken before the first await: this provider may be
    // disposed meanwhile (nothing watches it).
    final container = _container;
    final repository = _repository;
    final target = container.read(activeTargetProvider);
    // Read only if it exists: reading would start a session just to close it.
    final sessionState = container.exists(remoteSessionProvider)
        ? container.read(remoteSessionProvider)
        : null;
    final session = sessionState?.value;
    final inUse =
        target is DeviceTarget && target.serviceName == serviceName ||
        session?.pairingTarget?.serviceName == serviceName ||
        // Still loading (or failed) for a target that isn't the demo: which
        // TV it is for isn't known, and rebuilding costs nothing.
        sessionState != null && session == null && target is! DemoTarget;

    await repository.delete(serviceName);

    if (!inUse) return;
    // The default target follows the most recent TV, so clearing is enough
    // to move on; the session is rebuilt explicitly because the target may
    // have been `null` already.
    container.read(activeTargetProvider.notifier).clear();
    container.invalidate(remoteSessionProvider);
  }
}

/// The [DeviceActions] for the widgets.
@riverpod
DeviceActions deviceActions(Ref ref) => DeviceActions(ref);
