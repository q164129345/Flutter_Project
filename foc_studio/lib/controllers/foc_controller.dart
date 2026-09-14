import 'package:flutter/foundation.dart';

import '../protocol/pc_mcu/messages/control_messages.dart';
import '../services/background/serial_worker_messages.dart';
import '../services/serial_port_service.dart';
import 'foc_snapshot.dart';

export 'foc_snapshot.dart';

/// UI 的业务数据适配器：提供只读 state，并把用户操作转交给后台。
///
/// 真正的消息处理、历史记录和心跳由后台 FocSession 管理。
/// 当前页面开始监听时才获取业务快照，周期更新最多 20 次/秒；
/// 页面卸载后停止取快照，后台仍逐帧处理全部数据。
class FocController extends ChangeNotifier {
  FocController(this.serialService) {
    // 接收代理保存的快照与连接状态。这两条订阅本身不会开启业务轮询；
    // 是否需要轮询，要等页面通过 addListener 表达显示需求。
    serialService.focState.addListener(_handleSnapshot);
    serialService.addListener(_handleSnapshot);
  }

  final SerialPortService serialService;
  // 记录上次是否已向服务申请快照，防止重复申请或重复释放。
  bool _observing = false;
  // getter 只读取上一次拿到的快照，不会在 build 期间解包或遍历后台历史。
  FocSnapshot get state => serialService.focState.value;
  bool get isConnected => serialService.isConnected;

  /// 把目标使能状态和转速提交给后台；后台负责立即排队并定期重复发送。
  Future<bool> setMotorControl({
    required bool enabled,
    required int targetSpeedRpm,
  }) {
    return serialService.sendCommand(
      SerialOperation.setMotorControl,
      MotorControlCommand(enabled: enabled, targetSpeedRpm: targetSpeedRpm),
    );
  }

  // 这些方法只等待后台接受操作；下位机稍后返回的数据会进入后续快照。
  Future<bool> querySoftwareVersion() =>
      serialService.sendCommand(SerialOperation.querySoftwareVersion);
  Future<bool> queryMotorType() =>
      serialService.sendCommand(SerialOperation.queryMotorType);
  Future<bool> queryTuneParameters() =>
      serialService.sendCommand(SerialOperation.queryTuneParameters);
  Future<bool> queryDipSwitchId() =>
      serialService.sendCommand(SerialOperation.queryDipSwitchId);
  Future<bool> queryExternalFlashId() =>
      serialService.sendCommand(SerialOperation.queryExternalFlashId);
  Future<bool> rebootMcu() =>
      serialService.sendCommand(SerialOperation.rebootMcu);
  Future<void> clearProtocolError() => serialService.clearProtocolError();

  /// 成组提交调参数据，具体编码与写入/读回顺序由后台会话处理。
  Future<bool> writeTuneParameters({
    required PidParameters speedLoop,
    required CurrentLoopParameters currentLoop,
    required MotorLimits motorLimits,
  }) => serialService.sendCommand(SerialOperation.writeTuneParameters, (
    speedLoop: speedLoop,
    currentLoop: currentLoop,
    motorLimits: motorLimits,
  ));

  // 无可见页面监听时，不向页面发出通知；重新监听后会请求最新后台快照。
  void _handleSnapshot() {
    if (hasListeners) notifyListeners();
  }

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _syncObservation();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _syncObservation();
  }

  @override
  void notifyListeners() {
    super.notifyListeners();
    // 监听者可能在回调中移除自己，等通知结束后再核对一次真实监听状态。
    _syncObservation();
  }

  /// 只在监听者从“无”变“有”或从“有”变“无”时切换快照请求。
  void _syncObservation() {
    if (_observing == hasListeners) return;
    _observing = hasListeners;
    if (_observing) {
      serialService.retainFocSnapshots();
    } else {
      serialService.releaseFocSnapshots();
    }
  }

  /// 释放 UI 订阅；串口服务由 MainPage 持有，本控制器不负责断开串口。
  @override
  void dispose() {
    if (_observing) serialService.releaseFocSnapshots();
    _observing = false;
    serialService.focState.removeListener(_handleSnapshot);
    serialService.removeListener(_handleSnapshot);
    super.dispose();
  }
}
