import 'package:flutter/material.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.blue,
          title: const Text('Flutter Demo Home Page'),
        ),
        body: Container(
          color: Colors.white,
          child: Center(child: Text('Hello, World!')),
        ),
        bottomNavigationBar: Container(
          height: 60,
          color: Colors.blue,
          child: Center(child: Text('Bottom Navigation Bar')),
        ),
      ),
    );
  }
}
