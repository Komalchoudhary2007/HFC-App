import 'dart:typed_data';

class Hc20Frame {
  final int func;
  final Uint8List payload;
  Hc20Frame(this.func, this.payload);
}

class Hc20Codec {
  static const int header = 0x68;
  static const int tail = 0x16;

  static List<int> encode(int func, List<int> payload) {
    final len = payload.length;
    final bb = BytesBuilder();
    bb.add([header, func]);
    bb.add(_le16(len));
    bb.add(payload);
    final sum = _checksum(bb.toBytes());
    bb.add([sum, tail]);
    return bb.toBytes();
  }

  static Iterable<Hc20Frame> tryDecodeMany(Uint8List buffer) sync* {
    int i = 0;
    while (i + 6 <= buffer.length) {
      if (buffer[i] != header) { i++; continue; }
      final func = buffer[i + 1];
      final len = buffer[i + 2] | (buffer[i + 3] << 8);
      // Compute exclusive end index for the frame [i, endExclusive)
      final endExclusive = i + 1 + 1 + 2 + len + 1 + 1;
      if (endExclusive > buffer.length) break; // need full frame
      final tailIndex = endExclusive - 1;
      if (buffer[tailIndex] != tail) { i++; continue; }
      final csIndex = endExclusive - 2;
      final cs = buffer[csIndex];
      final calc = _checksum(buffer.sublist(i, csIndex));
      if (cs != calc) { i++; continue; }
      final payload = Uint8List.fromList(buffer.sublist(i + 4, i + 4 + len));
      yield Hc20Frame(func, payload);
      i = endExclusive;
    }
  }
  
  /// Decode frames and return both the frames and the number of bytes consumed
  /// This allows the caller to properly manage the buffer without losing incomplete frames
  static DecodeResult decodeMany(Uint8List buffer) {
    final frames = <Hc20Frame>[];
    int i = 0;
    while (i + 6 <= buffer.length) {
      if (buffer[i] != header) { i++; continue; }
      final func = buffer[i + 1];
      final len = buffer[i + 2] | (buffer[i + 3] << 8);
      // Compute exclusive end index for the frame [i, endExclusive)
      final endExclusive = i + 1 + 1 + 2 + len + 1 + 1;
      if (endExclusive > buffer.length) break; // need full frame
      final tailIndex = endExclusive - 1;
      if (buffer[tailIndex] != tail) { i++; continue; }
      final csIndex = endExclusive - 2;
      final cs = buffer[csIndex];
      final calc = _checksum(buffer.sublist(i, csIndex));
      if (cs != calc) { i++; continue; }
      final payload = Uint8List.fromList(buffer.sublist(i + 4, i + 4 + len));
      frames.add(Hc20Frame(func, payload));
      i = endExclusive;
    }
    return DecodeResult(frames, i);
  }

  static int _checksum(List<int> data) => data.fold<int>(0, (a, b) => (a + b) & 0xFF);
  static List<int> _le16(int v) => [v & 0xFF, (v >> 8) & 0xFF];
}

class DecodeResult {
  final List<Hc20Frame> frames;
  final int consumedBytes;
  DecodeResult(this.frames, this.consumedBytes);
}


