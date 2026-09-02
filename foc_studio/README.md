# foc_studio

## `lib/` 代码文件简介

### 应用入口

- [`main.dart`](lib/main.dart)：程序入口，初始化 Flutter、桌面窗口配置和应用主题，并启动主页面。

### 页面

- [`pages/main_page.dart`](lib/pages/main_page.dart)：应用主框架，管理左侧导航、页面切换，以及串口服务和 FOC 控制器的生命周期。
- [`pages/setting_page.dart`](lib/pages/setting_page.dart)：串口设置页面，负责扫描串口、选择波特率，以及连接和断开设备。

### 控制器

- [`controllers/foc_controller.dart`](lib/controllers/foc_controller.dart)：管理一轮完整的 PC-MCU 通信会话，包括心跳、周期电机控制、电机类型轮询、参数读写、消息状态更新和遥测缓存。
- [`controllers/mcu_clock_synchronizer.dart`](lib/controllers/mcu_clock_synchronizer.dart)：将 MCU 的 `HAL_GetTick()` 时间映射到 PC 时间，并处理 `uint32` 回绕和 MCU 重启后的时间重置。

### 串口服务

- [`services/serial_port_service.dart`](lib/services/serial_port_service.dart)：封装串口枚举、连接、配置、断开、原始字节收发和底层资源释放，不处理具体业务协议。

### PC-MCU 协议

- [`protocol/pc_mcu/commands.dart`](lib/protocol/pc_mcu/commands.dart)：集中定义所有协议命令号、通信方向和 payload 长度约束。
- [`protocol/pc_mcu/protocol_frame.dart`](lib/protocol/pc_mcu/protocol_frame.dart)：表示一条已经通过帧头和 CRC 校验的原始协议帧。
- [`protocol/pc_mcu/crc16_modbus.dart`](lib/protocol/pc_mcu/crc16_modbus.dart)：实现 CRC16-MODBUS 校验算法。
- [`protocol/pc_mcu/frame_encoder.dart`](lib/protocol/pc_mcu/frame_encoder.dart)：将 CMD 和 payload 编码为包含帧头、长度及 CRC 的完整发送帧。
- [`protocol/pc_mcu/frame_decoder.dart`](lib/protocol/pc_mcu/frame_decoder.dart)：增量解析串口字节流，支持拆包、粘包、乱码跳过和 CRC 错误恢复。
- [`protocol/pc_mcu/message_codec.dart`](lib/protocol/pc_mcu/message_codec.dart)：在原始协议帧和强类型业务消息之间转换，处理 Big Endian、带符号整数及定点数缩放。
- [`protocol/pc_mcu/protocol_client.dart`](lib/protocol/pc_mcu/protocol_client.dart)：连接串口服务与协议编解码器，是原始串口接收流的唯一协议解析入口，并提供各类命令发送方法。

### 协议消息模型

- [`protocol/pc_mcu/messages/mcu_message.dart`](lib/protocol/pc_mcu/messages/mcu_message.dart)：定义所有 MCU 上行消息的公共基类，以及未知命令消息模型。
- [`protocol/pc_mcu/messages/control_messages.dart`](lib/protocol/pc_mcu/messages/control_messages.dart)：定义电机控制、PID 参数、电流环参数和电机限幅等 PC 下行数据模型。
- [`protocol/pc_mcu/messages/telemetry_message.dart`](lib/protocol/pc_mcu/messages/telemetry_message.dart)：定义转速、温度、电流、电压、错误码、日志和传感器状态等 MCU 实时遥测消息。
- [`protocol/pc_mcu/messages/configuration_messages.dart`](lib/protocol/pc_mcu/messages/configuration_messages.dart)：定义软件版本、电机类型、PID 参数、限幅、拨码开关和外部 Flash ID 等配置响应消息。

### 公共组件

- [`widgets/navi_rail_bottom.dart`](lib/widgets/navi_rail_bottom.dart)：封装导航栏底部按钮，用于设置页等非标准 `NavigationRailDestination` 入口。
