import 'package:flutter/material.dart';

import '../services/serial_port_service.dart';

class SerialAssistantPage extends StatefulWidget {
  const SerialAssistantPage({super.key});

  @override
  State<SerialAssistantPage> createState() =>
      _SerialAssistantPageState();
}

class _SerialAssistantPageState extends State<SerialAssistantPage> {
  final SerialPortService _serialService = SerialPortService(); // 获取串口服务实例
  List<String> _ports = []; // 
  String? _selectedPort;    // 当前选择的串口

  final List<int> _baudRates = [
    9600,
    19200,
    38400,
    57600,
    115200,
    230400,
    460800,
    921600,
  ];

  int _selectedBaudRate = 115200; // 波特率
 
  String _status = '未连接';       // 连接状态

  final TextEditingController _sendController = TextEditingController();

  /// 当前是否已经连接串口
  bool get _isConnected => _serialService.isConnected;

  @override
  void initState() {
    super.initState();

    // 程序启动以后扫描一次串口
    _refreshPorts();
  }

  // =========================
  // 扫描串口
  // =========================
  void _refreshPorts() {
    try {
      final ports = _serialService.getAvailablePorts(); // 获取有效的串口列表
      String? selectedPort = _selectedPort;

      // 如果原来的串口号还在的话，就跳过这段代码。
      // 原来的串口号不在时，赋值列表里的第一个串口。如果没有串口被检查出来，即赋null。
      if (!ports.contains(selectedPort)) {
        selectedPort = ports.isNotEmpty ? ports.first : null;
      }

      // 通知Flutter框架，变量发生了变化
      setState(() {
        _ports = ports;
        _selectedPort = selectedPort;
      });

    } catch (e) {
      setState(() {
        _status = '扫描串口失败：$e';
      });
    }
  }

  // =========================
  // 连接串口
  // =========================
  void _connect() {
    if (_selectedPort == null) {
      setState(() {
        _status = '没有可用串口';
      });

      return;
    }

    try {
      _serialService.connect(
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

    setState(() {
      _status = '未连接';
    });
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

  // =========================
  // 发送数据
  // =========================
  void _sendData() {
    if (!_isConnected) {
      setState(() {
        _status = '请先连接串口';
      });

      return;
    }

    final text = _sendController.text;

    if (text.isEmpty) {
      return;
    }

    try {
      final count =
          _serialService.sendText(text);

      setState(() {
        _status = '已发送 $count 字节';
      });
    } catch (e) {
      setState(() {
        _status = '发送失败：$e';
      });
    }
  }

  // =========================
  // 页面销毁
  // =========================
  @override
  void dispose() {
    _sendController.dispose();

    // 页面销毁时断开串口并释放相关资源
    _serialService.disconnect();

    super.dispose();
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('简单的串口助手'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),

      body: Center(
        child: SizedBox(
          width: 760,
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // =========================
                  // 串口配置
                  // =========================
                  Row(
                    children: [
                      // 串口选择
                      Expanded(
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '串口',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedPort,
                              isExpanded: true,
                              isDense: true,
                              menuMaxHeight: 300,

                              // 将串口名称列表映射为下拉菜单选项，
                              // 再通过 toList() 生成 DropdownButton 所需的选项列表。
                              items: _ports.map((port) {
                                return DropdownMenuItem(
                                  value: port,
                                  child: Text(port),
                                );
                              }).toList(),

                              onChanged: _isConnected
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _selectedPort =
                                            value;
                                      });
                                    },
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      // 刷新
                      IconButton.filledTonal(
                        tooltip: '刷新串口',
                        onPressed: _isConnected
                            ? null
                            : _refreshPorts,
                        icon: const Icon(Icons.refresh),
                      ),

                      const SizedBox(width: 16),

                      // 波特率
                      SizedBox(
                        width: 120,
                        child: InputDecorator(
                          decoration:
                              const InputDecoration(
                            labelText: '波特率',
                            border:
                                OutlineInputBorder(),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedBaudRate,
                              isExpanded: true,
                              isDense: true,
                              items: _baudRates.map((baudRate) {
                                return DropdownMenuItem(
                                  value: baudRate,
                                  child: Text('$baudRate'),
                                );
                              }).toList(),

                              onChanged: _isConnected
                                  ? null
                                  : (value) {
                                      if (value == null) {
                                        return;
                                      }

                                      setState(() {
                                        _selectedBaudRate =
                                            value;
                                      });
                                    },
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      // 连接 / 断开
                      FilledButton.icon(
                        onPressed: _selectedPort == null
                            ? null
                            : _toggleConnection,
                        icon: Icon(
                          _isConnected
                              ? Icons.link_off
                              : Icons.link,
                        ),
                        label: Text(
                          _isConnected
                              ? '断开'
                              : '连接',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // =========================
                  // 发送数据
                  // =========================
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller:
                              _sendController,
                          enabled: _isConnected,
                          decoration:
                              const InputDecoration(
                            labelText: '发送数据',
                            hintText:
                                '例如：Hello,world',
                            border:
                                OutlineInputBorder(),
                          ),
                          onSubmitted: (_) {
                            _sendData();
                          },
                        ),
                      ),

                      const SizedBox(width: 12),

                      FilledButton.icon(
                        onPressed: _isConnected
                            ? _sendData
                            : null,
                        icon:
                            const Icon(Icons.send),
                        label:
                            const Text('发送'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // =========================
                  // 状态
                  // =========================
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: _isConnected
                            ? Colors.green
                            : Colors.grey,
                      ),

                      const SizedBox(width: 10),

                      Text(_status),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
