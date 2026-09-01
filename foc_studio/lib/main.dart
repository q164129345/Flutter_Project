import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'pages/main_page.dart';

// 应用的入口函数。async 让函数内部可以使用 await；
// Future<void> 表示它会异步执行，但完成后不返回数据。
Future<void> main() async {
  // 在调用插件之前，先确保 Flutter 引擎和平台通道已经初始化。
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化 window_manager，以便通过 Dart 代码控制原生桌面窗口。
  // await 表示等待初始化完成后，再继续执行下面的代码。
  await windowManager.ensureInitialized();

  // 定义窗口启动时使用的配置。
  // Size 的单位是逻辑像素，这里限制窗口不能缩小到 900 × 600 以下。
  const windowOptions = WindowOptions(minimumSize: Size(900, 600));

  // 等待原生窗口准备完成，并将上面的窗口配置应用到它。
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    // 显示窗口；如果不调用 show，窗口可能仍然处于隐藏状态。
    await windowManager.show();

    // 让窗口获得焦点，成为用户当前操作的活动窗口。
    await windowManager.focus();
  });

  // 启动 Flutter 应用，并从 MainApp 开始构建界面。
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MainPage());
  }
}
