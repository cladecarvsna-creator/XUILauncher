import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Short message for the status bar instead of raw exception text.
String friendlyError(Object e) {
  if (e is SocketException || e is http.ClientException || e is TimeoutException) {
    return 'Нет подключения к серверу. Проверьте интернет';
  }
  if (e is HttpException) return 'Сервер ответил ошибкой: ${e.message}';
  final text = e.toString();
  return text.startsWith('Exception: ') ? text.substring(11) : text;
}
