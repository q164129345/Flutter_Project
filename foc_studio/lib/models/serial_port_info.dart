/// 可供用户选择的本地串口；[name] 是连接时传给串口库的标识，
/// [description] 仅用于界面显示。
class SerialPortInfo {
  SerialPortInfo({required this.name, String? description})
    : description = _normalizedDescription(name, description);

  final String name;
  final String? description;

  /// 系统未提供可读描述时不伪造设备类型，只显示端口名。
  String get displayLabel =>
      description == null ? name : '$name - $description';

  static String? _normalizedDescription(String name, String? description) {
    final normalized = description?.trim();
    if (normalized == null || normalized.isEmpty) return null;

    // Windows 驱动常将端口号附在描述末尾，例如“USB 串行设备, (COM4)”。
    // 端口名已经在显示文本开头出现，移除这个重复后缀。
    final portSuffix = RegExp(
      r'(?:\s*[,，]\s*)?\s*\(' + RegExp.escape(name) + r'\)\s*$',
      caseSensitive: false,
    );
    return normalized.replaceFirst(portSuffix, '').trim();
  }
}
