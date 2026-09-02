import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:foc_studio/controllers/foc_controller.dart';
import 'package:foc_studio/protocol/pc_mcu/frame_encoder.dart';
import 'package:foc_studio/services/serial_port_service.dart';

void main() {
  testWidgets(
    'protocol errors keep sending, but disconnect stops every periodic send',
    (tester) async {
      final serialService = _FakeConnectedSerialPortService();
      final controller = FocController(serialService);
      addTearDown(() {
        controller.dispose();
        serialService.dispose();
      });

      // Ignore the heartbeat and initial queries sent when the session starts.
      serialService.writes.clear();
      expect(
        controller.setMotorControl(enabled: true, targetSpeedRpm: 1200),
        isTrue,
      );

      // This is a transport-valid frame whose payload cannot be decoded as a
      // motor-temperature message. It is a protocol error, not a disconnect.
      const encoder = ProtocolFrameEncoder();
      serialService.addReceived(
        encoder.encode(command: 0x65, payload: const [0x01]),
      );
      await tester.pump();

      expect(controller.lastProtocolError, isNotNull);
      expect(controller.isConnected, isTrue);
      expect(controller.motorControlEnabled, isTrue);

      final motorWritesBeforeTimer = serialService.motorControlWriteCount;
      await tester.pump(FocController.motorControlInterval);
      expect(
        serialService.motorControlWriteCount,
        greaterThan(motorWritesBeforeTimer),
      );

      serialService.simulateDisconnect();
      final writesAtDisconnect = serialService.writes.length;

      expect(controller.isConnected, isFalse);
      expect(controller.motorControlEnabled, isFalse);
      expect(controller.targetSpeedRpm, 0);

      await tester.pump(const Duration(seconds: 2));
      expect(serialService.writes, hasLength(writesAtDisconnect));
    },
  );
}

class _FakeConnectedSerialPortService extends SerialPortService {
  final StreamController<Uint8List> _receivedController =
      StreamController<Uint8List>.broadcast(sync: true);
  final List<Uint8List> writes = <Uint8List>[];

  SerialPortConnectionStatus _status = SerialPortConnectionStatus.connected;
  bool _connected = true;

  @override
  SerialPortConnectionStatus get connectionStatus => _status;

  @override
  bool get isConnected => _connected;

  @override
  Stream<Uint8List> get receivedBytesStream => _receivedController.stream;

  int get motorControlWriteCount =>
      writes.where((frame) => frame.length > 2 && frame[2] == 0x01).length;

  void addReceived(Uint8List bytes) {
    _receivedController.add(bytes);
  }

  void simulateDisconnect() {
    _connected = false;
    _status = SerialPortConnectionStatus.disconnected;
    notifyListeners();
  }

  @override
  int sendBytes(List<int> bytes) {
    if (!_connected) {
      throw StateError('串口没有连接');
    }
    writes.add(Uint8List.fromList(bytes));
    return bytes.length;
  }

  @override
  void dispose() {
    _receivedController.close();
    super.dispose();
  }
}
