import 'dart:isolate';

import '../../controllers/foc_snapshot.dart';
import '../serial_connection_status.dart';
import '../serial_statistics_snapshot.dart';

/// UI 与后台之间约定的操作类型，避免使用容易拼错的字符串指令。
/// 其中 statistics/focSnapshot 只获取显示值，其他操作管理连接或发送业务命令。
enum SerialOperation {
  listPorts,
  connect,
  disconnect,
  statistics,
  focSnapshot,
  setMotorControl,
  querySoftwareVersion,
  queryMotorType,
  queryTuneParameters,
  writeTuneParameters,
  queryDipSwitchId,
  queryExternalFlashId,
  rebootMcu,
  clearProtocolError,
  shutdown,
}

/// 启动参数：告诉后台应该往哪个 SendPort 发送握手、操作回复及连接事件。
class SerialWorkerStart {
  const SerialWorkerStart(this.events);
  final SendPort events;
}

/// UI -> 后台的请求信封。id 在当前代理内递增，用来区分同时等待的操作。
class SerialWorkerRequest {
  const SerialWorkerRequest(this.id, this.operation, [this.argument]);
  final int id;
  final SerialOperation operation;
  // 参数类型随 operation 改变：例如连接用命名记录，电机控制用命令对象。
  // 此处只传可跨 isolate 发送的数据，不传 Widget、串口句柄或定时器。
  final Object? argument;
}

/// 后台 -> UI 的操作回复。成功填 value，失败填 error，并保留原请求的 id。
class SerialWorkerResponse {
  const SerialWorkerResponse(this.id, {this.value, this.error});
  final int id;
  final Object? value;
  final String? error;
}

/// 后台主动推送的连接状态，让 UI 无需反复查询本地串口句柄。
/// statistics 记录这次连接变化时的累计值，供开始会话或断开时更新显示。
class SerialConnectionSnapshot {
  const SerialConnectionSnapshot({
    required this.status,
    this.portName,
    this.baudRate,
    this.error,
    this.statistics = const SerialStatisticsSnapshot(),
  });
  final SerialPortConnectionStatus status;
  final String? portName;
  final int? baudRate;
  final String? error;
  final SerialStatisticsSnapshot statistics;
}

/// 按需返回业务状态。snapshot 为 null 表示版本没变，UI 保留现有显示即可。
class FocSnapshotResponse {
  const FocSnapshotResponse(this.revision, this.snapshot);
  final int revision;
  final FocSnapshot? snapshot;
}
