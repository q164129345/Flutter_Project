import 'package:flutter/material.dart';

const _canvasColor = Color(0xFFF1F4F5);
const _inkColor = Color(0xFF173D62);
const _railColor = Color(0xFF2C455E);
const _activeNavColor = Color(0xFF3595D3);
const _borderColor = Color(0xFFB8C4CD);

void main() {
  runApp(const FocStudioApp());
}

class FocStudioApp extends StatelessWidget {
  const FocStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FOC Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _activeNavColor,
          brightness: Brightness.light,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: _canvasColor,
        fontFamily: 'Microsoft YaHei',
      ),
      home: const StudioWorkspace(),
    );
  }
}

class StudioWorkspace extends StatefulWidget {
  const StudioWorkspace({super.key});

  @override
  State<StudioWorkspace> createState() => _StudioWorkspaceState();
}

class _StudioWorkspaceState extends State<StudioWorkspace> {
  static const _modules = ['SYS', 'MOT', 'POS', 'CHT', 'QD', 'LOG', 'TUNE'];

  String _selectedModule = 'SYS';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _ModuleRail(
            modules: _modules,
            selectedModule: _selectedModule,
            onSelected: (module) => setState(() => _selectedModule = module),
          ),
          Expanded(
            child: _selectedModule == 'SYS'
                ? const SystemPage()
                : _ModulePlaceholder(module: _selectedModule),
          ),
        ],
      ),
    );
  }
}

class _ModuleRail extends StatelessWidget {
  const _ModuleRail({
    required this.modules,
    required this.selectedModule,
    required this.onSelected,
  });

  final List<String> modules;
  final String selectedModule;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      color: _railColor,
      child: SafeArea(
        right: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 25,
              height: 25,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF647A8C),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 13),
            for (final module in modules) ...[
              _ModuleButton(
                label: module,
                isSelected: module == selectedModule,
                onPressed: () => onSelected(module),
              ),
              const SizedBox(height: 5),
            ],
          ],
        ),
      ),
    );
  }
}

