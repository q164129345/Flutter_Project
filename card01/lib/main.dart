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
          title: Text('Card 01'),
          centerTitle: true,
          backgroundColor: Colors.blue,
        ),
        body: Card(
          elevation: 8, // 阴影
          margin: EdgeInsets.all(32), // 外边距
          shape: RoundedRectangleBorder( // 圆角矩形
            borderRadius: BorderRadius.circular(24), // 圆角
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // 自适应高度
            crossAxisAlignment: CrossAxisAlignment.center, // 水平居中
            children: [
              Text('电流波形', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color: Colors.blue),),
              SizedBox(height: 12),
              SizedBox(
                height: 220,
                width: double.infinity, // 宽度自适应
                child: Center(child: Text('这里放图表')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
