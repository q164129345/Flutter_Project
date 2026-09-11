// as math 给数学库起别名；后面用 math.max(a, b) 取较大值。
import 'dart:math' as math;

import 'package:flutter/material.dart';
// TextInputFormatter 来自 services，用来限制输入框接受的文字。
import 'package:flutter/services.dart';

// 页面共用的配色集中在这里，调整外观时不用逐个修改组件。
// 0xFFRRGGBB 中 FF 表示完全不透明，后六位分别表示红、绿、蓝。
// 名称前的下划线表示 Dart 库内私有，本文件中的组件都可以使用。
const _pageBackground = Color(0xFFEDF0F1);
const _panelBorder = Color(0xFFBBC4CA);
const _labelColor = Color(0xFF234F75);
const _mutedColor = Color(0xFF8498A6);
const _valueColor = Color(0xFF1688CB);

/// MOT 的静态界面。当前不订阅串口，也不发送电机控制命令。
///
/// 阅读顺序：MotPage 决定整体布局，_Panel 提供白色分区外壳，
/// _ControlPanel、_MonitorPanel、_FaultPanel 分别绘制三个区域。
/// 页面本身没有需要 setState 更新的业务状态，因此使用 StatelessWidget；
/// TextField 内部仍会自行管理用户正在输入的文字。
class MotPage extends StatelessWidget {
  const MotPage({super.key});

