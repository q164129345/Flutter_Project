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
          title: Text('Stack Container01'),
          backgroundColor: Colors.blue,
          centerTitle: true,
        ),
        body: Center(
          child: SerialStatistics(),
        ),
      ),
    );
  }
}

class SerialStatistics extends StatelessWidget {
  const SerialStatistics({super.key});

  @override
  Widget build(BuildContext context) {

    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 580,
      height: 350,

      child: Stack(
        children: [
          // 外层边框
          Positioned.fill(
            child: Container(
              margin: const EdgeInsets.only(top:10), // 外边距
              padding: const EdgeInsets.fromLTRB(18, 30, 18, 30), // 内边距
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline, width: 3), // 边框
                borderRadius: BorderRadius.circular(22), // 圆角
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.stretch, // 让子组件撑满高度
                children: [
                  // 接收统计
                  Expanded(
                    child: StatisticsGroup(
                      title: '接收',
                      children: [
                        StatisticRow(name: '接收总数', value: '1000'),
                        StatisticRow(name: '接收总字节', value: '800'),
                        StatisticRow(name: '接收速率', value: '30.0B/s'),
                        StatisticRow(name: 'CRC错误数', value: '0'),
                        StatisticRow(name: '无效帧数', value: '0'),
                      ],
                    ),
                  ),

                  SizedBox(width: 60), // 间距

                  Expanded(
                    child: StatisticsGroup(
                      title: '发送',
                      children: [
                        StatisticRow(name: '发送总数', value: '1000'),
                        StatisticRow(name: '发送总字节', value: '800'),
                        StatisticRow(name: '发送速率', value: '30.0B/s'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 标题
          Align(
            alignment: Alignment.topCenter,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
              ),
              color: colorScheme.surface,
              child: Text(
                '串口统计',
                style: const TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class StatisticsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const StatisticsGroup({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // 边框
        Positioned.fill(
          child: Container(
            margin: const EdgeInsets.only(top: 10), // 外边距
            padding: const EdgeInsets.fromLTRB( // 内边距
              12,
              20,
              12,
              20,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: colorScheme.outline,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        ),

        // 标题
        Align(
          alignment: Alignment.topCenter,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
            ),
            color: colorScheme.surface,
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class StatisticRow extends StatelessWidget {
  final String name;
  final String value;

  const StatisticRow({
    super.key,
    required this.name,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
              ),
            ),
          ),

          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}