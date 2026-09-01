import '../services/serial_port_service.dart';
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';


class SettingPage extends StatefulWidget {
  const SettingPage({super.key});

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  // 串口服务实例
  final SerialPortService _serialService = SerialPortService();

  // 下划线开头表示 Dart 库内私有成员；外部文件不能直接访问。
  // List<String> 表示列表中只允许存放字符串。
  List<String> _ports = [];

  // 当前选中的串口
  String? _selectedPort;

  // 波特率(跟下位机约定好460800)
  int _selectedBaudRate = 460800;

  // 连接状态
  String _status = '未连接';

  // getter 不另存一份状态，每次都直接读取 Service，避免两份连接状态不一致。
  bool get _isConnected => _serialService.isConnected;

  @override
  void initState() {
    super.initState();

    // initState() 在 State 创建后只执行一次，适合做首次扫描和建立监听。
    // 不要把这些操作放进 build()，因为 build() 可能被调用很多次。
    _refreshPorts(); // 程序启动以后扫描一次串口

    //_listenForIncomingData();
  }

  // =========================
  // 扫描串口
  // =========================
  void _refreshPorts() {
    try {
      final ports = _serialService.getAvailablePorts(); // 获取有效的串口列表
      String? selectedPort = _selectedPort;

      // 刷新后原串口可能已被拔出。如果原选择仍有效就保留，
      // 否则选择列表第一项；列表为空时使用 null。
      if (!ports.contains(selectedPort)) {
        selectedPort = ports.isNotEmpty ? ports.first : null;
      }

      // 先在局部变量中把新状态计算完，再一次性放入 setState。
      setState(() {
        _ports = ports;
        _selectedPort = selectedPort;
      });
    } catch (e) {
      setState(() => _status = '扫描串口失败：$e');
    }
  }

  // =========================
  // 连接串口
  // =========================
  void _connect() {
    if (_selectedPort == null) {
      setState(() => _status = '没有可用串口');

      return;
    }

    try {
      _serialService.connect(
        // 前面已经判断不为 null，所以这里可以用“!”做非空断言。
        // 易错点：不要在未检查 null 的情况下随意使用 !，否则运行时会崩溃。
        portName: _selectedPort!,
        baudRate: _selectedBaudRate,
      );
      setState(() => _status = '已连接 $_selectedPort $_selectedBaudRate baud');
    } catch (e) {
      setState(() => _status = '连接失败：$e');
    }
  }

  // =========================
  // 断开串口
  // =========================
  void _disconnect() {
    _serialService.disconnect();
    setState(() => _status = '未连接');
  }

  // =========================
  // 连接 / 断开
  // =========================
  void _toggleConnection() {
    if (_isConnected) {
      _disconnect();
    } else {
      _connect();
    }
  }



}




















