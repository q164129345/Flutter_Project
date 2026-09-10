import 'package:flutter/foundation.dart';

import 'serial_statistics_snapshot.dart';

/// UI 侧的统计显示对象：保存后台快照，不在这里累计字节或计算速率。
/// 统计面板挂载/卸载时，通过回调通知服务开始/停止请求显示快照。
class SerialPortStatistics extends ChangeNotifier {
  SerialPortStatistics({this.onListeningChanged});

  // true 表示至少有一个监听者，false 表示已无人需要显示统计。
  final void Function(bool)? onListeningChanged;
  bool _observing = false;
  SerialStatisticsSnapshot _snapshot = const SerialStatisticsSnapshot();
  int get sentFrameCount => _snapshot.sentFrameCount;
  int get sentByteCount => _snapshot.sentByteCount;
  int get receivedFrameCount => _snapshot.receivedFrameCount;
  int get receivedByteCount => _snapshot.receivedByteCount;
  int get crcErrorCount => _snapshot.crcErrorCount;
  int get invalidFrameCount => _snapshot.invalidFrameCount;
  double get sendBytesPerSecond => _snapshot.sendBytesPerSecond;
  double get receiveBytesPerSecond => _snapshot.receiveBytesPerSecond;

  /// 只有数值真正变化才刷新面板，避免空闲时每秒重复重建相同 UI。
  void update(SerialStatisticsSnapshot snapshot) {
    if (_snapshot.sameValues(snapshot)) return;
    _snapshot = snapshot;
    notifyListeners();
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
    // ChangeNotifier 会延后清理回调中被移除的监听者，通知结束后需再次检查。
    _syncObservation();
  }

  // 只报告“有/无监听者”的切换，多次添加监听不会重复创建快照定时器。
  void _syncObservation() {
    if (_observing == hasListeners) return;
    _observing = hasListeners;
    onListeningChanged?.call(_observing);
  }

  @override
  void dispose() {
    if (_observing) onListeningChanged?.call(false);
    _observing = false;
    super.dispose();
  }
}
