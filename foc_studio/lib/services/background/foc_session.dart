import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../../controllers/foc_snapshot.dart';
import '../../controllers/mcu_clock_synchronizer.dart';
import '../../protocol/pc_mcu/messages/configuration_messages.dart';
import '../../protocol/pc_mcu/messages/control_messages.dart';
import '../../protocol/pc_mcu/messages/mcu_message.dart';
import '../../protocol/pc_mcu/messages/telemetry_message.dart';
import '../../protocol/pc_mcu/protocol_client.dart';
import 'serial_transport.dart';

/// 运行在串口 isolate 内的业务会话，持续维护电机状态和有容量上限的历史记录。
///
/// SerialTransport 负责原始字节，PcMcuProtocolClient 负责协议帧和消息；
/// 本类负责心跳、周期控制、参数查询/读回、时间对齐和历史数据。
/// 它的通知只在后台更新版本号，页面通过 FocController 获取显示快照。
class FocSession extends ChangeNotifier {
  FocSession(
    this.serialService, {
    PcMcuProtocolClient? protocolClient,
    this.telemetryHistoryCapacity = 1200,
    this.logCapacity = 500,
    DateTime Function()? now,
  }) : assert(telemetryHistoryCapacity > 0),
       assert(logCapacity > 0),
       _protocolClient = protocolClient ?? PcMcuProtocolClient(serialService),
       _ownsProtocolClient = protocolClient == null,
       _now = now ?? DateTime.now {
    _lastConnectionStatus = serialService.connectionStatus;
    serialService.addListener(_handleConnectionChanged);
    _messageSubscription = _protocolClient.messages.listen(
      // 这个订阅与页面生命周期无关，页面隐藏后仍逐条处理已解出的消息。
      _handleMessage,
      onError: _handleProtocolError,
    );

    if (serialService.isConnected) {
      _startSession();
    }
  }

  static const Duration heartbeatInterval = Duration(seconds: 1);
  static const Duration motorControlInterval = Duration(milliseconds: 500);
  static const Duration motorTypeQueryInterval = Duration(seconds: 1);

  final SerialTransport serialService;
  final int telemetryHistoryCapacity;
  final int logCapacity;
  final PcMcuProtocolClient _protocolClient;
  final bool _ownsProtocolClient;
  final DateTime Function() _now;
  final McuClockSynchronizer _mcuClock = McuClockSynchronizer();

  // 使用双端队列保存历史：满容量时从队首移除最旧样本，再向队尾追加新样本。
  // 这样长期连接也不会无限增长，而且不用每次移动整个历史数组。
  final ListQueue<TimestampedSample<SpeedFeedbackMessage>> _speedHistory =
      ListQueue();
  final ListQueue<TimestampedSample<DqFeedbackMessage>> _dqHistory =
      ListQueue();
  final ListQueue<TimestampedSample<MotorCurrentMessage>> _currentHistory =
      ListQueue();
  final ListQueue<TimestampedSample<HallSensorStateMessage>> _hallHistory =
      ListQueue();
  final ListQueue<TimestampedSample<McuLogMessage>> _logs = ListQueue();

  late final StreamSubscription<McuMessage> _messageSubscription;
  late SerialPortConnectionStatus _lastConnectionStatus;
  // 定时器都在本后台 isolate 中运行，UI 忙碌或切页不会暂停这些会话策略。
  Timer? _heartbeatTimer;
  Timer? _motorControlTimer;
  Timer? _motorTypeQueryTimer;
  Timer? _postRebootVersionTimer;
  bool _isDisposed = false;

  bool _motorControlEnabled = false;
  int _targetSpeedRpm = 0;
  Object? _lastProtocolError;
  DateTime? _lastMessageAt;

  TimestampedSample<SpeedFeedbackMessage>? _latestSpeed;
  TimestampedSample<DqFeedbackMessage>? _latestDq;
  TimestampedSample<MotorCurrentMessage>? _latestCurrent;
  TimestampedSample<HallSensorStateMessage>? _latestHall;
  MotorTemperatureMessage? _motorTemperature;
  MosTemperatureMessage? _mosTemperature;
  MotorEnableStateMessage? _reportedEnableState;
  ErrorCodeMessage? _errorCode;
  AbsoluteSensorInfoMessage? _absoluteSensorInfo;
  SoftwareVersionMessage? _softwareVersion;
  MotorTypeMessage? _motorType;
  SpeedLoopParametersMessage? _speedLoopParameters;
  CurrentLoopParametersMessage? _currentLoopParameters;
  MotorLimitsMessage? _motorLimits;
  DipSwitchIdMessage? _dipSwitchId;
  ExternalFlashIdMessage? _externalFlashId;

