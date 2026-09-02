import 'dart:typed_data';

import '../commands.dart';

abstract class McuMessage {
  const McuMessage();

  PcMcuCommand? get command;
  int get commandId => command!.id;
}

/// Preserves valid frames with a command ID that this app does not yet know.
class UnknownMcuMessage extends McuMessage {
  UnknownMcuMessage({required this.commandId, required List<int> payload})
    : payload = Uint8List.fromList(payload);

  @override
  final int commandId;
  final Uint8List payload;

  @override
  PcMcuCommand? get command => null;
}
