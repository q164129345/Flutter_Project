import 'package:flutter/material.dart';

import '../services/serial_port_statistics.dart';
import 'mot_style_panel.dart';

/// 统计内容由设置页的“串口统计”分区提供外层标题和边框。
class SerialStatisticsPanel extends StatelessWidget {
  const SerialStatisticsPanel({super.key, required this.statistics});

  final SerialPortStatistics statistics;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: statistics,
      builder: (_, _) {
        final sendingMetrics = [
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
        ];
        final receivingMetrics = [
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
            value: '${statistics.receiveBytesPerSecond.toStringAsFixed(1)} B/s',
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
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '每次连接重新计数，断开后保留；速率每秒更新。',
              style: TextStyle(fontSize: 12, color: motMutedColor),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (_, constraints) {
                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StatisticsGroup(title: '发送', metrics: sendingMetrics),
                      const SizedBox(height: 16),
                      _StatisticsGroup(title: '接收', metrics: receivingMetrics),
                    ],
                  );
                }
                return Table(
                  columnWidths: const {
                    0: FlexColumnWidth(),
                    1: FixedColumnWidth(24),
                    2: FlexColumnWidth(),
                  },
                  defaultVerticalAlignment:
                      TableCellVerticalAlignment.intrinsicHeight,
                  children: [
                    TableRow(
                      children: [
                        _StatisticsGroup(
                          title: '发送',
                          metrics: sendingMetrics,
                          fillHeight: true,
                        ),
                        const SizedBox.shrink(),
                        _StatisticsGroup(
                          title: '接收',
                          metrics: receivingMetrics,
                          fillHeight: true,
                        ),
                      ],
                    ),
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

class _StatisticsGroup extends StatelessWidget {
  const _StatisticsGroup({
    required this.title,
    required this.metrics,
    this.fillHeight = false,
  });

  final String title;
  final List<_Metric> metrics;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    return MotStylePanel(
      title: title,
      fillHeight: fillHeight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final metric in metrics)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: metric.hint ?? '最近一个采样周期的平均字节速率',
                      child: Text(
                        metric.label,
                        style: const TextStyle(color: motMutedColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Semantics(
                    label: '${metric.label}：${metric.value}',
                    excludeSemantics: true,
                    child: Container(
                      width: 132,
                      constraints: const BoxConstraints(minHeight: 28),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F4FF),
                        border: Border.all(color: const Color(0xFFA1D4FF)),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        metric.value,
                        key: ValueKey(metric.label),
                        style: const TextStyle(
                          color: motValueColor,
                          fontWeight: FontWeight.w700,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
