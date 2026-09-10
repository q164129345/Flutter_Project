import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';

import '../../services/background/serial_transport.dart';
import 'frame_decoder.dart';
import 'message_codec.dart';
import 'messages/control_messages.dart';
import 'messages/mcu_message.dart';

/// 后台协议客户端：连接原始字节传输、帧解包器与业务消息编解码器。
///
/// 它是后台原始字节流的解包入口，完整消息交给 FocSession 更新状态和历史。
/// UI 不直接订阅这里的逐帧消息，只通过代理获取后台整理好的显示快照。
class PcMcuProtocolClient {
  PcMcuProtocolClient(
    this._serialService, {
    ProtocolFrameDecoder? frameDecoder,
    PcMcuMessageCodec? messageCodec,
  }) : frameDecoder = frameDecoder ?? ProtocolFrameDecoder(),
       messageCodec = messageCodec ?? const PcMcuMessageCodec() {
    _wasConnected = _serialService.isConnected;
    _serialService.addListener(_handleConnectionChanged);
    _serialSubscription = _serialService.receivedBytesStream.listen(
      _handleChunk,
      onError: _handleSerialError,
    );
  }

  final SerialTransport _serialService;
  // 同一个解包器跟随整次连接，才能把多次接收中的半帧接起来。
  final ProtocolFrameDecoder frameDecoder;
  final PcMcuMessageCodec messageCodec;
  final StreamController<McuMessage> _messageController =
      StreamController<McuMessage>.broadcast();

  late final StreamSubscription<Uint8List> _serialSubscription;
  late bool _wasConnected;
  bool _isDisposed = false;
  // 保持整帧发送顺序：上一帧未写完时，下一帧不能插到它的中间。
  final Queue<Uint8List> _outgoing = Queue();
  Timer? _writeTimer;
  // 当前队首帧已经写入多少字节；系统短写时从这个位置继续。
  int _writeOffset = 0;
  // 队列中尚未交给系统的总字节数，用于限制积压内存。
  int _queuedBytes = 0;

  Stream<McuMessage> get messages => _messageController.stream;
  int get frameDecodeFailureCount => frameDecoder.decodeFailureCount;

  int sendMotorControl(MotorControlCommand command) =>
      _sendFrame(messageCodec.encodeMotorControl(command));

  int sendHeartbeat() => _sendFrame(messageCodec.encodeHeartbeat());

  int querySoftwareVersion() =>
      _sendFrame(messageCodec.encodeQuerySoftwareVersion());

  int queryMotorType() => _sendFrame(messageCodec.encodeQueryMotorType());

  int querySpeedLoopParameters() =>
      _sendFrame(messageCodec.encodeQuerySpeedLoopParameters());

  int queryCurrentLoopParameters() =>
      _sendFrame(messageCodec.encodeQueryCurrentLoopParameters());

  int setSpeedLoopParameters(PidParameters parameters) =>
      _sendFrame(messageCodec.encodeSetSpeedLoopParameters(parameters));

  int setCurrentLoopParameters(CurrentLoopParameters parameters) =>
      _sendFrame(messageCodec.encodeSetCurrentLoopParameters(parameters));

  int rebootMcu() => _sendFrame(messageCodec.encodeRebootMcu());

  int queryMotorLimits() => _sendFrame(messageCodec.encodeQueryMotorLimits());

  int setMotorLimits(MotorLimits limits) =>
      _sendFrame(messageCodec.encodeSetMotorLimits(limits));

  int queryDipSwitchId() => _sendFrame(messageCodec.encodeQueryDipSwitchId());

  int queryExternalFlashId() =>
      _sendFrame(messageCodec.encodeQueryExternalFlashId());

