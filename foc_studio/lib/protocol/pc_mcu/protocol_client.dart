import 'dart:async';
import 'dart:typed_data';

import '../../services/serial_port_service.dart';
import 'frame_decoder.dart';
import 'message_codec.dart';
import 'messages/control_messages.dart';
import 'messages/mcu_message.dart';

/// Binds the serial byte transport to the PC-MCU frame and message codecs.
///
/// This object is the only consumer that should parse [receivedBytesStream].
/// Pages consume [messages] or state exposed by a higher-level controller.
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

  final SerialPortService _serialService;
  final ProtocolFrameDecoder frameDecoder;
  final PcMcuMessageCodec messageCodec;
  final StreamController<McuMessage> _messageController =
      StreamController<McuMessage>.broadcast();

  late final StreamSubscription<Uint8List> _serialSubscription;
  late bool _wasConnected;
  bool _isDisposed = false;

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

  void _handleChunk(Uint8List chunk) {
    if (_isDisposed) {
      return;
    }

    for (final frame in frameDecoder.addChunk(chunk)) {
      try {
        _messageController.add(messageCodec.decode(frame));
      } catch (error, stackTrace) {
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
      // Bytes left from a previous connection must never be combined with a
      // frame from a new MCU session. Clear them as soon as that session
      // disconnects; resetting only after a new reader starts could discard
      // the first partial frame of the new session.
      if (!isConnected) {
        frameDecoder.reset();
      }
      _wasConnected = isConnected;
    }
  }

  int _sendFrame(Uint8List frame) {
    var totalWritten = 0;
    while (totalWritten < frame.length) {
      final remaining = Uint8List.sublistView(frame, totalWritten);
      final written = _serialService.sendBytes(remaining);
      if (written <= 0 || written > remaining.length) {
        throw StateError(
          'Serial write made invalid progress: wrote $written of '
          '${remaining.length} remaining bytes',
        );
      }
      totalWritten += written;
    }
    return totalWritten;
  }

  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    _serialService.removeListener(_handleConnectionChanged);
    unawaited(_serialSubscription.cancel());
    unawaited(_messageController.close());
  }
}
