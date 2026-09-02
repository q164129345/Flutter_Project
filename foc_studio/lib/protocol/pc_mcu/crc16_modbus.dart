/// Calculates CRC16-MODBUS using polynomial 0xA001 and initial value 0xFFFF.
int crc16Modbus(Iterable<int> bytes) {
  var crc = 0xFFFF;

  for (final byte in bytes) {
    if (byte < 0 || byte > 0xFF) {
      throw RangeError.range(byte, 0, 0xFF, 'byte');
    }

    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      if ((crc & 1) != 0) {
        crc = (crc >> 1) ^ 0xA001;
      } else {
        crc >>= 1;
      }
    }
  }

  return crc & 0xFFFF;
}
