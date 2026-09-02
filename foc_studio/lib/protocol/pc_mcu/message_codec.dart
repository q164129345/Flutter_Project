import 'dart:convert';
import 'dart:typed_data';

import 'commands.dart';
import 'frame_encoder.dart';
import 'messages/configuration_messages.dart';
import 'messages/control_messages.dart';
import 'messages/mcu_message.dart';
import 'messages/telemetry_message.dart';
import 'protocol_frame.dart';

class PcMcuMessageCodec {
  const PcMcuMessageCodec({this.frameEncoder = const ProtocolFrameEncoder()});

  static const double _pidScale = 1000000;
  static const double _telemetryScale = 1000;

  final ProtocolFrameEncoder frameEncoder;

  McuMessage decode(ProtocolFrame frame) {
    final command = PcMcuCommand.tryFromId(frame.command);
    if (command == null) {
      return UnknownMcuMessage(
        commandId: frame.command,
        payload: frame.payload,
      );
    }
    if (command.direction != PcMcuDirection.mcuToPc) {
      throw FormatException(
        'Received PC-to-MCU command ${_hex(command.id)} from the MCU',
      );
    }
    if (!command.acceptsPayloadLength(frame.payloadLength)) {
      throw FormatException(
        '${command.name} payload length is ${frame.payloadLength}, '
        'expected ${command.payloadLength ?? '1..255'}',
      );
    }

    final payload = frame.payload;
    final data = ByteData.view(
      payload.buffer,
      payload.offsetInBytes,
      payload.lengthInBytes,
    );

    return switch (command) {
      PcMcuCommand.speedFeedback => SpeedFeedbackMessage(
        rpm: data.getInt16(0, Endian.big),
        mcuTickMs: data.getUint32(2, Endian.big),
      ),
      PcMcuCommand.motorTemperature => MotorTemperatureMessage(
        data.getInt16(0, Endian.big) / 10,
      ),
      PcMcuCommand.mosTemperature => MosTemperatureMessage(
        data.getInt16(0, Endian.big) / 10,
      ),
      PcMcuCommand.motorEnableState => MotorEnableStateMessage(
        _decodeBinaryFlag(payload[0], 'motor enable state'),
      ),
      PcMcuCommand.softwareVersionResponse => SoftwareVersionMessage(
        main: payload[0],
        sub: payload[1],
        mini: payload[2],
        revision: payload[3],
      ),
      PcMcuCommand.dqFeedback => DqFeedbackMessage(
        iq: data.getInt16(0, Endian.big) / _telemetryScale,
        id: data.getInt16(2, Endian.big) / _telemetryScale,
        uq: data.getInt16(4, Endian.big) / _telemetryScale,
        ud: data.getInt16(6, Endian.big) / _telemetryScale,
        mcuTickMs: data.getUint32(8, Endian.big),
      ),
      PcMcuCommand.motorCurrent => MotorCurrentMessage(
        amperes: data.getInt16(0, Endian.big) / _telemetryScale,
        mcuTickMs: data.getUint32(2, Endian.big),
      ),
      PcMcuCommand.errorCode => ErrorCodeMessage(data.getUint16(0, Endian.big)),
      PcMcuCommand.motorTypeResponse => MotorTypeMessage(payload[0]),
      PcMcuCommand.speedLoopParametersResponse => SpeedLoopParametersMessage(
        _decodePid(data, 0),
      ),
      PcMcuCommand.currentLoopParametersResponse =>
        CurrentLoopParametersMessage(
          CurrentLoopParameters(
            iq: _decodePid(data, 0),
            id: _decodePid(data, 20),
          ),
        ),
      PcMcuCommand.dipSwitchIdResponse => DipSwitchIdMessage(payload[0]),
      PcMcuCommand.motorLimitsResponse => MotorLimitsMessage(
        MotorLimits(
          voltageLimit: _decodeMicro(data.getInt32(0, Endian.big)),
          currentLimit: _decodeMicro(data.getInt32(4, Endian.big)),
        ),
      ),
      PcMcuCommand.logMessage => _decodeLogMessage(payload),
      PcMcuCommand.hallSensorState => HallSensorStateMessage(
        hallA: _decodeBinaryFlag(payload[0], 'Hall A'),
        hallB: _decodeBinaryFlag(payload[1], 'Hall B'),
        hallC: _decodeBinaryFlag(payload[2], 'Hall C'),
        hallState: payload[3],
        electricSector: data.getInt8(4),
        mcuTickMs: data.getUint32(5, Endian.big),
      ),
      PcMcuCommand.absoluteSensorInfo => AbsoluteSensorInfoMessage(
        pulseCounter: data.getUint32(0, Endian.big),
        countsPerRevolution: data.getUint32(4, Endian.big),
      ),
      PcMcuCommand.externalFlashIdResponse => ExternalFlashIdMessage(
        manufacturerId: payload[0],
        deviceId: payload[1],
      ),
      _ => throw FormatException(
        'No MCU message decoder for ${command.name} (${_hex(command.id)})',
      ),
    };
  }

  Uint8List encodeMotorControl(MotorControlCommand command) {
    _checkInt16(command.targetSpeedRpm, 'targetSpeedRpm');
    final payload = ByteData(3)
      ..setUint8(0, command.enabled ? 1 : 0)
      ..setInt16(1, command.targetSpeedRpm, Endian.big);
    return _encode(PcMcuCommand.motorControl, payload.buffer.asUint8List());
  }

