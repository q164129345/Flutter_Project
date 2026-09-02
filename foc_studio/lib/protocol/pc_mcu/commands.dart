enum PcMcuDirection { pcToMcu, mcuToPc }

/// Commands defined by the PC-MCU binary protocol.
///
/// [payloadLength] is `null` only for commands whose payload is variable-sized.
enum PcMcuCommand {
  motorControl(0x01, PcMcuDirection.pcToMcu, 3),
  heartbeat(0x02, PcMcuDirection.pcToMcu, 0),
  querySoftwareVersion(0x03, PcMcuDirection.pcToMcu, 0),
  queryMotorType(0x04, PcMcuDirection.pcToMcu, 0),
  querySpeedLoopParameters(0x05, PcMcuDirection.pcToMcu, 0),
  queryCurrentLoopParameters(0x06, PcMcuDirection.pcToMcu, 0),
  setSpeedLoopParameters(0x07, PcMcuDirection.pcToMcu, 20),
  setCurrentLoopParameters(0x08, PcMcuDirection.pcToMcu, 40),
  rebootMcu(0x0A, PcMcuDirection.pcToMcu, 0),
  queryMotorLimits(0x0B, PcMcuDirection.pcToMcu, 0),
  setMotorLimits(0x0C, PcMcuDirection.pcToMcu, 8),
  queryDipSwitchId(0x0D, PcMcuDirection.pcToMcu, 0),
  queryExternalFlashId(0x0E, PcMcuDirection.pcToMcu, 0),

  speedFeedback(0x64, PcMcuDirection.mcuToPc, 6),
  motorTemperature(0x65, PcMcuDirection.mcuToPc, 2),
  mosTemperature(0x66, PcMcuDirection.mcuToPc, 2),
  motorEnableState(0x67, PcMcuDirection.mcuToPc, 1),
  softwareVersionResponse(0x68, PcMcuDirection.mcuToPc, 4),
  dqFeedback(0x69, PcMcuDirection.mcuToPc, 12),
  motorCurrent(0x6A, PcMcuDirection.mcuToPc, 6),
  errorCode(0x6C, PcMcuDirection.mcuToPc, 2),
  motorTypeResponse(0x6D, PcMcuDirection.mcuToPc, 1),
  speedLoopParametersResponse(0x6E, PcMcuDirection.mcuToPc, 20),
  currentLoopParametersResponse(0x6F, PcMcuDirection.mcuToPc, 40),
  dipSwitchIdResponse(0x71, PcMcuDirection.mcuToPc, 1),
  motorLimitsResponse(0x72, PcMcuDirection.mcuToPc, 8),
  logMessage(0x73, PcMcuDirection.mcuToPc, null),
  hallSensorState(0x74, PcMcuDirection.mcuToPc, 9),
  absoluteSensorInfo(0x75, PcMcuDirection.mcuToPc, 8),
  externalFlashIdResponse(0x76, PcMcuDirection.mcuToPc, 2);

  const PcMcuCommand(this.id, this.direction, this.payloadLength);

  final int id;
  final PcMcuDirection direction;
  final int? payloadLength;

  bool acceptsPayloadLength(int length) {
    if (this == PcMcuCommand.logMessage) {
      // One byte for the log level, followed by at most 254 ASCII bytes.
      return length >= 1 && length <= 255;
    }
    return length == payloadLength;
  }

  static PcMcuCommand? tryFromId(int id) {
    for (final command in values) {
      if (command.id == id) {
        return command;
      }
    }
    return null;
  }
}
