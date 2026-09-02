import 'dart:typed_data';

import 'commands.dart';
import 'crc16_modbus.dart';
import 'protocol_frame.dart';

class ProtocolFrameEncoder {
  const ProtocolFrameEncoder();

  /// Encodes CRC as high byte followed by low byte, as specified by the
  /// project protocol document. This differs from the common MODBUS wire
  /// convention, which is why the ordering is explicit here.
  Uint8List encode({required int command, List<int> payload = const []}) {
    if (command < 0 || command > 0xFF) {
      throw RangeError.range(command, 0, 0xFF, 'command');
    }
    if (payload.length > ProtocolFrame.maximumPayloadLength) {
      throw RangeError.range(
        payload.length,
        0,
        ProtocolFrame.maximumPayloadLength,
        'payload.length',
      );
    }
    for (final byte in payload) {
      if (byte < 0 || byte > 0xFF) {
        throw RangeError.range(byte, 0, 0xFF, 'payload byte');
      }
    }

    final crcInput = <int>[command, payload.length, ...payload];
    final crc = crc16Modbus(crcInput);
    return Uint8List.fromList([
      ProtocolFrame.head1,
      ProtocolFrame.head2,
      ...crcInput,
      (crc >> 8) & 0xFF,
      crc & 0xFF,
    ]);
  }

  Uint8List encodeCommand(
    PcMcuCommand command, {
    List<int> payload = const [],
  }) {
    if (!command.acceptsPayloadLength(payload.length)) {
      throw ArgumentError.value(
        payload.length,
        'payload.length',
        '${command.name} expects ${command.payloadLength ?? 'a variable-length'} payload',
      );
    }
    return encode(command: command.id, payload: payload);
  }
}
