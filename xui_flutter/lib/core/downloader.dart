import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class DownloadTask {
  DownloadTask(this.url, this.path, {this.sha1, this.size, this.executable = false});

  final String url;
  final String path;
  final String? sha1;
  final int? size;
  final bool executable;
}

typedef ProgressCallback = void Function(int done, int total);

/// Parallel file downloader with SHA-1 verification and retries.
class Downloader {
  Downloader({http.Client? client, this.concurrency = 12})
      : client = client ?? http.Client();

  final http.Client client;
  final int concurrency;

  static const userAgent = 'XUILauncher/1.0';

  Future<String> getString(String url) async {
    final res = await client.get(Uri.parse(url), headers: {'User-Agent': userAgent});
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode} for $url');
    }
    return res.body;
  }

  /// Skips files that already exist with the expected size.
  static Future<bool> isUpToDate(DownloadTask t) async {
    final f = File(t.path);
    if (!await f.exists()) return false;
    if (t.size != null) return await f.length() == t.size;
    return true;
  }

  Future<void> downloadAll(
    List<DownloadTask> tasks, {
    ProgressCallback? onProgress,
  }) async {
    final pending = <DownloadTask>[];
    for (final t in tasks) {
      if (!await isUpToDate(t)) pending.add(t);
    }
    var done = 0;
    final total = pending.length;
    onProgress?.call(0, total);
    if (total == 0) return;

    var index = 0;
    Object? failure;
    Future<void> worker() async {
      while (failure == null && index < pending.length) {
        final t = pending[index++];
        try {
          await download(t);
        } catch (e) {
          failure ??= e;
          return;
        }
        done++;
        onProgress?.call(done, total);
      }
    }

    await Future.wait(List.generate(concurrency, (_) => worker()));
    if (failure != null) throw failure!;
  }

  Future<void> download(DownloadTask t, {int attempts = 3}) async {
    for (var attempt = 1;; attempt++) {
      try {
        await _downloadOnce(t);
        return;
      } catch (e) {
        if (attempt >= attempts) {
          throw Exception('Не удалось скачать ${t.url}: $e');
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
  }

  Future<void> _downloadOnce(DownloadTask t) async {
    await Directory(p.dirname(t.path)).create(recursive: true);
    final tmp = File('${t.path}.part');
    final req = http.Request('GET', Uri.parse(t.url))
      ..headers['User-Agent'] = userAgent;
    final res = await client.send(req);
    if (res.statusCode != 200) {
      await res.stream.drain<void>();
      throw HttpException('HTTP ${res.statusCode}');
    }
    final sink = tmp.openWrite();
    final digestSink = _DigestSink();
    final hasher = sha1.startChunkedConversion(digestSink);
    await for (final chunk in res.stream) {
      sink.add(chunk);
      hasher.add(chunk);
    }
    hasher.close();
    await sink.close();
    if (t.sha1 != null && digestSink.value.toString() != t.sha1!.toLowerCase()) {
      await tmp.delete();
      throw const FormatException('SHA-1 mismatch');
    }
    await tmp.rename(t.path);
    if (t.executable && !Platform.isWindows) {
      await Process.run('chmod', ['+x', t.path]);
    }
  }
}

class _DigestSink implements Sink<Digest> {
  late Digest value;

  @override
  void add(Digest data) => value = data;

  @override
  void close() {}
}
