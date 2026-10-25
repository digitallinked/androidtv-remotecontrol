import 'dart:io';

/// Opens the TLS connection to a TV.
///
/// Injectable so tests (and other transports) can replace the real network.
/// The returned socket must already have completed the TLS handshake, so the
/// caller can read `peerCertificate`.
typedef SocketConnector =
    Future<SecureSocket> Function(
      String host,
      int port,
      SecurityContext context,
    );

/// How long [defaultSocketConnector] waits for the TCP connection.
const Duration _connectTimeout = Duration(seconds: 10);

/// Connects with [context] as the client identity and accepts any server
/// certificate.
///
/// A TV presents a self-signed certificate, so there is nothing to validate it
/// against. The caller inspects `peerCertificate` and pins it (trust on first
/// use) once the TV is known.
Future<SecureSocket> defaultSocketConnector(
  String host,
  int port,
  SecurityContext context,
) => SecureSocket.connect(
  host,
  port,
  context: context,
  // Self-signed TV certificate; pinning happens above this layer.
  onBadCertificate: (_) => true,
  timeout: _connectTimeout,
);