  @override
  Widget build(BuildContext context) {
    // 以 14 号字实际缩放后的大小估算布局比例，例如双倍字号得到 2。
    // 这里只把布局比例下限设为 1，不会改变系统对文字本身的缩放。
    // 后面同时放大列宽和换行阈值，为较大的文字预留空间。
    final textScale = math.max(
      1.0,
      MediaQuery.textScalerOf(context).scale(14) / 14,
    );

    return ColoredBox(
      color: _pageBackground,
      // merge 继承上层文字样式，只覆盖字号、行高和颜色。
      // 子组件仍可覆盖局部样式；height: 1.2 表示行高为字号的 1.2 倍。
      child: DefaultTextStyle.merge(
        style: const TextStyle(fontSize: 14, height: 1.2, color: _labelColor),
        child: LayoutBuilder(
          // constraints 是父组件允许 MOT 使用的尺寸，已经扣除了左侧导航栏。
          // 窗口大小变化时会重新执行 builder，据此选择单列或多列布局。
          builder: (context, constraints) {
            // 页面左右各留 10 个逻辑像素，因此内容宽度减去 20。
            final contentWidth = math.max(0.0, constraints.maxWidth - 20);
            // 监控区宽时并排显示两组字段，窄时上下排列。
            final twoColumns = contentWidth >= 580 * textScale;
            // 控制区空间不足时，把按钮移到输入框下方。
            final compactControls = contentWidth < 540 * textScale;
            // 三元表达式“条件 ? 成立时的值 : 不成立时的值”：
            // 足够宽用 4 列，中等宽用 2 列，更窄用 1 列。
            final faultColumns = contentWidth >= 760 * textScale
                ? 4
                : contentWidth >= 380 * textScale
                ? 2
                : 1;
            // 根据当前间距和字号估算控制区、故障区高度，用剩余空间撑开监控区。
            // 这些是布局估算值，不是强制高度；文字换行后各区仍可自然增高。
            final controlHeight = compactControls
                ? 57 + 55 * textScale
                : 29 + 43 * textScale;
            // ceil() 向上取整，确保最后一行即使未排满也计入行数。
            final faultRows = (16 / faultColumns).ceil();
            final faultHeight =
                26 + 19 * textScale + faultRows * (34 * textScale + 4);
            // 36 = 上下外边距 20 + 两处分区间距 16；监控区至少保留 446 高。
            final monitorMinHeight = math.max(
              446.0,
              constraints.maxHeight - 36 - controlHeight - faultHeight,
            );

            // 内容超过窗口高度时允许整页滚动；不要在这个纵向 Column 中
            // 直接用 Expanded 分配高度，因为滚动方向没有有限的最大高度。
            return SingleChildScrollView(
              padding: const EdgeInsets.all(10),
              child: Column(
                // stretch 让三个分区横向占满可用宽度。
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ControlPanel(compact: compactControls),
                  const SizedBox(height: 8),
                  // 只限制最小高度，单列或大字号时允许内容自然撑高。
                  _MonitorPanel(
                    twoColumns: twoColumns,
                    textScale: textScale,
                    minHeight: monitorMinHeight,
                  ),
                  const SizedBox(height: 8),
                  _FaultPanel(
                    columns: faultColumns,
                    contentWidth: contentWidth,
                    textScale: textScale,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 三个区域共用的外壳：白色背景、圆角边框、居中标题和内容间距。
class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(15, 6, 15, 12),
    this.headerLeading,
  });

  final String title;
  // child 接收任意组件，因此同一个外壳可以装输入框、监控表或故障列表。
  final Widget child;
  // fromLTRB 的参数顺序为左、上、右、下；调用者可覆盖默认内边距。
  final EdgeInsets padding;
  // Widget? 允许为 null；目前只有故障区传入标题左侧的“--”。
  final Widget? headerLeading;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: _panelBorder),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Stack 将左侧状态和居中标题叠放在同一行，避免左侧文字把标题推偏。
          Stack(
            alignment: Alignment.center,
            children: [
              // 集合中的 if：只有传入了组件，才把它加入 children 列表。
              if (headerLeading != null)
                Align(alignment: Alignment.centerLeft, child: headerLeading),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

/// 控制区只负责输入和按钮外观，尚未调用串口或 FocController。
class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    // Wrap 与 Row 的区别是：宽度不足时允许自动换行。
    // spacing 是同一行的间隔，runSpacing 是相邻两行的间隔。
    final speedInput = Wrap(
      spacing: 10,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const Text('目标速度:'),
        SizedBox(
          width: 110,
          child: TextField(
            // ValueKey 为输入框提供稳定标识，便于定位组件和编写测试。
            key: const ValueKey('mot-target-speed'),
            // keyboardType 只提示平台使用数字键盘，不能阻止粘贴非法文字，
            // 所以还需要下面的 inputFormatters 检查实际输入。
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            inputFormatters: [
              TextInputFormatter.withFunction((oldValue, newValue) {
                // r'...' 是原始字符串，反斜杠直接交给正则表达式解释。
                // ^ 和 $ 匹配整个输入，-? 允许一个负号，\d{0,4} 允许 0~4 位数字。
                // 空串和单独的负号也是合法编辑中间态，便于清空或输入负数。
                // 不匹配时返回 oldValue，撤销本次编辑；这里只检查格式，
                // 尚未校验转速范围，也没有把输入值发送给设备。
                return RegExp(r'^-?\d{0,4}$').hasMatch(newValue.text)
                    ? newValue
                    : oldValue;
              }),
            ],
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, color: _labelColor),
            // InputDecoration 描述输入框外观；hintText 是空输入时的提示，
            // 并不会把 1500 设置成输入框的实际值。
            decoration: InputDecoration(
              isDense: true,
              hintText: '例如: 1500',
              hintStyle: const TextStyle(color: _mutedColor),
              filled: true,
              fillColor: const Color(0xFFDFE3E6),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: const BorderSide(color: _panelBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: const BorderSide(color: _panelBorder),
              ),
              // 获得输入焦点时使用蓝色边框，其余时候使用灰色边框。
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(3),
                borderSide: const BorderSide(color: _valueColor),
              ),
            ),
          ),
        ),
        const Text('RPM', style: TextStyle(color: _mutedColor)),
      ],
    );
    final buttons = Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        // 集合中的 for：复用相同样式，生成两个文字不同的按钮。
        for (final label in ['启动', '停止'])
          Tooltip(
            message: '尚未接入电机控制',
            child: FilledButton(
              // Flutter 约定 onPressed 为 null 时按钮禁用。
              // 后续接入控制命令时，再根据连接状态和输入有效性提供回调。
              onPressed: null,
              style: FilledButton.styleFrom(
                minimumSize: const Size(70, 28),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 7,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.standard,
                disabledBackgroundColor: const Color(0xFFBCC3C9),
                disabledForegroundColor: Colors.white,
                // copyWith 保留主题字体，只改字号和粗细；?. 表示
                // labelLarge 不为 null 时才调用 copyWith。
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              child: Text(label),
            ),
          ),
      ],
    );

    return _Panel(
      title: '控制',
      // 窄窗口上下排列，宽窗口左右排列；两种布局复用上面创建的组件。
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                speedInput,
                const SizedBox(height: 10),
                Align(alignment: Alignment.centerRight, child: buttons),
              ],
            )
          : Row(
              children: [
                // 横向 Row 宽度有限，Expanded 把按钮之外的剩余宽度交给输入区。
                Expanded(child: speedInput),
                const SizedBox(width: 16),
                buttons,
              ],
            ),
    );
  }
}

