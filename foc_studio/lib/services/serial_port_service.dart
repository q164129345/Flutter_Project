import 'dart:async';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../controllers/foc_snapshot.dart';
import 'background/serial_session_worker.dart';
import 'background/serial_worker_messages.dart';
import 'serial_connection_status.dart';
import 'serial_port_statistics.dart';
import 'serial_statistics_snapshot.dart';

export 'serial_connection_status.dart';

/// UI 侧的串口代理：把页面操作发给后台，并保存后台返回的显示数据。
///
/// isolate 是独立的 Dart 执行环境。这个对象运行在 UI isolate 中；
/// 真正的串口读写、解包、统计和心跳运行在 serial-session isolate 中。
/// UI 只接收连接状态和按需请求的快照，不接收原始串口字节。
class SerialPortService extends ChangeNotifier {
  SerialPortService() {
    // 统计面板开始/停止监听时，同步开始/停止向后台请求显示数据。
    statistics = SerialPortStatistics(onListeningChanged: _observeStatistics);
    // 即使页面尚未发起请求，启动失败也不会产生无人处理的 Future 错误。
    // 之后通过 _request 等待 _ready 的调用者仍会收到这个错误。
    _ready.future.ignore();
    _events.listen(_handleEvent);
    // 构造函数立即返回，后台准备过程不会阻塞页面创建。
    unawaited(_start());
  }

  // 这两个间隔只限制 UI 取快照的频率，不限制后台解包的频率。
  static const displayInterval = Duration(milliseconds: 50);
  static const statisticsInterval = Duration(seconds: 1);

  // 三条独立通知通道：统计面板、操作按钮、业务数据显示。
  // 连接状态则通过本 Service 的 notifyListeners 通知导航栏等组件。
  late final SerialPortStatistics statistics;
  final ValueNotifier<bool> busy = ValueNotifier(false);
  final ValueNotifier<FocSnapshot> focState = ValueNotifier(
    const FocSnapshot(),
  );
  // ReceivePort 像 UI 的“收件箱”；后台用它的 sendPort 把结果发回来。
  final ReceivePort _events = ReceivePort();
  // 后台启动后会返回自己的 SendPort，_ready 用来等待这次握手完成。
  final Completer<SendPort> _ready = Completer();
  // 请求编号 -> 等待结果的 Future。多个异步操作通过编号匹配各自的回复。
  final Map<int, Completer<Object?>> _pending = {};
  Isolate? _isolate;
  Object? _workerFailure;
  int _requestId = 0;
  // 使用计数而非单一开关，防止较早完成的操作提前解除其他操作的 busy 状态。
  int _busyCount = 0;
  // 有多少个控制器需要业务快照；全部退出监听后即可停止拉取。
  int _focObservers = 0;
  // 上次收到的后台状态版本；-1 表示下次必须获取完整快照。
  int _focRevision = -1;
  Timer? _statisticsTimer;
  Timer? _focTimer;
  // 同类快照最多允许一个请求等待回复，避免 UI 忙碌时积压重复请求。
  bool _statisticsPending = false;
  bool _focPending = false;
  // 分别表示“开始关闭”“通信资源已关闭”“Flutter 通知对象已释放”。
  // 拆开记录是为了正确处理后台尚未启动完成、UI 就已退出的情况。
  bool _closing = false;
  bool _closed = false;
  bool _disposed = false;
  Future<void>? _closeFuture;

  SerialPortConnectionStatus _connectionStatus =
      SerialPortConnectionStatus.disconnected;
  String? _connectedPortName;
  int? _connectedBaudRate;
  Object? _lastConnectionError;

  SerialPortConnectionStatus get connectionStatus => _connectionStatus;
  String? get connectedPortName => _connectedPortName;
  int? get connectedBaudRate => _connectedBaudRate;
  Object? get lastConnectionError => _lastConnectionError;
  bool get isConnected =>
      _connectionStatus == SerialPortConnectionStatus.connected;
  bool get isBusy => busy.value;

  /// 创建常驻后台会话；切换 NavigationRail 页面不会重新创建它。
  Future<void> _start() async {
    try {
      final isolate = await Isolate.spawn(
        serialSessionWorkerMain,
        SerialWorkerStart(_events.sendPort),
        debugName: 'serial-session',
        // 把后台未捕获异常和意外退出也送进同一个收件箱，避免界面假装仍在线。
        onError: _events.sendPort,
        onExit: _events.sendPort,
        errorsAreFatal: true,
      );
      _isolate = isolate;
      // await 期间可能已经发生关闭或失败，不能留下刚启动的孤立后台任务。
      if (_workerFailure != null || _closed) {
        isolate.kill(priority: Isolate.immediate);
      }
    } catch (error) {
      _fail(error);
    }
  }

