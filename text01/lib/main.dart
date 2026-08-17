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
        appBar: AppBar(title: Text("Text例程01"), centerTitle: true),
        body: Container(
          alignment: Alignment.center,
          width: double.infinity, //
          height: double.infinity,
          color: Colors.amberAccent,
          child: Text(
            "Hello, Flutter",
            style: TextStyle(
              fontSize: 30, //
              fontWeight: FontWeight.w900, // 加粗
              color: Colors.blue,
              fontStyle: FontStyle.italic, // 斜体
              decoration: TextDecoration.underline, // 字体下划线
              decorationColor: Colors.red, // 下划线的颜色
            ),
          ),
        ),
      ),
    );
  }
}
