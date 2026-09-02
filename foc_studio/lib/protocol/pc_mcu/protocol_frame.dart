import 'dart:typed_data';

/// A complete frame whose header and CRC have already been validated.
class ProtocolFrame {
  ProtocolFrame({required this.command, required List<int> payload})
    : payload = Uint8List.fromList(payload);

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
