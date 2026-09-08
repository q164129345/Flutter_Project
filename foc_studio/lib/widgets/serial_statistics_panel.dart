import 'package:flutter/material.dart';

import '../services/serial_port_statistics.dart';

/// MainPage 切走设置页时会卸载本组件，ListenableBuilder 随之取消监听。
/// 再次进入时直接读取后台累计值，无需等待下一次采样。
class SerialStatisticsPanel extends StatelessWidget {
  const SerialStatisticsPanel({super.key, required this.statistics});

  final SerialPortStatistics statistics;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: statistics,
      builder: (context, child) {
        final sending = _StatisticsCard(
          title: '发送',
          icon: Icons.arrow_upward_rounded,
          metrics: [
            _Metric(
              label: '发送总帧数',
              value: '${statistics.sentFrameCount}',
              hint: '完整写入系统发送缓冲区的协议帧数',
            ),
            _Metric(
              label: '发送总字节',
              value: '${statistics.sentByteCount} B',
              hint: '系统实际接受的字节数，包含帧头和 CRC',
            ),
            _Metric(
              label: '发送速率',
              value: '${statistics.sendBytesPerSecond.toStringAsFixed(1)} B/s',
            ),
          ],
        );
        final receiving = _StatisticsCard(
          title: '接收',
          icon: Icons.arrow_downward_rounded,
          metrics: [
            _Metric(
              label: '接收总帧数',
              value: '${statistics.receivedFrameCount}',
              hint: '通过帧校验和消息解码的完整帧数',
            ),
            _Metric(
              label: '接收总字节数',
              value: '${statistics.receivedByteCount} B',
              hint: '全部原始接收字节，包含帧头、CRC、无效帧和噪声',
            ),
            _Metric(
              label: '接收速率',
              value:
                  '${statistics.receiveBytesPerSecond.toStringAsFixed(1)} B/s',
            ),
            _Metric(
              label: 'CRC 错误数',
              value: '${statistics.crcErrorCount}',
              hint: '电脑接收时检测到的 CRC 校验错误，已包含在无效帧数中',
            ),
            _Metric(
              label: '无效帧数',
              value: '${statistics.invalidFrameCount}',
              hint: '长度、CRC 或消息内容错误；不将零散噪声和未收齐的半帧计为无效帧',
            ),
          ],
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('串口统计', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '每次连接重新计数，断开后保留；速率每秒更新。',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [sending, const SizedBox(height: 16), receiving],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: sending),
                    const SizedBox(width: 16),
                    Expanded(child: receiving),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _Metric {
  const _Metric({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;
}

class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({
    required this.title,
    required this.icon,
    required this.metrics,
  });

  final String title;
  final IconData icon;
  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            for (final metric in metrics)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Tooltip(
                      message: metric.hint ?? '最近一个采样周期的平均字节速率',
                      child: Text(
                        metric.label,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        metric.value,
                        key: ValueKey(metric.label),
                        textAlign: TextAlign.right,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
