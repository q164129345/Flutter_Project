/// LOG 页面使用的一条文本日志。
///
/// timestamp 是本机完成接收/解码该日志时记录的时间；message 保留下位机
/// 发送的原始文本。后续如需增加等级或来源，可在此模型中继续扩展。
class LogEntry {
  const LogEntry({required this.timestamp, required this.message});

  final DateTime timestamp;
  final String message;
}
