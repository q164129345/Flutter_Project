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
          title: Text("Column简单实例"), // 文本内容
          centerTitle: true, // 内容居中
        ),
        body: Container(
          // 让Container尽可能占满宽度与高度
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(color: Colors.yellow),
          child: Row(
            // MainAxisAlignment.center
            // MainAxisAlignment.end
            // MainAxisAlignment.spaceAround
            // MainAxisAlignment.spaceBetween
            mainAxisAlignment: MainAxisAlignment.center, // 主轴居中
            crossAxisAlignment: CrossAxisAlignment.center, // 交叉轴居中
            children: [
              Container(
                width: 80, //
                height: 80,
                color: Colors.blue,
              ),
              Container(
                margin: EdgeInsets.only(left: 10), // 左外边距
                width: 80, //
                height: 80,
                color: Colors.blue,
              ),
              Container(
                margin: EdgeInsets.only(left: 10), // 左外边距
                width: 80, //
                height: 80,
                color: Colors.blue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