  Stream<McuMessage> get messages => _protocolClient.messages;
  bool get isConnected => serialService.isConnected;
  bool get motorControlEnabled => _motorControlEnabled;
  int get targetSpeedRpm => _targetSpeedRpm;
  Object? get lastProtocolError => _lastProtocolError;
  DateTime? get lastMessageAt => _lastMessageAt;

  TimestampedSample<SpeedFeedbackMessage>? get latestSpeed => _latestSpeed;
  TimestampedSample<DqFeedbackMessage>? get latestDq => _latestDq;
  TimestampedSample<MotorCurrentMessage>? get latestCurrent => _latestCurrent;
  TimestampedSample<HallSensorStateMessage>? get latestHall => _latestHall;
  MotorTemperatureMessage? get motorTemperature => _motorTemperature;
  MosTemperatureMessage? get mosTemperature => _mosTemperature;
  MotorEnableStateMessage? get reportedEnableState => _reportedEnableState;
  ErrorCodeMessage? get errorCode => _errorCode;
  AbsoluteSensorInfoMessage? get absoluteSensorInfo => _absoluteSensorInfo;
  SoftwareVersionMessage? get softwareVersion => _softwareVersion;
  MotorTypeMessage? get motorType => _motorType;
  SpeedLoopParametersMessage? get speedLoopParameters => _speedLoopParameters;
  CurrentLoopParametersMessage? get currentLoopParameters =>
      _currentLoopParameters;
  MotorLimitsMessage? get motorLimits => _motorLimits;
  DipSwitchIdMessage? get dipSwitchId => _dipSwitchId;
  ExternalFlashIdMessage? get externalFlashId => _externalFlashId;

  // 对外提供不可修改的列表副本，避免快照持有后台正在增删的队列。
  List<TimestampedSample<SpeedFeedbackMessage>> get speedHistory =>
      List.unmodifiable(_speedHistory);
  List<TimestampedSample<DqFeedbackMessage>> get dqHistory =>
      List.unmodifiable(_dqHistory);
  List<TimestampedSample<MotorCurrentMessage>> get currentHistory =>
      List.unmodifiable(_currentHistory);
  List<TimestampedSample<HallSensorStateMessage>> get hallHistory =>
      List.unmodifiable(_hallHistory);
  List<TimestampedSample<McuLogMessage>> get logs => List.unmodifiable(_logs);

  /// 仅在 UI 请求且版本有变化时调用，把此刻的状态和有限历史整理成快照。
  /// 错误转成文本，传出去的对象只包含数据，不带本地串口资源。
  FocSnapshot snapshot() => FocSnapshot(
    isConnected: isConnected,
    motorControlEnabled: motorControlEnabled,
    targetSpeedRpm: targetSpeedRpm,
    lastProtocolError: lastProtocolError?.toString(),
    lastMessageAt: lastMessageAt,
    latestSpeed: latestSpeed,
    latestDq: latestDq,
    latestCurrent: latestCurrent,
    latestHall: latestHall,
    motorTemperature: motorTemperature,
    mosTemperature: mosTemperature,
    reportedEnableState: reportedEnableState,
    errorCode: errorCode,
    absoluteSensorInfo: absoluteSensorInfo,
    softwareVersion: softwareVersion,
    motorType: motorType,
    speedLoopParameters: speedLoopParameters,
    currentLoopParameters: currentLoopParameters,
    motorLimits: motorLimits,
    dipSwitchId: dipSwitchId,
    externalFlashId: externalFlashId,
    speedHistory: speedHistory,
    dqHistory: dqHistory,
    currentHistory: currentHistory,
    hallHistory: hallHistory,
    logs: logs,
  );

  /// 保存用户设定的目标并立即加入发送队列，之后每 500 ms 重发同一控制命令。
  /// 返回 true 表示接受了发送操作，不表示下位机已经完成执行。
  bool setMotorControl({required bool enabled, required int targetSpeedRpm}) {
    if (targetSpeedRpm < -0x8000 || targetSpeedRpm > 0x7FFF) {
      throw RangeError.range(targetSpeedRpm, -0x8000, 0x7FFF, 'targetSpeedRpm');
    }

    _motorControlEnabled = enabled;
    _targetSpeedRpm = targetSpeedRpm;
    notifyListeners();
    return _sendMotorControl();
  }

  bool querySoftwareVersion() => _trySend(_protocolClient.querySoftwareVersion);

  bool queryMotorType() => _trySend(_protocolClient.queryMotorType);

  bool queryTuneParameters() {
    return _trySend(() {
      _protocolClient.querySpeedLoopParameters();
      _protocolClient.queryCurrentLoopParameters();
      _protocolClient.queryMotorLimits();
    });
  }

