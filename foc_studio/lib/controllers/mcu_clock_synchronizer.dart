/// Maps the MCU's uint32 HAL_GetTick() clock onto the PC wall clock.
class McuClockSynchronizer {
  static const int _wrapAt = 0x100000000;

  DateTime? _pcOrigin;
  int? _lastTick;
  int _wrapCount = 0;

  DateTime align(int tickMs, DateTime receivedAt) {
    if (tickMs < 0 || tickMs > 0xFFFFFFFF) {
      throw RangeError.range(tickMs, 0, 0xFFFFFFFF, 'tickMs');
    }

    final lastTick = _lastTick;
    if (_pcOrigin == null) {
      _pcOrigin = receivedAt.subtract(Duration(milliseconds: tickMs));
    } else if (lastTick != null && tickMs < lastTick) {
      final looksLikeWrap = lastTick > 0xF0000000 && tickMs < 0x0FFFFFFF;
      if (looksLikeWrap) {
        _wrapCount++;
      } else {
        // A backwards jump away from the uint32 boundary indicates MCU reset.
        _wrapCount = 0;
        _pcOrigin = receivedAt.subtract(Duration(milliseconds: tickMs));
      }
    }

    _lastTick = tickMs;
    final extendedTick = _wrapCount * _wrapAt + tickMs;
    return _pcOrigin!.add(Duration(milliseconds: extendedTick));
  }

  void reset() {
    _pcOrigin = null;
    _lastTick = null;
    _wrapCount = 0;
  }
}
