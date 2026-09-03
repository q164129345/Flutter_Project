import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';

/// enum（枚举）用于列出有限且固定的几种状态。
/// 相比用“已连接”这类字符串判断，枚举不容易拼错，也方便 switch 逐一处理。
enum SerialPortConnectionStatus {
  disconnected, // 尚未连接，或者用户主动断开。
  connected, // 串口已经成功打开并完成配置。
  failed, // 最近一次连接尝试失败。
}

/// 串口服务层：只负责“找串口、连接、收发字节、释放资源”。
///
/// 将串口逻辑从 Widget 中拆出来，可以避免 UI 代码同时处理大量底层细节。
// extends ChangeNotifier 表示这个对象可以在状态改变时通知界面刷新。
// NavigationRail 中的 ListenableBuilder 正在监听这个 Service。
class SerialPortService extends ChangeNotifier {
  // “?”表示该变量可以为 null；未连接时就没有 SerialPort 对象。
  SerialPort? _port;

  // 保存当前连接状态。程序刚启动时还没有连接，所以初始值为 disconnected。
  // 下划线开头表示私有字段，只有本文件中的代码可以直接修改它。
  SerialPortConnectionStatus _connectionStatus =
      SerialPortConnectionStatus.disconnected;

  // 保存最近一次连接或传输失败抛出的异常，导航栏可以把具体原因放进 Tooltip。
  // Object? 中的“?”表示允许为 null；没有错误时它就是 null。
  Object? _lastConnectionError;

  // 连接成功后记录实际使用的串口名和波特率，例如 COM3、460800。
  // 断开或连接失败后，这两个字段会重新变成 null。
  String? _connectedPortName;
  int? _connectedBaudRate;

  // getter 只允许外部读取状态，不允许外部直接修改上面的私有字段。
  // “=>”是只有一个表达式时的简写，相当于 { return _connectionStatus; }。
  // int?声明的函数返回值类型是可空的 int，表示可能返回 null。
  SerialPortConnectionStatus get connectionStatus => _connectionStatus;
  Object? get lastConnectionError => _lastConnectionError;
  String? get connectedPortName => _connectedPortName;
  int? get connectedBaudRate => _connectedBaudRate;

  /// 每次调用都重新读取系统串口列表。
  /// USB 串口拔插后列表可能变化，所以 UI 需要提供“刷新”按钮。
  List<String> getAvailablePorts() {
    return SerialPort.availablePorts; // 通过系统接口枚举已存在串口名称
  }

  // SerialPortReader 把底层串口读取转换成 Dart Stream。
  SerialPortReader? _reader;

  // listen() 会返回订阅对象；必须保存它，断开时才能 cancel()。
  StreamSubscription<Uint8List>? _readerSubscription;

  // broadcast 允许多个监听者订阅。这里 UI 可以在字符串流和字节流之间切换。
  // 易错点：broadcast Stream 在没有监听者时不会替你缓存历史数据。
  final StreamController<Uint8List> _receivedBytesController =
      StreamController<Uint8List>.broadcast();

  /// HEX 模式直接使用原始字节，不做文字解码。
  Stream<Uint8List> get receivedBytesStream => _receivedBytesController.stream;

