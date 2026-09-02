import '../services/serial_port_service.dart';

import 'package:flutter/material.dart';

class SettingPage extends StatefulWidget {
  // required 表示创建 SettingPage 时必须传入 serialService。
  const SettingPage({super.key, required this.serialService});

  // final 表示设置页只能使用传入的 Service，不能在运行中把它替换掉。
  final SerialPortService serialService;

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  // 设置页与导航栏共用由 MainPage 持有的串口服务。
  // StatefulWidget 的 State 可以通过 widget 属性读取外层 Widget 的参数。
  SerialPortService get _serialService => widget.serialService;

  // 下划线开头表示 Dart 库内私有成员；外部文件不能直接访问。
  // List<String> 表示列表中只允许存放字符串。
  List<String> _ports = [];

  // 当前选中的串口
  String? _selectedPort;

  // 波特率(跟下位机约定好460800)
  static const int _baudRate = 460800;

  // 连接状态
  String _status = '未连接';

  // getter 不另存一份状态，每次都直接读取 Service，避免两份连接状态不一致。
  bool get _isConnected => _serialService.isConnected;

  @override
  void initState() {
    super.initState();

    // 用户从其他页面重新进入设置页时，根据 Service 恢复当前连接信息。
    _selectedPort = _serialService.connectedPortName;

    // switch 会覆盖枚举中的三种状态，所以无需再写 else。
    _status = switch (_serialService.connectionStatus) {
      SerialPortConnectionStatus.connected =>
        '已连接 ${_serialService.connectedPortName} '
            '${_serialService.connectedBaudRate} baud',
      SerialPortConnectionStatus.failed =>
        '连接失败：${_serialService.lastConnectionError ?? '未知错误'}',
      SerialPortConnectionStatus.disconnected => '未连接',
    };

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
        baudRate: _baudRate,
      );
      setState(() => _status = '已连接 $_selectedPort $_baudRate baud');
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
  // 输入框的公共外观
  // =========================
  // InputDecoration 不是一个可见的 Widget，它只是用来描述输入框的边框、
  // 标签和内边距。串口框与波特率框复用这个方法，可以保证外观一致。
  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      // labelText 会显示在输入框边框上。
      labelText: label,

      // always 表示无论输入框有没有内容，标签都始终浮在边框上方。
      // 易错点：如果使用默认值，空内容时标签可能落到输入框内部。
      floatingLabelBehavior: FloatingLabelBehavior.always,

      // OutlineInputBorder 会绘制截图中那种四周都有线的输入框。
      border: const OutlineInputBorder(),

      // 控制文字与边框之间的距离。
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  // getter 不额外保存状态，而是每次根据 _status 计算是否需要显示错误。
  // 易错点：这里依赖中文字符串判断，适合当前简单页面；状态变复杂时，
  // 更推荐使用 enum（枚举）区分“未连接、已连接、错误”等状态。
  bool get _hasError =>
      _status.startsWith('没有') ||
      _status.contains('失败') ||
      _status.contains('错误');

