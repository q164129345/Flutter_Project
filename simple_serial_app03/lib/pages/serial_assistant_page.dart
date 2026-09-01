import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/serial_port_service.dart';

// 用 enum 代替 bool，比如比 _isHexMode 更容易理解和扩展。
// 以后如果增加 ASCII、Base64 等模式，只需继续增加枚举值。
enum DataMode { text, hex }

/// 串口助手页面使用 StatefulWidget，因为串口列表、连接状态、
/// 数据模式和接收内容都会在页面显示期间发生变化。
class SerialAssistantPage extends StatefulWidget {
  const SerialAssistantPage({super.key});

  @override
  State<SerialAssistantPage> createState() => _SerialAssistantPageState();
}

class _SerialAssistantPageState extends State<SerialAssistantPage> {
  // State 存活期间只创建一个 Service，避免 build() 每次重建时反复创建串口。
  final SerialPortService _serialService = SerialPortService();

  // 下划线开头表示 Dart 库内私有成员；外部文件不能直接访问。
  // List<String> 表示列表中只允许存放字符串。
  List<String> _ports = [];

  // 刚启动或无可用串口时没有选中项，因此类型必须是可空 String?。
  String? _selectedPort;

  // final 表示变量不能再指向另一个 List，但 List 本身仍然是可变对象。
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

  // TextEditingController 让代码可以读取、修改 TextField 的内容。
  // 易错点：Controller 需要在 dispose() 中释放。
  final TextEditingController _sendController = TextEditingController();

  // 当前发送和接收数据的显示模式
  DataMode _dataMode = DataMode.text;

  // getter 不另存一份状态，每次都直接读取 Service，避免两份连接状态不一致。
  bool get _isConnected => _serialService.isConnected;

  // 每项已经包含时间戳和用于 UI 显示的文本。
  final List<String> _receivedMessages = [];

  // 字符串模式的订阅类型是 StreamSubscription<String>，
  // HEX 模式是 StreamSubscription<Uint8List>，所以这里用 dynamic 统一保存。
  // 无论实际类型是什么，都可以调用 cancel()。
  StreamSubscription<dynamic>? _receiveSubscription;

  // 用于在收到新数据后，让列表自动滚动到最底部。也必须 dispose()。
  final ScrollController _receiveScrollController = ScrollController();

  // =========================
  // 收到一条串口消息
  // =========================
  void _onReceivedText(String message) {
    // Stream 回调是异步的。页面可能已被关闭，这时不能再调用 setState()。
    if (!mounted) {
      return;
    }

    final now = DateTime.now(); // 当前时间

    final time =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';

    // setState() 告诉 Flutter：状态改变了，需要重新执行 build()。
    // 如果只修改 List 却不调用 setState，界面不会立即更新。
    setState(() {
      _receivedMessages.add('$time -> $message');
    });

    // setState 后 Widget 还没有立即完成新布局。
    // 等本帧结束再读 maxScrollExtent，才能拿到更新后的最大滚动距离。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // hasClients 用来确认 ScrollController 已经绑定到 ListView。
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
    // toRadixString(16) 转为十六进制；padLeft 保证 0A 不会只显示 A。
    // join(' ') 只增加显示用空格，并不会改变实际接收到的字节。
    return bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(' ');
  }

