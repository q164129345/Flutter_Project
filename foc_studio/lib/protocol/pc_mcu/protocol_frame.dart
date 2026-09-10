import 'dart:typed_data';

/// 协议帧的数据容器；由解包器产出的实例已通过帧头和 CRC 校验。
class ProtocolFrame {
  ProtocolFrame({required this.command, required List<int> payload})
    : payload = Uint8List.fromList(payload);

  /// 从缓冲区的 payload 范围复制一次数据，避免 sublist 后再复制第二次。
  /// 这里不能直接保留缓冲区视图，否则下次压缩或清空缓冲区会影响已解出的帧。
  ProtocolFrame.fromRange({
    required this.command,
    required List<int> bytes,
    required int start,
    required int end,
  }) : payload = Uint8List(end - start)..setRange(0, end - start, bytes, start);

  static const int head1 = 0xAA;
  static const int head2 = 0xBB;
  static const int maximumPayloadLength = 0xFF;
  static const int frameOverhead = 6;

  final int command;
  final Uint8List payload;

  int get payloadLength => payload.length;

  @override
  String toString() {
    final commandHex = command.toRadixString(16).padLeft(2, '0').toUpperCase();
    return 'ProtocolFrame(command: 0x$commandHex, payloadLength: $payloadLength)';
  }
}
