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
        body: Center(
          child: Container(
            margin: EdgeInsets.all(10.0), // 与邻居的最小距离
            transform: Matrix4.rotationZ(0.2), // 旋转
            width: 200.0, // 宽
            height: 200.0, // 高
            alignment: Alignment.center, // 内容居中
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20.0), // 圆角
              color: Colors.blue,
              border: Border.all(width: 4, color: Colors.yellow), // 边界
            ),
            child: Text(
              'Hello World!',
              style: TextStyle(color: Colors.white, fontSize: 20.0),
            ),
          ),
        ),
      ),
    );
  }
}