  @override
  Widget build(BuildContext context) {
    // build 可能因为 setState、主题变化等原因被反复执行。
    // 易错点：不要在 build 中扫描或连接串口，否则每次重建都会重复操作硬件。

    // 从当前主题读取颜色。相比直接写死颜色，切换明暗主题时更容易适配。
    final colorScheme = Theme.of(context).colorScheme;

    // Flutter 的界面由 Widget 一层层嵌套组成：
    // ColoredBox（背景） -> Align（位置） -> Padding（外边距）
    // -> ConstrainedBox（最大宽度） -> Column（垂直排列）。
    return ColoredBox(
      color: Color.fromARGB(248, 255, 254, 245),
      child: Align(
        // 把整个设置区域放在页面左上角。
        alignment: Alignment.topLeft,
        child: Padding(
          // 设置区域与页面四周保持 24 像素距离。
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            // 只限制“最大宽度”，不会强制控件永远等于 664 像素。
            // 页面更窄时，它会使用父组件允许的实际宽度。
            constraints: const BoxConstraints(maxWidth: 664),
            child: Column(
              // Column 只占用子组件实际需要的垂直空间。
              mainAxisSize: MainAxisSize.min,

              // 错误文字与上面的控件行都靠左对齐。
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 固定第一行的高度，使输入框、刷新按钮和连接按钮居中对齐。
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      // Expanded 会让串口下拉框占用 Row 中剩余的全部宽度。
                      // 易错点：Expanded 只能放在 Row、Column 或 Flex 内部。
                      Expanded(
                        // <String> 指定这个下拉框的值只能是 String 类型。
                        child: DropdownButtonFormField<String>(
                          // initialValue 主要用于创建表单时设置初始值。
                          // 当刷新串口导致 _selectedPort 改变时，ValueKey 也会改变，
                          // Flutter 会重新创建这个表单控件并应用新的初始值。
                          key: ValueKey(_selectedPort),
                          initialValue: _selectedPort,

                          // 让下拉框内容使用父组件提供的全部宽度，长串口名才有空间显示。
                          isExpanded: true,
                          decoration: _fieldDecoration('串口'),
                          hint: const Text('未检测到串口'),

                          // 将 List<String> 转换成下拉菜单需要的
                          // List<DropdownMenuItem<String>>。
                          items: _ports
                              .map(
                                (port) => DropdownMenuItem<String>(
                                  // value 是程序拿到的值，child 是用户看到的内容。
                                  value: port,
                                  child: Text(
                                    port,

                                    // 串口名过长时显示省略号，避免文字挤出边界。
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),

                          // Flutter 约定：onChanged 为 null 时，控件就是禁用状态。
                          // 已连接时禁止切换串口，避免 UI 选择与实际连接的端口不一致。
                          onChanged: _isConnected
                              ? null
                              : (port) {
                                  // 仅给变量赋值不会刷新页面；需要放进 setState，
                                  // Flutter 才会再次调用 build 显示新选择。
                                  setState(() => _selectedPort = port);
                                },
                        ),
                      ),

                      // SizedBox 在 Row 中只设置 width 时，可作为固定的水平间距。
                      const SizedBox(width: 8),

                      // filledTonal 是 Material 3 的浅色圆形图标按钮。
                      IconButton.filledTonal(
                        // 连接期间同样禁用刷新，防止串口列表变化后选中项被替换。
                        onPressed: _isConnected ? null : _refreshPorts,

                        // 鼠标悬停时显示提示，也能为无障碍工具提供按钮说明。
                        tooltip: '刷新串口',
                        icon: const Icon(Icons.refresh_rounded),
                        style: IconButton.styleFrom(
                          // Size.square(40) 等价于宽 40、高 40。
                          fixedSize: const Size.square(40),
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      const SizedBox(width: 16),

                      // 波特率固定为 460800，因此这里只绘制输入框外观，不允许编辑。
                      SizedBox(
                        width: 120,
                        child: InputDecorator(
                          decoration: _fieldDecoration('波特率'),

                          // 告诉 InputDecorator 当前有内容，标签应保持浮动状态。
                          isEmpty: false,

                          // 直接引用连接时使用的同一个常量，避免显示值与实际值不一致。
                          // 因为 _baudRate 是编译期常量，所以这里仍然可以使用 const。
                          child: const Text('$_baudRate'),
                        ),
                      ),
                      const SizedBox(width: 16),

                      // Tooltip 显示最近一次连接状态，例如“未连接”或“连接失败”。
                      Tooltip(
                        message: _status,
                        child: SizedBox(
                          // 固定按钮尺寸，防止“连接”和“断开”字数变化影响布局。
                          width: 96,
                          height: 40,
                          child: FilledButton.icon(
                            // 这里传递的是函数本身，不能写成 _toggleConnection()。
                            // 易错点：加括号会在 build 时立刻执行，而不是点击时执行。
                            onPressed: _toggleConnection,
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),

                              // StadiumBorder 会生成两端为半圆的胶囊形按钮。
                              shape: const StadiumBorder(),
                            ),

                            // 根据实际连接状态切换图标和文字。
                            icon: Icon(
                              _isConnected
                                  ? Icons.link_off_rounded
                                  : Icons.link_rounded,
                              size: 18,
                            ),
                            label: Text(_isConnected ? '断开' : '连接'),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Dart 集合中的 if：只有 _hasError 为 true 时，
                // 这个 Padding 和错误文字才会被加入 children 列表。
                if (_hasError)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      _status,

                      // 使用主题中的 error 颜色，自动适配当前配色方案。
                      style: TextStyle(color: colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
