# foc_studio 代码结构与 UML

本文档依据当前 `lib/` 源代码整理。图中省略了 Flutter 布局控件、窗口管理器等与串口业务无关的框架细节；类名、字段名和方法名均沿用源代码。

## 1. UML 类图

```mermaid
classDiagram
direction TB

class MainApp {
  <<UI>>
  +build(BuildContext context) Widget
}

class MainPage {
  <<UI>>
  +createState() State~MainPage~
}

class _MainPageState {
  <<UI>>
  -int _selectedIndex
  -SerialPortService _serialService
  -FocController _focController
  -List~Widget~ _pages
  +initState() void
  +build(BuildContext context) Widget
  +dispose() void
}

class SettingPage {
  <<UI>>
  +SerialPortService serialService
  +createState() State~SettingPage~
}

class _SettingPageState {
  <<UI>>
  -List~String~ _ports
  -String? _selectedPort
  -int _baudRate
  -String _status
  -bool _isConnected
  -_refreshPorts() void
  -_connect() void
  -_disconnect() void
  -_toggleConnection() void
  +build(BuildContext context) Widget
}

class _SerialConnectionIndicator {
  <<UI>>
  +SerialPortService service
  +build(BuildContext context) Widget
}

class SerialPortService {
  <<Service>>
  -SerialPort? _port
  -SerialPortReader? _reader
  -SerialPortConnectionStatus _connectionStatus
  -StreamController~Uint8List~ _receivedBytesController
  +Stream~Uint8List~ receivedBytesStream
  +bool isConnected
  +getAvailablePorts() List~String~
  +connect(String portName, int baudRate) void
  -_setConnectionStatus(SerialPortConnectionStatus status, Object? error) void
  -_startReading() void
  +sendBytes(List~int~ bytes) int
  +disconnect() void
  +dispose() void
}

class FocController {
  <<Controller>>
  +SerialPortService serialService
  -PcMcuProtocolClient _protocolClient
  -McuClockSynchronizer _mcuClock
  -TimestampedSample~SpeedFeedbackMessage~? _latestSpeed
  -TimestampedSample~DqFeedbackMessage~? _latestDq
  -TimestampedSample~MotorCurrentMessage~? _latestCurrent
  -ListQueue~TimestampedSample~ _speedHistory
  -ListQueue~TimestampedSample~ _dqHistory
  -ListQueue~TimestampedSample~ _currentHistory
  +setMotorControl(bool enabled, int targetSpeedRpm) bool
  +querySoftwareVersion() bool
  +queryMotorType() bool
  +queryTuneParameters() bool
  +writeTuneParameters(PidParameters speedLoop, CurrentLoopParameters currentLoop, MotorLimits motorLimits) bool
  -_handleConnectionChanged() void
  -_startSession() void
  -_handleMessage(McuMessage message) void
  -_timedSample(T value, int mcuTickMs, DateTime receivedAt) TimestampedSample~T~
  +dispose() void
}

class McuClockSynchronizer {
  <<Controller helper>>
  -DateTime? _pcOrigin
  -int? _lastTick
  -int _wrapCount
  +align(int tickMs, DateTime receivedAt) DateTime
  +reset() void
}

class PcMcuProtocolClient {
  <<Protocol>>
  -SerialPortService _serialService
  +ProtocolFrameDecoder frameDecoder
  +PcMcuMessageCodec messageCodec
  +Stream~McuMessage~ messages
  +sendMotorControl(MotorControlCommand command) int
  +sendHeartbeat() int
  +querySoftwareVersion() int
  +queryMotorType() int
  -_handleChunk(Uint8List chunk) void
  -_sendFrame(Uint8List frame) int
  +dispose() void
}

class ProtocolFrameDecoder {
  <<Protocol>>
  -List~int~ _buffer
  -int _crcErrorCount
  -int _decodeFailureCount
  +addChunk(Uint8List chunk) List~ProtocolFrame~
  +reset() void
}

class PcMcuMessageCodec {
  <<Protocol>>
  +ProtocolFrameEncoder frameEncoder
  +decode(ProtocolFrame frame) McuMessage
  +encodeMotorControl(MotorControlCommand command) Uint8List
  +encodeHeartbeat() Uint8List
  +encodeQuerySoftwareVersion() Uint8List
  +encodeQueryMotorType() Uint8List
}

class ProtocolFrameEncoder {
  <<Protocol>>
  +encode(int command, List~int~ payload) Uint8List
  +encodeCommand(PcMcuCommand command, List~int~ payload) Uint8List
}

class ProtocolFrame {
  <<Protocol model>>
  +int command
  +Uint8List payload
  +int payloadLength
}

class McuMessage {
  <<abstract message>>
  +PcMcuCommand? command
  +int commandId
}

class TimestampedSample~T~ {
  <<state model>>
  +T value
  +DateTime timestamp
}

class SpeedFeedbackMessage {
  +int rpm
  +int mcuTickMs
}

class DqFeedbackMessage {
  +double iq
  +double id
  +double uq
  +double ud
  +int mcuTickMs
}

class MotorCurrentMessage {
  +double amperes
  +int mcuTickMs
}

class McuLogMessage {
  +McuLogLevel level
  +String text
}

class SoftwareVersionMessage {
  +int main
  +int sub
  +int mini
  +int revision
  +String displayName
}

class MotorTypeMessage {
  +int rawType
  +MotorType? type
  +bool isKnown
}

MainApp --> MainPage : home
MainPage ..> _MainPageState : createState()
_MainPageState *-- SerialPortService : owns
_MainPageState *-- FocController : owns
_MainPageState --> SettingPage : builds
_MainPageState --> _SerialConnectionIndicator : builds
SettingPage ..> _SettingPageState : createState()
SettingPage o-- SerialPortService : injected
_SettingPageState --> SerialPortService : uses
_SerialConnectionIndicator --> SerialPortService : observes

FocController --> SerialPortService : observes connection
FocController *-- PcMcuProtocolClient : owns by default
FocController *-- McuClockSynchronizer
FocController o-- TimestampedSample~T~ : stores histories
FocController --> McuMessage : handles

PcMcuProtocolClient --> SerialPortService : consumes bytes / sends frames
PcMcuProtocolClient *-- ProtocolFrameDecoder
PcMcuProtocolClient *-- PcMcuMessageCodec
ProtocolFrameDecoder ..> ProtocolFrame : creates
PcMcuMessageCodec --> ProtocolFrame : decodes
PcMcuMessageCodec *-- ProtocolFrameEncoder
PcMcuMessageCodec ..> McuMessage : creates

McuMessage <|-- SpeedFeedbackMessage
McuMessage <|-- DqFeedbackMessage
McuMessage <|-- MotorCurrentMessage
McuMessage <|-- McuLogMessage
McuMessage <|-- SoftwareVersionMessage
McuMessage <|-- MotorTypeMessage
```

