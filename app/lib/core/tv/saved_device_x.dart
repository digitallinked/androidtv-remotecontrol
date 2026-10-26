import 'package:atv_remote/atv_remote.dart';
import 'package:tv_remote/core/storage/app_database.dart';

/// View helpers for a [SavedDevice].
extension SavedDeviceX on SavedDevice {
  /// The name shown for this TV: the user's nickname, or the name the TV
  /// announced.
  String get label => nickname ?? displayName;

  /// This TV as a discovery record at its last known address, for pairing
  /// it again. It carries the name the TV announced, never the nickname, so
  /// pairing again can't overwrite [displayName] with the nickname.
  DiscoveredTv toDiscoveredTv() => DiscoveredTv(
    serviceName: serviceName,
    displayName: displayName,
    host: lastHost,
    port: port,
    isLegacyService: false,
  );
}
