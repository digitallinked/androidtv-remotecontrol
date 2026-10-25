import 'dart:async';
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

/// How long [defaultSocketConnector] waits for connect plus handshake.
const Duration _connectTimeout = Duration(seconds: 10);

/// Connects with [context] as the client identity and accepts any server
/// certificate.
///
/// A TV presents a self-signed certificate, so there is nothing to validate it
/// against. The caller inspects `peerCertificate` and pins it (trust on first
/// use) once the TV is known.
///
/// Gives up after 10 seconds for TCP connect and TLS handshake together.
Future<SecureSocket> defaultSocketConnector(
  String host,
  int port,
  SecurityContext context,
) => socketConnectorWithTimeout(_connectTimeout)(host, port, context);

/// Like [defaultSocketConnector] but with a caller-chosen [timeout] for the
/// whole TCP connect plus TLS handshake.
///
/// Throws a [TimeoutException] when the limit is hit. A pending TCP connect is
/// cancelled. Dart offers no way to abort a TLS handshake that is already in
/// flight (`SecureSocket.secure` detaches the raw socket, and destroying it
/// afterwards does nothing), so a server that accepts and then never answers
/// keeps its half-open connection until it closes it. A handshake that
/// completes after the limit is handled: its socket is destroyed.
SocketConnector socketConnectorWithTimeout(Duration timeout) =>
    (host, port, context) async {
      final clock = Stopwatch()..start();
      final task = await Socket.startConnect(host, port);
      final Socket raw;
      try {
        raw = await task.socket.timeout(
          timeout,
          onTimeout: () {
            task.cancel();
            throw TimeoutException('connect timed out', timeout);
          },
        );
      } on Object {
        task.cancel();
        rethrow;
      }
      final remaining = timeout - clock.elapsed;
      final handshake = SecureSocket.secure(
        raw,
        host: host,
        context: context,
        // Self-signed TV certificate; pinning happens above this layer.
        onBadCertificate: (_) => true,
      );
      var abandoned = false;
      unawaited(
        handshake.then<void>((late) {
          if (abandoned) late.destroy();
        }, onError: (Object _) {}),
      );
      try {
        return await handshake.timeout(
          remaining.isNegative ? Duration.zero : remaining,
        );
      } on TimeoutException {
        abandoned = true;
        rethrow;
      }
    };
