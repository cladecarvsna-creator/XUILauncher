import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'api.dart';
import 'downloader.dart';
import 'models.dart';
import 'offline_uuid.dart';
import 'paths.dart';
import 'platform_info.dart';

/// Reports the current step ("Скачивание библиотек") and its progress (0..1,
/// or null when the step has no measurable progress).
typedef StatusCallback = void Function(String status, double? progress);

/// Everything needed to start the game once files are in place.
class LaunchPlan {
  LaunchPlan({
    required this.java,
    required this.args,
    required this.workingDir,
  });

  final String java;
  final List<String> args;
  final String workingDir;
}

/// Downloads a version with its libraries, assets and Java runtime, and
/// builds the command line to run it in offline mode.
class GameInstaller {
  GameInstaller(this.paths, this.dl, this.api);

  final LauncherPaths paths;
  final Downloader dl;
  final Api api;

  static const _librariesBase = 'https://libraries.minecraft.net/';
  static const _resourcesBase = 'https://resources.download.minecraft.net/';

  // ---------------------------------------------------------------------------
  // Version metadata
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> _loadVersionJson(
    String id,
    List<VersionEntry> manifest,
  ) async {
    final file = File(paths.versionJson(id));
    final entry = manifest.where((v) => v.id == id).firstOrNull;
    final exists = await file.exists();
    final fresh = exists &&
        (entry?.sha1 == null ||
            sha1.convert(await file.readAsBytes()).toString() == entry!.sha1);
    if (entry != null && !fresh) {
      await dl.download(DownloadTask(entry.url, file.path, sha1: entry.sha1));
    } else if (!exists) {
      throw Exception('Версия $id не найдена');
    }
    return jsonDecode(await file.readAsString()) as Map<String, dynamic>;
  }

  /// Resolves `inheritsFrom` chains (used by Fabric profiles) into one json.
  Future<Map<String, dynamic>> resolveVersion(
    String id,
    List<VersionEntry> manifest,
  ) async {
    final json = await _loadVersionJson(id, manifest);
    final parentId = json['inheritsFrom'] as String?;
    if (parentId == null) return json;
    final parent = await resolveVersion(parentId, manifest);
    return _merge(parent, json);
  }

  static Map<String, dynamic> _merge(
    Map<String, dynamic> parent,
    Map<String, dynamic> child,
  ) {
    final merged = Map<String, dynamic>.from(parent);
    child.forEach((key, value) {
      if (key == 'libraries') {
        merged['libraries'] = [...value as List, ...?parent['libraries'] as List?];
      } else if (key == 'arguments') {
        final pa = (parent['arguments'] as Map?) ?? const {};
        final ca = value as Map;
        merged['arguments'] = {
          'game': [...?pa['game'] as List?, ...?ca['game'] as List?],
          'jvm': [...?pa['jvm'] as List?, ...?ca['jvm'] as List?],
        };
      } else if (key != 'inheritsFrom') {
        merged[key] = value;
      }
    });
    // Keep the child's id so the jar of the parent is still used below.
    merged['jar'] = parent['jar'] ?? parent['id'];
    return merged;
  }

  /// Downloads a file unless it is already there, so installed versions
  /// start without internet.
  Future<void> _ensure(DownloadTask t) async {
    if (!await Downloader.isUpToDate(t)) await dl.download(t);
  }

  // ---------------------------------------------------------------------------
  // Rules
  // ---------------------------------------------------------------------------

  static bool rulesAllow(List? rules, {Map<String, bool> features = const {}}) {
    if (rules == null || rules.isEmpty) return true;
    var allowed = false;
    for (final r in rules.cast<Map<String, dynamic>>()) {
      final os = r['os'] as Map<String, dynamic>?;
      var matches = true;
      if (os != null) {
        final name = os['name'] as String?;
        if (name != null && name != PlatformInfo.osName) matches = false;
        final arch = os['arch'] as String?;
        if (arch == 'x86' && !PlatformInfo.is32Bit) matches = false;
        if (arch == 'arm64' && !PlatformInfo.isArm64) matches = false;
      }
      final f = r['features'] as Map<String, dynamic>?;
      if (f != null) {
        for (final e in f.entries) {
          if ((features[e.key] ?? false) != e.value) matches = false;
        }
      }
      if (matches) allowed = r['action'] == 'allow';
    }
    return allowed;
  }

  // ---------------------------------------------------------------------------
  // Libraries
  // ---------------------------------------------------------------------------

  static String _mavenPath(String name, {String ext = 'jar'}) {
    var coords = name;
    final at = coords.indexOf('@');
    if (at != -1) {
      ext = coords.substring(at + 1);
      coords = coords.substring(0, at);
    }
    final parts = coords.split(':');
    final group = parts[0].replaceAll('.', '/');
    final artifact = parts[1];
    final version = parts[2];
    final classifier = parts.length > 3 ? '-${parts[3]}' : '';
    return '$group/$artifact/$version/$artifact-$version$classifier.$ext';
  }

