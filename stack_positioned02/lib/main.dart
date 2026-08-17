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
        appBar: AppBar(title: Text("stack_positioned例程2"), centerTitle: true),
        body: Container(
          height: double.infinity,
          width: double.infinity,
          color: Colors.white, // 背景白色
          child: Stack(
            //alignment: AlignmentGeometry.center, // 居中
            children: [
              Container(width: 200, height: 200, color: Colors.grey),
              Positioned(
                // 坐标
                left: 10,
                top: 10,
                child: Container(width: 50, height: 50, color: Colors.red),
              ),
              Positioned(
                //坐标
                right: 10,
                bottom: 10,
                child: Container(width: 50, height: 50, color: Colors.blue),
              ),
              Positioned(
                //坐标
                left: 10,
                bottom: 10,
                child: Container(width: 50, height: 50, color: Colors.blue),
              ),
              Positioned(
                //坐标
                right: 10,
                top: 10,
                child: Container(width: 50, height: 50, color: Colors.blue),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
