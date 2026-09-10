/// 跨 isolate 传递的统计快照：只带数值，不带后台计时器和可变累加器。
/// UI 可以保留这份数据；后台继续收发时不会修改已经发出的快照。
class SerialStatisticsSnapshot {
  const SerialStatisticsSnapshot({
    this.sentFrameCount = 0,
    this.sentByteCount = 0,
    this.receivedFrameCount = 0,
    this.receivedByteCount = 0,
    this.crcErrorCount = 0,
    this.invalidFrameCount = 0,
    this.sendBytesPerSecond = 0,
    this.receiveBytesPerSecond = 0,
  });
  // 发送帧数按“整帧进入系统发送缓冲区”计；字节数包含短写时已接受的部分。
  final int sentFrameCount;
  final int sentByteCount;
  // 接收帧数只计成功解码的完整帧；字节数包含噪声、坏帧和未补齐的半帧。
  final int receivedFrameCount;
  final int receivedByteCount;
  // CRC 错误属于无效帧的一部分，两项不能相加当作总错误数。
  final int crcErrorCount;
  final int invalidFrameCount;
  // 单位为 B/s，按后台最近一次采样的实际经过时间计算。
  final double sendBytesPerSecond;
  final double receiveBytesPerSecond;

  /// 比较显示内容而非对象地址：新收到一个快照对象不一定意味着数值变了。
  bool sameValues(SerialStatisticsSnapshot other) =>
      sentFrameCount == other.sentFrameCount &&
      sentByteCount == other.sentByteCount &&
      receivedFrameCount == other.receivedFrameCount &&
      receivedByteCount == other.receivedByteCount &&
      crcErrorCount == other.crcErrorCount &&
      invalidFrameCount == other.invalidFrameCount &&
      sendBytesPerSecond == other.sendBytesPerSecond &&
      receiveBytesPerSecond == other.receiveBytesPerSecond;
}
