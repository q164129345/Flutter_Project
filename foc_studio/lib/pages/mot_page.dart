// as math 给数学库起别名；后面用 math.max(a, b) 取较大值。
import 'dart:math' as math;

import 'package:flutter/material.dart';
// TextInputFormatter 来自 services，用来限制输入框接受的文字。
import 'package:flutter/services.dart';

import '../controllers/foc_controller.dart';
import '../protocol/pc_mcu/messages/configuration_messages.dart';

// 页面共用的配色集中在这里，调整外观时不用逐个修改组件。
// 0xFFRRGGBB 中 FF 表示完全不透明，后六位分别表示红、绿、蓝。
// 名称前的下划线表示 Dart 库内私有，本文件中的组件都可以使用。
const _pageBackground = Color(0xFFFFF7FF);
const _panelBorder = Color(0xFF7B7780);
const _labelColor = Color(0xFF625E66);
const _mutedColor = Color(0xFF85818A);
const _valueColor = Color(0xFF1688CB);

String? _number(double? value) => value?.toStringAsFixed(2);

String? _errorCodeText(int? code) =>
    code == null ? null : '0x${code.toRadixString(16).padLeft(4, '0')}';

/// 把空值和不符合目标转速格式的编辑统一还原为 0，确保输入框始终有值。
TextEditingValue _targetSpeedInputFormatter(
  TextEditingValue oldValue,
  TextEditingValue newValue,
) {
  const zeroValue = TextEditingValue(
    text: '0',
    selection: TextSelection.collapsed(offset: 1),
  );
  final text = newValue.text;
  if (text.isEmpty || !RegExp(r'^-?\d{0,4}$').hasMatch(text)) {
    return zeroValue;
  }

  // 初始值为 0 时，直接继续输入数字应得到 1、12、123…，而不是 01、012…
  final normalized = text.replaceFirst(RegExp(r'^0+(?=\d)'), '');
  return normalized == text
      ? newValue
      : TextEditingValue(
          text: normalized,
          selection: TextSelection.collapsed(offset: normalized.length),
        );
}

String? _motorTypeName(MotorTypeMessage? message) {
  if (message == null) return null;
  final name = switch (message.type) {
    MotorType.sideBrushZhongling => '边刷(中菱)',
    MotorType.rollerBrush => '滚刷',
    MotorType.newSideBrush11050 => '1.5N',
    MotorType.zhonglingHubMotor => '中菱轮毂电机',
    MotorType.cutter08Nm => '0.8N',
    MotorType.frxCutter04Nm => '0.4N',
    MotorType.unknown || null => '未知',
  };
  return '${message.rawType} ($name)';
}

/// MOT 页面只在挂载期间监听控制器。
/// MainPage 只把当前导航页挂到树上，因此这里的 listener 生命周期就是
/// MOT 的可见生命周期；后台 FocSession 不受切页影响，仍持续解包。
class MotPage extends StatefulWidget {
  const MotPage({required this.controller, super.key});

  final FocController controller;

  @override
  State<MotPage> createState() => _MotPageState();
}

class _MotPageState extends State<MotPage> {
  late final TextEditingController _targetSpeedController;
  bool _commandPending = false;

  FocController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _targetSpeedController = TextEditingController(text: '0');
    controller.addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _setMotorControl(bool enabled) async {
    if (_commandPending || !controller.isConnected) return;
    final targetSpeed = int.tryParse(_targetSpeedController.text.trim());
    // 输入框已限制正常编辑；仍将单独的负号等无法解析的值安全地按 0 发送。
    final targetSpeedRpm =
        targetSpeed != null && targetSpeed >= -0x8000 && targetSpeed <= 0x7fff
        ? targetSpeed
        : 0;

    setState(() => _commandPending = true);
    try {
      await controller.setMotorControl(
        enabled: enabled,
        targetSpeedRpm: targetSpeedRpm,
      );
    } catch (_) {
      // 控制区不显示命令失败提示；finally 仍会恢复按钮状态。
    } finally {
      if (mounted) setState(() => _commandPending = false);
    }
  }