  /// 分发后台消息：启动握手、操作回复、连接变化，以及 isolate 异常/退出。
  void _handleEvent(dynamic event) {
    if (event is SendPort) {
      if (!_ready.isCompleted) _ready.complete(event);
    } else if (event is SerialWorkerResponse) {
      // 完成对应的 Future，让页面里 await connect() 等调用继续往下执行。
      final pending = _pending.remove(event.id);
      if (event.error == null) {
        pending?.complete(event.value);
      } else {
        pending?.completeError(StateError(event.error!));
      }
    } else if (event is SerialConnectionSnapshot && !_closing) {
      _connectionStatus = event.status;
      _connectedPortName = event.portName;
      _connectedBaudRate = event.baudRate;
      _lastConnectionError = event.error;
      statistics.update(event.statistics);
      // 连接边界使旧业务快照失效；断开时立即清掉旧电机状态。
      _focRevision = -1;
      if (!isConnected) focState.value = const FocSnapshot();
      notifyListeners();
      if (_focObservers > 0) unawaited(_pollFoc());
    } else if (!_closing && (event == null || event is List)) {
      // Isolate 的 onExit 默认发送 null，onError 发送错误与堆栈组成的列表。
      _fail(
        StateError(event == null ? '串口后台任务意外退出' : '串口后台任务失败：${event.first}'),
      );
    }
  }

  /// 后台已不可用：结束所有等待、停止轮询，并明确通知 UI 连接失败。
  void _fail(Object error) {
    if (_workerFailure != null) return;
    _workerFailure = error;
    if (!_ready.isCompleted) _ready.completeError(error);
    // 不能只更新错误文字，否则原本 await 后台回复的操作会一直等下去。
    for (final request in _pending.values) {
      request.completeError(error);
    }
    _pending.clear();
    _statisticsTimer?.cancel();
    _focTimer?.cancel();
    _isolate?.kill(priority: Isolate.immediate);
    if (_closing || _disposed) return;
    _connectionStatus = SerialPortConnectionStatus.failed;
    _lastConnectionError = error;
    _connectedPortName = null;
    _connectedBaudRate = null;
    // 保留最近已收到的累计数；速率使用快照默认值 0，表示不再收发。
    statistics.update(
      SerialStatisticsSnapshot(
        sentFrameCount: statistics.sentFrameCount,
        sentByteCount: statistics.sentByteCount,
        receivedFrameCount: statistics.receivedFrameCount,
        receivedByteCount: statistics.receivedByteCount,
        crcErrorCount: statistics.crcErrorCount,
        invalidFrameCount: statistics.invalidFrameCount,
      ),
    );
    focState.value = const FocSnapshot();
    notifyListeners();
  }

  /// 统一的跨 isolate 请求入口；await 只挂起当前操作，不占住 UI 执行时间。
  Future<Object?> _request(
    SerialOperation operation, [
    Object? argument,
  ]) async {
    if (_workerFailure != null) throw _workerFailure!;
    if (_closing && operation != SerialOperation.shutdown) {
      throw StateError('串口服务已关闭');
    }
    final port = await _ready.future;
    // 等待启动期间也可能发生关闭，因此握手完成后需要再次检查状态。
    if (_workerFailure != null) throw _workerFailure!;
    if (_closing && operation != SerialOperation.shutdown) {
      throw StateError('串口服务已关闭');
    }
    final id = ++_requestId;
    final result = Completer<Object?>();
    // 先登记等待者，再发请求，保证极快返回的回复也能找到对应 Future。
    _pending[id] = result;
    port.send(SerialWorkerRequest(id, operation, argument));
    return result.future;
  }

  /// 为扫描/连接/断开统一维护忙碌状态，供设置页暂时禁用相关按钮。
  Future<T> _withBusy<T>(Future<T> Function() operation) async {
    if (_closing) throw StateError('串口服务已关闭');
    _busyCount++;
    busy.value = true;
    try {
      return await operation();
    } finally {
      _busyCount--;
      if (!_disposed) busy.value = _busyCount > 0;
    }
  }

