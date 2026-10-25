import 'package:atv_remote/src/framing.dart';
import 'package:test/test.dart';

void main() {
  group('encodeFrame', () {
    test('encodes short payload with 1-byte varint', () {
      expect(encodeFrame([1, 2, 3]), orderedEquals([3, 1, 2, 3]));
    });

    test('encodes 300-byte payload with 2-byte varint', () {
      final f = encodeFrame(List.filled(300, 7));
      expect(f.sublist(0, 2), orderedEquals([0xAC, 0x02]));
      expect(f.length, 302);
    });

    test('encodes empty payload as a single zero length byte', () {
      expect(encodeFrame(const []), orderedEquals([0]));
    });
  });

  group('FrameDecoder', () {
    test('decoder reassembles frames split across chunks', () {
      final d = FrameDecoder();
      expect(d.add([3, 1]), isEmpty);
      expect(
        d.add([2, 3, 2, 9]),
        orderedEquals([
          orderedEquals([1, 2, 3]),
        ]),
      );
      expect(
        d.add([9]),
        orderedEquals([
          orderedEquals([9, 9]),
        ]),
      );
    });

    test('decoder returns multiple frames from one chunk', () {
      expect(
        FrameDecoder().add([1, 5, 1, 6]),
        orderedEquals([
          orderedEquals([5]),
          orderedEquals([6]),
        ]),
      );
    });

    test('decoder buffers a partially received varint', () {
      final d = FrameDecoder();
      // 300 is encoded as 0xAC 0x02; feed the first varint byte alone.
      expect(d.add([0xAC]), isEmpty);
      final payload = List.filled(300, 7);
      final out = d.add([0x02, ...payload]);
      expect(out, hasLength(1));
      expect(out.single, orderedEquals(payload));
    });

    test('decoder handles one byte at a time', () {
      final frame = encodeFrame([0xDE, 0xAD, 0xBE, 0xEF]);
      final d = FrameDecoder();
      final out = <List<int>>[];
      for (final b in frame) {
        out.addAll(d.add([b]));
      }
      expect(
        out,
        orderedEquals([
          orderedEquals([0xDE, 0xAD, 0xBE, 0xEF]),
        ]),
      );
    });

    test('decoder rejects frames larger than 1 MiB', () {
      expect(
        () => FrameDecoder().add([0x80, 0x80, 0x80, 0x01]),
        throwsA(isA<FrameTooLargeException>()),
      );
    });

    test('decoder rejects a varint longer than 5 bytes', () {
      expect(
        () => FrameDecoder().add([0x80, 0x80, 0x80, 0x80, 0x80, 0x01]),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