  /// Library key without version, so that a child profile can override the
  /// version of a library the parent also declares.
  static String _libraryKey(String name) {
    final parts = name.split(':');
    final classifier = parts.length > 3 ? ':${parts[3]}' : '';
    return '${parts[0]}:${parts[1]}$classifier';
  }

  ({List<DownloadTask> downloads, List<String> classpath, List<String> natives})
      _collectLibraries(Map<String, dynamic> version) {
    final downloads = <DownloadTask>[];
    final classpath = <String>[];
    final natives = <String>[];
    final seen = <String>{};

    for (final lib in (version['libraries'] as List? ?? const [])
        .cast<Map<String, dynamic>>()) {
      if (!rulesAllow(lib['rules'] as List?)) continue;
      final name = lib['name'] as String;
      final d = lib['downloads'] as Map<String, dynamic>?;

      // Old-style natives: a classifier per OS, extracted before launch.
      final nativesMap = lib['natives'] as Map<String, dynamic>?;
      if (nativesMap != null) {
        final key = (nativesMap[PlatformInfo.osName] as String?)
            ?.replaceAll(r'${arch}', PlatformInfo.archBits);
        final artifact = key == null
            ? null
            : (d?['classifiers'] as Map<String, dynamic>?)?[key]
                as Map<String, dynamic>?;
        if (artifact != null) {
          final path = p.join(paths.libraries, artifact['path'] as String);
          downloads.add(DownloadTask(artifact['url'] as String, path,
              sha1: artifact['sha1'] as String?,
              size: (artifact['size'] as num?)?.toInt()));
          natives.add(path);
        }
        if (d?['artifact'] == null) continue;
      }

      if (!seen.add(_libraryKey(name))) continue;

      final artifact = d?['artifact'] as Map<String, dynamic>?;
      String path;
      if (artifact != null) {
        final rel = (artifact['path'] as String?) ?? _mavenPath(name);
        path = p.join(paths.libraries, rel);
        final url = artifact['url'] as String?;
        if (url != null && url.isNotEmpty) {
          downloads.add(DownloadTask(url, path,
              sha1: artifact['sha1'] as String?,
              size: (artifact['size'] as num?)?.toInt()));
        }
      } else {
        final rel = _mavenPath(name);
        path = p.join(paths.libraries, rel);
        var base = (lib['url'] as String?) ?? _librariesBase;
        if (!base.endsWith('/')) base = '$base/';
        downloads.add(DownloadTask('$base$rel', path,
            sha1: lib['sha1'] as String?, size: (lib['size'] as num?)?.toInt()));
      }
      classpath.add(path);
      // New-style natives (1.19+) are regular libraries named "...:natives-os".
      if (name.contains(':natives-')) natives.add(path);
    }
    return (downloads: downloads, classpath: classpath, natives: natives);
  }

