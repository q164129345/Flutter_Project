import 'package:flutter/material.dart'; // 导入 Material 组件库。

void main() {
  // 应用入口。
  runApp(const MainApp()); // 启动应用。
} // main 函数结束。

class MainApp extends StatefulWidget {
  // 定义可以保存状态的根组件。
  const MainApp({super.key}); // 定义常量构造函数。

  @override // 重写创建状态对象的方法。
  State<MainApp> createState() => _MainAppState(); // 创建 MainApp 的状态对象。
} // MainApp 类结束。

class _MainAppState extends State<MainApp> {
  // 定义 MainApp 的状态类。
  final PageController _pageController = PageController(); // 创建页面控制器。

  void _changePage(int pageIndex) {
    // 定义按钮切换页面的方法。
    _pageController.animateToPage(
      // 让 PageView 动画切换到指定页面。
      pageIndex, // 传入目标页面的索引。
      duration: const Duration(milliseconds: 300), // 设置动画持续时间。
      curve: Curves.easeInOut, // 设置动画速度曲线。
    ); // 页面切换动画设置结束。
  } // 页面切换方法结束。

  @override // 重写释放资源的方法。
  void dispose() {
    // 在组件销毁时执行清理工作。
    _pageController.dispose(); // 释放页面控制器占用的资源。
    super.dispose(); // 调用父类的资源释放方法。
  } // dispose 方法结束。

  @override // 重写父类的 build 方法。
  Widget build(BuildContext context) {
    // 构建应用界面。
    return MaterialApp(
      // 创建 Material 风格应用。
      home: Scaffold(
        // 创建页面基础结构。
        appBar: AppBar(
          // 创建顶部标题栏。
          centerTitle: true, // 让标题居中。
          backgroundColor: Colors.amberAccent, // 设置标题栏背景色。
          title: const Text(
            // 创建标题文字。
            'Page_View01实例', // 设置标题内容。
            style: TextStyle(
              // 设置标题样式。
              color: Colors.blueAccent, // 设置标题颜色。
              fontSize: 30, // 设置标题字号。
            ), // 标题样式结束。
          ), // 标题文字结束。
        ), // 标题栏结束。
        body: Column(
          // 使用纵向布局放置 PageView 和按钮。
          children: [
            // 定义纵向布局中的组件。
            Expanded(
              // 让 PageView 占据按钮以外的剩余空间。
              child: PageView(
                // 创建可左右滑动的 PageView。
                controller: _pageController, // 把页面控制器交给 PageView。
                children: [
                  // 定义 PageView 中的页面。
                  Container(
                    // 创建第一个页面。
                    color: Colors.red, // 设置红色背景。
                    child: const Center(
                      // 让内容居中。
                      child: Text(
                        // 创建页码文字。
                        '第 1 页', // 设置第一页文字。
                        style: TextStyle(
                          // 设置文字样式。
                          color: Colors.white, // 设置白色文字。
                          fontSize: 32, // 设置文字字号。
                        ), // 文字样式结束。
                      ), // 页码文字结束。
                    ), // 居中组件结束。
                  ), // 第一个页面结束。
                  Container(
                    // 创建第二个页面。
                    color: Colors.green, // 设置绿色背景。
                    child: const Center(
                      // 让内容居中。
                      child: Text(
                        // 创建页码文字。
                        '第 2 页', // 设置第二页文字。
                        style: TextStyle(
                          // 设置文字样式。
                          color: Colors.white, // 设置白色文字。
                          fontSize: 32, // 设置文字字号。
                        ), // 文字样式结束。
                      ), // 页码文字结束。
                    ), // 居中组件结束。
                  ), // 第二个页面结束。
                  Container(
                    // 创建第三个页面。
                    color: Colors.blue, // 设置蓝色背景。
                    child: const Center(
                      // 让内容居中。
                      child: Text(
                        // 创建页码文字。
                        '第 3 页', // 设置第三页文字。
                        style: TextStyle(
                          // 设置文字样式。
                          color: Colors.white, // 设置白色文字。
                          fontSize: 32, // 设置文字字号。
                        ), // 文字样式结束。
                      ), // 页码文字结束。
                    ), // 居中组件结束。
                  ), // 第三个页面结束。
                ], // 页面列表结束。
              ), // PageView 结束。
            ), // Expanded 组件结束。
            SizedBox(height: 10),
            Row(
              // 使用横向布局放置三个按钮。
              mainAxisAlignment: MainAxisAlignment.spaceEvenly, // 均匀排列按钮。
              children: [
                // 定义横向布局中的按钮。
                ElevatedButton(
                  // 创建第一个页面按钮。
                  onPressed: () => _changePage(0), // 点击后切换到第一页。
                  child: const Text('第 1 页'), // 设置按钮文字。
                ), // 第一个按钮结束。
                ElevatedButton(
                  // 创建第二个页面按钮。
                  onPressed: () => _changePage(1), // 点击后切换到第二页。
                  child: const Text('第 2 页'), // 设置按钮文字。
                ), // 第二个按钮结束。
                ElevatedButton(
                  // 创建第三个页面按钮。
                  onPressed: () => _changePage(2), // 点击后切换到第三页。
                  child: const Text('第 3 页'), // 设置按钮文字。
                ), // 第三个按钮结束。
              ], // 按钮列表结束。
            ), // Row 组件结束。
            SizedBox(height: 10),
          ], // 纵向布局的组件列表结束。
        ), // Column 组件结束。
      ), // 页面基础结构结束。
    ); // 返回应用组件。
  } // build 方法结束。
} // _MainAppState 类结束。
