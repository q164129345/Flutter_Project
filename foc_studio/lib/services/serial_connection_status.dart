/// UI 与后台共用的连接状态，不包含任何本地串口资源。
/// disconnected：当前未连接；connected：已打开并配置成功；failed：连接/后台失败。
enum SerialPortConnectionStatus { disconnected, connected, failed }
