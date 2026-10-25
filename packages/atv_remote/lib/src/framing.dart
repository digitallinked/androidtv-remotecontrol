import 'dart:typed_data';

/// Largest payload accepted in either direction: 1 MiB.
const int maxFrameSize = 1024 * 1024;

/// Longest varint length prefix accepted. Five 7-bit groups cover 35 bits,
/// far more than [maxFrameSize] needs, so a longer varint is malformed.
const int _maxVarintBytes = 5;

/// Thrown when a frame's declared or actual size exceeds [maxFrameSize].
class FrameTooLargeException implements Exception {
  /// Creates an exception reporting a frame of [size] bytes.
  const FrameTooLargeException(this.size);

  /// The offending frame size in bytes.
  final int size;

  @override
  String toString() =>
      'FrameTooLargeException: frame of $size bytes exceeds the '
      '$maxFrameSize byte limit';
}

/// Prefixes [payload] with its byte length encoded as a protobuf varint.
///
/// Throws a [FrameTooLargeException] if [payload] is longer than
/// [maxFrameSize].
Uint8List encodeFrame(List<int> payload) {
  if (payload.length > maxFrameSize) {
    throw FrameTooLargeException(payload.length);
  }

  final header = <int>[];
  var remaining = payload.length;
  do {
    var group = remaining & 0x7F;
    remaining >>= 7;
    if (remaining != 0) group |= 0x80;
    header.add(group);
  } while (remaining != 0);

  final frame = Uint8List(header.length + payload.length)
    ..setRange(0, header.length, header)
    ..setRange(header.length, header.length + payload.length, payload);
  return frame;
}

/// Reassembles length-prefixed frames from a stream of arbitrary chunks.
///
/// Input may be split at any byte boundary, including inside a length varint
/// or inside a payload. Partial data is buffered until the rest arrives.
///
/// A [FormatException] or [FrameTooLargeException] means the byte stream is
/// corrupt; the decoder should be discarded along with its connection.
class FrameDecoder {
  final List<int> _buffer = <int>[];

  /// Appends [chunk] and returns every frame payload it completes, in order.
  ///
  /// Returns an empty list when no complete frame is available yet.
  List<Uint8List> add(List<int> chunk) {
    _buffer.addAll(chunk);

    final frames = <Uint8List>[];
    while (true) {
      final header = _readVarint();
      if (header == null) break;

      final (length, headerSize) = header;
      if (length > maxFrameSize) throw FrameTooLargeException(length);

      final total = headerSize + length;
      if (_buffer.length < total) break;

      frames.add(Uint8List.fromList(_buffer.sublist(headerSize, total)));
      _buffer.removeRange(0, total);
    }
    return frames;
  }

  /// Parses the varint at the start of the buffer without consuming it.
  ///
  /// Returns `(value, byteCount)`, or `null` if the varint is incomplete.
  (int, int)? _readVarint() {
    var value = 0;
    var multiplier = 1;
    for (var i = 0; i < _maxVarintBytes; i++) {
      if (i >= _buffer.length) return null;
      final byte = _buffer[i];
      value += (byte & 0x7F) * multiplier;
      if ((byte & 0x80) == 0) return (value, i + 1);
      multiplier *= 0x80;
    }
    throw const FormatException('Varint length prefix longer than 5 bytes');
  }
}
