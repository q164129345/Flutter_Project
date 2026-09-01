import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

/// 串口服务层：只负责“找串口、连接、收发字节、释放资源”。
///
/// 将串口逻辑从 Widget 中拆出来，可以避免 UI 代码同时处理大量底层细节。
class SerialPortService {
  // “?”表示该变量可以为 null；未连接时就没有 SerialPort 对象。
  SerialPort? _port;

  /// 每次调用都重新读取系统串口列表。
  /// USB 串口拔插后列表可能变化，所以 UI 需要提供“刷新”按钮。
  List<String> getAvailablePorts() {
    return SerialPort.availablePorts; // 通过系统接口枚举已存在串口名称
  }

  // SerialPortReader 把底层串口读取转换成 Dart Stream。
  SerialPortReader? _reader;

  // listen() 会返回订阅对象；必须保存它，断开时才能 cancel()。
  StreamSubscription<Uint8List>? _readerSubscription;

  // broadcast 允许多个监听者订阅。这里 UI 可以在字符串流和字节流之间切换。
  // 易错点：broadcast Stream 在没有监听者时不会替你缓存历史数据。
  final StreamController<Uint8List> _receivedBytesController =
      StreamController<Uint8List>.broadcast();

  /// HEX 模式直接使用原始字节，不做文字解码。
  Stream<Uint8List> get receivedBytesStream => _receivedBytesController.stream;

  /// 字符串模式：原始字节 -> UTF-8 文本 -> 按换行符拆分。
  ///
  /// allowMalformed 为 true 时，非法 UTF-8 字节会被替换字符代替，不会让整个流报错中断。
  /// LineSplitter 只在收到 \n 或 \r\n 后才产生一条消息；
  /// 如果设备不发换行符，字符串模式就会一直等待。
  Stream<String> get receivedTextStream => receivedBytesStream
      .cast<List<int>>()
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());

  // “?.”是空安全访问，“?? false”表示 _port 为 null 时返回 false。
  bool get isConnected => _port?.isOpen ?? false;

  /// 打开并配置串口。
  void connect({required String portName, required int baudRate}) {
    // 如果已经连接，先断开
    if (isConnected) {
      disconnect();
    }

    // 先使用局部变量，配置全部成功后再赋给 _port。
    // 这样如果中途失败，isConnected 不会误判为已连接。
    final port = SerialPort(portName);

    try {
      // 打开串口：读 + 写
      final success = port.openReadWrite();

      if (!success) {
        _releasePortObject(port);

        throw Exception('打开串口失败，串口可能被占用');
      }

      // SerialPortConfig 包含底层资源，用完后也需要 dispose()。
      final config = SerialPortConfig();

      try {
        // 波特率
        config.baudRate = baudRate;

        // 常见的 8N1：8 个数据位、无校验、1 个停止位。
        // 易错点：这些参数必须与对端设备完全一致。
        config.bits = 8;
        config.stopBits = 1;
        config.parity = SerialPortParity.none;

        // 不使用流控
        config.setFlowControl(SerialPortFlowControl.none);

        // 应用配置
        port.config = config;
      } finally {
        // finally 无论配置成功还是抛出异常都会执行，用于保证资源释放。
        config.dispose();
      }

      // 配置成功以后，才保存这个串口对象
      _port = port;

      // 开始监听接收串口数据
      _startReading();
    } catch (e) {
      // 连接的任意一步失败时，都尝试关闭并释放已创建的对象。
      try {
        if (port.isOpen) {
          port.close();
        }
      } catch (_) {}

      _releasePortObject(port);

      // rethrow 会保留原始异常和堆栈，让 UI 层可以显示“连接失败”。
      rethrow;
    }
  }

  /// 开始接收数据
  void _startReading() {
    final port = _port;

    if (port == null) {
      return;
    }

    // 创建异步串口读取器
    _reader = SerialPortReader(port);

    _readerSubscription = _reader!.stream.listen(
      (data) {
        // 复制数据，避免底层读缓冲区被重复使用
        // 易错点：Stream 的一次 data 回调只是“当前读到的一块”，
        // 并不保证恰好是一个完整协议数据包。复杂协议需要另外做组包。
        _receivedBytesController.add(Uint8List.fromList(data));
      },
      onError: (error) {
        _receivedBytesController.addError(error);
      },
    );
  }

  /// 发送原始字节，HEX 模式最终会调用这里。
  int sendBytes(List<int> bytes) {
    if (!isConnected || _port == null) {
      throw StateError('串口没有连接');
    }

    // write() 的返回值是实际写入的字节数，不是字符个数。
    return _port!.write(Uint8List.fromList(bytes));
  }

  /// 发送字符串：先通过 UTF-8 转换成字节，再复用 sendBytes()。
  /// 注意：一个中文字符通常会编码成 3 个 UTF-8 字节。
  int sendText(String text) {
    return sendBytes(utf8.encode(text));
  }

  /// 停止串口接收
  void _stopReading() {
    // 先取消 Stream 监听，避免断开后回调仍继续访问旧串口。
    _readerSubscription?.cancel();
    _readerSubscription = null;

    // SerialPortReader 必须关闭
    _reader?.close();
    _reader = null;
  }

  /// 断开串口
  void disconnect() {
    // 先停止接收
    _stopReading();

    final port = _port;

    // 先解除当前对象引用，使 UI 能立即读到“未连接”状态。
    _port = null;

    if (port == null) {
      return;
    }

    try {
      if (port.isOpen) {
        port.close();
      }
    } catch (e) {
      debugPrint('关闭串口失败：$e');
    }

    _releasePortObject(port);
  }

  /// 释放 SerialPort 对象
  void _releasePortObject(SerialPort port) {
    // flutter_libserialport 在 Windows 下
    // dispose() 当前可能导致程序崩溃。
    //
    // 所以 Windows 暂时不要调用。
    if (Platform.isWindows) {
      return;
    }

    try {
      port.dispose();
    } catch (e) {
      debugPrint('释放串口失败：$e');
    }
  }

  /// 销毁整个 Service。
  /// 易错点：StreamController 关闭后不能再 add()，因此 dispose 后该对象不能复用。
  void dispose() {
    disconnect();
    _receivedBytesController.close();
  }
}
