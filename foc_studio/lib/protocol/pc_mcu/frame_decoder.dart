import 'dart:typed_data';

import 'commands.dart';
import 'crc16_modbus.dart';
import 'protocol_frame.dart';

/// 增量解包器：把任意大小的串口字节块拼成通过校验的完整协议帧。
///
/// 一次读取可能只有半帧，也可能包含多帧，因此整个连接期间复用同一个解包器。
/// 未收齐的数据留到下一次 addChunk，不能为每个字节块重新创建解包器。
class ProtocolFrameDecoder {
  final List<int> _buffer = <int>[];
  // 指向尚未处理的数据起点。消费一帧时只移动游标，不立即搬移后面的所有字节。
  int _readOffset = 0;

  int _discardedByteCount = 0;
  int _crcErrorCount = 0;
  int _decodeFailureCount = 0;

  int get bufferedByteCount => _buffer.length - _readOffset;
  int get discardedByteCount => _discardedByteCount;
  int get crcErrorCount => _crcErrorCount;

  /// 被判定为无效的候选帧数，例如长度错误或 CRC 不匹配。
  ///
  /// 半帧是正常的串口分段现象，不计失败；它会保存在缓冲区中等待后续字节。
  int get decodeFailureCount => _decodeFailureCount;

  /// 追加新字节并取出当前能解出的全部完整帧；数据不足时立即返回，不等待补包。
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

      if (headerIndex > _readOffset) {
        _discardedByteCount += headerIndex - _readOffset;
        _readOffset = headerIndex;
      }

      // 至少收到两个帧头字节、命令和长度后，才能知道这一帧需要多少数据。
      if (bufferedByteCount < 4) {
        break;
      }

      final payloadLength = _buffer[_readOffset + 3];
      final command = PcMcuCommand.tryFromId(_buffer[_readOffset + 2]);
      final expectedPayloadLength = command?.payloadLength;
      if (expectedPayloadLength != null &&
          payloadLength != expectedPayloadLength) {
        // 已知命令的长度不符时立即重新找帧头，避免错误 LEN 让后续好帧一直等待。
        // 只跳过第一个帧头字节，保留在后续字节中重新找到正确帧头的机会。
        _readOffset++;
        _discardedByteCount++;
        _decodeFailureCount++;
        continue;
      }

      final frameLength = ProtocolFrame.frameOverhead + payloadLength;
      if (bufferedByteCount < frameLength) {
        // 保留半帧并结束本轮；下次接收回调会把后续部分接在它后面。
        break;
      }

      // 协议约定 CRC 覆盖 CMD + LEN + DATA，不包含前面的 AA BB。
      // 直接按缓冲区索引计算，避免每帧先 sublist 复制一份校验输入。
      final crcInputEnd = _readOffset + 4 + payloadLength;
      final calculatedCrc = crc16ModbusRange(
        _buffer,
        _readOffset + 2,
        crcInputEnd,
      );
      final receivedCrc =
          (_buffer[crcInputEnd] << 8) | _buffer[crcInputEnd + 1];

      if (receivedCrc != calculatedCrc) {
        // 校验失败时只跳过一个字节。坏帧的候选范围内仍可能包含真正的帧头，
        // 直接扔掉整个候选帧可能连后面的好帧一起丢失。
        _readOffset++;
        _discardedByteCount++;
        _crcErrorCount++;
        _decodeFailureCount++;
        continue;
      }

      frames.add(
        ProtocolFrame.fromRange(
          command: _buffer[_readOffset + 2],
          bytes: _buffer,
          start: _readOffset + 4,
          end: crcInputEnd,
        ),
      );
      _readOffset += frameLength;
    }

    // 每次处理完一个接收块才清理一次已消费前缀，保留待补齐的数据。
    // 若每解出一帧就 removeRange，批量多帧输入会反复搬移同一批剩余字节。
    if (_readOffset == _buffer.length) {
      _buffer.clear();
    } else if (_readOffset > 0) {
      _buffer.removeRange(0, _readOffset);
    }
    _readOffset = 0;
    return frames;
  }

  /// 连接结束时清空状态，防止上次会话的半帧与新连接的数据拼在一起。
  void reset() {
    _buffer.clear();
    _readOffset = 0;
    _discardedByteCount = 0;
    _crcErrorCount = 0;
    _decodeFailureCount = 0;
  }

  int _findHeader() {
    for (var index = _readOffset; index + 1 < _buffer.length; index++) {
      if (_buffer[index] == ProtocolFrame.head1 &&
          _buffer[index + 1] == ProtocolFrame.head2) {
        return index;
      }
    }
    return -1;
  }

  void _discardBytesWithoutHeader() {
    if (bufferedByteCount == 0) {
      return;
    }

    // 尾部单独的 AA 可能是跨接收块的帧头，下一块首字节可能就是 BB，必须保留。
    final keepTrailingHead1 = _buffer.last == ProtocolFrame.head1;
    final discardCount = bufferedByteCount - (keepTrailingHead1 ? 1 : 0);
    if (discardCount > 0) {
      _readOffset += discardCount;
      _discardedByteCount += discardCount;
    }
  }
}
