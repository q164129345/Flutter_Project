import 'package:flutter/material.dart';

void main() {
  runApp(MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Card02 - Card.filled()'),
          centerTitle: true,
          backgroundColor: Colors.blue,
        ),
        body: SizedBox(
          width: 200, // 设置卡片宽度
          child: Card.filled(
            child: Padding(
              padding: const EdgeInsets.all(20), // 内边距
              child: Column(
                mainAxisSize: MainAxisSize.min, // 根据内容自适应高度
                crossAxisAlignment: CrossAxisAlignment.start, // 内容靠左对齐
                children: const [
                  Text('电机01 运行状态', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  SizedBox(height: 16),
                  Text('转速：1500 rpm'),
                  Text('电流：0.8 A'),
                  Text('温度：42 ℃'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
