import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';


class SerialPortService {
  /// 串口实例
  SerialPort? _port;

  /// 获取系统当前有效串口
  List<String> getAvailablePorts() {
    return SerialPort.availablePorts; // 通过系统接口枚举已存在串口名称
  }

  /// 读串口的句柄
  SerialPortReader? _reader;

  /// 接收监听
  StreamSubscription<String>? _readerSubscription;

  /// 将接收的字符串消息发给UI
  final StreamController<String> _receivedTextController = StreamController<String>.broadcast();

  /// UI通过这个Stream 获取串口接收的数据
  Stream<String> get receviedTextStream => _receivedTextController.stream;

  /// 当前串口是否已经打开
  bool get isConnected => _port?.isOpen ?? false;

  /// 打开串口
  void connect({
    required String portName,
    required int baudRate,
  }) {
    // 如果已经连接，先断开
    if (isConnected) {
      disconnect();
    }

    final port = SerialPort(portName); // 创建串口对象

    try {
      // 打开串口：读 + 写
      final success = port.openReadWrite();

      if (!success) {
        _releasePortObject(port);

        throw Exception(
          '打开串口失败，串口可能被占用',
        );
      }

      // 创建串口配置
      final config = SerialPortConfig();

      try {
        // 波特率
        config.baudRate = baudRate;

        // 8N1
        config.bits = 8;
        config.stopBits = 1;
        config.parity = SerialPortParity.none;

        // 不使用流控
        config.setFlowControl(
          SerialPortFlowControl.none,
        );

        // 应用配置
        port.config = config;
      } finally {
        config.dispose();
      }

      // 配置成功以后，才保存这个串口对象
      _port = port;

      // 开始监听接收串口数据
      _startReading();
    } catch (e) {
      try {
        if (port.isOpen) {
          port.close();
        }
      } catch (_) {}

      _releasePortObject(port);

      rethrow;
    }
  }

  /// 开始接收数据
  void _startReading() {
    final port = _port;

    if (port == null) return;

    // 创建异步串口读取器
    _reader = SerialPortReader(port);

    _readerSubscription = _reader!
      .stream
      .cast<List<int>>()
      // Uint8List
      //     ↓
      // UTF-8 String
      .transform(const Utf8Decoder(allowMalformed: true))
      // String 数据流
      //     ↓
      // 按 \n / \r\n分割成一条条消息
      .transform(const LineSplitter())
      // 监控每一条完整的信息
      .listen(
        (message) {
        _receivedTextController.add(message);
        },
        onError: (error) {
          _receivedTextController.addError(error);
        },
      );
  }

  /// 发送字符串
  int sendText(String text) {
    if (!isConnected || _port == null) {
      throw StateError('串口没有连接');
    }

    // String
    //    ↓
    // UTF-8
    //    ↓
    // Uint8List
    final data = Uint8List.fromList(
      utf8.encode(text),
    );

    return _port!.write(data);
  }

  /// 停止串口接收
  void _stopReading() {
    // 取消 Stream 监听
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

    // 先解除当前对象引用
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

  /// 销毁整个Servie
  void dispose() {
    disconnect();
    _receivedTextController.close();
  }

}







