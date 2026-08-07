import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo', // 应用程序标题(UI上不显示它)
      home: ScaffoldActionButton(), // 调用StatefulWidget对象ScaffoldActionButton
    );
  }
}

/// This is the stateful widget that the main application instantiates.
class ScaffoldActionButton extends StatefulWidget {
  const ScaffoldActionButton({super.key});

  @override
  State<ScaffoldActionButton> createState() => _ScaffoldActionButtonState();
}

class _ScaffoldActionButtonState extends State<ScaffoldActionButton> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scaffold Action Button')),
      body: Center(child: Text('You have pressed the button $_counter times.')),
      backgroundColor: const Color.fromRGBO(
        254,
        248,
        236,
        1,
      ), // 设置背景颜色（类似Noctis的Lux主题的背景颜色）
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() {
          _counter++;
        }),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
