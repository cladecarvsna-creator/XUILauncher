import 'dart:convert';

import 'downloader.dart';
import 'models.dart';

/// Mojang and Fabric HTTP endpoints.
class Api {
  Api(this.dl);

  final Downloader dl;

  static const manifestUrl =
      'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json';
  static const newsUrl = 'https://launchercontent.mojang.com/v2/javaPatchNotes.json';
  static const javaRuntimesUrl =
      'https://launchermeta.mojang.com/v1/products/java-runtime/2ec0cc96c44e5a76b9c8b7c39df7210883d12871/all.json';
  static const fabricMeta = 'https://meta.fabricmc.net/v2';

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
}
