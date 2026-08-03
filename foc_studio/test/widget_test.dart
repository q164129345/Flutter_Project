import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:foc_studio/main.dart';

void main() {
  Future<void> pumpStudio(
    WidgetTester tester, {
    Size size = const Size(912, 759),
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const FocStudioApp());
  }

  testWidgets('shows the SYS page in its disconnected state', (tester) async {
    await pumpStudio(tester);

    expect(find.text('串口状态: 未连接'), findsOneWidget);
    expect(find.text('外部 Flash 信息'), findsOneWidget);
    expect(find.text('串口统计'), findsOneWidget);
    expect(find.byKey(const Key('connectButton')), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('disconnectButton')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('adds a port and toggles the simulated connection', (
    tester,
  ) async {
    await pumpStudio(tester);

    await tester.enterText(find.byKey(const Key('manualPortInput')), 'COM9');
    await tester.tap(find.text('添加'));
    await tester.pump();
    expect(find.text('COM9'), findsOneWidget);

    await tester.tap(find.byKey(const Key('connectButton')));
    await tester.pump();
    expect(find.text('串口状态: 已连接'), findsOneWidget);
    expect(find.text('制造商ID:FOC Studio', findRichText: true), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const Key('restartButton')))
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.byKey(const Key('disconnectButton')));
    await tester.pump();
    expect(find.text('串口状态: 未连接'), findsOneWidget);
  });

  testWidgets('switches sidebar modules and handles a narrow window', (
    tester,
  ) async {
    await pumpStudio(tester, size: const Size(600, 520));

    await tester.tap(find.text('MOT'));
    await tester.pump();
    expect(find.text('MOT 模块开发中'), findsOneWidget);

    await tester.tap(find.text('SYS'));
    await tester.pump();
    expect(find.text('串口统计'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
