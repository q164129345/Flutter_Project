import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:foc_studio/protocol/pc_mcu/crc16_modbus.dart';
import 'package:foc_studio/protocol/pc_mcu/frame_decoder.dart';
import 'package:foc_studio/protocol/pc_mcu/frame_encoder.dart';
import 'package:foc_studio/protocol/pc_mcu/protocol_frame.dart';

void main() {
  group('CRC16-MODBUS', () {
    test('matches the standard check value', () {
      expect(crc16Modbus(ascii.encode('123456789')), 0x4B37);
    });
  });

  group('PC-MCU frame codec', () {
    const encoder = ProtocolFrameEncoder();

    test('encodes CRC high byte before low byte', () {
      expect(
        encoder.encode(command: 0x02),
        Uint8List.fromList([0xAA, 0xBB, 0x02, 0x00, 0xD0, 0x00]),
      );
    });

    test('decodes a frame received one byte at a time', () {
      final decoder = ProtocolFrameDecoder();
      final encoded = encoder.encode(
        command: 0x64,
        payload: [0xFB, 0x2E, 0x01, 0x02, 0x03, 0x04],
      );
      final decoded = <ProtocolFrame>[];

      for (final byte in encoded) {
        decoded.addAll(decoder.addChunk(Uint8List.fromList([byte])));
      }

      expect(decoded, hasLength(1));
      final frame = decoded.single;
      expect(frame.command, 0x64);
      expect(
        frame.payload,
        Uint8List.fromList([0xFB, 0x2E, 0x01, 0x02, 0x03, 0x04]),
      );
      expect(decoder.bufferedByteCount, 0);
      expect(decoder.decodeFailureCount, 0);
    });

    test('keeps an incomplete frame without recording a decode failure', () {
      final decoder = ProtocolFrameDecoder();
      final encoded = encoder.encode(command: 0x67, payload: [0x01]);

      expect(
        decoder.addChunk(Uint8List.fromList(encoded.sublist(0, 3))),
        isEmpty,
      );
      expect(decoder.bufferedByteCount, 3);
      expect(decoder.decodeFailureCount, 0);

      final frames = decoder.addChunk(Uint8List.fromList(encoded.sublist(3)));
      expect(frames, hasLength(1));
      expect(frames.single.command, 0x67);
      expect(decoder.bufferedByteCount, 0);
      expect(decoder.decodeFailureCount, 0);
    });

    test('keeps a trailing first header byte between chunks', () {
      final decoder = ProtocolFrameDecoder();
      expect(decoder.addChunk(Uint8List.fromList([0x10, 0x20, 0xAA])), isEmpty);

      final remainder = encoder.encode(command: 0x02).sublist(1);
      final frames = decoder.addChunk(Uint8List.fromList(remainder));

      expect(frames, hasLength(1));
      expect(frames.single.command, 0x02);
      expect(decoder.discardedByteCount, 2);
    });

    test('decodes multiple frames from one serial chunk', () {
      final decoder = ProtocolFrameDecoder();
      final first = encoder.encode(command: 0x65, payload: [0x00, 0xFA]);
      final second = encoder.encode(command: 0x67, payload: [0x01]);

      final frames = decoder.addChunk(
        Uint8List.fromList([...first, ...second]),
      );

      expect(frames.map((frame) => frame.command), [0x65, 0x67]);
    });

    test('recovers from a corrupt frame and leading garbage', () {
      final decoder = ProtocolFrameDecoder();
      final corrupt = encoder.encode(command: 0x65, payload: [0x00, 0xFA]);
      corrupt[corrupt.length - 1] ^= 0x01;
      final valid = encoder.encode(command: 0x67, payload: [0x01]);

      final frames = decoder.addChunk(
        Uint8List.fromList([0x00, 0x11, ...corrupt, ...valid]),
      );

      expect(frames, hasLength(1));
      expect(frames.single.command, 0x67);
      expect(decoder.crcErrorCount, 1);
      expect(decoder.decodeFailureCount, 1);
    });
  });
}
