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
          title: Text("List View例程01"),
          centerTitle: true,
          backgroundColor: Colors.blueAccent,
        ),
        body: ListView.builder(
          itemCount: 100, // 列表总长度
          padding: EdgeInsets.all(20), // 外边距
          itemBuilder: (BuildContext context, int index) {
            return Container(
              alignment: Alignment.center, // 居中
              color: Colors.amberAccent, //
              width: double.infinity,
              height: 80,
              margin: EdgeInsets.only(top: 10), // 上边距
              child: Text(
                "第$index个",
                style: TextStyle(color: Colors.black, fontSize: 25),
              ),
            );
          },
        ),
      ),
    );
  }
}
