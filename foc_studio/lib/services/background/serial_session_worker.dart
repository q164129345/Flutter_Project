import 'dart:isolate';

import '../../protocol/pc_mcu/messages/control_messages.dart';
import 'foc_session.dart';
import 'serial_transport.dart';
import 'serial_worker_messages.dart';

/// 常驻串口 isolate 的入口：创建并持有整个串口会话。
///
/// 串口读取器把字节交给本 isolate 内的协议层；解包、消息处理、历史记录、
/// 统计和心跳都在后台执行。UI 页面是否显示，不会改变这条处理链路。
void serialSessionWorkerMain(SerialWorkerStart start) {
  // 在后台内部创建这些对象，避免把串口句柄、订阅或定时器传到 UI。
  final transport = SerialTransport();
  final session = FocSession(transport);
  // requests 接收 UI 发来的操作；start.events 用于把结果发回 UI。
  final requests = ReceivePort();
  // 只记录状态版本，不在每条消息到达时复制历史记录或通知页面。
  var revision = 0;
  session.addListener(() => revision++);

  // 连接/断开是低频事件，主动推送给 UI，使导航栏及时反映实际连接状态。
  // 携带统计值可展示新连接清零后的状态，或断开时保留的最后累计值。
  void publishConnection() {
    start.events.send(
      SerialConnectionSnapshot(
        status: transport.connectionStatus,
        portName: transport.connectedPortName,
        baudRate: transport.connectedBaudRate,
        error: transport.lastConnectionError?.toString(),
        statistics: transport.statistics.snapshot(),
      ),
    );
  }

  transport.addListener(publishConnection);
  // 把后台的收件地址交给 UI，完成启动握手，然后发送初始连接状态。
  start.events.send(requests.sendPort);
  publishConnection();

  // 这里只处理 UI 操作；持续接收与解包由 transport/session 自己的订阅驱动，
  // 即使没有任何快照请求，它们也会继续运行。
  requests.listen((dynamic event) {
    final request = event as SerialWorkerRequest;
    try {
      Object? result;
      switch (request.operation) {
        case SerialOperation.listPorts:
          result = transport.getAvailablePorts();
        case SerialOperation.connect:
          // 命名记录把端口名和波特率作为一组参数传递，双方按同一结构读取。
          final options = request.argument as ({String portName, int baudRate});
          transport.connect(
            portName: options.portName,
            baudRate: options.baudRate,
          );
        case SerialOperation.disconnect:
          transport.disconnect();
        case SerialOperation.statistics:
          // 读取已经由后台累计/采样的数值，取快照本身不会清零或重新计数。
          result = transport.statistics.snapshot();
        case SerialOperation.focSnapshot:
          // UI 传来上次看到的版本；版本相同就不生成包含历史列表的新快照。
          result = FocSnapshotResponse(
            revision,
            request.argument == revision ? null : session.snapshot(),
          );
        case SerialOperation.setMotorControl:
          final command = request.argument as MotorControlCommand;
          result = session.setMotorControl(
            enabled: command.enabled,
            targetSpeedRpm: command.targetSpeedRpm,
          );
        case SerialOperation.querySoftwareVersion:
          result = session.querySoftwareVersion();
        case SerialOperation.queryMotorType:
          result = session.queryMotorType();
        case SerialOperation.queryTuneParameters:
          result = session.queryTuneParameters();
        case SerialOperation.writeTuneParameters:
          // 三组参数一起交给会话，统一按“写入参数，再发送读回查询”的顺序排队。
          final parameters =
              request.argument
                  as ({
                    PidParameters speedLoop,
                    CurrentLoopParameters currentLoop,
                    MotorLimits motorLimits,
                  });
          result = session.writeTuneParameters(
            speedLoop: parameters.speedLoop,
            currentLoop: parameters.currentLoop,
            motorLimits: parameters.motorLimits,
          );
        case SerialOperation.queryDipSwitchId:
          result = session.queryDipSwitchId();
        case SerialOperation.queryExternalFlashId:
          result = session.queryExternalFlashId();
        case SerialOperation.rebootMcu:
          result = session.rebootMcu();
        case SerialOperation.clearProtocolError:
          session.clearProtocolError();
        case SerialOperation.shutdown:
          // 先停业务订阅/定时器，再释放串口；退出时附带回复，结束 UI 的等待。
          transport.removeListener(publishConnection);
          session.dispose();
          transport.dispose();
          requests.close();
          Isolate.exit(start.events, SerialWorkerResponse(request.id));
      }
      // 原样带回请求编号，UI 才能把回复交给正确的 await 调用者。
      start.events.send(SerialWorkerResponse(request.id, value: result));
    } catch (error) {
      // 单次操作失败只回复该请求；未捕获的后台异常另由 Isolate.onError 上报。
      // 转为字符串可避免把异常内部可能包含的本地资源跨 isolate 传递。
      start.events.send(
        SerialWorkerResponse(request.id, error: error.toString()),
      );
    }
  });
}
