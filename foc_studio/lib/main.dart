import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:foc_studio/navigation/navigation_button.dart';


void main() {
  runApp(const ProviderScope(child: MainApp()));
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'foc_studio',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: Scaffold(
        body: Center(
          child: NavigationButton(
            text: 'Home',
            selected: true,
            onPressed: () {
              // Handle button press
              print('Navigation button pressed');
            },
          ),
        ),
      ),
    );
  }
}