  /// 枚举串口也交给后台，避免驱动响应慢时卡住页面。
  Future<List<String>> getAvailablePorts() => _withBusy(
    () async => (await _request(SerialOperation.listPorts))! as List<String>,
  );

  /// 等后台完成打开和配置后返回；括号里的命名记录用于传递连接参数。
  Future<void> connect({required String portName, required int baudRate}) =>
      _withBusy(() async {
        await _request(SerialOperation.connect, (
          portName: portName,
          baudRate: baudRate,
        ));
      });

  /// 主动断开当前连接，后台同时停止本次会话的心跳和周期控制。
  Future<void> disconnect() => _withBusy(() async {
    await _request(SerialOperation.disconnect);
  });

  /// 转交业务操作。发送类操作返回 true 表示后台已接收并排队，非 MCU 应答。
  Future<bool> sendCommand(
    SerialOperation operation, [
    Object? argument,
  ]) async => (await _request(operation, argument)) as bool? ?? true;

  /// 面板出现时立即取一次累计值，然后每秒更新；面板消失只停止取快照。
  /// 后台的字节计数、帧计数和速率采样始终按会话状态独立执行。
  void _observeStatistics(bool visible) {
    _statisticsTimer?.cancel();
    _statisticsTimer = null;
    if (!visible || _closing || _workerFailure != null) return;
    unawaited(_pollStatistics());
    _statisticsTimer = Timer.periodic(
      statisticsInterval,
      (_) => unawaited(_pollStatistics()),
    );
  }

  /// 获取统计显示值；如果等待期间面板已经卸载，就不再应用这次回复。
  Future<void> _pollStatistics() async {
    if (_statisticsPending || _closing) return;
    _statisticsPending = true;
    try {
      final snapshot =
          await _request(SerialOperation.statistics)
              as SerialStatisticsSnapshot;
      if (!_closing && statistics.hasListeners) statistics.update(snapshot);
    } catch (error) {
      if (!_closing) _fail(error);
    } finally {
      _statisticsPending = false;
    }
  }

  /// 第一个业务监听者出现时启动取快照，其余监听者复用同一个定时器。
  void retainFocSnapshots() {
    if (_closing || _workerFailure != null) return;
    if (++_focObservers != 1) return;
    unawaited(_pollFoc());
    _focTimer = Timer.periodic(displayInterval, (_) => unawaited(_pollFoc()));
  }

  /// 最后一个业务监听者离开时停止显示轮询，保留后台会话及其历史数据。
  void releaseFocSnapshots() {
    if (_focObservers > 0) _focObservers--;
    if (_focObservers == 0) {
      _focTimer?.cancel();
      _focTimer = null;
    }
  }

  /// 携带已知版本请求业务快照；后台状态没变时返回 null，省去复制和重建。
  Future<void> _pollFoc() async {
    if (_focPending || _closing) return;
    _focPending = true;
    try {
      final response =
          await _request(SerialOperation.focSnapshot, _focRevision)
              as FocSnapshotResponse;
      if (!_closing && _focObservers > 0 && response.snapshot != null) {
        _focRevision = response.revision;
        focState.value = response.snapshot!;
      }
    } catch (error) {
      if (!_closing) _fail(error);
    } finally {
      _focPending = false;
    }
  }

  /// 需要等待后台清理完成时可 await close()；重复调用复用同一个关闭过程。
  Future<void> close() => _closeFuture ??= _close();

  /// 先让后台正常释放串口；若任务已失败或迟迟不回复，再请求终止 isolate。
  Future<void> _close() async {
    _closing = true;
    _statisticsTimer?.cancel();
    _focTimer?.cancel();
    try {
      await _request(
        SerialOperation.shutdown,
      ).timeout(const Duration(seconds: 2));
    } catch (_) {
      // 关闭失败或超时仍进入 finally，避免遗留消息端口和等待中的请求。
    } finally {
      _closed = true;
      _isolate?.kill(priority: Isolate.immediate);
      _events.close();
      final error = StateError('串口服务已关闭');
      if (!_ready.isCompleted) _ready.completeError(error);
      for (final pending in _pending.values) {
        pending.completeError(error);
      }
      _pending.clear();
    }
  }

  /// Flutter 的 dispose 不能等待异步操作，因此启动关闭后立即释放 UI 通知对象。
  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(close());
    statistics.dispose();
    focState.dispose();
    busy.dispose();
    super.dispose();
  }
}
