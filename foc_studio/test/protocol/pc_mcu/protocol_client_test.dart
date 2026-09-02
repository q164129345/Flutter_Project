import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:foc_studio/protocol/pc_mcu/frame_encoder.dart';
import 'package:foc_studio/protocol/pc_mcu/messages/telemetry_message.dart';
import 'package:foc_studio/protocol/pc_mcu/protocol_client.dart';
import 'package:foc_studio/services/serial_port_service.dart';

void main() {
  test('retries the unsent tail when a serial write is short', () {
    final serialService = _ShortWritingSerialPortService(maxWriteLength: 2);
    final client = PcMcuProtocolClient(serialService);
    addTearDown(() {
      client.dispose();
      serialService.dispose();
    });

    final written = client.sendHeartbeat();
    final expected = const ProtocolFrameEncoder().encode(command: 0x02);

    expect(written, expected.length);
    expect(serialService.acceptedBytes, expected);
    expect(serialService.writeCallCount, greaterThan(1));
  });

  test('fails without spinning when a serial write makes no progress', () {
    final serialService = _ShortWritingSerialPortService(maxWriteLength: 0);
    final client = PcMcuProtocolClient(serialService);
    addTearDown(() {
      client.dispose();
      serialService.dispose();
    });

    expect(client.sendHeartbeat, throwsStateError);
    expect(serialService.writeCallCount, 1);
  });

  test(
    'reassembles one MCU frame delivered in several stream chunks',
    () async {
      final serialService = _ShortWritingSerialPortService(maxWriteLength: 2);
      final client = PcMcuProtocolClient(serialService);
      addTearDown(() {
        client.dispose();
        serialService.dispose();
      });

      final message = expectLater(
        client.messages,
        emits(
          isA<MotorEnableStateMessage>().having(
            (value) => value.enabled,
            'enabled',
            isTrue,
          ),
        ),
      );
      final frame = const ProtocolFrameEncoder().encode(
        command: 0x67,
        payload: const [0x01],
      );

      serialService
        ..addReceived(frame.sublist(0, 1))
        ..addReceived(frame.sublist(1, 4))
        ..addReceived(frame.sublist(4));

      await message;
      expect(client.frameDecodeFailureCount, 0);
    },
  );
}

class _ShortWritingSerialPortService extends SerialPortService {
  _ShortWritingSerialPortService({required this.maxWriteLength});

  final int maxWriteLength;
  final List<int> acceptedBytes = <int>[];
  final StreamController<Uint8List> _receivedController =
      StreamController<Uint8List>.broadcast();
  int writeCallCount = 0;

  @override
  SerialPortConnectionStatus get connectionStatus =>
      SerialPortConnectionStatus.connected;

  @override
  bool get isConnected => true;

  @override
  Stream<Uint8List> get receivedBytesStream => _receivedController.stream;

  void addReceived(List<int> bytes) {
    _receivedController.add(Uint8List.fromList(bytes));
  }

  @override
  int sendBytes(List<int> bytes) {
    writeCallCount++;
    final written = min(maxWriteLength, bytes.length);
    acceptedBytes.addAll(bytes.take(written));
    return written;
  }

  @override
  void dispose() {
    _receivedController.close();
    super.dispose();
  }
}