  /// 在串口 isolate 内处理任意字节块，补齐的每一帧都进入消息解码和统计。
  void _handleChunk(Uint8List chunk) {
    if (_isDisposed || !_serialService.isConnected) {
      return;
    }

    final statistics = _serialService.statistics;
    // 解包器内部保存累计错误数；取本轮差值，防止把旧错误重复加入会话统计。
    final previousFailures = frameDecoder.decodeFailureCount;
    final previousCrcErrors = frameDecoder.crcErrorCount;
    final frames = frameDecoder.addChunk(chunk);
    statistics.recordInvalidFrames(
      count: frameDecoder.decodeFailureCount - previousFailures,
      crcErrors: frameDecoder.crcErrorCount - previousCrcErrors,
    );

    for (final frame in frames) {
      try {
        final message = messageCodec.decode(frame);
        // 帧校验和业务内容解码都成功后，才计入有效接收帧数。
        statistics.recordReceivedFrame();
        _messageController.add(message);
      } catch (error, stackTrace) {
        statistics.recordInvalidFrames(count: 1);
        _messageController.addError(error, stackTrace);
      }
    }
  }

  void _handleSerialError(Object error, StackTrace stackTrace) {
    if (!_isDisposed) {
      _messageController.addError(error, stackTrace);
    }
  }

  void _handleConnectionChanged() {
    final isConnected = _serialService.isConnected;
    if (isConnected != _wasConnected) {
      // 断开时立即清掉旧半帧和旧发送队列，避免重连后混入上一次会话的数据。
      // 不等新读取器启动后再清理，以免误删新连接刚收到的首段数据。
      if (!isConnected) {
        frameDecoder.reset();
        _clearWrites();
      }
      _wasConnected = isConnected;
    }
  }

  /// 完整帧先进入有序队列，实际写入由后台事件循环稍后执行。
  int _sendFrame(Uint8List frame) {
    if (_isDisposed || !_serialService.isConnected) {
      throw StateError('串口没有连接');
    }
    // 驱动持续无法接收数据时拒绝继续积压，避免待发送内容无限占用内存。
    if (_queuedBytes + frame.length > 64 * 1024) {
      throw StateError('串口发送队列已满');
    }
    _outgoing.addLast(frame);
    _queuedBytes += frame.length;
    _scheduleWrite(Duration.zero);
    // 返回值表示已经入队的长度；实际发送字节数/帧数在真正写入时再统计。
    return frame.length;
  }

  // ??= 确保同一时刻只有一个待执行的发送定时器，多个命令可以共用它。
  void _scheduleWrite(Duration delay) {
    _writeTimer ??= Timer(delay, _drainWrites);
  }

  /// 尽量写出队首帧，遇到暂时写不进去或达到本轮预算时让出执行机会。
  void _drainWrites() {
    _writeTimer = null;
    if (_isDisposed || !_serialService.isConnected) return;
    // 即使有大量命令排队，也要让后台有机会处理接收事件和心跳定时器。
    var budget = 4096;
    try {
      while (_outgoing.isNotEmpty && budget > 0) {
        final frame = _outgoing.first;
        // sublistView 只创建剩余部分的视图，重试时不复制整帧。
        final remaining = Uint8List.sublistView(frame, _writeOffset);
        final written = _serialService.sendBytes(remaining);
        if (written == 0) {
          // 非阻塞写返回 0 通常表示系统发送缓冲区暂满，不是帧无效。
          // 保留帧与偏移，5 ms 后再试；不在 while 中空转等待，也不丢弃帧尾。
          _scheduleWrite(const Duration(milliseconds: 5));
          return;
        }
        if (written < 0 || written > remaining.length) {
          throw StateError('Serial write returned invalid length: $written');
        }
        _writeOffset += written;
        _queuedBytes -= written;
        budget -= written;
        if (_writeOffset == frame.length) {
          // 整帧都已被系统接受才弹出队列并计一帧，短写重试不会重复计数。
          _outgoing.removeFirst();
          _writeOffset = 0;
          _serialService.statistics.recordSentFrame();
        }
      }
      if (_outgoing.isNotEmpty) _scheduleWrite(Duration.zero);
    } catch (error, stackTrace) {
      _clearWrites();
      _messageController.addError(error, stackTrace);
    }
  }

  /// 断开、写入失败或销毁时统一停止重试，旧命令不能带到下一次连接。
  void _clearWrites() {
    _writeTimer?.cancel();
    _writeTimer = null;
    _outgoing.clear();
    _writeOffset = 0;
    _queuedBytes = 0;
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _clearWrites();
    _serialService.removeListener(_handleConnectionChanged);
    unawaited(_serialSubscription.cancel());
    unawaited(_messageController.close());
  }
}
