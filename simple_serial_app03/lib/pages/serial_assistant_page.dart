import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/serial_port_service.dart';

enum DataMode { text, hex }

class SerialAssistantPage extends StatefulWidget {
  const SerialAssistantPage({super.key});

  @override
  State<SerialAssistantPage> createState() => _SerialAssistantPageState();
}

class _SerialAssistantPageState extends State<SerialAssistantPage> {
  // 对象实例化
  final SerialPortService _serialService = SerialPortService();

  // 保存当前扫描得到的串口名称
  List<String> _ports = [];

  // 当前选择的串口
  String? _selectedPort;

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

  // 波特率
  int _selectedBaudRate = 115200;

  // 连接状态
  String _status = '未连接';

  // 保存发送TextField的文本
  final TextEditingController _sendController = TextEditingController();

  // 当前发送和接收数据的显示模式
  DataMode _dataMode = DataMode.text;

  // 当前是否已经连接串口
  bool get _isConnected => _serialService.isConnected;

  // 保存所有收到的字符串信息
  final List<String> _receviedMessage = [];

  // 监听 serialPortService的接收Stream
  StreamSubscription<dynamic>? _receiveSubscription;

  // 控制接收区域滚动
  final ScrollController _receiveScrollController = ScrollController();

  // =========================
  // 收到一条串口消息
  // =========================
  void _onReceviedText(String message) {
    if (!mounted) {
      return;
    }

    final now = DateTime.now(); // 当前时间

    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    setState(() {
      _receviedMessage.add('$time -> $message');
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_receiveScrollController.hasClients) {
        _receiveScrollController.jumpTo(
          _receiveScrollController.position.maxScrollExtent,
        );
      }
    });
  }

  // =========================
  // 将串口字节格式化为 HEX 文本
  // =========================
  String _bytesToHex(Uint8List bytes) {
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  // =========================
  // 根据当前模式监听串口数据
  // =========================
  void _listenForIncomingData() {
    _receiveSubscription?.cancel();

    if (_dataMode == DataMode.hex) {
      _receiveSubscription = _serialService.receivedBytesStream.listen((bytes) {
        if (bytes.isNotEmpty) {
          _onReceviedText(_bytesToHex(bytes));
        }
      }, onError: _onReceiveError);
    } else {
      _receiveSubscription = _serialService.receivedTextStream.listen(
        _onReceviedText,
        onError: _onReceiveError,
      );
    }
  }

  void _onReceiveError(Object error) {
    if (!mounted) {
      return;
    }

    setState(() {
      _status = '接收失败：$error';
    });
  }

  @override
  void initState() {
    super.initState();
    _refreshPorts(); // 程序启动以后扫描一次串口

    _listenForIncomingData();
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

  // =========================
  // 将 HEX 输入转换为字节
  // 支持 AA BB CC、AABBCC、0xAA 0xBB 等格式
  // =========================
  Uint8List _parseHex(String input) {
    final cleaned = input
        .replaceAll(RegExp(r'0[xX]'), '')
        .replaceAll(RegExp(r'[\s,]+'), '');

    if (cleaned.isEmpty) {
      throw const FormatException('请输入 HEX 数据');
    }

    if (cleaned.length.isOdd) {
      throw const FormatException('HEX 字符数量必须是偶数');
    }

    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(cleaned)) {
      throw const FormatException('HEX 数据中包含非法字符');
    }

    final bytes = <int>[];

    for (var index = 0; index < cleaned.length; index += 2) {
      bytes.add(int.parse(cleaned.substring(index, index + 2), radix: 16));
    }

    return Uint8List.fromList(bytes);
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
      final count = _dataMode == DataMode.hex
          ? _serialService.sendBytes(_parseHex(text))
          : _serialService.sendText(text);

      setState(() => _status = '已发送 $count 字节');
    } on FormatException catch (e) {
      setState(() => _status = 'HEX 格式错误：${e.message}');
    } catch (e) {
      setState(() => _status = '发送失败：$e');
    }
  }

  // =========================
  // 清空接收数据
  // =========================
  void _clearReceivedData() {
    setState(() {
      _receviedMessage.clear();
    });
  }

  // =========================
  // 页面销毁
  // =========================
  @override
  void dispose() {
    _sendController.dispose();

    // 取消接收Stream的监听
    _receiveSubscription?.cancel();

    // 销毁接收区域滚动控制器
    _receiveScrollController.dispose();

    // 关闭串口并销毁 Service
    _serialService.dispose();

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
                                        _selectedPort = value;
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
                        onPressed: _isConnected ? null : _refreshPorts,
                        icon: const Icon(Icons.refresh),
                      ),

                      const SizedBox(width: 16),

                      // 波特率
                      SizedBox(
                        width: 120,
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: '波特率',
                            border: OutlineInputBorder(),
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
                                        _selectedBaudRate = value;
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
                        icon: Icon(_isConnected ? Icons.link_off : Icons.link),
                        label: Text(_isConnected ? '断开' : '连接'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // =========================
                  // 数据模式
                  // =========================
                  Row(
                    children: [
                      const Text('数据模式：'),
                      const SizedBox(width: 12),
                      SegmentedButton<DataMode>(
                        segments: const [
                          ButtonSegment<DataMode>(
                            value: DataMode.text,
                            label: Text('字符串'),
                            icon: Icon(Icons.text_fields),
                          ),
                          ButtonSegment<DataMode>(
                            value: DataMode.hex,
                            label: Text('HEX'),
                            icon: Icon(Icons.numbers),
                          ),
                        ],
                        selected: <DataMode>{_dataMode},
                        showSelectedIcon: false,
                        onSelectionChanged: (selection) {
                          final mode = selection.first;

                          if (mode == _dataMode) {
                            return;
                          }

                          setState(() {
                            _dataMode = mode;
                          });
                          _listenForIncomingData();
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // =========================
                  // 发送数据
                  // =========================
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sendController,
                          enabled: _isConnected,
                          decoration: InputDecoration(
                            labelText: _dataMode == DataMode.hex
                                ? '发送 HEX 数据'
                                : '发送字符串',
                            hintText: _dataMode == DataMode.hex
                                ? '例如：01 A0 FF'
                                : '例如：Hello, world',
                            border: const OutlineInputBorder(),
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

                  // =========================
                  // 状态
                  // =========================
                  Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 10,
                        color: _isConnected ? Colors.green : Colors.grey,
                      ),

                      const SizedBox(width: 10),

                      Text(_status),

                      const Spacer(),

                      OutlinedButton.icon(
                        onPressed: _receviedMessage.isEmpty
                            ? null
                            : _clearReceivedData,
                        icon: const Icon(Icons.delete_sweep),
                        label: const Text('清空接收'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // =========================
                  // 接收区域
                  // =========================
                  InputDecorator(
                    decoration: InputDecoration(
                      labelText: _dataMode == DataMode.hex
                          ? '接收数据（HEX）'
                          : '接收数据（字符串）',
                      border: const OutlineInputBorder(),
                      contentPadding: const EdgeInsets.all(12),
                    ),

                    child: SizedBox(
                      height: 260,
                      child: _receviedMessage.isEmpty
                          ? const Center(
                              child: Text(
                                '暂时没有数据',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              controller: _receiveScrollController,
                              itemCount: _receviedMessage.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: SelectableText(
                                    _receviedMessage[index],
                                  ),
                                );
                              },
                            ),
                    ),
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
