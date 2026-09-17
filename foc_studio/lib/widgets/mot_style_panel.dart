import 'package:flutter/material.dart';

/// MOT 与设置页共用的页面色彩与分区外壳。
const motPageBackground = Color(0xFFFFF7FF);
const motPanelBorder = Color(0xFF7B7780);
const motLabelColor = Color(0xFF625E66);
const motMutedColor = Color(0xFF85818A);
const motValueColor = Color(0xFF1688CB);

/// 带居中浮动标题的圆角分区。
///
/// 标题以 Stack 覆盖顶部边框，形成 MOT 页面使用的 fieldset 式标题缺口。
class MotStylePanel extends StatelessWidget {
  const MotStylePanel({
    super.key,
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(15, 18, 15, 12),
    this.fillHeight = false,
  });

  final String title;
  final Widget child;
  final EdgeInsets padding;
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 表格等布局会先用无界高度测量内容，再用统一的确定高度重新布局。
        // 无界阶段必须按内容撑开；只有拿到确定高度后才能安全地填满父组件。
        final shouldFillHeight = fillHeight && constraints.hasBoundedHeight;
        final panelBody = Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: motPageBackground,
            border: Border.all(color: motPanelBorder, width: 1.5),
            borderRadius: BorderRadius.circular(18),
          ),
          child: child,
        );

        return Stack(
          key: ValueKey('mot-panel-$title'),
          clipBehavior: Clip.none,
          children: [
            shouldFillHeight
                ? Positioned.fill(top: 10, child: panelBody)
                : Container(
                    margin: const EdgeInsets.only(top: 10),
                    child: panelBody,
                  ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Align(
                child: Container(
                  color: motPageBackground,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
