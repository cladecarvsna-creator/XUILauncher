import 'dart:convert';

import 'downloader.dart';
import 'models.dart';

/// Mojang, Fabric and Modrinth HTTP endpoints.
class Api {
  Api(this.dl);

  final Downloader dl;

  static const manifestUrl =
      'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json';
  static const newsUrl = 'https://launchercontent.mojang.com/v2/javaPatchNotes.json';
  static const javaRuntimesUrl =
      'https://launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json';
  static const fabricMeta = 'https://meta.fabricmc.net/v2';
  static const modrinth = 'https://api.modrinth.com/v2';

  Future<List<VersionEntry>> versionManifest() async {
    final j = jsonDecode(await dl.getString(manifestUrl)) as Map<String, dynamic>;
    return (j['versions'] as List)
        .map((e) => VersionEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Java Edition patch notes; shown as news on the main page.
  Future<List<NewsItem>> news() async {
    final j = jsonDecode(await dl.getString(newsUrl)) as Map<String, dynamic>;
    final entries = (j['entries'] as List? ?? const []).cast<Map<String, dynamic>>();
    return entries.take(12).map((e) {
      final image = (e['image'] as Map?)?['url'] as String?;
      final body = (e['shortText'] as String?) ??
          _stripHtml(e['body'] as String? ?? '');
      return NewsItem(
        title: e['title'] as String? ?? '',
        text: body,
        date: DateTime.tryParse(e['date'] as String? ?? ''),
        imageUrl: image == null
            ? null
            : image.startsWith('http')
                ? image
                : 'https://launchercontent.mojang.com$image',
        category: e['type'] as String?,
      );
    }).toList();
  }

  static String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Latest stable Fabric loader version for the given Minecraft version.
  Future<String> latestFabricLoader(String mcVersion) async {
    final list = jsonDecode(
        await dl.getString('$fabricMeta/versions/loader/$mcVersion')) as List;
    if (list.isEmpty) {
      throw Exception('Fabric не поддерживает Minecraft $mcVersion');
    }
    final stable = list.cast<Map<String, dynamic>>().firstWhere(
          (e) => (e['loader'] as Map)['stable'] == true,
          orElse: () => list.first as Map<String, dynamic>,
        );
    return (stable['loader'] as Map)['version'] as String;
  }

  Future<String> fabricProfileJson(String mcVersion, String loader) =>
      dl.getString('$fabricMeta/versions/loader/$mcVersion/$loader/profile/json');

  Future<List<ModrinthHit>> searchMods(
    String query, {
    String? mcVersion,
    String loader = 'fabric',
    int offset = 0,
  }) async {
    final facets = [
      ['project_type:mod'],
      ['categories:$loader'],
      if (mcVersion != null) ['versions:$mcVersion'],
    ];
    final uri = Uri.parse('$modrinth/search').replace(queryParameters: {
      'query': query,
      'limit': '30',
      'offset': '$offset',
      'index': query.isEmpty ? 'downloads' : 'relevance',
      'facets': jsonEncode(facets),
    });
    final j = jsonDecode(await dl.getString(uri.toString())) as Map<String, dynamic>;
    return (j['hits'] as List)
        .map((e) => ModrinthHit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Primary file of the newest mod version matching the build.
  Future<({String url, String filename, String? sha1})?> modFile(
    String projectId, {
    required String mcVersion,
    String loader = 'fabric',
  }) async {
    final uri = Uri.parse('$modrinth/project/$projectId/version').replace(
      queryParameters: {
        'loaders': jsonEncode([loader]),
        'game_versions': jsonEncode([mcVersion]),
      },
    );
    final list = jsonDecode(await dl.getString(uri.toString())) as List;
    if (list.isEmpty) return null;
    final files = ((list.first as Map)['files'] as List).cast<Map<String, dynamic>>();
    final file = files.firstWhere((f) => f['primary'] == true,
        orElse: () => files.first);
    return (
      url: file['url'] as String,
      filename: file['filename'] as String,
      sha1: (file['hashes'] as Map?)?['sha1'] as String?,
    );
  }
}
