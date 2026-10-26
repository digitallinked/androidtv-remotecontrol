import 'package:atv_remote/atv_remote.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tv_remote/app/flavor.dart';

part 'remote_client_factory.g.dart';

/// Creates a new [RemoteClient] for one connection attempt to the TV at
/// [host]:[port], presenting [identity].
typedef RemoteClientFactory =
    RemoteClient Function({
      required String host,
      required int port,
      required ClientIdentity identity,
    });

/// The app version reported to the TV. A test holds it equal to the
/// `pubspec.yaml` version.
const kAppVersion = '1.0.0';

/// The name this app gives itself towards the TV: the pairing client name
/// and the device model.
const kRemoteClientName = 'Remotely';

/// How this phone describes itself to the TV in the given [flavor].
DeviceInfo deviceInfoFor(Flavor flavor) => DeviceInfo(
  model: kRemoteClientName,
  vendor: 'digitallinked',
  packageName: flavor.applicationId,
  appVersion: kAppVersion,
);

/// Builds the real [RemoteClient]s of this app; tests override it with a
/// fake.
@Riverpod(keepAlive: true)
RemoteClientFactory remoteClientFactory(Ref ref) {
  final deviceInfo = deviceInfoFor(ref.watch(flavorProvider));
  return ({required host, required port, required identity}) => RemoteClient(
    host: host,
    port: port,
    identity: identity,
    deviceInfo: deviceInfo,
  );
}
