import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("GridView实例"), centerTitle: true),
        body: GridView.count(
          scrollDirection: Axis.vertical, // 滚动方向：纵轴（上下）
          crossAxisCount: 3, // 3列
          padding: EdgeInsets.all(20), // 外边距
          mainAxisSpacing: 10, // 主轴间距（横向间距）
          crossAxisSpacing: 10, // 纵向间距
          children: List.generate(100, (int index) {
            return Container(
              alignment: Alignment.center,
              color: Colors.blueAccent,
              child: Text(
                "第${index + 1}个",
                style: TextStyle(color: Colors.white, fontSize: 20),
              ),
            );
          }),
        ),
      ),
    );
  }
}
