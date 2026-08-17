import 'package:flutter/material.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  // 自动创建 10 个蓝色的正方形 Container，并把它们作为一个列表返回。
  List<Widget> getList() {
    return List.generate(10, (index) {
      // 自动生成10个Container
      return Container(width: 100, height: 100, color: Colors.blue);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("Warp 实验例程"), // 内容
          centerTitle: true, // 居中
        ),
        body: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.orange,
          child: Wrap(
            spacing: 10, // 水平方向的widget间隔
            runSpacing: 10, // run的垂直间隔
            alignment: WrapAlignment.center, // run内部的对齐方式：居中对齐
            direction: Axis.horizontal, // 轴：水平对齐
            children: getList(),
          ),
        ),
      ),
    );
  }
}
