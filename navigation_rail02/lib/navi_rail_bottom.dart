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
      child: Padding(
        // Padding 位于 InkWell 外面，避免扩大水波纹区域。
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Container(
          width: 56, // 设置指示器宽度
          height: 32, // 设置指示器高度
          clipBehavior: Clip.antiAlias, // 按圆角裁剪水波纹，防止波纹超出指示器
          decoration: BoxDecoration(
            color: indicatorColor, // 根据选中、按下或悬停状态显示背景色
            borderRadius: BorderRadius.circular(20), // 设置胶囊形圆角
          ),
          // 为什么这里需要套一层Material()? 因为InkWell需要被一个Material父类套住。然后，Container并不是一个Material组件
          // 比如Scafolld是一个Material组件。
          // Note: 其实InkWell发现上一层没办法提供Material表面时，会一层一层往上找，如果能找到的话，水纹效果就正常显示。
          // 所以，最保险就是在InkWell外面套一层Material()，这样就不需要依赖父类是否能提供Material表面。
          child: Material(
            color: Colors.transparent, // 透明
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

              //mouseCursor: SystemMouseCursors.click, // 鼠标悬停时显示可点击的手形光标
              borderRadius: BorderRadius.circular(20), // 将水波纹裁剪为胶囊形圆角
              // 悬停和按下背景由 Container 根据状态重新构建后显示。 负责。
              hoverColor: Colors.transparent, // 透明
              highlightColor: Colors.transparent, // 透明
              splashColor: colorScheme.primary.withAlpha(
                30,
              ), // 使用当前主题的主色，并将它设置为较透明的颜色。

              child: Icon(
                widget.icon,
                color: widget.selected
                    ? colorScheme.onSecondaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
