import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../protocol/pc_mcu/messages/configuration_messages.dart';
import '../protocol/pc_mcu/messages/control_messages.dart';
import '../protocol/pc_mcu/messages/mcu_message.dart';
import '../protocol/pc_mcu/messages/telemetry_message.dart';
import '../protocol/pc_mcu/protocol_client.dart';
import '../services/serial_port_service.dart';
import 'mcu_clock_synchronizer.dart';

class TimestampedSample<T> {
  const TimestampedSample({required this.value, required this.timestamp});

  final T value;
  final DateTime timestamp;
}

/// Owns one PC-MCU protocol session and exposes state suitable for the UI.
///
/// Serial I/O stays in [SerialPortService], binary framing stays in
/// [PcMcuProtocolClient], and session policy (heartbeat, polling, read-back)
/// lives here.
class FocController extends ChangeNotifier {
  FocController(
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

  final SerialPortService serialService;
  final int telemetryHistoryCapacity;
  final int logCapacity;
  final PcMcuProtocolClient _protocolClient;
  final bool _ownsProtocolClient;
  final DateTime Function() _now;
  final McuClockSynchronizer _mcuClock = McuClockSynchronizer();

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

  List<TimestampedSample<SpeedFeedbackMessage>> get speedHistory =>
      List.unmodifiable(_speedHistory);
  List<TimestampedSample<DqFeedbackMessage>> get dqHistory =>
      List.unmodifiable(_dqHistory);
  List<TimestampedSample<MotorCurrentMessage>> get currentHistory =>
      List.unmodifiable(_currentHistory);
  List<TimestampedSample<HallSensorStateMessage>> get hallHistory =>
      List.unmodifiable(_hallHistory);
  List<TimestampedSample<McuLogMessage>> get logs => List.unmodifiable(_logs);

  /// Updates the desired command and sends it immediately when connected.
  /// The same command is then refreshed every 500 ms by the session timer.
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

  /// Writes all tuning parameters and immediately reads all of them back.
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

  void _startSession() {
    _cancelTimers();
    _resetSessionState();

    // Send heartbeat first so normal MCU telemetry can start immediately.
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
        // A valid but unknown command is preserved on [messages] for future
        // protocol extensions. It does not mutate today's controller state.
        break;
    }

    notifyListeners();
  }

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
    // 由 SerialPortService 切换连接状态，并通过 _handleConnectionChanged 停止会话。
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
