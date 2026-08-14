import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("Flex例程"), // 文本内容
          centerTitle: true, // 居中
        ),
        body: Container(
          // 尽可能占满父类的宽度与高度
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(color: Colors.orange), // 颜色
          child: Flex(
            //direction: Axis.vertical, // 垂直布局
            direction: Axis.horizontal, // 水平布局
            spacing: 10.0, // 间隔
            children: [
              Expanded(
                flex: 2, // 扩大2倍
                child: Container(
                  color: Colors.red, //
                  height: 100,
                  width: 100,
                ),
              ),

              Expanded(
                flex: 1, // 扩大1倍
                child: Container(
                  color: Colors.blue, //
                  height: 100,
                  width: 100,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
