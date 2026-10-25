import 'package:atv_remote/src/proto/polo.pb.dart';
import 'package:atv_remote/src/proto/remotemessage.pb.dart';
import 'package:test/test.dart';

void main() {
  test('RemoteKeyInject round-trips', () {
    final msg = RemoteMessage(
      remoteKeyInject: RemoteKeyInject(
        keyCode: RemoteKeyCode.KEYCODE_DPAD_UP,
        direction: RemoteDirection.SHORT,
      ),
    );
    final decoded = RemoteMessage.fromBuffer(msg.writeToBuffer());
    expect(decoded.remoteKeyInject.keyCode, RemoteKeyCode.KEYCODE_DPAD_UP);
    expect(decoded.remoteKeyInject.direction, RemoteDirection.SHORT);
  });

  test('OuterMessage pairing request round-trips with version and status', () {
    final m = OuterMessage(
      protocolVersion: 2,
      status: OuterMessage_Status.STATUS_OK,
      pairingRequest: PairingRequest(
        serviceName: 'atvremote',
        clientName: 'Phone',
      ),
    );
    final decoded = OuterMessage.fromBuffer(m.writeToBuffer());
    expect(decoded.protocolVersion, 2);
    expect(decoded.status, OuterMessage_Status.STATUS_OK);
    expect(decoded.pairingRequest.serviceName, 'atvremote');
    expect(decoded.pairingRequest.clientName, 'Phone');
  });
}
