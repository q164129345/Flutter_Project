import '../protocol/pc_mcu/messages/configuration_messages.dart';
import '../protocol/pc_mcu/messages/telemetry_message.dart';

/// 一条带时间的样本。T 表示具体数据类型，例如转速、电流或日志。
/// 遥测时间由后台对齐 MCU tick 得到；日志使用后台实际处理消息的时间。
class TimestampedSample<T> {
  const TimestampedSample({required this.value, required this.timestamp});
  final T value;
  final DateTime timestamp;
}

/// 某一时刻的业务显示快照，只包含数据，不包含串口、订阅或定时器。
///
/// 后台负责时间对齐和历史容量限制，只有 UI 请求时才整理并传回快照。
/// 字段不重新赋值，后台生成的历史列表也不可修改，避免 UI 改动后台采样结果。
class FocSnapshot {
  const FocSnapshot({
    this.isConnected = false,
    this.motorControlEnabled = false,
    this.targetSpeedRpm = 0,
    this.lastProtocolError,
    this.lastMessageAt,
    this.latestSpeed,
    this.latestDq,
    this.latestCurrent,
    this.latestHall,
    this.motorTemperature,
    this.mosTemperature,
    this.reportedEnableState,
    this.errorCode,
    this.absoluteSensorInfo,
    this.softwareVersion,
    this.motorType,
    this.speedLoopParameters,
    this.currentLoopParameters,
    this.motorLimits,
    this.dipSwitchId,
    this.externalFlashId,
    this.speedHistory = const [],
    this.dqHistory = const [],
    this.currentHistory = const [],
    this.hallHistory = const [],
    this.logs = const [],
  });

  // 会话状态与最近通信情况；尚未收到对应数据时，可空字段保持 null。
  final bool isConnected;
  final bool motorControlEnabled;
  final int targetSpeedRpm;
  final String? lastProtocolError;
  final DateTime? lastMessageAt;
  // 最新遥测值，适合数值仪表等只需要当前读数的组件。
  final TimestampedSample<SpeedFeedbackMessage>? latestSpeed;
  final TimestampedSample<DqFeedbackMessage>? latestDq;
  final TimestampedSample<MotorCurrentMessage>? latestCurrent;
  final TimestampedSample<HallSensorStateMessage>? latestHall;
  final MotorTemperatureMessage? motorTemperature;
  final MosTemperatureMessage? mosTemperature;
  final MotorEnableStateMessage? reportedEnableState;
  final ErrorCodeMessage? errorCode;
  final AbsoluteSensorInfoMessage? absoluteSensorInfo;
  // 设备信息与参数查询结果；来自下位机回复，而非 UI 自行推断。
  final SoftwareVersionMessage? softwareVersion;
  final MotorTypeMessage? motorType;
  final SpeedLoopParametersMessage? speedLoopParameters;
  final CurrentLoopParametersMessage? currentLoopParameters;
  final MotorLimitsMessage? motorLimits;
  final DipSwitchIdMessage? dipSwitchId;
  final ExternalFlashIdMessage? externalFlashId;
  // 有容量上限的历史副本，供曲线或日志组件显示；取快照不会清空后台历史。
  final List<TimestampedSample<SpeedFeedbackMessage>> speedHistory;
  final List<TimestampedSample<DqFeedbackMessage>> dqHistory;
  final List<TimestampedSample<MotorCurrentMessage>> currentHistory;
  final List<TimestampedSample<HallSensorStateMessage>> hallHistory;
  final List<TimestampedSample<McuLogMessage>> logs;
}
