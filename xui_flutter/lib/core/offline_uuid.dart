import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Same UUID the vanilla server assigns to an offline-mode player:
/// UUID v3 of `"OfflinePlayer:" + name`.
String offlineUuid(String nickname) {
  final bytes = md5.convert(utf8.encode('OfflinePlayer:$nickname')).bytes.toList();
  bytes[6] = (bytes[6] & 0x0f) | 0x30;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

String dashedUuid(String hex) =>
    '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-'
    '${hex.substring(16, 20)}-${hex.substring(20)}';
