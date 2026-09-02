import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:foc_studio/protocol/pc_mcu/frame_decoder.dart';
import 'package:foc_studio/protocol/pc_mcu/message_codec.dart';
import 'package:foc_studio/protocol/pc_mcu/messages/configuration_messages.dart';
import 'package:foc_studio/protocol/pc_mcu/messages/control_messages.dart';
import 'package:foc_studio/protocol/pc_mcu/messages/telemetry_message.dart';
import 'package:foc_studio/protocol/pc_mcu/protocol_frame.dart';

void main() {
  const codec = PcMcuMessageCodec();

  test('encodes motor control using signed big-endian RPM', () {
    final bytes = codec.encodeMotorControl(
      const MotorControlCommand(enabled: true, targetSpeedRpm: -1234),
    );
    final frame = ProtocolFrameDecoder().addChunk(bytes).single;

    expect(frame.command, 0x01);
    expect(frame.payload, Uint8List.fromList([0x01, 0xFB, 0x2E]));
  });

  test('decodes speed feedback and uint32 MCU tick in big endian', () {
    final message = codec.decode(
      ProtocolFrame(
        command: 0x64,
        payload: [0xFB, 0x2E, 0x01, 0x02, 0x03, 0x04],
      ),
    );

    expect(message, isA<SpeedFeedbackMessage>());
    final speed = message as SpeedFeedbackMessage;
    expect(speed.rpm, -1234);
    expect(speed.mcuTickMs, 0x01020304);
  });

  test('round-trips PID fixed-point payload values', () {
    const parameters = PidParameters(
      kp: 1.25,
      ki: -0.5,
      kd: 0.000001,
      ramp: 120.75,
      tf: 0.003,
    );

    final requestFrame = ProtocolFrameDecoder()
        .addChunk(codec.encodeSetSpeedLoopParameters(parameters))
        .single;
    final response =
        codec.decode(
              ProtocolFrame(command: 0x6E, payload: requestFrame.payload),
            )
            as SpeedLoopParametersMessage;

    expect(response.parameters.kp, closeTo(parameters.kp, 0.0000001));
    expect(response.parameters.ki, closeTo(parameters.ki, 0.0000001));
    expect(response.parameters.kd, closeTo(parameters.kd, 0.0000001));
    expect(response.parameters.ramp, closeTo(parameters.ramp, 0.0000001));
    expect(response.parameters.tf, closeTo(parameters.tf, 0.0000001));
  });

  test('decodes scaled DQ telemetry', () {
    final data = ByteData(12)
      ..setInt16(0, 1250, Endian.big)
      ..setInt16(2, -250, Endian.big)
      ..setInt16(4, 24000, Endian.big)
      ..setInt16(6, -12000, Endian.big)
      ..setUint32(8, 987654, Endian.big);

    final message =
        codec.decode(
              ProtocolFrame(command: 0x69, payload: data.buffer.asUint8List()),
            )
            as DqFeedbackMessage;

    expect(message.iq, 1.25);
    expect(message.id, -0.25);
    expect(message.uq, 24.0);
    expect(message.ud, -12.0);
    expect(message.mcuTickMs, 987654);
  });

  test('rejects a known command with the wrong payload length', () {
    expect(
      () => codec.decode(ProtocolFrame(command: 0x64, payload: [0x00])),
      throwsFormatException,
    );
  });

  test('rejects a non-binary motor enable state', () {
    expect(
      () => codec.decode(ProtocolFrame(command: 0x67, payload: [0x02])),
      throwsFormatException,
    );
  });

  test('all documented MCU-to-PC commands have a decoder', () {
    final frames = <ProtocolFrame>[
      ProtocolFrame(command: 0x64, payload: List.filled(6, 0)),
      ProtocolFrame(command: 0x65, payload: List.filled(2, 0)),
      ProtocolFrame(command: 0x66, payload: List.filled(2, 0)),
      ProtocolFrame(command: 0x67, payload: [0]),
      ProtocolFrame(command: 0x68, payload: List.filled(4, 0)),
      ProtocolFrame(command: 0x69, payload: List.filled(12, 0)),
      ProtocolFrame(command: 0x6A, payload: List.filled(6, 0)),
      ProtocolFrame(command: 0x6C, payload: List.filled(2, 0)),
      ProtocolFrame(command: 0x6D, payload: [1]),
      ProtocolFrame(command: 0x6E, payload: List.filled(20, 0)),
      ProtocolFrame(command: 0x6F, payload: List.filled(40, 0)),
      ProtocolFrame(command: 0x71, payload: [0]),
      ProtocolFrame(command: 0x72, payload: List.filled(8, 0)),
      ProtocolFrame(command: 0x73, payload: [0, 0x4F, 0x4B]),
      ProtocolFrame(command: 0x74, payload: [0, 0, 0, 0, 0xFF, 0, 0, 0, 0]),
      ProtocolFrame(command: 0x75, payload: List.filled(8, 0)),
      ProtocolFrame(command: 0x76, payload: List.filled(2, 0)),
    ];

    final messages = frames.map(codec.decode).toList();

    expect(messages, hasLength(17));
    expect(messages[0], isA<SpeedFeedbackMessage>());
    expect(messages[4], isA<SoftwareVersionMessage>());
    expect(messages[9], isA<SpeedLoopParametersMessage>());
    expect(messages[13], isA<McuLogMessage>());
    expect(messages[16], isA<ExternalFlashIdMessage>());
  });

  test('all documented PC-to-MCU commands have an encoder', () {
    const pid = PidParameters(kp: 0, ki: 0, kd: 0, ramp: 0, tf: 0);
    const currentLoops = CurrentLoopParameters(iq: pid, id: pid);
    const limits = MotorLimits(voltageLimit: 24, currentLimit: 10);

    final encodedFrames = <Uint8List>[
      codec.encodeMotorControl(
        const MotorControlCommand(enabled: false, targetSpeedRpm: 0),
      ),
      codec.encodeHeartbeat(),
      codec.encodeQuerySoftwareVersion(),
      codec.encodeQueryMotorType(),
      codec.encodeQuerySpeedLoopParameters(),
      codec.encodeQueryCurrentLoopParameters(),
      codec.encodeSetSpeedLoopParameters(pid),
      codec.encodeSetCurrentLoopParameters(currentLoops),
      codec.encodeRebootMcu(),
      codec.encodeQueryMotorLimits(),
      codec.encodeSetMotorLimits(limits),
      codec.encodeQueryDipSwitchId(),
      codec.encodeQueryExternalFlashId(),
    ];
    const expectedCommands = [
      0x01,
      0x02,
      0x03,
      0x04,
      0x05,
      0x06,
      0x07,
      0x08,
      0x0A,
      0x0B,
      0x0C,
      0x0D,
      0x0E,
    ];

    final decodedCommands = encodedFrames
        .map((bytes) => ProtocolFrameDecoder().addChunk(bytes).single.command)
        .toList();

    expect(decodedCommands, expectedCommands);
  });
}
