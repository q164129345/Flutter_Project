import 'package:flutter/material.dart';

class NaviRailBottomState extends StatefulWidget {
  const NaviRailBottomState({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  final IconData icon; // 图标
  final String tooltip; // 提示文字
  final bool selected; // 是否被选中
  final VoidCallback onTap; // 点击事件

  @override
  State<NaviRailBottomState> createState() => _NaviRailBottomState();
}

class _NaviRailBottomState extends State<NaviRailBottomState> {
  bool _hovered = false; // 鼠标是否悬停
  bool _pressed = false; // 鼠标是否被按下

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    Color indicatorColor; // 图标后面的背景颜色

    if (widget.selected) {
      indicatorColor = colorScheme.secondaryContainer; // 选中状态
    } else if (_pressed) {
      indicatorColor = colorScheme.onSurface.withAlpha(30); // 鼠标按下
    } else if (_hovered) {
      indicatorColor = colorScheme.onSurface.withAlpha(20); // 鼠标悬停
    } else {
      indicatorColor = Colors.transparent; // 普通状态
    }

    return Tooltip(
      message: widget.tooltip,
      child: InkWell(
        onTap: widget.onTap,

        // 鼠标进入/离开
        onHover: (value) {
          setState(() {
            _hovered = value;
          });
        },

        // 鼠标按下/松开
        onHighlightChanged: (value) {
          setState(() {
            _pressed = value;
          });
        },

        mouseCursor: SystemMouseCursors.click,

        // 不让InkWell 自己画整块背景
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,

        child: Padding(
          padding: const EdgeInsetsGeometry.symmetric(vertical: 8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 56,
            height: 32,

            decoration: BoxDecoration(
              color: indicatorColor,
              borderRadius: BorderRadius.circular(20),
            ),

            child: Icon(
              widget.icon,
              color: widget.selected
                  ? colorScheme.onSecondaryContainer
                  : colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