### 类图说明

1. **UI 层**由 `MainApp`、`MainPage`、`_MainPageState`、`SettingPage`、`_SettingPageState` 和 `_SerialConnectionIndicator` 组成。`_MainPageState` 是顶层对象生命周期的所有者：它创建同一个 `SerialPortService` 和 `FocController`，把 `SerialPortService` 注入 `SettingPage`，并在退出时按 `FocController.dispose()`、`SerialPortService.dispose()` 的顺序释放资源。`_SettingPageState` 只负责串口扫描、选择、连接/断开操作及状态文字；`_SerialConnectionIndicator` 只展示连接状态。
2. **Service 层**的核心是 `SerialPortService`。它只处理串口枚举、打开和配置、创建读取器、收发原始字节、连接状态以及资源释放，不解释任何 PC-MCU 命令。`receivedBytesStream` 是 Service 层向上提供的原始字节边界。
3. **协议层**以 `PcMcuProtocolClient` 为门面。它是 `receivedBytesStream` 的唯一协议消费者：`ProtocolFrameDecoder` 负责拆包、粘包、帧头同步和 CRC 校验；`PcMcuMessageCodec` 负责把 `ProtocolFrame` 转换成强类型 `McuMessage`，或把下行命令交给 `ProtocolFrameEncoder` 编码。图中只展开了对主流程最有代表性的消息子类，其余温度、错误码、传感器和参数响应类遵循相同继承关系。
4. **Controller 层**的 `FocController` 负责一次通信会话的业务策略，包括心跳、周期电机控制、电机类型轮询、配置查询、最新状态和有限长度的遥测历史。带 MCU tick 的消息会经 `_timedSample()` 和 `McuClockSynchronizer.align()` 映射到 PC 时间。
5. 当前依赖方向清晰：UI 调用 Service；协议客户端消费 Service 的字节流；Controller 订阅协议消息并整理成 UI 可读状态。需要特别注意的是，`_MainPageState` 虽然持有 `_focController`，但当前只创建和释放它，没有把它传给任何数据页面，也没有用它驱动 UI。