/// 监控区根据字段配置生成多行数值显示，并按可用宽度切换布局。
class _MonitorPanel extends StatelessWidget {
  const _MonitorPanel({
    required this.twoColumns,
    required this.textScale,
    required this.minHeight,
  });

  final bool twoColumns;
  final double textScale;
  final double minHeight;

  // static const 表示这些配置属于类且是编译期常量，无需每次 build 重建。
  // 当前范围和版本号用于复现参考图；0.0.0.0 是占位版本，并非设备读取结果。
  static const _motorFields = [
    _MonitorField('软件版本', '(main.sub.mini.fixed)', value: '0.0.0.0'),
    _MonitorField('电机类型', '(0~6)'),
    _MonitorField('拨码ID', '(0~7)'),
    _MonitorField('使能状态', '(0/1)'),
    _MonitorField('转速', '(-3000~3000)', unit: 'RPM'),
    _MonitorField('电流', '(0~30.0)', unit: 'A'),
    _MonitorField('电机温度', '(0.1 °C)', unit: '°C'),
    _MonitorField('MOS温度', '(0.1 °C)', unit: '°C'),
  ];

  // d/q 轴电流、电压分量放在第二组；单位和范围提示与读数分开保存。
  static const _dqFields = [
    _MonitorField('Iq电流分量', '(-32.768~32.767)', unit: 'A'),
    _MonitorField('Id电流分量', '(-32.768~32.767)', unit: 'A'),
    _MonitorField('Uq电压分量', '(-32.768~32.767)', unit: 'V'),
    _MonitorField('Ud电压分量', '(-32.768~32.767)', unit: 'V'),
  ];

  @override
  Widget build(BuildContext context) {
    // 局部函数把一组字段转换为一列组件。=> 是只有一个返回表达式的函数简写。
    // 字段配置与绘制代码分开后，添加字段只需修改上面的列表。
    Widget fieldColumn(List<_MonitorField> fields) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in fields)
          _MonitorRow(field: field, textScale: textScale),
      ],
    );

    return ConstrainedBox(
      // 只给最小高度，不固定最大高度，保证窄屏或大字号时内容仍能完整显示。
      constraints: BoxConstraints(minHeight: minHeight),
      child: _Panel(
        title: '监控界面',
        child: twoColumns
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 左组固定预留宽度，右组使用剩余空间；两组都从顶部开始排列。
                  SizedBox(
                    width: 280 * textScale,
                    child: fieldColumn(_motorFields),
                  ),
                  Expanded(child: fieldColumn(_dqFields)),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  fieldColumn(_motorFields),
                  const SizedBox(height: 12),
                  fieldColumn(_dqFields),
                ],
              ),
      ),
    );
  }
}

/// 一项监控字段的显示配置，属于普通 Dart 数据类，本身不会绘制界面。
/// label 是名称，hint 是范围或精度提示，unit 是单位，value 是显示字符串。
/// 所有成员为 final，创建后不重新赋值；未传 value 时默认显示“--”。
class _MonitorField {
  const _MonitorField(
    this.label,
    this.hint, {
    this.unit = '',
    this.value = '--',
  });

  final String label;
  final String hint;
  final String unit;
  final String value;
}

/// 一行监控信息：左侧名称与提示，中间只读数值框，右侧单位。
class _MonitorRow extends StatelessWidget {
  const _MonitorRow({required this.field, required this.textScale});

