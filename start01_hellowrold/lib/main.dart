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
      title: 'start01_hello_world',
      theme: ThemeData(scaffoldBackgroundColor: Colors.white),
      home: Scaffold(body: const Center(child: Text('Hello, World!!'))),
    );
  }
}
