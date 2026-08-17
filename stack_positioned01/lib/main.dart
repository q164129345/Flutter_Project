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
        //
        appBar: AppBar(title: Text("stack_positioned例程"), centerTitle: true),
        body: Container(
          height: double.infinity,
          width: double.infinity,
          color: Colors.white, // 背景白色
          child: Stack(
            alignment: AlignmentGeometry.center, // 居中
            children: [
              //
              Container(width: 300, height: 300, color: Colors.blue),
              Container(width: 200, height: 200, color: Colors.red),
              Container(width: 100, height: 100, color: Colors.yellow),
              Container(width: 50, height: 50, color: Colors.green),
            ],
          ),
        ),
      ),
    );
  }
}