class _ModuleButton extends StatelessWidget {
  const _ModuleButton({
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$label 模块',
      child: Semantics(
        selected: isSelected,
        button: true,
        label: '$label 模块',
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 30,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected ? _activeNavColor : const Color(0xFF344F69),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 11,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SystemPage extends StatefulWidget {
  const SystemPage({super.key});

  @override
  State<SystemPage> createState() => _SystemPageState();
}

class _SystemPageState extends State<SystemPage> {
  final TextEditingController _manualPortController = TextEditingController();
  final List<String> _ports = ['COM3', 'COM4'];
  String? _selectedPort;
  bool _connected = false;

  @override
  void dispose() {
    _manualPortController.dispose();
    super.dispose();
  }

  void _addPort() {
    final port = _manualPortController.text.trim();
    if (port.isEmpty) {
      return;
    }

    setState(() {
      if (!_ports.contains(port)) {
        _ports.add(port);
      }
      _selectedPort = port;
      _manualPortController.clear();
    });
  }

  void _connect() {
    if (_selectedPort == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先选择串口')));
      return;
    }
    setState(() => _connected = true);
  }

  void _restartMcu() {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已发送 MCU 重启模拟指令')));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 68, 24, 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight - 100),
            child: Column(
              children: [
                _ConnectionControls(
                  connected: _connected,
                  ports: _ports,
                  selectedPort: _selectedPort,
                  manualPortController: _manualPortController,
                  onPortChanged: (port) => setState(() => _selectedPort = port),
                  onAddPort: _addPort,
                  onConnect: _connect,
                  onDisconnect: () => setState(() => _connected = false),
                  onRestart: _restartMcu,
                ),
                const SizedBox(height: 18),
                _InformationPanel(
                  title: '外部 Flash 信息',
                  child: _FlashInformation(connected: _connected),
                ),
                const SizedBox(height: 16),
                _InformationPanel(
                  title: '串口统计',
                  minHeight: 200,
                  child: _SerialStatistics(connected: _connected),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConnectionControls extends StatelessWidget {
  const _ConnectionControls({
    required this.connected,
    required this.ports,
    required this.selectedPort,
    required this.manualPortController,
    required this.onPortChanged,
    required this.onAddPort,
    required this.onConnect,
    required this.onDisconnect,
    required this.onRestart,
  });

  final bool connected;
  final List<String> ports;
  final String? selectedPort;
  final TextEditingController manualPortController;
  final ValueChanged<String?> onPortChanged;
  final VoidCallback onAddPort;
  final VoidCallback onConnect;
  final VoidCallback onDisconnect;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: _inkColor, fontSize: 14);

    return Column(
      children: [
        Text(
          '串口状态: ${connected ? '已连接' : '未连接'}',
          style: const TextStyle(color: Color(0xFFFF4E45), fontSize: 16),
        ),
        const SizedBox(height: 12),
        const Text(
          '软件版本: v0.0.0.23',
          style: TextStyle(color: _inkColor, fontSize: 14),
        ),
        const SizedBox(height: 17),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Text('选择串口:', style: labelStyle),
            SizedBox(
              width: 122,
              height: 29,
              child: DropdownButtonFormField<String>(
                key: const Key('portSelector'),
                initialValue: selectedPort,
                isExpanded: true,
                hint: const Text('请选择串口'),
                decoration: _fieldDecoration(),
                style: const TextStyle(color: Colors.black87, fontSize: 13),
                items: ports
                    .map(
                      (port) =>
                          DropdownMenuItem(value: port, child: Text(port)),
                    )
                    .toList(),
                onChanged: connected ? null : onPortChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            Text('或手动输入:', style: labelStyle),
            SizedBox(
              width: 130,
              height: 29,
              child: TextField(
                key: const Key('manualPortInput'),
                controller: manualPortController,
                enabled: !connected,
                onSubmitted: (_) => onAddPort(),
                style: const TextStyle(fontSize: 13),
                decoration: _fieldDecoration(hintText: '例如: /dev/tty.usb...'),
              ),
            ),
            SizedBox(
              height: 29,
              child: OutlinedButton(
                onPressed: connected ? null : onAddPort,
                style: _compactButtonStyle(),
                child: const Text('添加'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            SizedBox(
              height: 29,
              child: OutlinedButton(
                key: const Key('connectButton'),
                onPressed: connected ? null : onConnect,
                style: _compactButtonStyle(),
                child: const Text('连接串口'),
              ),
            ),
            SizedBox(
              height: 29,
              child: OutlinedButton(
                key: const Key('disconnectButton'),
                onPressed: connected ? onDisconnect : null,
                style: _compactButtonStyle(),
                child: const Text('断开串口'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        SizedBox(
          height: 29,
          child: OutlinedButton(
            key: const Key('restartButton'),
            onPressed: connected ? onRestart : null,
            style: _compactButtonStyle(),
            child: const Text('重启 MCU'),
          ),
        ),
      ],
    );
  }

  InputDecoration _fieldDecoration({String? hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF8A99A8), fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: _borderColor),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: _borderColor),
      ),
    );
  }

  ButtonStyle _compactButtonStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: _inkColor,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      minimumSize: Size.zero,
      side: const BorderSide(color: Color(0xFFD8DEE3)),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      textStyle: const TextStyle(fontSize: 13),
    );
  }
}

class _InformationPanel extends StatelessWidget {
  const _InformationPanel({
    required this.title,
    required this.child,
    this.minHeight,
  });

  final String title;
  final Widget child;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: minHeight ?? 90),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _borderColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _inkColor,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _FlashInformation extends StatelessWidget {
  const _FlashInformation({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final manufacturer = connected ? 'FOC Studio' : '--';
    final deviceId = connected ? 'W25Q128JV' : '--';
    return Wrap(
      spacing: 34,
      runSpacing: 8,
      children: [
        _InfoText(label: '制造商ID:', value: manufacturer),
        _InfoText(label: '设备ID:', value: deviceId),
      ],
    );
  }
}

class _SerialStatistics extends StatelessWidget {
  const _SerialStatistics({required this.connected});

  final bool connected;

  @override
  Widget build(BuildContext context) {
    final frameCount = connected ? '12' : '0';
    return Wrap(
      spacing: 42,
      runSpacing: 7,
      children: [
        _StatisticsColumn(
          values: [
            _InfoText(label: '发送帧数:', value: frameCount),
            _InfoText(label: '发送总字节:', value: connected ? '384' : '0'),
            _InfoText(label: '发送速率:', value: connected ? '32 B/s' : '0 B/s'),
            _InfoText(label: 'CRC错误数:', value: '0'),
          ],
        ),
        _StatisticsColumn(
          values: [
            _InfoText(label: '接收总帧数:', value: connected ? '8' : '0'),
            _InfoText(label: '接收总字节:', value: connected ? '256' : '0'),
            _InfoText(label: '接收速率:', value: connected ? '21 B/s' : '0 B/s'),
            _InfoText(label: '无效帧数:', value: '0'),
          ],
        ),
      ],
    );
  }
}

class _StatisticsColumn extends StatelessWidget {
  const _StatisticsColumn({required this.values});

  final List<Widget> values;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: values
          .expand((value) => [value, const SizedBox(height: 5)])
          .take(values.length * 2 - 1)
          .toList(),
    );
  }
}

class _InfoText extends StatelessWidget {
  const _InfoText({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(color: _inkColor, fontSize: 14),
        children: [
          TextSpan(text: label),
          TextSpan(text: value),
        ],
      ),
    );
  }
}

class _ModulePlaceholder extends StatelessWidget {
  const _ModulePlaceholder({required this.module});

  final String module;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        '$module 模块开发中',
        style: const TextStyle(color: _inkColor, fontSize: 18),
      ),
    );
  }
}
