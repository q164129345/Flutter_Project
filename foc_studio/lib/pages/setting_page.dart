import 'dart:async';

import 'package:flutter/material.dart';

import '../controllers/foc_controller.dart';
import '../services/serial_port_service.dart';
import '../widgets/external_flash_info_panel.dart';
import '../widgets/mot_style_panel.dart';
import '../widgets/serial_statistics_panel.dart';

class SettingPage extends StatefulWidget {
  const SettingPage({
    super.key,
    required this.serialService,
    required this.controller,
  });

  final SerialPortService serialService;
  final FocController controller;

  @override
  State<SettingPage> createState() => _SettingPageState();
}

class _SettingPageState extends State<SettingPage> {
  SerialPortService get _serialService => widget.serialService;
  FocController get _controller => widget.controller;

  List<String> _ports = [];
  bool _scanning = false;
  Object? _scanError;
  int _scanGeneration = 0;
  String? _selectedPort;
  static const int _baudRate = 460800;
  String _status = '未连接';
  bool _flashQueryPending = false;
  bool _wasConnected = false;

  bool get _isConnected => _serialService.isConnected;

  @override
  void initState() {
    super.initState();
    _selectedPort = _serialService.connectedPortName;
    _status = _connectionStatusText;
    _wasConnected = _isConnected;
    _serialService.addListener(_handleConnectionChanged);
    _serialService.busy.addListener(_handleBusyChanged);
    _controller.addListener(_handleControllerChanged);
    _refreshPorts();
    if (_isConnected) unawaited(_queryExternalFlashId());
  }

  String get _connectionStatusText => switch (_serialService.connectionStatus) {
    SerialPortConnectionStatus.connected =>
      '已连接 ${_serialService.connectedPortName} '
          '${_serialService.connectedBaudRate} baud',
    SerialPortConnectionStatus.failed =>
      '连接失败：${_serialService.lastConnectionError ?? '未知错误'}',
    SerialPortConnectionStatus.disconnected =>
      _serialService.lastConnectionError == null
          ? '未连接'
          : '串口错误：${_serialService.lastConnectionError}',
  };

  void _handleBusyChanged() => setState(() {});

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  void _handleConnectionChanged() {
    final isConnected = _isConnected;
    final becameConnected = !_wasConnected && isConnected;
    _wasConnected = isConnected;
    setState(() {
      _status = _connectionStatusText;
      final connectedPort = _serialService.connectedPortName;
      if (connectedPort != null) {
        if (!_ports.contains(connectedPort)) {
          _ports = [..._ports, connectedPort];
        }
        _selectedPort = connectedPort;
      }
    });
    if (becameConnected) unawaited(_queryExternalFlashId());
  }