  /// 先按顺序排队写入全部参数，再排队发送读回查询，供后续核对下位机实际参数。
  bool writeTuneParameters({
    required PidParameters speedLoop,
    required CurrentLoopParameters currentLoop,
    required MotorLimits motorLimits,
  }) {
    return _trySend(() {
      _protocolClient.setSpeedLoopParameters(speedLoop);
      _protocolClient.setCurrentLoopParameters(currentLoop);
      _protocolClient.setMotorLimits(motorLimits);
      _protocolClient.querySpeedLoopParameters();
      _protocolClient.queryCurrentLoopParameters();
      _protocolClient.queryMotorLimits();
    });
  }

  bool queryDipSwitchId() => _trySend(_protocolClient.queryDipSwitchId);

  bool queryExternalFlashId() => _trySend(_protocolClient.queryExternalFlashId);

  bool rebootMcu() {
    final sent = _trySend(_protocolClient.rebootMcu);
    if (sent) {
      _prepareForMcuRestart();
      notifyListeners();
    }
    return sent;
  }

  void clearProtocolError() {
    if (_lastProtocolError != null) {
      _lastProtocolError = null;
      notifyListeners();
    }
  }

  /// 连接状态决定业务会话是否运行，与当前选中的页面无关。
  void _handleConnectionChanged() {
    final status = serialService.connectionStatus;
    if (status != _lastConnectionStatus) {
      _lastConnectionStatus = status;
      if (status == SerialPortConnectionStatus.connected) {
        _startSession();
      } else {
        _stopSession(resetState: true);
      }
    }
    notifyListeners();
  }

  /// 新连接先清理旧状态，再发送初始命令并启动后台周期任务。
  void _startSession() {
    _cancelTimers();
    _resetSessionState();

    // 心跳先入队，告诉下位机 PC 在线，使其开始上传正常遥测数据。
    _sendHeartbeat();
    _sendMotorControl();
    querySoftwareVersion();
    queryMotorType();

    _heartbeatTimer = Timer.periodic(
      heartbeatInterval,
      (_) => _sendHeartbeat(),
    );
    _motorControlTimer = Timer.periodic(
      motorControlInterval,
      (_) => _sendMotorControl(),
    );
    _startMotorTypePolling();
  }

  void _stopSession({required bool resetState}) {
    _cancelTimers();
    if (resetState) {
      _resetSessionState();
    }
  }

  /// 未拿到有效电机类型时每秒查询一次，成功识别后停止无意义的重复查询。
  void _startMotorTypePolling() {
    _motorTypeQueryTimer?.cancel();
    _motorTypeQueryTimer = Timer.periodic(motorTypeQueryInterval, (_) {
      if (_motorType?.isKnown ?? false) {
        _motorTypeQueryTimer?.cancel();
        _motorTypeQueryTimer = null;
      } else {
        queryMotorType();
      }
    });
  }

  /// 重启会使 MCU 的计时与状态失效；清理旧数据，稍后重新查询版本和电机类型。
  void _prepareForMcuRestart() {
    _clearReceivedState();
    _mcuClock.reset();
    _startMotorTypePolling();
    _postRebootVersionTimer?.cancel();
    _postRebootVersionTimer = Timer(
      const Duration(seconds: 1),
      querySoftwareVersion,
    );
  }

  bool _sendHeartbeat() => _trySend(_protocolClient.sendHeartbeat);

  bool _sendMotorControl() {
    return _trySend(
      () => _protocolClient.sendMotorControl(
        MotorControlCommand(
          enabled: _motorControlEnabled,
          targetSpeedRpm: _targetSpeedRpm,
        ),
      ),
    );
  }

  /// 统一处理未连接和入队失败，避免后台定时器里的异常变成未捕获错误。
  bool _trySend(void Function() operation) {
    if (!serialService.isConnected || _isDisposed) {
      return false;
    }
    try {
      operation();
      return true;
    } catch (error) {
      _lastProtocolError = error;
      notifyListeners();
      return false;
    }
  }