## 2. UML 时序图：用户点击“连接”后的完整调用流程

```mermaid
sequenceDiagram
autonumber
actor User as 用户
participant UI as _SettingPageState
participant S as SerialPortService
participant Port as SerialPort
participant Reader as SerialPortReader
participant P as PcMcuProtocolClient
participant F as FocController
participant C as PcMcuMessageCodec
participant E as ProtocolFrameEncoder
participant I as _SerialConnectionIndicator

Note over P,F: 二者已在 _MainPageState.initState() 中创建并完成监听注册
User->>UI: FilledButton.onPressed
UI->>UI: _toggleConnection()
Note over UI: 点击“连接”时 _isConnected == false
UI->>UI: _connect()

alt _selectedPort == null
  UI->>UI: setState()
  Note over UI: _status = “没有可用串口”
else 已选择串口
  UI->>S: connect(portName, baudRate)
  opt _port != null
    S->>S: disconnect()
  end
  S->>Port: SerialPort(portName)
  S->>Port: openReadWrite()

  alt 打开、配置和启动读取均成功
    S->>Port: config = SerialPortConfig
    S->>S: _startReading()
    S->>Reader: SerialPortReader(port)
    S->>Reader: stream.listen(...)
    S->>S: _setConnectionStatus(SerialPortConnectionStatus.connected)

    S-->>P: notifyListeners()
    P->>P: _handleConnectionChanged()
    S-->>F: notifyListeners()
    F->>F: _handleConnectionChanged()
    F->>F: _startSession()
    F->>F: _cancelTimers()
    F->>F: _resetSessionState()

    F->>F: _sendHeartbeat()
    F->>F: _trySend(_protocolClient.sendHeartbeat)
    F->>P: sendHeartbeat()
    P->>C: encodeHeartbeat()
    C->>E: encodeCommand(PcMcuCommand.heartbeat)
    E->>E: encode(command, payload)
    E-->>C: Uint8List frame
    C-->>P: Uint8List frame
    P->>P: _sendFrame(frame)
    loop 直到完整帧写完
      P->>S: sendBytes(remaining)
      S->>Port: write(data)
      Port-->>S: written
      S-->>P: written
    end

    F->>F: _sendMotorControl()
    F->>F: _trySend(...)
    F->>P: sendMotorControl(MotorControlCommand)
    P->>C: encodeMotorControl(command)
    C->>E: encodeCommand(PcMcuCommand.motorControl, payload)
    E->>E: encode(command, payload)
    E-->>C: Uint8List frame
    C-->>P: Uint8List frame
    P->>P: _sendFrame(frame)
    P->>S: sendBytes(remaining)
    S->>Port: write(data)

    F->>F: querySoftwareVersion()
    F->>F: _trySend(_protocolClient.querySoftwareVersion)
    F->>P: querySoftwareVersion()
    P->>C: encodeQuerySoftwareVersion()
    C->>E: encodeCommand(PcMcuCommand.querySoftwareVersion)
    E->>E: encode(command, payload)
    E-->>C: Uint8List frame
    C-->>P: Uint8List frame
    P->>P: _sendFrame(frame)
    P->>S: sendBytes(remaining)
    S->>Port: write(data)

    F->>F: queryMotorType()
    F->>F: _trySend(_protocolClient.queryMotorType)
    F->>P: queryMotorType()
    P->>C: encodeQueryMotorType()
    C->>E: encodeCommand(PcMcuCommand.queryMotorType)
    E->>E: encode(command, payload)
    E-->>C: Uint8List frame
    C-->>P: Uint8List frame
    P->>P: _sendFrame(frame)
    P->>S: sendBytes(remaining)
    S->>Port: write(data)

    F->>F: _startMotorTypePolling()
    Note over F: 建立 heartbeatInterval、motorControlInterval、motorTypeQueryInterval 对应的周期任务
    F->>F: notifyListeners()
    S-->>I: notifyListeners()
    I->>I: build(context)
    Note over I: 导航栏连接图标变为绿色

    S-->>UI: connect() 返回
    UI->>UI: setState()
    Note over UI: _status = “已连接 ...”并重建连接按钮
  else 任一步骤抛出异常
    S->>S: _stopReading()
    S->>Port: close()
    S->>S: _releasePortObject(port)
    S->>S: _setConnectionStatus(SerialPortConnectionStatus.failed, error: e)
    S-->>P: notifyListeners()
    P->>P: _handleConnectionChanged()
    S-->>F: notifyListeners()
    F->>F: _handleConnectionChanged()
    F->>F: _stopSession(resetState: true)
    S-->>I: notifyListeners()
    I->>I: build(context)
    S-->>UI: rethrow
    UI->>UI: setState()
    Note over UI: _status = “连接失败：...”
  end
end
```

