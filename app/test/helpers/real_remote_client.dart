import 'package:atv_remote/atv_remote.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:tv_remote/app/flavor.dart';
import 'package:tv_remote/core/session/remote_client_factory.dart';

/// Builds the app's real [RemoteClient], as production does for the dev
/// flavor, for tests that talk to the fake TV over real sockets.
RemoteClient realRemoteClient({
  required String host,
  required int port,
  required ClientIdentity identity,
}) => RemoteClient(
  host: host,
  port: port,
  identity: identity,
  deviceInfo: deviceInfoFor(Flavor.dev),
);

/// Replaces `testAppOverrides`' fake client factory with [realRemoteClient].
Override realRemoteClients() =>
    remoteClientFactoryProvider.overrideWithValue(realRemoteClient);