  /// 每条解码成功的消息都更新后台状态，不能因 UI 不可见而跳过采样。
  void _handleMessage(McuMessage message) {
    if (_isDisposed) {
      return;
    }

    final receivedAt = _now();
    _lastMessageAt = receivedAt;

    switch (message) {
      case SpeedFeedbackMessage():
        _latestSpeed = _timedSample(message, message.mcuTickMs, receivedAt);
        _addBounded(_speedHistory, _latestSpeed!, telemetryHistoryCapacity);
      case DqFeedbackMessage():
        _latestDq = _timedSample(message, message.mcuTickMs, receivedAt);
        _addBounded(_dqHistory, _latestDq!, telemetryHistoryCapacity);
      case MotorCurrentMessage():
        _latestCurrent = _timedSample(message, message.mcuTickMs, receivedAt);
        _addBounded(_currentHistory, _latestCurrent!, telemetryHistoryCapacity);
      case HallSensorStateMessage():
        _latestHall = _timedSample(message, message.mcuTickMs, receivedAt);
        _addBounded(_hallHistory, _latestHall!, telemetryHistoryCapacity);
      case MotorTemperatureMessage():
        _motorTemperature = message;
      case MosTemperatureMessage():
        _mosTemperature = message;
      case MotorEnableStateMessage():
        _reportedEnableState = message;
      case ErrorCodeMessage():
        _errorCode = message;
      case AbsoluteSensorInfoMessage():
        _absoluteSensorInfo = message;
      case SoftwareVersionMessage():
        _softwareVersion = message;
      case MotorTypeMessage():
        _motorType = message;
        if (message.isKnown) {
          _motorTypeQueryTimer?.cancel();
          _motorTypeQueryTimer = null;
        }
      case SpeedLoopParametersMessage():
        _speedLoopParameters = message;
      case CurrentLoopParametersMessage():
        _currentLoopParameters = message;
      case MotorLimitsMessage():
        _motorLimits = message;
      case DipSwitchIdMessage():
        _dipSwitchId = message;
      case ExternalFlashIdMessage():
        _externalFlashId = message;
      case McuLogMessage():
        _addBounded(
          _logs,
          TimestampedSample(value: message, timestamp: receivedAt),
          logCapacity,
        );
      case UnknownMcuMessage():
        // 未知命令仍保留在后台消息流中，方便协议扩展；暂不映射到已有业务字段。
        break;
    }

    // 此通知只让后台记录状态版本变化，不会按每条消息直接重建 UI。
    notifyListeners();
  }

  /// 按 MCU 采样 tick 对齐时间，保留真实采样间隔，避免批量到达时曲线时间重叠。
  TimestampedSample<T> _timedSample<T>(
    T value,
    int mcuTickMs,
    DateTime receivedAt,
  ) {
    return TimestampedSample(
      value: value,
      timestamp: _mcuClock.align(mcuTickMs, receivedAt),
    );
  }

  void _handleProtocolError(Object error, StackTrace stackTrace) {
    if (_isDisposed) {
      return;
    }
    // 帧或消息解码失败不代表串口已断开，继续维持周期发送。真正的传输故障
    // 由 SerialTransport 切换连接状态，并通过 _handleConnectionChanged 停止会话。
    _lastProtocolError = error;
    debugPrint('PC-MCU protocol error: $error\n$stackTrace');
    notifyListeners();
  }

  void _resetSessionState() {
    _motorControlEnabled = false;
    _targetSpeedRpm = 0;
    _lastProtocolError = null;
    _lastMessageAt = null;
    _mcuClock.reset();
    _clearReceivedState();
  }

  void _clearReceivedState() {
    _latestSpeed = null;
    _latestDq = null;
    _latestCurrent = null;
    _latestHall = null;
    _motorTemperature = null;
    _mosTemperature = null;
    _reportedEnableState = null;
    _errorCode = null;
    _absoluteSensorInfo = null;
    _softwareVersion = null;
    _motorType = null;
    _speedLoopParameters = null;
    _currentLoopParameters = null;
    _motorLimits = null;
    _dipSwitchId = null;
    _externalFlashId = null;
    _speedHistory.clear();
    _dqHistory.clear();
    _currentHistory.clear();
    _hallHistory.clear();
    _logs.clear();
  }

  void _cancelTimers() {
    _heartbeatTimer?.cancel();
    _motorControlTimer?.cancel();
    _motorTypeQueryTimer?.cancel();
    _postRebootVersionTimer?.cancel();
    _heartbeatTimer = null;
    _motorControlTimer = null;
    _motorTypeQueryTimer = null;
    _postRebootVersionTimer = null;
  }

  /// 只淘汰最旧的历史显示数据；所有收到的完整帧仍已参与解码和统计。
  void _addBounded<T>(ListQueue<T> queue, T value, int capacity) {
    if (queue.length == capacity) {
      queue.removeFirst();
    }
    queue.addLast(value);
  }

  @override
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _cancelTimers();
    serialService.removeListener(_handleConnectionChanged);
    unawaited(_messageSubscription.cancel());
    if (_ownsProtocolClient) {
      _protocolClient.dispose();
    }
    super.dispose();
  }
}