### 连接时序说明

1. UI 入口是连接按钮的 `onPressed`，它调用 `_toggleConnection()`；在未连接状态下继续进入 `_connect()`。页面仅校验选择项、调用 Service，并用 `setState()` 更新本地提示文字。
2. `SerialPortService.connect()` 完成真正的硬件工作：创建 `SerialPort`、执行 `openReadWrite()`、应用 8N1/无流控配置，并由 `_startReading()` 创建 `SerialPortReader` 和数据流订阅。只有这些步骤全部成功后，才调用 `_setConnectionStatus(SerialPortConnectionStatus.connected)`。
3. 连接状态通过 `notifyListeners()` 同步通知多个观察者。`PcMcuProtocolClient._handleConnectionChanged()` 记录会话是否连接；`FocController._handleConnectionChanged()` 调用 `_startSession()`；导航栏的监听最终触发 `_SerialConnectionIndicator.build()`，显示绿色连接状态。
4. `_startSession()` 不只是设置标志，它会立即发送心跳、当前电机控制命令、软件版本查询和电机类型查询。每条命令均经过 `PcMcuMessageCodec`、`ProtocolFrameEncoder`、`PcMcuProtocolClient._sendFrame()`、`SerialPortService.sendBytes()`，最终到 `SerialPort.write()`。随后启动 1 秒心跳、500 毫秒电机控制和 1 秒电机类型查询周期任务。
5. `PcMcuProtocolClient._sendFrame()` 用循环处理串口短写，直到完整帧发完；图中对第一条心跳完整展开，其余三条使用同一发送通道。
6. 任一打开、配置或读取初始化步骤失败时，Service 负责停止读取、关闭/释放端口、切换到 `failed` 并重新抛出异常；Controller 停止会话，UI 捕获异常并显示“连接失败”。这体现了分工：UI 决定显示什么，Service 决定底层连接是否成立。

## 3. UML 时序图：串口收到数据后的实际处理链路

> 重要：当前源代码不存在“最终由 UI 显示遥测数据”的完整链路。下面的图严格展示实际代码：数据处理到 `FocController.notifyListeners()` 为止；现有 UI 没有订阅 `FocController`，因此不会因收到数据而重建或显示 `latestSpeed`、`latestDq`、`latestCurrent`、`logs` 等内容。

