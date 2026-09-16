import 'package:flutter/material.dart';

import '../models/log_entry.dart';
import '../services/serial_port_service.dart';

/// 显示下位机通过现有协议上传的文本日志。
///
/// 页面不直接操作串口；只订阅 SerialPortService 已整理好的日志快照。
class LogPage extends StatefulWidget {
  const LogPage({super.key, required this.serialService});

  final SerialPortService serialService;

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  final ScrollController _scrollController = ScrollController();
  late List<LogEntry> _entries;

  SerialPortService get _serialService => widget.serialService;

  @override
  void initState() {
    super.initState();
    _entries = _serialService.logEntries.value;
    _serialService.logEntries.addListener(_handleEntriesChanged);
    _serialService.retainLogSnapshots();
  }

  @override
  void didUpdateWidget(covariant LogPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serialService == _serialService) return;
    oldWidget.serialService.logEntries.removeListener(_handleEntriesChanged);
    oldWidget.serialService.releaseLogSnapshots();
    _entries = _serialService.logEntries.value;
    _serialService.logEntries.addListener(_handleEntriesChanged);
    _serialService.retainLogSnapshots();
  }

  void _handleEntriesChanged() {
    final previousLength = _entries.length;
    final currentEntries = _serialService.logEntries.value;
    setState(() => _entries = currentEntries);
    if (currentEntries.length > previousLength) _scrollToBottom();
  }

  /// 等本帧 ListView 完成布局后再读取 maxScrollExtent，避免滚动范围过旧。
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _clearLogs() async {
    try {
      await _serialService.clearLogs();
    } catch (_) {
      // 服务层会将后台故障同步到连接状态；页面保留现有日志供用户查看。
    }
  }

  @override
  void dispose() {
    _serialService.logEntries.removeListener(_handleEntriesChanged);
    _serialService.releaseLogSnapshots();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Logs', style: textTheme.headlineSmall),
              const Spacer(),
              IconButton(
                onPressed: _clearLogs,
                tooltip: 'Clear logs',
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card.filled(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SelectionArea(
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _entries.length,
                    itemBuilder: (context, index) {
                      final entry = _entries[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 1),
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${_formatTimestamp(entry.timestamp)}  ',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              TextSpan(text: entry.message),
                            ],
                          ),
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontFamily: 'monospace',
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${_entries.length} lines', style: textTheme.bodySmall),
              const Spacer(),
              Icon(Icons.circle, size: 10, color: colorScheme.primary),
              const SizedBox(width: 6),
              Text('Auto Scroll', style: textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    String threeDigits(int value) => value.toString().padLeft(3, '0');
    return '${twoDigits(timestamp.hour)}:${twoDigits(timestamp.minute)}:'
        '${twoDigits(timestamp.second)}.${threeDigits(timestamp.millisecond)}';
  }
}
