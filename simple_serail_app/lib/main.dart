import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';


import 'package:flutter_libserialport/flutter_libserialport.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.blue),
      home: const SerialAssistantPage(),
    );
  }
}

class SerialAssistantPage extends StatefulWidget {
  const SerialAssistantPage({super.key});

  @override
  State<SerialAssistantPage> createState() => _SerialAssistantPageState();
}

class _SerialAssistantPageState extends State<SerialAssistantPage> {
  List<String> _ports = []; // 系统检测到的串口

  // 常用的波特率
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

  int _selectedBaudRate = 115200; // 默认波特率
  SerialPort? _port;              // 当前串口对象
  bool _isConnected = false;      // 是否已经连接
  String _status = '未连接';      // 状态提示
  String? _selectedPort;          // 当前选择的串口
  final TextEditingController _sendController = TextEditingController(); // 发送输入框

  // 断开串口
  void _disconnect() {
    try {
      _port?.close();

      // Windows下 flutter_Libserialport的dispose()
      // 当前存在可能导致程序崩溃的问题。
      // 暂时不要调用
      //_port?.dispose();
    }catch(e) {
      debugPrint('关闭串口失败：$e');
    }

    setState(() {
      _port = null;
      _isConnected = false;
      _status = '未连接';
    });
  }

  // 打开串口
  void _connect() {
    if(_selectedPort == null) {
      setState(() {
        _status = '没有可用串口';
      });
      return;
    }

    final port = SerialPort(_selectedPort!);

    try {
      // 打开串口：读 + 写
      final suceess = port.openReadWrite();

      if (!suceess) {
        setState(() {
          _status = '打开串口失败,串口可能被占用';
        });

        port.dispose();
        return;
      }

      // 配置串口参数
      final config = SerialPortConfig();

      try {
        // 设置用户选择的波特率
        config.baudRate = _selectedBaudRate;

        // 8N1
        config.bits = 8;
        config.stopBits = 1;
        config.parity = SerialPortParity.none;

        // 不使用硬件/软件控流
        config.setFlowControl(SerialPortFlowControl.none); 

        port.config = config;

      } finally {
        config.dispose();
      }

      setState(() {
        _port = port;
        _isConnected = true;
        _status = '已连接 $_selectedPort $_selectedBaudRate baud';
      });
    } catch(e) {
      port.dispose();

      setState(() {
        _status = '连接失败: $e';
      });
    }
  }

  // 扫描当前系统可用串口
  void _refreshPorts() {
    try {
      final ports = SerialPort.availablePorts;

      String? selectedPort = _selectedPort;

      // 原来的串口不存在了
      if (!ports.contains(selectedPort)) {
        selectedPort = ports.isNotEmpty ? ports.first : null;
      }

      setState(() {
        _ports = ports;
        _selectedPort = selectedPort;
      });

    } catch (e) {
      setState(() {
        _status = '扫描串口失败: $e';
      });
    }
  }

  // 连接、断开串口
  void _toggleConnection() {
    if(_isConnected) {
      _disconnect();
    } else {
      _connect();
    }
  }

  // 发送数据
  void _sendData() {
    if (!_isConnected || _port == null) {
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
      // String -> UTF-8 -> Uint8List
      final data = Uint8List.fromList(utf8.encode(text));

      final count = _port!.write(data);

      setState(() {
        _status = '已发送 $count 字节';
      });

    } catch (e) {
      setState(() {
        _status = '发送失败: $e';
      });
    }

  }

  @override
  void dispose() {
    _sendController.dispose();

    try {
      _port?.close();
      // Windows 暂时不要调用
      //_port?.dispose();

    } catch (e) {
      debugPrint('关闭串口失败：$e');
    }

    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _refreshPorts(); // 程序启动后，扫描一次串口
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('简单的串口助手'), centerTitle: true),
      body: Center(
        child: SizedBox(
          width: 760,
          child: Card(
            margin: const EdgeInsets.all(24), // 组件外部的间距
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min, //
                children: [
                  // 串口配置
                  Row(
                    children: [
                    // 串口选择
                      Expanded(
                        child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: '串口',
                          border: OutlineInputBorder(),

                          // 控制InputDecorator内部空间
                          contentPadding: EdgeInsets.symmetric(horizontal: 20,vertical: 8),

                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                              value: _selectedPort, // 当前选中的串口
                              isExpanded: true,     // 占满InputDecorator的宽度
                              isDense: true,        // 减少DropdownButton自身高度
                              menuMaxHeight: 300,   // 限制弹出的下拉菜单高度
                              items: _ports.map((port) {
                                return DropdownMenuItem(value: port, child: Text(port),);
                              }).toList(), 
                              onChanged:  _isConnected ? null :(value) { setState(() {
                                  _selectedPort = value;
                                });}
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 8,),

                      // 刷新串口
                      IconButton.filledTonal(
                        tooltip: '刷新串口',
                        onPressed: _isConnected ? null : _refreshPorts,
                        icon: const Icon(Icons.refresh),
                      ),

                      const SizedBox(width: 16),

                      SizedBox(
                        width: 120,
                        child: InputDecorator(
                          decoration: const InputDecoration(labelText: '波特率', border: OutlineInputBorder()),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<int>(
                              value: _selectedBaudRate,
                              isExpanded: true, // 占满InputDecorator的宽度
                              isDense: true,    // 减少DropdownButton自身高度
                              items: _baudRates.map((baudRate) {
                                return DropdownMenuItem(
                                  value: baudRate,
                                  child: Text('$baudRate'),
                                );
                              }).toList(),
                              onChanged: _isConnected ? null : (value) {
                                                                if (value == null) {
                                                                  return;
                                                                }

                                                                setState(() {
                                                                  _selectedBaudRate = value;
                                                                });
                                                              },
                            )
                          ),
                        ),
                      ),

                      const SizedBox(width: 16),
                      
                      // 连接 / 断开
                      FilledButton.icon(
                        onPressed: _selectedPort == null ? null : _toggleConnection, 
                        icon: Icon(
                          _isConnected ? Icons.link_off : Icons.link,
                        ),
                        label: Text(_isConnected ? '断开' : '连接'
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // 发送区域
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sendController,
                          enabled: _isConnected,
                          decoration: const InputDecoration(
                            labelText: '发送数据',
                            hintText: '例如：Hello,world',
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) {
                            _sendData();
                          },
                        ),
                      ),

                      const SizedBox(width: 12),

                      FilledButton.icon(
                        onPressed: _isConnected ? _sendData : null,
                        icon: const Icon(Icons.send), 
                        label: const Text('发送'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 15),

                  // 状态
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size:10,
                        color: _isConnected ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 10),
                      Text(_status),
                    ],
                  )
                ],
              ),
            ), // 组件边界与内部子组件之间的间距
          ),
        ),
      ),
    );
  }
}
