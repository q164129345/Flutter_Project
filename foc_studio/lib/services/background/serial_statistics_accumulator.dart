import 'dart:async';

import '../serial_statistics_snapshot.dart';

import 'package:flutter/foundation.dart';

/// 仅在串口 isolate 中累计数值，每秒采样速率。页面可见性不影响采样。
/// UI 按需读取不可变快照，不直接订阅本对象。
class SerialStatisticsAccumulator extends ChangeNotifier {
  SerialStatisticsAccumulator({Duration Function()? elapsed})
    : _elapsed = elapsed ?? _monotonicClock();

  static const sampleInterval = Duration(seconds: 1);

  // 使用单调递增的经过时间，而不是系统日期，避免调整电脑时间影响速率。
  final Duration Function() _elapsed;
  Timer? _sampleTimer;
  Duration _lastSampleAt = Duration.zero;
  // 上次采样的累计字节数；本次累计减去它们，就是这段时间实际收发的字节。
  int _lastSentBytes = 0;
  int _lastReceivedBytes = 0;

  int _sentFrameCount = 0;
  int _sentByteCount = 0;
  int _receivedFrameCount = 0;
  int _receivedByteCount = 0;
  int _crcErrorCount = 0;
  int _invalidFrameCount = 0;
  double _sendBytesPerSecond = 0;
  double _receiveBytesPerSecond = 0;

  /// 完整写入系统发送缓冲区的协议帧数；短写重试不重复计帧。
  int get sentFrameCount => _sentFrameCount;

  /// 系统实际接受的发送字节数，包含未能完整发送的帧的已写入部分。
  int get sentByteCount => _sentByteCount;

  /// 通过帧校验和消息解码的完整接收帧数。
  int get receivedFrameCount => _receivedFrameCount;

  /// 原始接收字节数，包含帧头、CRC、无效帧、噪声和未完成的帧。
  int get receivedByteCount => _receivedByteCount;
  int get crcErrorCount => _crcErrorCount;

  /// 帧长度、CRC 或消息内容错误。CRC 错误是其中的子集，不重复累加。
  /// 零散噪声和等待补齐的半帧不计为无效帧。
  int get invalidFrameCount => _invalidFrameCount;
  double get sendBytesPerSecond => _sendBytesPerSecond;
  double get receiveBytesPerSecond => _receiveBytesPerSecond;

  /// 复制当前数值供 UI 显示，不重置计数，也不依赖 UI 是否在监听。
  SerialStatisticsSnapshot snapshot() => SerialStatisticsSnapshot(
    sentFrameCount: sentFrameCount,
    sentByteCount: sentByteCount,
    receivedFrameCount: receivedFrameCount,
    receivedByteCount: receivedByteCount,
    crcErrorCount: crcErrorCount,
    invalidFrameCount: invalidFrameCount,
    sendBytesPerSecond: sendBytesPerSecond,
    receiveBytesPerSecond: receiveBytesPerSecond,
  );

  // 高频收发路径只做累加，不逐字节或逐帧触发 UI 更新。
  void recordSentBytes(int count) {
    assert(count >= 0);
    _sentByteCount += count;
  }

  void recordSentFrame() => _sentFrameCount++;

  void recordReceivedBytes(int count) {
    assert(count >= 0);
    _receivedByteCount += count;
  }

  void recordReceivedFrame() => _receivedFrameCount++;

  void recordInvalidFrames({required int count, int crcErrors = 0}) {
    assert(count >= 0 && crcErrors >= 0 && crcErrors <= count);
    _invalidFrameCount += count;
    _crcErrorCount += crcErrors;
  }

  /// 成功建立新连接时清零；计数生命周期与设置页无关。
  void startSession() {
    _sampleTimer?.cancel();
    _sentFrameCount = 0;
    _sentByteCount = 0;
    _receivedFrameCount = 0;
    _receivedByteCount = 0;
    _crcErrorCount = 0;
    _invalidFrameCount = 0;
    _sendBytesPerSecond = 0;
    _receiveBytesPerSecond = 0;
    _lastSentBytes = 0;
    _lastReceivedBytes = 0;
    _lastSampleAt = _elapsed();
    _sampleTimer = Timer.periodic(sampleInterval, (_) => _sampleRates());
    notifyListeners();
  }

  /// 断开后保留累计值，立即归零速率并停止采样。
  void stopSession() {
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _sendBytesPerSecond = 0;
    _receiveBytesPerSecond = 0;
    notifyListeners();
  }

  /// 后台独立采样：速率 = 自上次采样以来新增的字节数 / 实际经过秒数。
  void _sampleRates() {
    final now = _elapsed();
    final microseconds = (now - _lastSampleAt).inMicroseconds;
    if (microseconds <= 0) {
      return;
    }

    // 使用实际经过时间，避免定时器延迟导致 B/s 被高估。
    final seconds = microseconds / Duration.microsecondsPerSecond;
    _sendBytesPerSecond = (_sentByteCount - _lastSentBytes) / seconds;
    _receiveBytesPerSecond =
        (_receivedByteCount - _lastReceivedBytes) / seconds;
    _lastSentBytes = _sentByteCount;
    _lastReceivedBytes = _receivedByteCount;
    _lastSampleAt = now;
    notifyListeners();
  }

  // 用闭包保留同一个 Stopwatch，之后每次调用都返回从它启动至今的时长。
  static Duration Function() _monotonicClock() {
    final clock = Stopwatch()..start();
    return () => clock.elapsed;
  }

  @override
  void dispose() {
    _sampleTimer?.cancel();
    super.dispose();
  }
}
