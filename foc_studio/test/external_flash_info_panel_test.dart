import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foc_studio/protocol/pc_mcu/messages/configuration_messages.dart';
import 'package:foc_studio/widgets/external_flash_info_panel.dart';

void main() {
  Widget buildPanel({
    ExternalFlashIdMessage? flashId,
    bool isConnected = true,
    bool isQueryPending = false,
    required VoidCallback onRefresh,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: ExternalFlashInfoPanel(
          flashId: flashId,
          isConnected: isConnected,
          isQueryPending: isQueryPending,
          onRefresh: onRefresh,
        ),
      ),
    );
  }

  testWidgets('displays MCU Flash IDs as fixed-width hexadecimal values', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPanel(
        flashId: const ExternalFlashIdMessage(manufacturerId: 0, deviceId: 239),
        onRefresh: () {},
      ),
    );

    expect(find.text('外部Flash信息'), findsOneWidget);
    expect(find.text('制造商ID:'), findsOneWidget);
    expect(find.text('设备ID:'), findsOneWidget);
    expect(find.text('0x00'), findsOneWidget);
    expect(find.text('0xEF'), findsOneWidget);
  });

  testWidgets('shows unread values and disables refresh while disconnected', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildPanel(isConnected: false, flashId: null, onRefresh: () {}),
    );

    expect(find.text('未读取'), findsNWidgets(2));
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });

  testWidgets('shows the pending state and invokes refresh when enabled', (
    tester,
  ) async {
    var refreshCount = 0;
    await tester.pumpWidget(buildPanel(onRefresh: () => refreshCount++));

    await tester.tap(find.byKey(const ValueKey('external-flash-refresh')));
    expect(refreshCount, 1);

    await tester.pumpWidget(
      buildPanel(isQueryPending: true, onRefresh: () => refreshCount++),
    );
    expect(find.text('读取中…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
  });
}