  Uint8List encodeHeartbeat() => _encodeEmpty(PcMcuCommand.heartbeat);

  Uint8List encodeQuerySoftwareVersion() =>
      _encodeEmpty(PcMcuCommand.querySoftwareVersion);

  Uint8List encodeQueryMotorType() => _encodeEmpty(PcMcuCommand.queryMotorType);

  Uint8List encodeQuerySpeedLoopParameters() =>
      _encodeEmpty(PcMcuCommand.querySpeedLoopParameters);

  Uint8List encodeQueryCurrentLoopParameters() =>
      _encodeEmpty(PcMcuCommand.queryCurrentLoopParameters);

  Uint8List encodeSetSpeedLoopParameters(PidParameters parameters) {
    final payload = ByteData(20);
    _encodePid(payload, 0, parameters);
    return _encode(
      PcMcuCommand.setSpeedLoopParameters,
      payload.buffer.asUint8List(),
    );
  }

  Uint8List encodeSetCurrentLoopParameters(CurrentLoopParameters parameters) {
    final payload = ByteData(40);
    _encodePid(payload, 0, parameters.iq);
    _encodePid(payload, 20, parameters.id);
    return _encode(
      PcMcuCommand.setCurrentLoopParameters,
      payload.buffer.asUint8List(),
    );
  }

  Uint8List encodeRebootMcu() => _encodeEmpty(PcMcuCommand.rebootMcu);

  Uint8List encodeQueryMotorLimits() =>
      _encodeEmpty(PcMcuCommand.queryMotorLimits);

  Uint8List encodeSetMotorLimits(MotorLimits limits) {
    final payload = ByteData(8)
      ..setInt32(
        0,
        _encodeMicro(limits.voltageLimit, 'voltageLimit'),
        Endian.big,
      )
      ..setInt32(
        4,
        _encodeMicro(limits.currentLimit, 'currentLimit'),
        Endian.big,
      );
    return _encode(PcMcuCommand.setMotorLimits, payload.buffer.asUint8List());
  }

  Uint8List encodeQueryDipSwitchId() =>
      _encodeEmpty(PcMcuCommand.queryDipSwitchId);

  Uint8List encodeQueryExternalFlashId() =>
      _encodeEmpty(PcMcuCommand.queryExternalFlashId);

  Uint8List _encodeEmpty(PcMcuCommand command) => _encode(command, const []);

  Uint8List _encode(PcMcuCommand command, List<int> payload) {
    if (command.direction != PcMcuDirection.pcToMcu) {
      throw ArgumentError('${command.name} is not a PC-to-MCU command');
    }
    return frameEncoder.encodeCommand(command, payload: payload);
  }

  PidParameters _decodePid(ByteData data, int offset) {
    return PidParameters(
      kp: _decodeMicro(data.getInt32(offset, Endian.big)),
      ki: _decodeMicro(data.getInt32(offset + 4, Endian.big)),
      kd: _decodeMicro(data.getInt32(offset + 8, Endian.big)),
      ramp: _decodeMicro(data.getInt32(offset + 12, Endian.big)),
      tf: _decodeMicro(data.getInt32(offset + 16, Endian.big)),
    );
  }

  void _encodePid(ByteData data, int offset, PidParameters parameters) {
    data
      ..setInt32(offset, _encodeMicro(parameters.kp, 'kp'), Endian.big)
      ..setInt32(offset + 4, _encodeMicro(parameters.ki, 'ki'), Endian.big)
      ..setInt32(offset + 8, _encodeMicro(parameters.kd, 'kd'), Endian.big)
      ..setInt32(offset + 12, _encodeMicro(parameters.ramp, 'ramp'), Endian.big)
      ..setInt32(offset + 16, _encodeMicro(parameters.tf, 'tf'), Endian.big);
  }

  McuLogMessage _decodeLogMessage(Uint8List payload) {
    final level = McuLogLevel.tryFromProtocolValue(payload[0]);
    if (level == null) {
      throw FormatException('Unknown MCU log level ${payload[0]}');
    }
    return McuLogMessage(
      level: level,
      text: ascii.decode(payload.sublist(1), allowInvalid: true),
    );
  }

  bool _decodeBinaryFlag(int value, String fieldName) {
    if (value != 0 && value != 1) {
      throw FormatException('$fieldName must be 0 or 1, got $value');
    }
    return value == 1;
  }

  double _decodeMicro(int raw) => raw / _pidScale;

  int _encodeMicro(double value, String fieldName) {
    if (!value.isFinite) {
      throw ArgumentError.value(value, fieldName, 'must be finite');
    }
    final raw = (value * _pidScale).round();
    if (raw < -0x80000000 || raw > 0x7FFFFFFF) {
      throw ArgumentError.value(
        value,
        fieldName,
        'scaled value must fit in a signed 32-bit integer',
      );
    }
    return raw;
  }

  void _checkInt16(int value, String fieldName) {
    if (value < -0x8000 || value > 0x7FFF) {
      throw RangeError.range(value, -0x8000, 0x7FFF, fieldName);
    }
  }

  String _hex(int value) =>
      '0x${value.toRadixString(16).padLeft(2, '0').toUpperCase()}';
}
