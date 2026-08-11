import 'package:flutter/material.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int selectedIndex = 2; // 默认显示 POS

  final page = const [
    // SysPage(),
    // MotPage(),
    // PosPage(),
    // ChtPage(),
    // QdPage(),
    // LogPage(),
    // TunePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold();
  }
}