  @override
  void dispose() {
    controller.removeListener(_handleControllerChanged);
    _targetSpeedController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = controller.state;
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
            // 监控区宽时并排显示两组字段，窄时上下排列。无论哪种排法，
            // 每个 Column 都只承载一组字段（第一组 9 项、第二组 4 项）。
            final twoColumns = contentWidth >= 580 * textScale;
            // 控制区空间不足时，把按钮移到输入框下方。
            final compactControls = contentWidth < 540 * textScale;
            // 不使用 SingleChildScrollView：三个分区均直接受当前窗口约束。
            return Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                // stretch 让三个分区横向占满可用宽度。
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ControlPanel(
                    compact: compactControls,
                    targetSpeedController: _targetSpeedController,
                    enabled: controller.isConnected && !_commandPending,
                    commandPending: _commandPending,
                    onStart: () => _setMotorControl(true),
                    onStop: () => _setMotorControl(false),
                  ),
                  const SizedBox(height: 8),
                  // Expanded 取得控制区和故障区实际布局后剩余的精确高度，
                  // 避免依据估算高度时出现数个像素的底部溢出。
                  Expanded(
                    child: _MonitorPanel(
                      twoColumns: twoColumns,
                      textScale: textScale,
                      snapshot: snapshot,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _FaultPanel(
                    contentWidth: contentWidth,
                    textScale: textScale,
                    snapshot: snapshot,
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

/// 三个区域共用的外壳。
///
/// Container 绘制边框和内容背景；Stack 让居中标题覆盖顶部边框，形成类似
/// fieldset 的标题缺口。MOT 页面只使用三个该组件实例，分别对应控制、监控和故障区。
class _StackPanel extends StatelessWidget {
  const _StackPanel({
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
    final panelBody = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: _pageBackground,
        border: Border.all(color: _panelBorder, width: 1.5),
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );

    return Stack(
      key: ValueKey('mot-panel-$title'),
      clipBehavior: Clip.none,
      children: [
        // 边框下移，给标题留出覆盖边线的位置。
        fillHeight
            ? Positioned.fill(top: 10, child: panelBody)
            : Container(
                margin: const EdgeInsets.only(top: 10),
                child: panelBody,
              ),
        // 标题底色与页面、面板相同，所以能自然遮住一段顶部边框。
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Align(
            child: Container(
              color: _pageBackground,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900, // 900 是 Flutter 支持的最大粗体
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 控制区展示目标速度输入和控制按钮。
class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.compact,
    required this.targetSpeedController,
    required this.enabled,
    required this.commandPending,
    required this.onStart,
    required this.onStop,
  });

  final bool compact;
  final TextEditingController targetSpeedController;
  final bool enabled;
  final bool commandPending;
  final VoidCallback onStart;
  final VoidCallback onStop;

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
            controller: targetSpeedController,
            // 未连接时仍允许先填写目标值；只有已连接时才开放发送按钮。
            enabled: !commandPending,
            // keyboardType 只提示平台使用数字键盘，不能阻止粘贴非法文字，
            // 所以还需要下面的 inputFormatters 检查实际输入。
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            inputFormatters: [
              TextInputFormatter.withFunction(_targetSpeedInputFormatter),
            ],
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 14, color: _labelColor),
            // InputDecoration 描述输入框外观。
            decoration: InputDecoration(
              isDense: true,
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
    FilledButton controlButton(String label, VoidCallback callback) {
      return FilledButton(
        onPressed: enabled ? callback : null,
        style: FilledButton.styleFrom(
          minimumSize: const Size(70, 28),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.standard,
          disabledBackgroundColor: const Color(0xFFBCC3C9),
          disabledForegroundColor: Colors.white,
          textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        ),
        child: Text(label),
      );
    }

    final buttons = Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [controlButton('启动', onStart), controlButton('停止', onStop)],
    );

    return _StackPanel(
      title: '控制',
      // 窄窗口上下排列，宽窗口左右排列；两种布局复用上面创建的组件。
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          compact
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
                    Expanded(child: speedInput),
                    const SizedBox(width: 16),
                    buttons,
                  ],
                ),
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
    required this.snapshot,
  });

  final bool twoColumns;
  final double textScale;
  final FocSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final motorFields = [
      _MonitorField('软件版本', value: snapshot.softwareVersion?.displayName),
      _MonitorField('电机类型', value: _motorTypeName(snapshot.motorType)),
      _MonitorField('拨码ID', value: snapshot.dipSwitchId?.id),
      _MonitorField(
        '使能状态',
        value: snapshot.reportedEnableState == null
            ? null
            : (snapshot.reportedEnableState!.enabled ? '1' : '0'),
      ),
      _MonitorField('转速', unit: 'RPM', value: snapshot.latestSpeed?.value.rpm),
      _MonitorField(
        '电流',
        unit: 'A',
        value: _number(snapshot.latestCurrent?.value.amperes),
      ),
      _MonitorField(
        '电机温度',
        unit: '°C',
        value: _number(snapshot.motorTemperature?.celsius),
      ),
      _MonitorField(
        'MOS温度',
        unit: '°C',
        value: _number(snapshot.mosTemperature?.celsius),
      ),
      _MonitorField('错误码', value: _errorCodeText(snapshot.errorCode?.code)),
    ];
    final dq = snapshot.latestDq?.value;
    final dqFields = [
      _MonitorField('Iq电流分量', unit: 'A', value: _number(dq?.iq)),
      _MonitorField('Id电流分量', unit: 'A', value: _number(dq?.id)),
      _MonitorField('Uq电压分量', unit: 'V', value: _number(dq?.uq)),
      _MonitorField('Ud电压分量', unit: 'V', value: _number(dq?.ud)),
    ];

    // 局部函数把一组字段转换为一列组件。=> 是只有一个返回表达式的函数简写。
    // 字段配置与绘制代码分开后，添加字段只需修改上面的列表。
    Widget fieldColumn(List<_MonitorField> fields) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final field in fields)
          _MonitorRow(field: field, textScale: textScale),
      ],
    );

    return _StackPanel(
      title: '监控界面',
      // 外层 Expanded 已提供精确剩余高度，因此边框也填满该空间。
      fillHeight: true,
      child: twoColumns
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 左组固定预留宽度，右组使用剩余空间；两组都从顶部开始排列。
                SizedBox(
                  width: 280 * textScale,
                  child: fieldColumn(motorFields),
                ),
                Expanded(child: fieldColumn(dqFields)),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                fieldColumn(motorFields),
                const SizedBox(height: 12),
                fieldColumn(dqFields),
              ],
            ),
    );
  }
}

