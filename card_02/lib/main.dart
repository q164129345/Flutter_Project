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
          title: Text('Card02'),
          centerTitle: true,
          backgroundColor: Colors.blue,
        ),
        body: Card.filled(
          margin: const EdgeInsets.all(16),
          child: ListTile(
            leading: const Icon(Icons.usb),
            title: const Text('串口配置'),
            subtitle: const Text('COM3 - 115200 baud'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => debugPrint('打开串口配置'),
          ),
        ),
      ),
    );
  }
}