  @override
  void didUpdateWidget(covariant SettingPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serialService != _serialService) {
      oldWidget.serialService.removeListener(_handleConnectionChanged);
      oldWidget.serialService.busy.removeListener(_handleBusyChanged);
      _serialService.addListener(_handleConnectionChanged);
      _serialService.busy.addListener(_handleBusyChanged);
      _selectedPort = _serialService.connectedPortName;
      _status = _connectionStatusText;
      _wasConnected = _isConnected;
      _refreshPorts();
    }
    if (oldWidget.controller != _controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      _controller.addListener(_handleControllerChanged);
    }
  }

  @override
  void dispose() {
    _serialService.removeListener(_handleConnectionChanged);
    _serialService.busy.removeListener(_handleBusyChanged);
    _controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  /// 发送查询命令；具体的 ID 值只在 MCU 响应后经 FocController 快照回到 UI。
  Future<void> _queryExternalFlashId() async {
    if (_flashQueryPending || !_isConnected) return;

    setState(() => _flashQueryPending = true);
    try {
      await _controller.queryExternalFlashId();
    } catch (_) {
      // 命令发送失败时保持“未读取”或上一次 MCU 响应，不伪造任何设备数据。
    } finally {
      if (mounted) setState(() => _flashQueryPending = false);
    }
  }

  Future<void> _refreshPorts() async {
    final service = _serialService;
    final generation = ++_scanGeneration;
    setState(() {
      _scanning = true;
      _scanError = null;
    });

    final connectedPort = service.connectedPortName;
    List<String>? ports;
    Object? scanError;
    try {
      ports = connectedPort != null
          ? [connectedPort]
          : await service.getAvailablePorts();
    } catch (error) {
      scanError = error;
    }

    if (!mounted ||
        service != _serialService ||
        generation != _scanGeneration) {
      return;
    }

    setState(() {
      _scanning = false;
      _scanError = scanError;
      if (ports == null) return;
      _ports = ports;
      if (!ports.contains(_selectedPort)) {
        _selectedPort = ports.firstOrNull;
      }
      _status = _connectionStatusText;
    });
  }

  Future<void> _connect() async {
    if (_selectedPort == null) {
      setState(() => _status = '没有可用串口');
      return;
    }

    final service = _serialService;
    try {
      await service.connect(portName: _selectedPort!, baudRate: _baudRate);
      if (!mounted || service != _serialService) return;
      setState(() => _status = _connectionStatusText);
    } catch (error) {
      if (!mounted || service != _serialService) return;
      setState(() => _status = '连接失败：$error');
    }
  }

  Future<void> _disconnect() async {
    final service = _serialService;
    try {
      await service.disconnect();
      if (!mounted || service != _serialService) return;
      setState(() => _status = _connectionStatusText);
    } catch (error) {
      if (!mounted || service != _serialService) return;
      setState(() => _status = '断开失败：$error');
    }
  }

  void _toggleConnection() {
    if (_isConnected) {
      _disconnect();
    } else {
      _connect();
    }
  }

  InputDecoration _fieldDecoration() {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(3),
      borderSide: BorderSide(color: color),
    );

    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFDFE3E6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      border: border(motPanelBorder),
      enabledBorder: border(motPanelBorder),
      focusedBorder: border(motValueColor),
    );
  }

  bool get _hasError =>
      _status.startsWith('没有') ||
      _status.contains('失败') ||
      _status.contains('错误');

  ButtonStyle _buttonStyle(BuildContext context) => FilledButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: 14),
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    disabledBackgroundColor: const Color(0xFFBCC3C9),
    disabledForegroundColor: Colors.white,
    textStyle: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontSize: 12, fontWeight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
  );

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ColoredBox(
      color: motPageBackground,
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 14, height: 1.2, color: motLabelColor),
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(10),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  MotStylePanel(
                    title: '串口连接',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('串口:'),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                key: ValueKey(_selectedPort),
                                initialValue: _selectedPort,
                                isExpanded: true,
                                decoration: _fieldDecoration(),
                                hint: Text(
                                  _scanning
                                      ? '正在扫描串口…'
                                      : _scanError != null
                                      ? '扫描失败，请刷新重试'
                                      : '未检测到串口',
                                ),
                                items: _ports
                                    .map(
                                      (port) => DropdownMenuItem<String>(
                                        value: port,
                                        child: Text(
                                          port,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: _isConnected || _serialService.isBusy
                                    ? null
                                    : (port) =>
                                          setState(() => _selectedPort = port),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Tooltip(
                              message: '刷新串口',
                              child: IconButton(
                                onPressed: _isConnected || _serialService.isBusy
                                    ? null
                                    : _refreshPorts,
                                icon: const Icon(Icons.refresh_rounded),
                                style: IconButton.styleFrom(
                                  fixedSize: const Size.square(36),
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Text('波特率:'),
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 110,
                              child: InputDecorator(
                                decoration: _fieldDecoration(),
                                isEmpty: false,
                                child: const Text('$_baudRate'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Tooltip(
                              message: _status,
                              child: SizedBox(
                                width: 96,
                                height: 36,
                                child: FilledButton(
                                  onPressed: _serialService.isBusy
                                      ? null
                                      : _toggleConnection,
                                  style: _buttonStyle(context),
                                  child: Text(_isConnected ? '断开' : '连接'),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (_scanError != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              '扫描串口失败：$_scanError',
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ),
                        if (_hasError)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              _status,
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  MotStylePanel(
                    title: '串口统计',
                    child: SerialStatisticsPanel(
                      statistics: _serialService.statistics,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ExternalFlashInfoPanel(
                    flashId: _controller.state.externalFlashId,
                    isConnected: _isConnected,
                    isQueryPending: _flashQueryPending,
                    onRefresh: _queryExternalFlashId,
                  ),
                ]),
              ),
            ),
            const SliverFillRemaining(hasScrollBody: false, child: SizedBox()),
          ],
        ),
      ),
    );
  }
}
