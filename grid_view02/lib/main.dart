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
        appBar: AppBar(
          centerTitle: true,
          title: Text(
            "GridView02例程",
            style: TextStyle(color: Colors.deepPurpleAccent, fontSize: 30),
          ),
        ),
        body: GridView.extent(
          padding: EdgeInsets.all(10),
          scrollDirection: Axis.vertical, // 纵向
          mainAxisSpacing: 10, // 横向间距
          crossAxisSpacing: 10, // 纵向间距
          maxCrossAxisExtent: 100, // 每个网格子项允许的最大宽度是100像素
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
