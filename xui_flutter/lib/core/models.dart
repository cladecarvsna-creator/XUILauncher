import 'dart:convert';

enum ModLoader {
  vanilla('Vanilla'),
  fabric('Fabric');

  const ModLoader(this.title);
  final String title;

  static ModLoader parse(String? v) =>
      ModLoader.values.firstWhere((e) => e.name == v, orElse: () => vanilla);
}

/// A "сборка": a game folder bound to a Minecraft version and a mod loader.
class GameBuild {
  GameBuild({
    required this.id,
    required this.name,
    required this.mcVersion,
    this.loader = ModLoader.vanilla,
    this.loaderVersion,
    DateTime? created,
    this.lastPlayed,
    this.iconIndex = 0,
  }) : created = created ?? DateTime.now();

  final String id;
  String name;
  String mcVersion;
  ModLoader loader;
  String? loaderVersion;
  final DateTime created;
  DateTime? lastPlayed;
  int iconIndex;

  /// Version id as stored in the versions folder (vanilla or loader profile).
  String get launchVersionId => loader == ModLoader.fabric && loaderVersion != null
      ? 'fabric-loader-$loaderVersion-$mcVersion'
      : mcVersion;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mcVersion': mcVersion,
        'loader': loader.name,
        'loaderVersion': loaderVersion,
        'created': created.toIso8601String(),
        'lastPlayed': lastPlayed?.toIso8601String(),
        'iconIndex': iconIndex,
      };

  factory GameBuild.fromJson(Map<String, dynamic> j) => GameBuild(
        id: j['id'] as String,
        name: j['name'] as String,
        mcVersion: j['mcVersion'] as String,
        loader: ModLoader.parse(j['loader'] as String?),
        loaderVersion: j['loaderVersion'] as String?,
        created: DateTime.tryParse(j['created'] as String? ?? ''),
        lastPlayed: DateTime.tryParse(j['lastPlayed'] as String? ?? ''),
        iconIndex: (j['iconIndex'] as num?)?.toInt() ?? 0,
      );
}

class LauncherSettings {
  LauncherSettings({
    this.nickname = 'nickname',
    this.memoryMb = 4096,
    this.javaPath = '',
    this.jvmArgs = '',
    this.width = 1280,
    this.height = 720,
    this.fullscreen = false,
    this.closeOnLaunch = false,
    this.showSnapshots = false,
    this.selectedBuild,
  });

  String nickname;
  int memoryMb;

  /// Empty = download the Java runtime Mojang recommends for the version.
  String javaPath;
  String jvmArgs;
  int width;
  int height;
  bool fullscreen;
  bool closeOnLaunch;
  bool showSnapshots;
  String? selectedBuild;

  Map<String, dynamic> toJson() => {
        'nickname': nickname,
        'memoryMb': memoryMb,
        'javaPath': javaPath,
        'jvmArgs': jvmArgs,
        'width': width,
        'height': height,
        'fullscreen': fullscreen,
        'closeOnLaunch': closeOnLaunch,
        'showSnapshots': showSnapshots,
        'selectedBuild': selectedBuild,
      };

  factory LauncherSettings.fromJson(Map<String, dynamic> j) => LauncherSettings(
        nickname: j['nickname'] as String? ?? 'nickname',
        memoryMb: (j['memoryMb'] as num?)?.toInt() ?? 4096,
        javaPath: j['javaPath'] as String? ?? '',
        jvmArgs: j['jvmArgs'] as String? ?? '',
        width: (j['width'] as num?)?.toInt() ?? 1280,
        height: (j['height'] as num?)?.toInt() ?? 720,
        fullscreen: j['fullscreen'] as bool? ?? false,
        closeOnLaunch: j['closeOnLaunch'] as bool? ?? false,
        showSnapshots: j['showSnapshots'] as bool? ?? false,
        selectedBuild: j['selectedBuild'] as String?,
      );

  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());
}

class VersionEntry {
  VersionEntry(this.id, this.type, this.url, this.sha1, this.releaseTime);

  final String id;
  final String type;
  final String url;
  final String? sha1;
  final DateTime releaseTime;

  bool get isRelease => type == 'release';

  factory VersionEntry.fromJson(Map<String, dynamic> j) => VersionEntry(
        j['id'] as String,
        j['type'] as String,
        j['url'] as String,
        j['sha1'] as String?,
        DateTime.tryParse(j['releaseTime'] as String? ?? '') ?? DateTime(2009),
      );
}

class NewsItem {
  NewsItem({
    required this.title,
    required this.text,
    required this.date,
    this.imageUrl,
    this.link,
    this.category,
  });

  final String title;
  final String text;
  final DateTime? date;
  final String? imageUrl;
  final String? link;
  final String? category;
}

class ModrinthHit {
  ModrinthHit({
    required this.projectId,
    required this.slug,
    required this.title,
    required this.description,
    required this.author,
    required this.downloads,
    this.iconUrl,
  });

  final String projectId;
  final String slug;
  final String title;
  final String description;
  final String author;
  final int downloads;
  final String? iconUrl;

  factory ModrinthHit.fromJson(Map<String, dynamic> j) => ModrinthHit(
        projectId: j['project_id'] as String,
        slug: j['slug'] as String? ?? '',
        title: j['title'] as String? ?? '',
        description: j['description'] as String? ?? '',
        author: j['author'] as String? ?? '',
        downloads: (j['downloads'] as num?)?.toInt() ?? 0,
        iconUrl: (j['icon_url'] as String?)?.isEmpty ?? true
            ? null
            : j['icon_url'] as String,
      );
}
