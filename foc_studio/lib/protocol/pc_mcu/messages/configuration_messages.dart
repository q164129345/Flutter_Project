import '../commands.dart';
import 'control_messages.dart';
import 'mcu_message.dart';

class SoftwareVersionMessage extends McuMessage {
  const SoftwareVersionMessage({
    required this.main,
    required this.sub,
    required this.mini,
    required this.revision,
  });

  final int main;
  final int sub;
  final int mini;
  final int revision;

  String get displayName => '$main.$sub.$mini.$revision';

  @override
  PcMcuCommand get command => PcMcuCommand.softwareVersionResponse;
}

enum MotorType {
  unknown(0),
  sideBrushZhongling(1),
  rollerBrush(2),
  newSideBrush11050(3),
  zhonglingHubMotor(4),
  cutter08Nm(5),
  frxCutter04Nm(6);

  const MotorType(this.protocolValue);

  final int protocolValue;

  static MotorType? tryFromProtocolValue(int value) {
    for (final type in values) {
      if (type.protocolValue == value) {
        return type;
      }
    }
    return null;
  }
}

class MotorTypeMessage extends McuMessage {
  const MotorTypeMessage(this.rawType);

  final int rawType;

  MotorType? get type => MotorType.tryFromProtocolValue(rawType);
  bool get isKnown => rawType != 0 && type != null;

  @override
  PcMcuCommand get command => PcMcuCommand.motorTypeResponse;
}

class SpeedLoopParametersMessage extends McuMessage {
  const SpeedLoopParametersMessage(this.parameters);

  final PidParameters parameters;

  @override
  PcMcuCommand get command => PcMcuCommand.speedLoopParametersResponse;
}

class CurrentLoopParametersMessage extends McuMessage {
  const CurrentLoopParametersMessage(this.parameters);

  final CurrentLoopParameters parameters;

  @override
  PcMcuCommand get command => PcMcuCommand.currentLoopParametersResponse;
}

class DipSwitchIdMessage extends McuMessage {
  const DipSwitchIdMessage(this.id);

  final int id;

  @override
  PcMcuCommand get command => PcMcuCommand.dipSwitchIdResponse;
}

class MotorLimitsMessage extends McuMessage {
  const MotorLimitsMessage(this.limits);

  final MotorLimits limits;

  @override
  PcMcuCommand get command => PcMcuCommand.motorLimitsResponse;
}

class ExternalFlashIdMessage extends McuMessage {
  const ExternalFlashIdMessage({
    required this.manufacturerId,
    required this.deviceId,
  });

  final int manufacturerId;
  final int deviceId;

  @override
  PcMcuCommand get command => PcMcuCommand.externalFlashIdResponse;
}
