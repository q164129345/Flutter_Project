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
  int baudRate = 115200;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("DropdownButton01例程"),
          centerTitle: true, // 居中
          backgroundColor: Colors.blueAccent,
        ),
        body: Center(
          child: DropdownButton<int>(
            isExpanded: false, // 是否扩大
            menuMaxHeight: 200,
            borderRadius: BorderRadius.circular(14.0),
            value: baudRate,
            items: const [
              DropdownMenuItem(value: 9600, child: Text('9600')),
              DropdownMenuItem(value: 115200, child: Text('115200')),
              DropdownMenuItem(value: 512000, child: Text('512000')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                baudRate = value;
              });
              debugPrint("baudRate change to : $value");
            },
          ),
        ),
      ),
    );
  }
}
