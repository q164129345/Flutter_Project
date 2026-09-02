import 'dart:typed_data';

import 'crc16_modbus.dart';
import 'protocol_frame.dart';

/// Incrementally turns arbitrary serial chunks into validated protocol frames.
///
/// A serial read can contain part of a frame or several frames. The decoder
/// therefore owns a buffer and must live for the whole serial session.
class ProtocolFrameDecoder {
  final List<int> _buffer = <int>[];

  int _discardedByteCount = 0;
  int _crcErrorCount = 0;
  int _decodeFailureCount = 0;

  int get bufferedByteCount => _buffer.length;
  int get discardedByteCount => _discardedByteCount;
  int get crcErrorCount => _crcErrorCount;

  /// Number of complete frame candidates rejected while unpacking.
  ///
  /// Receiving only part of a frame is normal serial-stream behavior and is
  /// deliberately not counted as a failure; the bytes remain in [_buffer]
  /// until later chunks complete the candidate.
  int get decodeFailureCount => _decodeFailureCount;

  List<ProtocolFrame> addChunk(Uint8List chunk) {
    if (chunk.isNotEmpty) {
      _buffer.addAll(chunk);
    }

    final frames = <ProtocolFrame>[];
    while (true) {
      final headerIndex = _findHeader();
      if (headerIndex < 0) {
        _discardBytesWithoutHeader();
        break;
      }

      if (headerIndex > 0) {
        _buffer.removeRange(0, headerIndex);
        _discardedByteCount += headerIndex;
      }

      // Head1 + Head2 + CMD + LEN
      if (_buffer.length < 4) {
        break;
      }

      final payloadLength = _buffer[3];
      final frameLength = ProtocolFrame.frameOverhead + payloadLength;
      if (_buffer.length < frameLength) {
        break;
      }

      final crcInputEnd = 4 + payloadLength;
      final calculatedCrc = crc16Modbus(_buffer.sublist(2, crcInputEnd));
      final receivedCrc =
          (_buffer[crcInputEnd] << 8) | _buffer[crcInputEnd + 1];

      if (receivedCrc != calculatedCrc) {
        // Discard only the first header byte. A valid frame may start inside
        // the rejected candidate, so throwing away the whole candidate could
        // lose synchronization.
        _buffer.removeAt(0);
        _discardedByteCount++;
        _crcErrorCount++;
        _decodeFailureCount++;
        continue;
      }

      frames.add(
        ProtocolFrame(
          command: _buffer[2],
          payload: _buffer.sublist(4, crcInputEnd),
        ),
      );
      _buffer.removeRange(0, frameLength);
    }

    return frames;
  }

  void reset() {
    _buffer.clear();
    _discardedByteCount = 0;
    _crcErrorCount = 0;
    _decodeFailureCount = 0;
  }

  int _findHeader() {
    for (var index = 0; index + 1 < _buffer.length; index++) {
      if (_buffer[index] == ProtocolFrame.head1 &&
          _buffer[index + 1] == ProtocolFrame.head2) {
        return index;
      }
    }
    return -1;
  }

  void _discardBytesWithoutHeader() {
    if (_buffer.isEmpty) {
      return;
    }

    // Keep a trailing 0xAA because the next serial chunk may start with 0xBB.
    final keepTrailingHead1 = _buffer.last == ProtocolFrame.head1;
    final discardCount = _buffer.length - (keepTrailingHead1 ? 1 : 0);
    if (discardCount > 0) {
      _buffer.removeRange(0, discardCount);
      _discardedByteCount += discardCount;
    }
  }
}
