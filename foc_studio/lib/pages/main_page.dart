import 'package:flutter/material.dart';
import 'setting_page.dart';
import '../widgets/navi_rail_bottom.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  // 当前选中了左侧第几个导航项
  int _selectedIndex = 0;

  // 右侧需要显示的页面
  final List<Widget> _pages = const [
    Center(child: Text('当前是MOT', style: TextStyle(fontSize: 30))),
    Center(child: Text('当前是POS', style: TextStyle(fontSize: 30))),
    Center(child: Text('当前是CHT', style: TextStyle(fontSize: 30))),
    SettingPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 左侧导航栏
          NavigationRail(
            backgroundColor: const Color.fromARGB(248, 252, 251, 238),

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

            trailingAtBottom: true,

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
