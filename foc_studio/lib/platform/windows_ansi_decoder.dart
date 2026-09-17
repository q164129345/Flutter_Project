import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

typedef _MultiByteToWideCharNative =
    Int32 Function(
      Uint32 codePage,
      Uint32 flags,
      Pointer<Uint8> multiByteString,
      Int32 multiByteLength,
      Pointer<Uint16> wideString,
      Int32 wideLength,
    );

typedef _MultiByteToWideCharDart =
    int Function(
      int codePage,
      int flags,
      Pointer<Uint8> multiByteString,
      int multiByteLength,
      Pointer<Uint16> wideString,
      int wideLength,
    );

/// 将 libserialport 回退为 Latin-1 的 Windows 端口描述还原为系统 ANSI 文本。
///
/// libserialport 将端口描述按 UTF-8 读取；Windows 驱动若返回本地 ANSI 字节，
/// 它会回退为 Latin-1。Latin-1 的码位恰好保留原始字节，因此可交给 Windows
/// 的 CP_ACP 转为 Unicode。含有非 Latin-1 字符的文本已正确解码，保持不变。
class WindowsAnsiDecoder {
  WindowsAnsiDecoder._();

  static const _cpAcp = 0;

  static final _multiByteToWideChar = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<_MultiByteToWideCharNative, _MultiByteToWideCharDart>(
        'MultiByteToWideChar',
      );

  static String decodeIfSingleByte(String value) {
    if (value.runes.any((rune) => rune > 0xFF)) return value;

    final bytes = latin1.encode(value);
    if (bytes.isEmpty) return value;
    final source = calloc<Uint8>(bytes.length);
    Pointer<Uint16>? destination;
    try {
      source.asTypedList(bytes.length).setAll(0, bytes);
      final outputLength = _multiByteToWideChar(
        _cpAcp,
        0,
        source,
        bytes.length,
        nullptr,
        0,
      );
      if (outputLength == 0) return value;

      destination = calloc<Uint16>(outputLength);
      final written = _multiByteToWideChar(
        _cpAcp,
        0,
        source,
        bytes.length,
        destination,
        outputLength,
      );
      return written == 0
          ? value
          : String.fromCharCodes(destination.asTypedList(written));
    } finally {
      calloc.free(source);
      if (destination != null) calloc.free(destination);
    }
  }
}
