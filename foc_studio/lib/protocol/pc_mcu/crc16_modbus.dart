/// 逐位计算 CRC16-MODBUS，多项式为 0xA001，初始值为 0xFFFF。
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

/// 对 [start, end) 范围直接计算 CRC，供接收解包使用，避免逐帧复制字节列表。
/// 查表结果与上面的逐位算法一致；输入由串口字节流保证在 0..255 范围内。
int crc16ModbusRange(List<int> bytes, int start, int end) {
  RangeError.checkValidRange(start, end, bytes.length);
  var crc = 0xFFFF;
  for (var index = start; index < end; index++) {
    crc = (crc >> 8) ^ _crcTable[(crc ^ bytes[index]) & 0xFF];
  }
  return crc;
}

// 预先算好 256 种单字节的 CRC 变换，把每字节 8 次位运算合并为一次查表。
// 该表在使用它的 isolate 内只初始化一次，后续所有帧复用。
final List<int> _crcTable = List<int>.generate(256, (value) {
  var crc = value;
  for (var bit = 0; bit < 8; bit++) {
    crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1;
  }
  return crc;
}, growable: false);