/// 一项监控字段的显示配置，属于普通 Dart 数据类，本身不会绘制界面。
/// label 是名称，hint 是范围或精度提示，unit 是单位，value 是显示字符串。
/// 所有成员为 final，创建后不重新赋值；未传 value 时默认显示“--”。
class _MonitorField {
  const _MonitorField(this.label, {this.unit = '', this.value});

  final String label;
  final String unit;
  final Object? value;

  String get displayValue => value?.toString() ?? '--';
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
              width: 100 * textScale, // 左侧标签区域的期望宽度
              child: Text(field.label),
            ),
          ),
          // Semantics 给屏幕阅读器提供说明。excludeSemantics 避免再重复朗读
          // 内部的占位文字，明确“--”或占位版本号都不是实际设备读数。
          Semantics(
            label: '${field.label}：${field.displayValue}',
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
                field.displayValue,
                style: const TextStyle(
                  color: _valueColor,
                  fontWeight: FontWeight.w700,
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

/// 故障区将故障码按 bit 展开；未收到故障码时明确显示“未知”。
class _FaultPanel extends StatelessWidget {
  const _FaultPanel({
    required this.contentWidth,
    required this.textScale,
    required this.snapshot,
  });

  final double contentWidth;
  final double textScale;
  final FocSnapshot snapshot;

  static const _faults = [
    '驱动器过压',
    '驱动器欠压',
    '驱动器过流',
    '驱动器过载',

    '速度超差（堵转）',
    '预留位5',
    '电机过温',
    'MOS管过温',

    'FOC校准失败',
    '485/编码器通讯故障',
    'CAN总线通讯故障',
    '失控（缺相）',

    '电流偏置校准失败',
    'PLL失锁',
    '保留位14',
    '保留位15',
  ];
  // 应用的最小窗口尺寸保证每一格都有足够的宽度，因此固定为 4 列。
  static const _columns = 4;

  @override
  Widget build(BuildContext context) {
    // contentWidth 是页面内边距扣除后的宽度；面板自身还有左右 8 的
    // padding 和 1.5 的边框。多预留 1 像素，避免浮点取整后第 4 项被
    // Wrap 错误地换到下一行，从而破坏固定 4 列的布局。
    final tileWidth = (contentWidth - 20 - (_columns - 1) * 8) / _columns;
    final errorCode = snapshot.errorCode?.code;

    return _StackPanel(
      title: '电机故障信息',
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (var bit = 0; bit < _faults.length; bit++)
            _FaultTile(
              bit: bit,
              name: _faults[bit],
              errorCode: errorCode,
              width: tileWidth,
              textScale: textScale,
            ),
        ],
      ),
    );
  }
}

class _FaultTile extends StatelessWidget {
  const _FaultTile({
    required this.bit,
    required this.name,
    required this.errorCode,
    required this.width,
    required this.textScale,
  });

  final int bit;
  final String name;
  final int? errorCode;
  final double width;
  final double textScale;

  @override
  Widget build(BuildContext context) {
    final known = errorCode != null;
    final active = known && (errorCode! & (1 << bit)) != 0;
    final state = !known ? '未知' : (active ? '故障' : '正常');
    final color = !known
        ? const Color(0xFF98A8AA)
        : active
        ? Colors.red.shade700
        : Colors.green.shade700;
    return Semantics(
      label: 'bit$bit $name：$state',
      excludeSemantics: true,
      child: Tooltip(
        message: 'bit$bit $name：$state',
        child: Container(
          width: width,
          constraints: BoxConstraints(minHeight: 34 * textScale),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F5),
            border: Border.all(color: const Color(0xFFDFE5E9)),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color,
                  border: Border.all(color: const Color(0xFF849496)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'bit$bit ',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      TextSpan(text: name),
                    ],
                  ),
                  style: const TextStyle(fontSize: 12, color: _mutedColor),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