  // =========================
  // 根据当前模式监听串口数据
  // =========================
  void _listenForIncomingData() {
    // 易错点：切换模式时必须先取消上一个订阅，
    // 否则同一份数据可能被多个监听器同时显示，而且会造成资源泄漏。
    _receiveSubscription?.cancel();

    if (_dataMode == DataMode.hex) {
      _receiveSubscription = _serialService.receivedBytesStream.listen((bytes) {
        // 注意：bytes 是底层某次读到的数据块，不一定就是一个完整的设备数据包。
        if (bytes.isNotEmpty) {
          _onReceivedText(_bytesToHex(bytes));
        }
      }, onError: _onReceiveError);
    } else {
      _receiveSubscription = _serialService.receivedTextStream.listen(
        _onReceivedText,
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

    // initState() 在 State 创建后只执行一次，适合做首次扫描和建立监听。
    // 不要把这些操作放进 build()，因为 build() 可能被调用很多次。
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

  // =========================
  // 将 HEX 输入转换为字节
  // 支持 AA BB CC、AABBCC、0xAA 0xBB 等格式
  // =========================
  Uint8List _parseHex(String input) {
    // 第一步：删除可选的 0x 前缀、空白和逗号。
    // r'...' 是 Dart 的原始字符串，正则中的 \s 不需要再写成 \\s。
    final cleaned = input
        .replaceAll(RegExp(r'0[xX]'), '')
        .replaceAll(RegExp(r'[\s,]+'), '');

    if (cleaned.isEmpty) {
      throw const FormatException('请输入 HEX 数据');
    }

    // 一个字节必须由两个 HEX 字符表示，例如 0A、FF。
    // 因此 ABC 这种奇数长度是不明确的，直接报错比自动补零更安全。
    if (cleaned.length.isOdd) {
      throw const FormatException('HEX 字符数量必须是偶数');
    }

    // ^ 和 $ 要求整个字符串都是合法 HEX，不能只验证其中一部分。
    if (!RegExp(r'^[0-9a-fA-F]+$').hasMatch(cleaned)) {
      throw const FormatException('HEX 数据中包含非法字符');
    }

    final bytes = <int>[];

    // 每两个字符切成一组，radix: 16 表示按十六进制解析。
    // 例如“FF”会转换成十进制整数 255。
    for (var index = 0; index < cleaned.length; index += 2) {
      bytes.add(int.parse(cleaned.substring(index, index + 2), radix: 16));
    }

    return Uint8List.fromList(bytes);
  }

  // =========================
  // 发送数据
  // =========================
  void _sendData() {
    // 在调用 Service 前先做 UI 层校验，让用户可以看到更友好的状态提示。
    if (!_isConnected) {
      setState(() {
        _status = '请先连接串口';
      });

      return;
    }

    // TextField 中的内容无论是文字还是 HEX，读出来的类型都是 String。
    final text = _sendController.text;

    if (text.isEmpty) {
      return;
    }

    try {
      // 三元表达式：条件 ? HEX 分支 : 字符串分支。
      final count = _dataMode == DataMode.hex
          ? _serialService.sendBytes(_parseHex(text))
          : _serialService.sendText(text);

      setState(() => _status = '已发送 $count 字节');
    } on FormatException catch (e) {
      // 单独捕获 HEX 格式错误，可以显示更明确的原因。
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
      _receivedMessages.clear();
    });
  }

  // =========================
  // 页面销毁
  // =========================
  @override
  void dispose() {
    // dispose() 在页面永久移出 Widget 树时执行。
    // 这里需要对创建过的 Controller、Stream 订阅和 Service 成对释放。
    _sendController.dispose();

    // 取消接收Stream的监听
    _receiveSubscription?.cancel();

    // 销毁接收区域滚动控制器
    _receiveScrollController.dispose();

    // 关闭串口并销毁 Service
    _serialService.dispose();

    // 一般先释放自己的资源，最后调用父类 dispose()。
    super.dispose();
  }

  // =========================
  // UI
  // =========================
  @override
  Widget build(BuildContext context) {
    // build() 应当只根据当前状态描述 UI，不要在这里连接串口或创建 Stream 监听。
    // setState()、窗口尺寸变化、主题变化等都可能让 build() 重复执行。
    return Scaffold(
      appBar: AppBar(
        title: const Text('简单的串口助手'),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),

      body: Center(
        // 限制桌面端页面的内容宽度，避免窗口很大时控件被无限拉宽。
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
                      // Expanded 让串口下拉框占用 Row 中剩余的可用宽度。
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
                              // map() 把每个串口名称转换成一个下拉菜单项。
                              // map 返回 Iterable，DropdownButton.items 需要 List，所以最后调用 toList()。
                              items: _ports.map((port) {
                                return DropdownMenuItem(
                                  value: port,
                                  child: Text(port),
                                );
                              }).toList(),

                              // Flutter 按钮/输入控件的回调为 null 时会自动进入禁用状态。
                              // 连接中禁止换串口，避免 UI 所选串口与实际已打开串口不一致。
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
                        // SegmentedButton 支持多选，因此 selected 的类型是 Set<DataMode>。
                        // 本页只允许单选，集合中始终只放当前一项。
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

                          // 模式变化后不仅需要刷新标题，也要重新订阅对应的数据流。
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
                          // controller 保存用户输入；之后 _sendData() 通过 controller.text 读取。
                          controller: _sendController,
                          // 不仅禁用“发送”按钮，连接前也禁用输入框。
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
                          // 用户在输入框中按 Enter 时发送。
                          // 参数本身就是当前文本，但这里统一让 _sendData() 从 controller 读取，所以用 _ 忽略它。
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
                        onPressed: _receivedMessages.isEmpty
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
                      child: _receivedMessages.isEmpty
                          ? const Center(
                              child: Text(
                                '暂时没有数据',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              // builder 只构建当前需要显示的列表项，比一次性创建所有 Widget 更节省资源。
                              controller: _receiveScrollController,
                              itemCount: _receivedMessages.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  // SelectableText 允许用户鼠标选择并复制接收到的数据。
                                  child: SelectableText(
                                    _receivedMessages[index],
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
