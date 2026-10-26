import 'package:tv_remote/core/storage/app_database.dart';
import 'package:tv_remote/core/tv/server_key_pin.dart';

/// The SHA-256 of the TV key that `FakeRemoteClients` presents by default:
/// 32 bytes of 7. Written out because a `for` element isn't allowed in a
/// constant list, and default parameter values must be constant.
const List<int> testServerKey = <int>[
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, //
  7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, 7, //
];

/// The pin of [testServerKey], as stored after pairing.
final String testPin = serverKeyPinFromSha256(testServerKey);

/// A saved TV for tests: `serviceName` and `displayName` are both [name],
/// the port is 6466 and [at] defaults to `DateTime.utc(2026, 10, 25)`.
///
/// The pin is [pin], or [testPin] when [pin] is omitted; pass
/// `noPin: true` for a TV without a trusted key.
SavedDevice savedTv({
  String name = 'Living Room TV 3',
  String host = '192.168.0.20',
  String? pin,
  bool noPin = false,
  String? nickname,
  String? wolMac,
  DateTime? at,
}) => SavedDevice(
  serviceName: name,
  displayName: name,
  lastHost: host,
  port: 6466,
  nickname: nickname,
  wolMac: wolMac,
  serverKeyPin: noPin ? null : (pin ?? testPin),
  lastConnectedAt: at ?? DateTime.utc(2026, 10, 25),
);
