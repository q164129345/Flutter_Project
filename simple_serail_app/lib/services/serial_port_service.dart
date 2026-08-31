import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';


class SerialPortService {
  SerialPort? _port;

  /// 当前串口是否已经打开
  bool get isConnected => _port?.isOpen ?? false;

  /// 获取系统当前有效串口
  List<String> getAvailablePorts() {
    return SerialPort.availablePorts;
  }

  /// 打开串口
  void connect({
    required String portName,
    required int baudRate,
  }) {
    // 如果已经连接，先断开
    if (isConnected) {
      disconnect();
    }

    final port = SerialPort(portName);

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

  /// 关闭串口
  void disconnect() {
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

  /// 销毁服务
  void dispose() {
    disconnect();
  }
}