  final _MonitorField field;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          // Flexible 允许标签区域在空间不足时缩小；内部 SizedBox 给出期望宽度。
          // 它与 Expanded 的区别是：不强制把分配到的剩余宽度全部占满。
          Flexible(
            child: SizedBox(
              width: 120 * textScale,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(field.label),
                  Text(
                    field.hint,
                    style: const TextStyle(fontSize: 11, color: _mutedColor),
                  ),
                ],
              ),
            ),
          ),
          // Semantics 给屏幕阅读器提供说明。excludeSemantics 避免再重复朗读
          // 内部的占位文字，明确“--”或占位版本号都不是实际设备读数。
          Semantics(
            label: '${field.label}：尚未接入数据',
            excludeSemantics: true,
            // 用 Container + Text 绘制只读数值框，不使用可编辑的 TextField。
            child: Container(
              width: 90 * textScale,
              constraints: const BoxConstraints(minHeight: 28),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F4FF),
                border: Border.all(color: const Color(0xFFA1D4FF)),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(
                field.value,
                style: const TextStyle(
                  color: _valueColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          // 即使字段没有单位，也保留同样宽度，使各行数值框边缘对齐。
          SizedBox(
            width: 48 * textScale,
            child: Padding(
              padding: const EdgeInsets.only(left: 10),
              child: Text(
                field.unit,
                style: const TextStyle(color: _mutedColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 故障区将 16 个故障位按索引排列，目前全部使用表示“状态未知”的灰灯。
class _FaultPanel extends StatelessWidget {
  const _FaultPanel({
    required this.columns,
    required this.contentWidth,
    required this.textScale,
  });

  final int columns;
  final double contentWidth;
  final double textScale;

  // 列表索引就是 bit 编号：第 0 项对应 bit0，第 15 项对应 bit15。
  // 后续绑定故障码时可用 (errorCode & (1 << bit)) != 0 判断某一位是否置位；
  // 未收到故障码的状态应与“已收到且所有位均为 0”分开处理。
  static const _faults = [
    '驱动器过压',
    '驱动器欠压',
    '驱动器过流',
    '预留位3',
    '速度超差',
    '预留位5',
    '电机过温',
    'MOS管过温',
    'FOC校准失败',
    '485/编码器通讯故障',
    'CAN总线通讯故障',
    '保留位11',
    '保留位12',
    '保留位13',
    '保留位14',
    '保留位15',
  ];

  @override
  Widget build(BuildContext context) {
    // 扣除面板左右 padding、边框与列间距，故障位保持从左到右排列。
    // 16 = 左右各 8 的内边距；2 = 左右各 1 的边框；每两列之间相隔 8。
    final tileWidth = (contentWidth - 16 - 2 - (columns - 1) * 8) / columns;

    return _Panel(
      title: '电机故障信息',
      padding: const EdgeInsets.all(8),
      headerLeading: const Tooltip(
        message: '尚未接入故障数据',
        child: Text('--', style: TextStyle(color: _mutedColor)),
      ),
      // 每个故障项使用计算好的宽度，Wrap 会自动形成指定列数并换行。
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (var bit = 0; bit < _faults.length; bit++)
            Semantics(
              label: 'bit$bit ${_faults[bit]}：状态未知',
              excludeSemantics: true,
              child: Tooltip(
                // 鼠标悬停时显示完整位编号、名称及占位状态。
                message: 'bit$bit ${_faults[bit]}：尚未接入数据',
                child: Container(
                  width: tileWidth,
                  constraints: BoxConstraints(minHeight: 34 * textScale),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F4F5),
                    border: Border.all(color: const Color(0xFFDFE5E9)),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Row(
                    children: [
                      // 小圆点只是状态展示，没有点击行为；灰色不代表“无故障”。
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF98A8AA),
                          border: Border.all(color: const Color(0xFF849496)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 文字占用圆点之外的剩余宽度，长名称可自动换行。
                      Expanded(
                        // Text.rich + TextSpan 让同一段文字有不同样式：
                        // bit 编号加粗，故障名称保持普通字重。
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'bit$bit ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(text: _faults[bit]),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 12,
                            color: _mutedColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
