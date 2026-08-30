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
        appBar: AppBar(
          title: Text('CustomPaint例程1'),
          backgroundColor: Colors.blueAccent,
        ),
        body: Center(
          child: SizedBox(
            width: 500,
            height: 300,
            child: CustomPaint(painter: LinePainter()),
          ),
        ),
      ),
    );
  }
}

class LinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 3;

    canvas.drawLine(const Offset(20, 100), const Offset(450, 100), paint);
  }

  @override
  bool shouldRepaint(covariant LinePainter oldDelegate) {
    return false;
  }
}