  /// 字符串模式：原始字节 -> UTF-8 文本 -> 按换行符拆分。
  ///
  /// allowMalformed 为 true 时，非法 UTF-8 字节会被替换字符代替，不会让整个流报错中断。
  /// LineSplitter 只在收到 \n 或 \r\n 后才产生一条消息；
  /// 如果设备不发换行符，字符串模式就会一直等待。
  Stream<String> get receivedTextStream => receivedBytesStream
      .cast<List<int>>()
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());

  // 必须同时满足两个条件才算真正连接：
  // 1. 业务状态已经变成 connected；2. 系统底层的串口仍然处于打开状态。
  // “?.”是空安全访问，“?? false”表示 _port 为 null 时返回 false。
  bool get isConnected =>
      _connectionStatus == SerialPortConnectionStatus.connected &&
      (_port?.isOpen ?? false);

  /// 统一修改连接状态并通知界面。
  ///
  /// error 放在花括号中，所以它是可选的命名参数；调用失败状态时才需要传入。
  void _setConnectionStatus(
    SerialPortConnectionStatus status, {
    Object? error,
  }) {
    // 先比较新旧值。状态和错误都没有变化时，不必让界面重复 build。
    final changed =
        _connectionStatus != status ||
        _lastConnectionError?.toString() != error?.toString();

    // 无论界面是否需要刷新，Service 内部都先保存最新值。
    _connectionStatus = status;
    _lastConnectionError = error;

    if (changed) {
      // 通知所有监听者。MainPage 中的 ListenableBuilder 收到通知后，
      // 会重新构建串口图标，从而更新图标、颜色和提示文字。
      notifyListeners();
    }
  }

  /// 打开并配置串口。
  void connect({required String portName, required int baudRate}) {
    // 如果已经连接，先断开
    if (_port != null) {
      disconnect();
    }

    // 先使用局部变量，配置全部成功后再赋给 _port。
    // 这样如果中途失败，isConnected 不会误判为已连接。
    final port = SerialPort(portName);

    try {
      // 打开串口：读 + 写
      final success = port.openReadWrite();

      if (!success) {
        throw Exception('打开串口失败，串口可能被占用');
      }

      // SerialPortConfig 包含底层资源，用完后也需要 dispose()。
      final config = SerialPortConfig();

      try {
        // 波特率
        config.baudRate = baudRate;

        // 常见的 8N1：8 个数据位、无校验、1 个停止位。
        // 易错点：这些参数必须与对端设备完全一致。
        config.bits = 8;
        config.stopBits = 1;
        config.parity = SerialPortParity.none;

        // 不使用流控
        config.setFlowControl(SerialPortFlowControl.none);

        // 应用配置
        port.config = config;
      } finally {
        // finally 无论配置成功还是抛出异常都会执行，用于保证资源释放。
        config.dispose();
      }

      // 配置成功以后，才保存这个串口对象
      _port = port;

      // 开始监听接收串口数据
      _startReading();

      // 只有“打开、配置、启动读取”全部完成，才记录信息并宣布连接成功。
      _connectedPortName = portName;
      _connectedBaudRate = baudRate;
      _setConnectionStatus(SerialPortConnectionStatus.connected);
    } catch (e) {
      // 连接的任意一步失败时，都尝试关闭并释放已创建的对象。
      _stopReading();
      _port = null;

      try {
        if (port.isOpen) {
          port.close();
        }
      } catch (_) {}

      _releasePortObject(port);

      // 连接失败时不能保留上一次的信息，否则导航栏可能显示错误的串口名。
      _connectedPortName = null;
      _connectedBaudRate = null;
      _setConnectionStatus(SerialPortConnectionStatus.failed, error: e);

      // rethrow 会保留原始异常和堆栈，让 UI 层可以显示“连接失败”。
      rethrow;
    }
  }

  /// 开始接收数据
  void _startReading() {
    final port = _port;

    if (port == null) {
      return;
    }

    // 创建异步串口读取器。回调捕获本次会话的 port/reader，避免旧会话延迟到达的
    // error/done 事件误伤后来重新建立的连接。
    final reader = SerialPortReader(port);
    _reader = reader;

    _readerSubscription = reader.stream.listen(
      (data) {
        if (!identical(_port, port) || !identical(_reader, reader)) {
          return;
        }
        // 复制数据，避免底层读缓冲区被重复使用
        // 易错点：Stream 的一次 data 回调只是“当前读到的一块”，
        // 并不保证恰好是一个完整协议数据包。复杂协议需要另外做组包。
        _receivedBytesController.add(Uint8List.fromList(data));
      },
      onError: (Object error, StackTrace stackTrace) {
        _handleReaderFailure(port, reader, error, stackTrace);
      },
      onDone: () => _handleReaderDone(port, reader),
    );
  }

  /// SerialPortReader 的读取错误属于传输层故障，不是协议帧格式错误。
  ///
  /// libserialport 的读取循环在此类错误后已经退出；若仍保留 connected，业务层
  /// 会继续发送心跳和电机控制命令，却再也收不到反馈。因此这里必须结束整个连接。
  void _handleReaderFailure(
    SerialPort port,
    SerialPortReader reader,
    Object error,
    StackTrace stackTrace,
  ) {
    if (!identical(_port, port) || !identical(_reader, reader)) {
      return;
    }

    // 保留错误事件供协议/UI 层展示，但连接状态由 Service 在传输层直接处理。
    _receivedBytesController.addError(error, stackTrace);
    _disconnectAfterTransportFailure(port, error);
  }

  /// 主动 disconnect 会先清空 _reader，所以只有非预期结束才会进入故障处理。
  void _handleReaderDone(SerialPort port, SerialPortReader reader) {
    if (!identical(_port, port) || !identical(_reader, reader)) {
      return;
    }

    final error = StateError('串口接收流意外结束');
    _receivedBytesController.addError(error, StackTrace.current);
    _disconnectAfterTransportFailure(port, error);
  }

  void _disconnectAfterTransportFailure(SerialPort port, Object error) {
    if (!identical(_port, port)) {
      return;
    }

    debugPrint('串口传输已中断：$error');
    _stopReading();

    _port = null;
    _connectedPortName = null;
    _connectedBaudRate = null;

    try {
      if (port.isOpen) {
        port.close();
      }
    } catch (closeError) {
      debugPrint('传输故障后关闭串口失败：$closeError');
    }

    _releasePortObject(port);
    _setConnectionStatus(SerialPortConnectionStatus.disconnected, error: error);
  }

  /// 发送原始字节，HEX 模式最终会调用这里。
  int sendBytes(List<int> bytes) {
    if (!isConnected || _port == null) {
      throw StateError('串口没有连接');
    }

    final port = _port!;
    final data = Uint8List.fromList(bytes);

    if (data.isEmpty) {
      return 0;
    }

    // 不传 timeout，使用 libserialport 的非阻塞写。这个方法会在 Flutter UI
    // isolate 上被连接回调和协议定时器调用，阻塞写会让整个 Windows 窗口停止
    // 响应；而且部分串口驱动并不保证能严格遵守 libserialport 的写超时。
    //
    // 返回值是本次被系统发送缓冲区接受的字节数。短写由协议层从未写入的位置
    // 继续发送；返回 0 表示缓冲区暂时没有空间，不应被误判为串口已断开。
    try {
      final written = port.write(data);
      if (written < 0 || written > data.length) {
        final error = StateError('串口返回了非法写入长度：$written/${data.length}');
        _disconnectAfterTransportFailure(port, error);
        throw error;
      }
      return written;
    } on SerialPortError catch (error) {
      // 参数/协议类异常不在这里处理；只有底层串口 I/O 错误才判定传输中断。
      _disconnectAfterTransportFailure(port, error);
      rethrow;
    }
  }

  /// 发送字符串：先通过 UTF-8 转换成字节，再复用 sendBytes()。
  /// 注意：一个中文字符通常会编码成 3 个 UTF-8 字节。
  int sendText(String text) {
    return sendBytes(utf8.encode(text));
  }

  /// 停止串口接收
  void _stopReading() {
    // 先清空标记，让 cancel/close 触发的 onDone 被识别为主动停止。
    final subscription = _readerSubscription;
    final reader = _reader;
    _readerSubscription = null;
    _reader = null;

    // 先取消 Stream 监听，避免断开后回调仍继续访问旧串口。
    if (subscription != null) {
      unawaited(subscription.cancel());
    }

    // SerialPortReader 必须关闭
    reader?.close();
  }

  /// 断开串口
  void disconnect() {
    // 先停止接收
    _stopReading();

    final port = _port;

    // 先解除当前对象引用，使 UI 能立即读到“未连接”状态。
    _port = null;
    _connectedPortName = null;
    _connectedBaudRate = null;

    if (port == null) {
      // 即使本来就没有 SerialPort 对象，也要把失败等旧状态恢复为未连接。
      _setConnectionStatus(SerialPortConnectionStatus.disconnected);
      return;
    }

    try {
      if (port.isOpen) {
        port.close();
      }
    } catch (e) {
      debugPrint('关闭串口失败：$e');
    }

    _releasePortObject(port);

    // 资源关闭完成后通知导航栏显示灰色的“未连接”图标。
    _setConnectionStatus(SerialPortConnectionStatus.disconnected);
  }

  /// 释放 SerialPort 对象
  void _releasePortObject(SerialPort port) {
    // flutter_libserialport 在 Windows 下
    // dispose() 当前可能导致程序崩溃。
    //
    // 所以 Windows 暂时不要调用。
    if (Platform.isWindows) {
      return;
    }

    try {
      port.dispose();
    } catch (e) {
      debugPrint('释放串口失败：$e');
    }
  }

  /// 销毁整个 Service。
  /// 易错点：StreamController 关闭后不能再 add()，因此 dispose 后该对象不能复用。
  @override
  void dispose() {
    disconnect();
    _receivedBytesController.close();
    super.dispose();
  }
}