```mermaid
sequenceDiagram
autonumber
participant MCU as MCU
participant Reader as SerialPortReader
participant S as SerialPortService
participant P as PcMcuProtocolClient
participant D as ProtocolFrameDecoder
participant C as PcMcuMessageCodec
participant F as FocController
participant Clock as McuClockSynchronizer
participant MainUI as _MainPageState
participant SettingUI as _SettingPageState

MCU-->>Reader: 原始串口字节
Reader-->>S: stream data(data)
S->>S: _receivedBytesController.add(Uint8List.fromList(data))
S-->>P: _handleChunk(chunk)
P->>D: addChunk(chunk)

alt 只有半帧或尚未找到有效帧
  D-->>P: 空的 List<ProtocolFrame>
  Note over D: 字节保留在 _buffer，等待后续 chunk
else 得到一个或多个 CRC 有效帧
  D-->>P: List<ProtocolFrame>
  loop 每个 ProtocolFrame
    P->>C: decode(frame)
    alt 解码成功
      C-->>P: McuMessage
      P->>P: _messageController.add(message)
      P-->>F: _handleMessage(message)
      F->>F: _lastMessageAt = _now()

      alt SpeedFeedbackMessage / DqFeedbackMessage / MotorCurrentMessage / HallSensorStateMessage
        F->>F: _timedSample(value, mcuTickMs, receivedAt)
        F->>Clock: align(mcuTickMs, receivedAt)
        Clock-->>F: DateTime
        F->>F: _addBounded(queue, value, capacity)
      else 温度、状态、错误、配置响应
        Note over F: 更新对应的 _motorTemperature、_softwareVersion、_motorType 等最新状态
      else McuLogMessage
        F->>F: _addBounded(_logs, value, logCapacity)
      else UnknownMcuMessage
        Note over F: 保留在 messages 流中，不修改当前 Controller 状态
      end

      F->>F: notifyListeners()
      Note over F,SettingUI: 当前没有 addListener() 或 ListenableBuilder(listenable: _focController)
      Note over MainUI,SettingUI: _focController 只在 _MainPageState.initState() 创建，并在 dispose() 释放；没有数据 Widget 读取 Controller 状态
    else decode(frame) 抛出异常
      P->>P: _messageController.addError(error, stackTrace)
      P-->>F: _handleProtocolError(error, stackTrace)
      F->>F: notifyListeners()
      Note over F,SettingUI: 协议错误同样没有绑定到现有 UI
    end
  end
end
```

### 接收时序说明

1. `SerialPortReader` 产生的每次 `data` 只是任意大小的字节块，不保证正好是一帧。`SerialPortService` 复制该字节块并写入 `_receivedBytesController`；它仍然不理解业务协议。
2. `PcMcuProtocolClient._handleChunk()` 把字节交给 `ProtocolFrameDecoder.addChunk()`。Decoder 持有跨回调的 `_buffer`，所以能处理半帧、粘包、前导乱码和 CRC 错误；只有帧头、长度和 CRC 均合法时才产生 `ProtocolFrame`。
3. `PcMcuMessageCodec.decode()` 根据 `PcMcuCommand`、Big Endian 字段布局和缩放规则创建具体的 `McuMessage`。成功结果经 `_messageController` 广播；格式异常则经 `addError()` 进入 `FocController._handleProtocolError()`，但协议错误不会直接断开串口。
4. `FocController._handleMessage()` 把消息整理成适合展示的状态。转速、DQ、电流和霍尔消息会通过 `_timedSample()` 调用 `McuClockSynchronizer.align()`，再由 `_addBounded()` 写入有限长度历史；温度、错误码和配置响应更新各自的最新值；日志进入 `_logs`。处理完成后统一调用 `notifyListeners()`。
5. **实际断点在 UI 层。** `_MainPageState` 创建了 `_focController`，但 `_pages` 中目前只有三个静态 `Text` 占位页和 `SettingPage`；没有页面接收 `FocController`，也没有 `ListenableBuilder` 监听它。现有唯一的 `ListenableBuilder` 监听的是 `SerialPortService`，因此它只能更新连接图标，不能显示收到的 MCU 数据。
6. 要闭合该链路，UI 层需要让真实数据页面获得同一个 `FocController`，通过 `ListenableBuilder(listenable: controller, ...)` 或等价监听方式触发其 `build()`，并读取 `latestSpeed`、`latestDq`、`latestCurrent`、`motorTemperature`、`logs` 等 getter。该步骤是建议的后续设计，不是当前源码中已经存在的调用。

## UI 层与 Service 层职责总结

| 层 | 当前负责 | 不应负责 |
|---|---|---|
| UI 层 | 导航、串口选择、用户点击事件、连接状态和错误文字展示；未来还应监听 `FocController` 并把结构化状态渲染为控件或图表 | 直接打开串口、拼协议帧、计算 CRC、解析二进制 payload、管理心跳定时器 |
| Service 层 | 枚举端口、打开/配置/关闭串口、创建读取器、收发原始字节、报告连接/传输状态、释放资源 | 识别 PC-MCU 命令、解析遥测数据、决定电机控制业务策略、直接构建 Widget |
| 协议层 | 字节组帧与校验、命令编解码、强类型消息流、完整帧发送 | 页面布局、串口生命周期策略、遥测展示形式 |
| Controller 层 | 会话策略、周期命令、配置读写、消息状态归并、时间对齐、历史缓存、通知 UI | 直接操作 Flutter 控件或底层 `SerialPort` |