  Future<void> _extractNatives(List<String> jars, String targetDir) async {
    final dir = Directory(targetDir);
    if (await dir.exists()) await dir.delete(recursive: true);
    await dir.create(recursive: true);
    for (final jar in jars) {
      final archive = ZipDecoder().decodeBytes(await File(jar).readAsBytes());
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final name = entry.name;
        if (name.startsWith('META-INF/')) continue;
        final lower = name.toLowerCase();
        final isNative = lower.endsWith('.so') ||
            lower.endsWith('.dll') ||
            lower.endsWith('.dylib') ||
            lower.endsWith('.jnilib');
        if (!isNative) continue;
        final out = File(p.join(targetDir, p.basename(name)));
        await out.writeAsBytes(entry.content as List<int>);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Assets
  // ---------------------------------------------------------------------------

  Future<String> _installAssets(
    Map<String, dynamic> version,
    String gameDir,
    StatusCallback onStatus,
  ) async {
    final index = version['assetIndex'] as Map<String, dynamic>;
    final indexId = index['id'] as String;
    final indexPath = p.join(paths.assets, 'indexes', '$indexId.json');
    await _ensure(DownloadTask(index['url'] as String, indexPath,
        sha1: index['sha1'] as String?, size: (index['size'] as num?)?.toInt()));
    final json =
        jsonDecode(await File(indexPath).readAsString()) as Map<String, dynamic>;
    final objects = (json['objects'] as Map).cast<String, dynamic>();

    final tasks = <DownloadTask>[];
    objects.forEach((name, obj) {
      final hash = obj['hash'] as String;
      final prefix = hash.substring(0, 2);
      tasks.add(DownloadTask(
        '$_resourcesBase$prefix/$hash',
        p.join(paths.assets, 'objects', prefix, hash),
        sha1: hash,
        size: (obj['size'] as num).toInt(),
      ));
    });
    await dl.downloadAll(tasks, onProgress: (done, total) {
      onStatus('Скачивание ресурсов $done/$total', total == 0 ? 1 : done / total);
    });

    // Pre-1.7 versions read assets from a flat folder instead of the store.
    final isVirtual = json['virtual'] == true;
    final mapToResources = json['map_to_resources'] == true;
    if (!isVirtual && !mapToResources) return paths.assets;
    final target = mapToResources
        ? p.join(gameDir, 'resources')
        : p.join(paths.assets, 'virtual', indexId);
    for (final e in objects.entries) {
      final hash = e.value['hash'] as String;
      final out = File(p.join(target, e.key));
      if (await out.exists()) continue;
      await out.parent.create(recursive: true);
      await File(p.join(paths.assets, 'objects', hash.substring(0, 2), hash))
          .copy(out.path);
    }
    return target;
  }

  // ---------------------------------------------------------------------------
  // Java runtime
  // ---------------------------------------------------------------------------

  Future<String> _installJava(
    Map<String, dynamic> version,
    StatusCallback onStatus,
  ) async {
    final component =
        (version['javaVersion'] as Map?)?['component'] as String? ?? 'jre-legacy';
    final home = p.join(paths.runtimes, component);
    final java = _javaExecutable(home);
    final marker = File(p.join(home, '.installed'));
    if (await marker.exists() && await File(java).exists()) return java;

    onStatus('Поиск Java ($component)', null);
    final all = jsonDecode(await dl.getString(Api.javaRuntimesUrl))
        as Map<String, dynamic>;
    var candidates = (all[PlatformInfo.runtimePlatform] as Map?)?[component] as List?;
    // Apple Silicon has no build of the legacy runtime; Rosetta runs x64 one.
    if ((candidates == null || candidates.isEmpty) &&
        PlatformInfo.runtimePlatform == 'mac-os-arm64') {
      candidates = (all['mac-os'] as Map?)?[component] as List?;
    }
    if (candidates == null || candidates.isEmpty) {
      throw Exception(
          'Mojang не публикует Java $component для этой системы. Укажите путь к Java в настройках.');
    }
    final manifestUrl = (candidates.first as Map)['manifest']['url'] as String;
    final manifest = jsonDecode(await dl.getString(manifestUrl)) as Map<String, dynamic>;
    final files = (manifest['files'] as Map).cast<String, dynamic>();

    final tasks = <DownloadTask>[];
    final links = <String, String>{};
    for (final e in files.entries) {
      final path = p.join(home, e.key);
      final info = e.value as Map<String, dynamic>;
      switch (info['type']) {
        case 'directory':
          await Directory(path).create(recursive: true);
        case 'file':
          final raw = (info['downloads'] as Map)['raw'] as Map<String, dynamic>;
          tasks.add(DownloadTask(raw['url'] as String, path,
              sha1: raw['sha1'] as String?,
              size: (raw['size'] as num?)?.toInt(),
              executable: info['executable'] == true));
        case 'link':
          links[path] = info['target'] as String;
      }
    }
    await dl.downloadAll(tasks, onProgress: (done, total) {
      onStatus('Скачивание Java $done/$total', total == 0 ? 1 : done / total);
    });
    if (!Platform.isWindows) {
      for (final l in links.entries) {
        final link = Link(l.key);
        if (await link.exists()) await link.delete();
        await link.create(l.value);
      }
      for (final t in tasks.where((t) => t.executable)) {
        await Process.run('chmod', ['+x', t.path]);
      }
    }
    await marker.writeAsString(component);
    return java;
  }

  static String _javaExecutable(String home) {
    if (Platform.isWindows) return p.join(home, 'bin', 'javaw.exe');
    if (Platform.isMacOS) {
      return p.join(home, 'jre.bundle', 'Contents', 'Home', 'bin', 'java');
    }
    return p.join(home, 'bin', 'java');
  }

  // ---------------------------------------------------------------------------
  // Install + launch
  // ---------------------------------------------------------------------------

  /// Installs the Fabric profile json for a build if it uses Fabric.
  Future<void> _ensureLoader(GameBuild build) async {
    if (build.loader != ModLoader.fabric) return;
    build.loaderVersion ??= await api.latestFabricLoader(build.mcVersion);
    final file = File(paths.versionJson(build.launchVersionId));
    if (await file.exists()) return;
    await file.parent.create(recursive: true);
    await file.writeAsString(
        await api.fabricProfileJson(build.mcVersion, build.loaderVersion!));
  }

  Future<LaunchPlan> prepare({
    required GameBuild build,
    required LauncherSettings settings,
    required List<VersionEntry> manifest,
    required StatusCallback onStatus,
  }) async {
    final gameDir = paths.instanceDir(build.id);
    await Directory(gameDir).create(recursive: true);

    onStatus('Загрузка информации о версии', null);
    await _ensureLoader(build);
    final version = await resolveVersion(build.launchVersionId, manifest);

    // Client jar (stored under the vanilla id, also for Fabric).
    final jarId = (version['jar'] as String?) ?? build.mcVersion;
    final client = (version['downloads'] as Map?)?['client'] as Map?;
    final jarPath = paths.versionJar(jarId);
    if (client != null) {
      onStatus('Скачивание Minecraft ${build.mcVersion}', null);
      await _ensure(DownloadTask(client['url'] as String, jarPath,
          sha1: client['sha1'] as String?, size: (client['size'] as num?)?.toInt()));
    }

    final libs = _collectLibraries(version);
    await dl.downloadAll(libs.downloads, onProgress: (done, total) {
      onStatus('Скачивание библиотек $done/$total', total == 0 ? 1 : done / total);
    });

    final assetsDir = await _installAssets(version, gameDir, onStatus);

    final java = settings.javaPath.trim().isNotEmpty
        ? settings.javaPath.trim()
        : await _installJava(version, onStatus);

    onStatus('Подготовка к запуску', null);
    final nativesDir = paths.nativesDir(build.id);
    await _extractNatives(libs.natives, nativesDir);

    final classpath = [...libs.classpath, jarPath]
        .join(PlatformInfo.classpathSeparator);
    final uuid = offlineUuid(settings.nickname);
    final vars = <String, String>{
      'auth_player_name': settings.nickname,
      'version_name': build.launchVersionId,
      'game_directory': gameDir,
      'assets_root': assetsDir,
      'game_assets': assetsDir,
      'assets_index_name': (version['assetIndex'] as Map)['id'] as String,
      'auth_uuid': uuid,
      'auth_access_token': '0',
      'auth_session': '0',
      'auth_xuid': '0',
      'clientid': '0',
      'user_type': 'legacy',
      'user_properties': '{}',
      'version_type': (version['type'] as String?) ?? 'release',
      'natives_directory': nativesDir,
      'launcher_name': 'XUILauncher',
      'launcher_version': '1.0',
      'classpath': classpath,
      'classpath_separator': PlatformInfo.classpathSeparator,
      'library_directory': paths.libraries,
      'resolution_width': '${settings.width}',
      'resolution_height': '${settings.height}',
    };
    final features = {
      'has_custom_resolution': !settings.fullscreen,
      'is_demo_user': false,
    };

    final jvm = <String>[
      '-Xmx${settings.memoryMb}M',
      '-Xms${settings.memoryMb < 1024 ? settings.memoryMb : 1024}M',
      '-Dlog4j2.formatMsgNoLookups=true',
      ...settings.jvmArgs.split(RegExp(r'\s+')).where((a) => a.isNotEmpty),
    ];
    final game = <String>[];
    final arguments = version['arguments'] as Map<String, dynamic>?;
    if (arguments != null) {
      jvm.addAll(_expandArgs(arguments['jvm'] as List? ?? const [], features));
      game.addAll(_expandArgs(arguments['game'] as List? ?? const [], features));
    } else {
      if (Platform.isMacOS) jvm.add('-XstartOnFirstThread');
      jvm.addAll([r'-Djava.library.path=${natives_directory}', '-cp', r'${classpath}']);
      game.addAll((version['minecraftArguments'] as String? ?? '').split(' '));
      if (!settings.fullscreen) {
        game.addAll([
          '--width', r'${resolution_width}',
          '--height', r'${resolution_height}',
        ]);
      }
    }
    if (settings.fullscreen) game.add('--fullscreen');

    String sub(String s) => s.replaceAllMapped(
        RegExp(r'\$\{([a-zA-Z_]+)\}'), (m) => vars[m[1]] ?? m[0]!);

    return LaunchPlan(
      java: java,
      workingDir: gameDir,
      args: [
        ...jvm.map(sub),
        version['mainClass'] as String,
        ...game.where((a) => a.isNotEmpty).map(sub),
      ],
    );
  }

  static List<String> _expandArgs(List raw, Map<String, bool> features) {
    final out = <String>[];
    for (final a in raw) {
      if (a is String) {
        out.add(a);
      } else if (a is Map) {
        if (!rulesAllow(a['rules'] as List?, features: features)) continue;
        final v = a['value'];
        if (v is String) {
          out.add(v);
        } else if (v is List) {
          out.addAll(v.cast<String>());
        }
      }
    }
    return out;
  }
}
