/// Pure-Dart client for the Android TV Remote Service v2 protocol.
///
/// This is the only library the app imports. No Flutter imports are allowed
/// in this package.
library;

export 'src/backoff.dart' show Backoff;
export 'src/discovery.dart' show DiscoveredTv, TvDiscovery, parseServiceRecord;
export 'src/identity.dart'
    show ClientIdentity, RsaPublicParts, rsaPublicPartsFromCertificateDer;
export 'src/key_codes.dart' show KeyCodes, KeyDirection;
export 'src/pairing_client.dart'
    show PairingClient, PairingException, PairingFailure;
export 'src/pairing_secret.dart'
    show InvalidPairingCodeException, computePairingSecret;
export 'src/remote_client.dart'
    show DeviceInfo, RemoteClient, RemoteConnectException;
export 'src/remote_events.dart'
    show
        CurrentAppChanged,
        ImeShowRequested,
        PowerStateChanged,
        RemoteCloseReason,
        RemoteClosed,
        RemoteErrorReceived,
        RemoteEvent,
        RemoteReady,
        VolumeChanged;
export 'src/socket_connector.dart'
    show SocketConnector, defaultSocketConnector, socketConnectorWithTimeout;
export 'src/tv_connection.dart'
    show ConnectionState, ConnectionStatus, NotConnectedException, TvConnection;
export 'src/wake_on_lan.dart' show buildMagicPacket, sendWakeOnLan;

/// Name of this package, used by the smoke test to prove the library loads.
const String atvRemotePackageName = 'atv_remote';
