import 'package:flutter/material.dart'; // 导入 Flutter 的 Material Design 组件库。

void main() {
  // main 是整个 Dart 程序的入口，应用会从这里开始运行。
  runApp(const MainApp()); // 启动 Flutter 应用，并把 MainApp 作为最外层组件。
} // main 函数到这里结束。

class MainApp extends StatefulWidget {
  // 定义一个有状态组件，数据变化时可以重新构建界面。
  const MainApp({super.key}); // MainApp 的构造函数；super.key 用于标识和管理组件。

  @override // 表示下面的方法重写了父类 StatefulWidget 中的方法。
  State<MainApp> createState() => _MainAppState(); // 创建并返回保存 MainApp 状态的对象。
} // MainApp 组件类到这里结束。

class _MainAppState extends State<MainApp> {
  // 定义 MainApp 的状态类；开头的下划线表示它仅在当前文件中可见。
  @override // 表示下面的 build 方法重写了 State 类中的方法。
  Widget build(BuildContext context) {
    // build 方法负责描述当前页面要显示的组件树。
    return MaterialApp(
      // 创建 Material Design 风格的应用，并将它返回给 Flutter 框架。
      home: Scaffold(
        // 设置应用首页；Scaffold 提供 AppBar、body 等标准页面结构。
        appBar: AppBar(
          // 创建显示在页面顶部的应用栏。
          centerTitle: true, // 将应用栏中的标题水平居中。
          title: Text(
            // 使用 Text 组件作为应用栏标题。
            "GridView03实例", // 设置标题中显示的文字。
            style: TextStyle(
              color: Colors.blueAccent, // 设置标题文字颜色为蓝色。
              fontSize: 30, // 设置标题文字大小为 30。
            ), // 设置标题颜色为蓝色，字号为 30。
          ), // Text 标题组件配置到这里结束。
        ), // AppBar 应用栏配置到这里结束。
        body: GridView.builder(
          padding: EdgeInsets.all(20), // 在网格列表四周设置 20 像素的内边距。
          // 将页面主体设置为按需创建子项的网格列表。
          // 这里是重点！！！！！！！！！！！！！！！
          // 按照列数
          // gridDelegate: SliverGridDelegateWithFixedCrossAxisCount( // 使用固定列数的网格布局规则。
          //   crossAxisCount: 4, // 每一行固定显示 4 个子项。
          //   mainAxisSpacing: 10, // 设置主轴方向（竖直方向）的间距为 10。
          //   crossAxisSpacing: 10, // 设置交叉轴方向（水平方向）的间距为 10。
          // ), // 固定列数的网格布局规则配置到这里结束。
          // 按照宽度
          gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
            // 使用子项最大宽度来决定每行显示多少列。
            maxCrossAxisExtent: 200, // 每个网格子项在交叉轴方向的最大宽度为 200。
            mainAxisSpacing: 10, // 设置网格子项之间的竖直间距为 10。
            crossAxisSpacing: 10, // 设置网格子项之间的水平间距为 10。
          ), // 按最大宽度排列的网格布局规则配置到这里结束。
          itemCount: 100, // 指定网格列表一共创建 100 个子项。
          itemBuilder: (BuildContext context, int index) {
            // 根据索引 index 按需创建每一个网格子项。
            return Container(
              // 为当前索引位置返回一个矩形容器。
              alignment: Alignment.center, // 将容器中的子组件放在正中央。
              color: Colors.blueAccent, // 将容器背景色设置为蓝色。
              child: Text(
                // 在容器中放置一个文字组件。
                "第${index + 1}个", // 显示从 1 开始的序号；index 本身从 0 开始。
                style: TextStyle(
                  color: Colors.white, // 设置网格中的文字颜色为白色。
                  fontSize: 20, // 设置网格中的文字大小为 20。
                ), // 将文字设为白色，字号设为 20。
              ), // Text 文字组件配置到这里结束。
            ); // Container 容器配置到这里结束并返回。
          }, // itemBuilder 回调函数到这里结束。
        ), // GridView.builder 网格列表配置到这里结束。
      ), // Scaffold 页面结构配置到这里结束。
    ); // MaterialApp 配置结束，并将其作为 build 方法的结果返回。
  } // build 方法到这里结束。
} // _MainAppState 状态类到这里结束。
