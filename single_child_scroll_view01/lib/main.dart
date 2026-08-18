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
  final ScrollController _controller = ScrollController(); // 实例化一个滚动控制器

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text("Singal_Child_Scroll_View01"),
          centerTitle: true,
          backgroundColor: Colors.grey,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              controller: _controller,
              child: Column(
                children: List.generate(100, (index) {
                  // 生成100个Container
                  return Container(
                    alignment: Alignment.center, // child居中
                    margin: EdgeInsets.only(top: 10),
                    height: 100, //
                    width: double.infinity,
                    color: Colors.blueAccent,
                    child: Text(
                      "我是第${index + 1}个",
                      style: TextStyle(color: Colors.white, fontSize: 30),
                    ),
                  );
                }),
              ),
            ),
            //
            // 放堆叠对象
            Positioned(
              right: 10,
              top: 10,
              child: GestureDetector(
                // 简单的跳转
                //onTap: () => _controller.jumpTo(0), // 跳转顶部
                // 带动画的跳转
                onTap: () => _controller.animateTo(
                  0, // 顶部位置
                  duration: Duration(seconds: 2), // 动画时间2S
                  curve: Curves.easeIn, // 动画效果
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    color: Colors.red,
                  ),
                  alignment: Alignment.center, // 居中
                  width: 80,
                  height: 80,
                  child: Text("去顶部"),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              right: 10,
              child: GestureDetector(
                // 简单的跳转
                // onTap: () => _controller.jumpTo(
                //   _controller.position.maxScrollExtent,
                // ), // 跳转到_controller的最底部。

                // 带动画的跳转
                onTap: () => _controller.animateTo(
                  _controller.position.maxScrollExtent, // 跳转到最底部
                  duration: Duration(seconds: 2), // 动画时间2S
                  curve: Curves.easeIn, // 动画效果
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(40),
                    color: Colors.red,
                  ),
                  alignment: Alignment.center, // 居中
                  width: 80,
                  height: 80,
                  child: Text("去底部"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
