import '../commands.dart';
import 'mcu_message.dart';

class SpeedFeedbackMessage extends McuMessage {
  const SpeedFeedbackMessage({required this.rpm, required this.mcuTickMs});

  final int rpm;
  final int mcuTickMs;

  @override
  PcMcuCommand get command => PcMcuCommand.speedFeedback;
}

class MotorTemperatureMessage extends McuMessage {
  const MotorTemperatureMessage(this.celsius);

  final double celsius;

  @override
  PcMcuCommand get command => PcMcuCommand.motorTemperature;
}

class MosTemperatureMessage extends McuMessage {
  const MosTemperatureMessage(this.celsius);

  final double celsius;

  @override
  PcMcuCommand get command => PcMcuCommand.mosTemperature;
}

class MotorEnableStateMessage extends McuMessage {
  const MotorEnableStateMessage(this.enabled);

  final bool enabled;

  @override
  PcMcuCommand get command => PcMcuCommand.motorEnableState;
}

class DqFeedbackMessage extends McuMessage {
  const DqFeedbackMessage({
    required this.iq,
    required this.id,
    required this.uq,
    required this.ud,
    required this.mcuTickMs,
  });

  final double iq;
  final double id;
  final double uq;
  final double ud;
  final int mcuTickMs;

  @override
  PcMcuCommand get command => PcMcuCommand.dqFeedback;
}

class MotorCurrentMessage extends McuMessage {
  const MotorCurrentMessage({required this.amperes, required this.mcuTickMs});

  final double amperes;
  final int mcuTickMs;

  @override
  PcMcuCommand get command => PcMcuCommand.motorCurrent;
}

class ErrorCodeMessage extends McuMessage {
  const ErrorCodeMessage(this.code);

  final int code;

  @override
  PcMcuCommand get command => PcMcuCommand.errorCode;
}

enum McuLogLevel {
  info(0),
  warning(1),
  error(2);

  const McuLogLevel(this.protocolValue);

  final int protocolValue;

  static McuLogLevel? tryFromProtocolValue(int value) {
    for (final level in values) {
      if (level.protocolValue == value) {
        return level;
      }
    }
    return null;
  }
}

class McuLogMessage extends McuMessage {
  const McuLogMessage({required this.level, required this.text});

  final McuLogLevel level;
  final String text;

  @override
  PcMcuCommand get command => PcMcuCommand.logMessage;
}

class HallSensorStateMessage extends McuMessage {
  const HallSensorStateMessage({
    required this.hallA,
    required this.hallB,
    required this.hallC,
    required this.hallState,
    required this.electricSector,
    required this.mcuTickMs,
  });

  final bool hallA;
  final bool hallB;
  final bool hallC;
  final int hallState;
  final int electricSector;
  final int mcuTickMs;

  bool get isValid => hallState >= 1 && hallState <= 6 && electricSector >= 0;

  @override
  PcMcuCommand get command => PcMcuCommand.hallSensorState;
}

class AbsoluteSensorInfoMessage extends McuMessage {
  const AbsoluteSensorInfoMessage({
    required this.pulseCounter,
    required this.countsPerRevolution,
  });

  final int pulseCounter;
  final int countsPerRevolution;

  double? get mechanicalAngleRadians {
    if (countsPerRevolution == 0) {
      return null;
    }
    return pulseCounter / countsPerRevolution * 2 * 3.141592653589793;
  }

  @override
  PcMcuCommand get command => PcMcuCommand.absoluteSensorInfo;
}
