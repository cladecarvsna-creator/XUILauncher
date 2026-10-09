import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// A mod as listed on minecraft-inside.ru.
class ModEntry {
  ModEntry({
    required this.id,
    required this.title,
    required this.url,
    this.description = '',
    this.author = '',
    this.iconUrl,
    this.versions = const [],
  });

  final String id;
  final String title;

  /// Mod page, e.g. https://minecraft-inside.ru/mods/196602-tnt-expansion.html
  final String url;
  final String description;
  final String author;
  final String? iconUrl;

  /// Minecraft versions from the "[1.21.1] [1.20.1]" tags of the title.
  final List<String> versions;
}

/// One downloadable file from a mod page ("Для 1.21.1 fabric").
class ModFile {
  ModFile({required this.url, required this.mcVersion, required this.loader});

  final String url;
  final String mcVersion;
  final String loader;
}

/// Mod catalog backed by minecraft-inside.ru, which works from Russia
/// (unlike Modrinth). The site has no API, so its HTML is parsed.
class MinecraftInside {
  MinecraftInside(this.client);

  final http.Client client;

  static const base = 'https://minecraft-inside.ru';
  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36 XUILauncher/1.0',
    'Accept-Language': 'ru-RU,ru;q=0.9',
    'Referer': '$base/',
  };

  Future<String> _get(String url) async {
    final res = await client.get(Uri.parse(url), headers: _headers);
    if (res.statusCode != 200) {
      throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
    }
    return utf8.decode(res.bodyBytes, allowMalformed: true);
  }

  /// Newest mods for a Minecraft version, one site page (about 20 mods).
  Future<List<ModEntry>> browse({String? mcVersion, int page = 1}) async {
    final path = mcVersion == null ? '/mods/' : '/mods/$mcVersion/';
    final url = page <= 1 ? '$base$path' : '$base${path}page/$page/';
    return parseListing(await _get(url));
  }

  /// Mods whose title matches [query]. The site's own search is closed to
  /// robots, so this scans the newest listing pages for the version.
  Future<List<ModEntry>> search(
    String query, {
    String? mcVersion,
    int pages = 6,
  }) async {
    final q = query.toLowerCase().trim();
    final pageResults = await Future.wait([
      for (var i = 1; i <= pages; i++)
        browse(mcVersion: mcVersion, page: i).catchError((_) => <ModEntry>[]),
    ]);
    final seen = <String>{};
    return [
      for (final list in pageResults)
        for (final m in list)
          if (seen.add(m.id) &&
              (m.title.toLowerCase().contains(q) ||
                  m.description.toLowerCase().contains(q)))
            m,
    ];
  }

  /// Files listed on a mod page.
  Future<List<ModFile>> files(ModEntry mod) async =>
      parseFiles(await _get(mod.url));

  /// Picks the file for a build: exact Minecraft version and loader.
  static ModFile? pick(List<ModFile> files, String mcVersion, String loader) {
    for (final f in files) {
      if (f.mcVersion == mcVersion && f.loader == loader) return f;
    }
    return null;
  }

  /// Downloads [file] into [dir] and returns the saved path. Download links
  /// may redirect to the file or lead to a page that links to it.
  Future<String> download(ModFile file, String dir, {String? fallbackName}) async {
    var url = file.url;
    for (var hop = 0; hop < 3; hop++) {
      final req = http.Request('GET', Uri.parse(url))..headers.addAll(_headers);
      final res = await client.send(req);
      if (res.statusCode != 200) {
        await res.stream.drain<void>();
        throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
      }
      final type = res.headers['content-type'] ?? '';
      if (type.contains('text/html')) {
        final html = await res.stream.bytesToString();
        final next = _fileLinkInPage(html);
        if (next == null) {
          throw const FormatException('На странице скачивания нет ссылки на файл');
        }
        url = next;
        continue;
      }
      final name = _fileName(res.headers['content-disposition'],
              res.request?.url ?? Uri.parse(url)) ??
          fallbackName ??
          'mod-${DateTime.now().millisecondsSinceEpoch}.jar';
      await Directory(dir).create(recursive: true);
      final out = File(p.join(dir, name));
      final sink = out.openWrite();
      await res.stream.pipe(sink);
      return out.path;
    }
    throw const FormatException('Слишком много переходов при скачивании');
  }

  // ---------------------------------------------------------------------------
  // HTML parsing
  // ---------------------------------------------------------------------------

  static final _modLink = RegExp(
    r'''href=["'](?:https?://minecraft-inside\.ru)?(/mods/(\d+)-[^"'#?]+\.html)["'][^>]*>(.*?)</a>''',
    dotAll: true,
    caseSensitive: false,
  );
  static final _image = RegExp(
    r'''(?:src|data-src)=["']((?:https?://minecraft-inside\.ru)?/uploads/[^"']+\.(?:png|jpe?g|webp|gif))["']''',
    caseSensitive: false,
  );
  static final _author = RegExp(
    r'''href=["'](?:https?://minecraft-inside\.ru)?/(?:creator|user)/([^"'/]+)/?["']''',
    caseSensitive: false,
  );
  static final _paragraph = RegExp(r'<p[^>]*>(.*?)</p>', dotAll: true, caseSensitive: false);
  static final _versionTag = RegExp(r'\[([0-9][0-9.]*)\]');
  static final _download = RegExp(
    r'''href=["']((?:https?://minecraft-inside\.ru)?/download/\d+/?)["'][^>]*>(.*?)</a>''',
    dotAll: true,
    caseSensitive: false,
  );
  static final _fileLabel = RegExp(
    r'Для\s+([0-9][0-9.]*)\s+(fabric|forge|neoforge|quilt)',
    caseSensitive: false,
  );

  static String _abs(String url) => url.startsWith('http') ? url : '$base$url';

  static String _text(String html) => _unescape(html
      .replaceAll(RegExp(r'<[^>]+>'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim());

  static String _unescape(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&laquo;', '«')
      .replaceAll('&raquo;', '»')
      .replaceAll('&mdash;', '—');

  /// Listing page: each mod is a block that starts at the first link to its
  /// page and ends where the next mod's block starts.
  static List<ModEntry> parseListing(String html) {
    final starts = <String, int>{};
    final titles = <String, String>{};
    final paths = <String, String>{};
    for (final m in _modLink.allMatches(html)) {
      final id = m[2]!;
      starts.putIfAbsent(id, () => m.start);
      paths[id] = m[1]!;
      final text = _text(m[3]!);
      // The title link carries the "[1.21.1]" tags; other links are the
      // picture and "Подробнее".
      if (text.length > (titles[id]?.length ?? 0) && text != 'Подробнее') {
        titles[id] = text;
      }
    }
    final ids = starts.keys.toList()..sort((a, b) => starts[a]!.compareTo(starts[b]!));
    final entries = <ModEntry>[];
    for (var i = 0; i < ids.length; i++) {
      final id = ids[i];
      final title = titles[id];
      // Sidebar links ("Fabric", "Forge") have no version tags; skip them.
      if (title == null || !_versionTag.hasMatch(title)) continue;
      final from = starts[id]!;
      final to = i + 1 < ids.length ? starts[ids[i + 1]]! : html.length;
      final block = html.substring(from, to);
      final image = _image.firstMatch(block)?[1];
      final author = _author.firstMatch(block)?[1];
      final description = _paragraph
          .allMatches(block)
          .map((m) => _text(m[1]!))
          .firstWhere((t) => t.length > 20, orElse: () => '');
      entries.add(ModEntry(
        id: id,
        title: title.replaceAll(_versionTag, '').replaceAll(RegExp(r'\s+'), ' ').trim(),
        url: _abs(paths[id]!),
        description: description,
        author: author == null ? '' : Uri.decodeComponent(author),
        iconUrl: image == null ? null : _abs(image),
        versions: [for (final v in _versionTag.allMatches(title)) v[1]!],
      ));
    }
    return entries;
  }

  /// Mod page: the "Скачать" table with links like "Для 1.21.1 fabric".
  static List<ModFile> parseFiles(String html) {
    final files = <ModFile>[];
    final seen = <String>{};
    for (final m in _download.allMatches(html)) {
      final url = _abs(m[1]!);
      // The label is the link text, or the table row around the link.
      var label = _fileLabel.firstMatch(_text(m[2]!));
      if (label == null) {
        final rowStart = html.lastIndexOf('<tr', m.start);
        final rowEnd = html.indexOf('</tr>', m.end);
        if (rowStart != -1 && rowEnd != -1) {
          label = _fileLabel.firstMatch(_text(html.substring(rowStart, rowEnd)));
        }
      }
      if (label == null || !seen.add(url)) continue;
      files.add(ModFile(
        url: url,
        mcVersion: label[1]!,
        loader: label[2]!.toLowerCase(),
      ));
    }
    return files;
  }

  static String? _fileLinkInPage(String html) {
    final m = RegExp(
      r'''href=["']([^"']+\.(?:jar|zip))["']''',
      caseSensitive: false,
    ).firstMatch(html);
    return m == null ? null : _abs(_unescape(m[1]!));
  }

  static String? _fileName(String? disposition, Uri url) {
    if (disposition != null) {
      final star = RegExp(r"filename\*=(?:UTF-8'')?([^;]+)", caseSensitive: false)
          .firstMatch(disposition);
      if (star != null) return _safe(Uri.decodeComponent(star[1]!.replaceAll('"', '')));
      final plain = RegExp(r'filename="?([^";]+)"?', caseSensitive: false)
          .firstMatch(disposition);
      if (plain != null) return _safe(plain[1]!);
    }
    final last = url.pathSegments.where((s) => s.isNotEmpty).lastOrNull;
    if (last != null && (last.endsWith('.jar') || last.endsWith('.zip'))) {
      return _safe(Uri.decodeComponent(last));
    }
    return null;
  }

  /// Keeps a server-supplied name inside the mods folder.
  static String _safe(String name) =>
      p.basename(name.replaceAll('\\', '/')).replaceAll(RegExp(r'[<>:"|?*]'), '_');
}
