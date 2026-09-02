import 'package:flutter_test/flutter_test.dart';
import 'package:foc_studio/controllers/mcu_clock_synchronizer.dart';

void main() {
  test('preserves MCU sampling intervals instead of PC receive intervals', () {
    final synchronizer = McuClockSynchronizer();
    final receivedAt = DateTime.utc(2026, 1, 1, 12);

    final first = synchronizer.align(1000, receivedAt);
    final second = synchronizer.align(
      1050,
      receivedAt.add(const Duration(milliseconds: 500)),
    );

    expect(second.difference(first), const Duration(milliseconds: 50));
  });

  test('continues smoothly through uint32 tick wrap', () {
    final synchronizer = McuClockSynchronizer();
    final receivedAt = DateTime.utc(2026, 1, 1, 12);

    final beforeWrap = synchronizer.align(0xFFFFFFF0, receivedAt);
    final afterWrap = synchronizer.align(
      0x00000010,
      receivedAt.add(const Duration(milliseconds: 32)),
    );

    expect(afterWrap.difference(beforeWrap), const Duration(milliseconds: 32));
  });

  test('starts a new clock mapping after an MCU reset', () {
    final synchronizer = McuClockSynchronizer();
    final firstReceive = DateTime.utc(2026, 1, 1, 12);
    final rebootReceive = firstReceive.add(const Duration(seconds: 10));

    synchronizer.align(5000, firstReceive);
    final afterReboot = synchronizer.align(100, rebootReceive);

    expect(afterReboot, rebootReceive);
  });
}
