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
          margin: EdgeInsets.all(32), // 外边距
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('电流波形', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,color: Colors.blue),),
              SizedBox(height: 12),
              SizedBox(
                height: 220,
                width: double.infinity,
                child: Center(child: Text('这里放图表')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
