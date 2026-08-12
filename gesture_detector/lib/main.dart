import 'package:flutter/material.dart';

void main() {
  runApp(MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key}); // This widget is the root of your application.

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  int counter = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: GestureDetector(
            // 点击事件
            onTap: () {
              setState(() {
                counter++; // 点击时计数器加一
              });
            },

            // 长按事件
            onLongPress: () {
              setState(() {
                counter = 0; // 长按时计数器归零
              });
            },

            // 双击事件
            onDoubleTap: () {
              setState(() {
                counter--; // 双击时计数器减一
              });
            },

            // 上下滑动事件
            onPanUpdate: (details) {
              setState(() {
                counter += details.delta.dy > 0 ? 1 : -1; // 上下滑动时计数器加减
              });
            },

            child: Text('Counter: $counter', style: TextStyle(fontSize: 24)),
          ),
        ),
      ),
    );
  }
}
