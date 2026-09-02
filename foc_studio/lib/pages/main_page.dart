import 'package:flutter/material.dart';

import '../controllers/foc_controller.dart';
import '../services/serial_port_service.dart';
import '../widgets/navi_rail_bottom.dart';
import 'setting_page.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // 当前选中了左侧第几个导航项
  int _selectedIndex = 0;

  // 串口服务由主页面持有，使切换页面时连接不会被设置页销毁，
  // 导航栏和设置页也能读取同一个连接状态。
  final SerialPortService _serialService = SerialPortService();

  // FocController 负责协议解析、心跳、周期控制和结构化电机状态。
  late final FocController _focController;

  // 右侧需要显示的页面。
  // late 表示稍后在 initState 中赋值；final 表示赋值一次后不能换成另一个列表。
  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();

    _focController = FocController(_serialService);

    // 把同一个 _serialService 传给 SettingPage，这种做法通常称为“依赖注入”。
    // 因为 Service 由 MainPage 持有，所以离开设置页时串口不会被自动断开。
    _pages = [
      const Center(child: Text('当前是MOT', style: TextStyle(fontSize: 30))),
      const Center(child: Text('当前是POS', style: TextStyle(fontSize: 30))),
      const Center(child: Text('当前是CHT', style: TextStyle(fontSize: 30))),
      SettingPage(serialService: _serialService),
    ];
  }

  @override
  void dispose() {
    // 先停止协议订阅和定时器，再释放其依赖的串口服务。
    _focController.dispose();
    _serialService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 左侧导航栏
          NavigationRail(
            backgroundColor: const Color.fromARGB(248, 250, 248, 230),

            // SYS不是destination,
            // 所以选中SYS时，让NavigationRail没有选中项
            selectedIndex: _selectedIndex < 3 ? _selectedIndex : null,

            // 点击导航按钮
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            // 暂时把文字全部显示出来
            labelType: NavigationRailLabelType.all,

            // 让leading在rail顶部,让trailing在rail底部,让destinations在中间
            leadingAtTop: true,
            trailingAtBottom: true,

            // 串口状态不是导航目的地，因此放在 leading 中，只负责展示状态。
            // leading常放Logo、头像、状态等信息，trailing常放设置、退出等操作。
            leading: ListenableBuilder(
              // listenable 指定需要监听哪个 ChangeNotifier。
              listenable: _serialService,

              // Service 调用 notifyListeners() 后，只重新执行这个 builder，
              // 不需要手动在 MainPage 中调用 setState。
              builder: (context, child) {
                return _SerialConnectionIndicator(service: _serialService);
              },
            ),

            // 每个可点击目的地
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.speed),
                label: Text('MOT'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.location_searching),
                label: Text('POS'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.show_chart),
                label: Text('CHT'),
              ),
            ],

            trailing: NaviRailBottomState(
              icon: Icons.settings,
              tooltip: '设置',
              selected: _selectedIndex == 3,
              onTap: () {
                setState(() {
                  _selectedIndex = 3;
                });
              },
            ),
          ),

          // 左侧导航栏与右侧页面之间的分割线
          const VerticalDivider(width: 1, thickness: 1),

          //右侧页面占满剩余空间
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}

class _SerialConnectionIndicator extends StatelessWidget {
  const _SerialConnectionIndicator({required this.service});

  final SerialPortService service;

  @override
  Widget build(BuildContext context) {
    // 从主题中取得颜色，错误色和普通文字色可以自动适配明暗主题。
    final colorScheme = Theme.of(context).colorScheme;

    // switch 表达式根据连接状态返回一个 Dart record（记录）：
    // 第一个值是图标，第二个值是颜色，第三个值是提示文字。
    // 左边的 (icon, color, message) 会把三个值分别取出来。
    final (icon, color, message) = switch (service.connectionStatus) {
      SerialPortConnectionStatus.connected => (
        Icons.usb_rounded,
        Colors.green.shade700,
        '串口已连接：${service.connectedPortName ?? ''} '
            '${service.connectedBaudRate ?? ''} baud',
      ),
      SerialPortConnectionStatus.failed => (
        Icons.usb_off_rounded,
        colorScheme.error,
        '串口连接失败：${service.lastConnectionError ?? '未知错误'}',
      ),
      SerialPortConnectionStatus.disconnected => (
        Icons.usb_off_rounded,
        colorScheme.onSurfaceVariant,
        '串口未连接',
      ),
    };

    return Semantics(
      // Semantics 让屏幕阅读器也能读出连接状态。
      label: message,
      child: Tooltip(
        // 鼠标停留在图标上时显示详细状态。
        message: message,
        child: Container(
          width: 56,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            // withAlpha(24) 生成很浅的同色背景；alpha 的范围是 0～255。
            color: color.withAlpha(24),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: color),
        ),
      ),
    );
  }
}
