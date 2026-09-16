import 'package:flutter/material.dart';

import '../protocol/pc_mcu/messages/configuration_messages.dart';
import 'mot_style_panel.dart';

/// 展示 MCU 通过串口协议返回的外部 Flash JEDEC ID。
class ExternalFlashInfoPanel extends StatelessWidget {
  const ExternalFlashInfoPanel({
    super.key,
    required this.flashId,
    required this.isConnected,
    required this.isQueryPending,
    required this.onRefresh,
  });

  final ExternalFlashIdMessage? flashId;
  final bool isConnected;
  final bool isQueryPending;
  final VoidCallback onRefresh;

  bool get _canRefresh => isConnected && !isQueryPending;

  @override
  Widget build(BuildContext context) {
    return MotStylePanel(
      title: '外部Flash信息',
      child: Wrap(
        spacing: 28,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _IdValue(label: '制造商ID', value: flashId?.manufacturerId),
          _IdValue(label: '设备ID', value: flashId?.deviceId),
          FilledButton.icon(
            key: const ValueKey('external-flash-refresh'),
            onPressed: _canRefresh ? onRefresh : null,
            icon: isQueryPending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
            label: Text(isQueryPending ? '读取中…' : '刷新'),
          ),
        ],
      ),
    );
  }
}

class _IdValue extends StatelessWidget {
  const _IdValue({required this.label, required this.value});

  final String label;
  final int? value;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? '未读取'
        : '0x${value!.toRadixString(16).toUpperCase().padLeft(2, '0')}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label:'),
        const SizedBox(width: 8),
        Text(text, key: ValueKey('external-flash-$label')),
      ],
    );
  }
}
