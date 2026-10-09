import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'api.dart';
import 'downloader.dart';
import 'errors.dart';
import 'game.dart';
import 'models.dart';
import 'paths.dart';

enum LauncherPage { home, catalog, myMods, settings, console }

/// App state: builds, settings, the download/launch pipeline and game logs.
class LauncherController extends ChangeNotifier {
  LauncherController(this.paths)
      : dl = Downloader(),
        settings = LauncherSettings() {
    api = Api(dl);
    installer = GameInstaller(paths, dl, api);
  }

  final LauncherPaths paths;
  final Downloader dl;
  late final Api api;
  late final GameInstaller installer;

  LauncherSettings settings;
  final List<GameBuild> builds = [];
  List<VersionEntry> versions = [];
  List<NewsItem> news = [];
  bool newsLoading = true;
  String? newsError;
  String? versionsError;

  LauncherPage page = LauncherPage.home;

  // Progress bar at the bottom.
  String status = 'Готово к игре';
  double? progress = 0;
  bool busy = false;

  Process? _game;
  bool get gameRunning => _game != null;

  final List<String> console = [];
  static const _consoleLimit = 5000;

  GameBuild? get selected {
    final id = settings.selectedBuild;
    return builds.where((b) => b.id == id).firstOrNull ?? builds.firstOrNull;
  }

  // ---------------------------------------------------------------------------
  // Loading & saving
  // ---------------------------------------------------------------------------

  Future<void> load() async {
    final sFile = File(paths.settingsFile);
    if (await sFile.exists()) {
      try {
        settings = LauncherSettings.fromJson(
            jsonDecode(await sFile.readAsString()) as Map<String, dynamic>);
      } catch (_) {}
    }
    final bFile = File(paths.buildsFile);
    if (await bFile.exists()) {
      try {
        final list = jsonDecode(await bFile.readAsString()) as List;
        builds
          ..clear()
          ..addAll(list.map((e) => GameBuild.fromJson(e as Map<String, dynamic>)));
      } catch (_) {}
    }
    notifyListeners();
    unawaited(refreshVersions());
    unawaited(refreshNews());
  }

  Future<void> saveSettings() async {
    await File(paths.settingsFile).writeAsString(settings.encode());
    notifyListeners();
  }

  Future<void> _saveBuilds() async {
    await File(paths.buildsFile).writeAsString(
        const JsonEncoder.withIndent('  ')
            .convert(builds.map((b) => b.toJson()).toList()));
  }

  Future<void> refreshVersions() async {
    try {
      versions = await api.versionManifest();
      versionsError = null;
      if (builds.isEmpty) {
        final latest = versions.firstWhere((v) => v.isRelease);
        await createBuild(name: 'Моя сборка', version: latest.id);
      }
    } catch (e) {
      versionsError = 'Нет связи с серверами Mojang';
      log('[XUI] Не удалось получить список версий: $e');
    }
    notifyListeners();
  }

  Future<void> refreshNews() async {
    newsLoading = true;
    notifyListeners();
    try {
      news = await api.news();
      newsError = null;
    } catch (e) {
      newsError = 'Новости недоступны';
    }
    newsLoading = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Builds
  // ---------------------------------------------------------------------------

  void go(LauncherPage p) {
    page = p;
    notifyListeners();
  }

  void select(GameBuild b) {
    settings.selectedBuild = b.id;
    unawaited(saveSettings());
  }

  Future<GameBuild> createBuild({
    required String name,
    required String version,
    ModLoader loader = ModLoader.vanilla,
  }) async {
    final id = '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-'
        '${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}';
    final build = GameBuild(
      id: id,
      name: name,
      mcVersion: version,
      loader: loader,
      iconIndex: builds.length % 6,
    );
    builds.add(build);
    settings.selectedBuild = build.id;
    await Directory(paths.instanceDir(id)).create(recursive: true);
    await _saveBuilds();
    await saveSettings();
    return build;
  }

  Future<void> updateBuild(GameBuild b) async {
    await _saveBuilds();
    notifyListeners();
  }

  Future<void> deleteBuild(GameBuild b) async {
    builds.remove(b);
    if (settings.selectedBuild == b.id) {
      settings.selectedBuild = builds.firstOrNull?.id;
    }
    final dir = Directory(paths.instanceDir(b.id));
    if (await dir.exists()) await dir.delete(recursive: true);
    await _saveBuilds();
    await saveSettings();
    _setStatus('Сборка «${b.name}» удалена', 0);
  }

  Future<void> openFolder([GameBuild? b]) async {
    final dir = b == null ? paths.root : paths.instanceDir(b.id);
    await Directory(dir).create(recursive: true);
    final cmd = Platform.isWindows
        ? 'explorer'
        : Platform.isMacOS
            ? 'open'
            : 'xdg-open';
    await Process.start(cmd, [dir], mode: ProcessStartMode.detached);
  }

  String modsDir(GameBuild b) => p.join(paths.instanceDir(b.id), 'mods');

  // ---------------------------------------------------------------------------
  // Mods
  // ---------------------------------------------------------------------------

  Future<List<File>> listMods(GameBuild b) async {
    final dir = Directory(modsDir(b));
    if (!await dir.exists()) return [];
    final files = await dir
        .list()
        .where((e) =>
            e is File &&
            (e.path.endsWith('.jar') || e.path.endsWith('.jar.disabled')))
        .cast<File>()
        .toList();
    files.sort((a, b) => p.basename(a.path).compareTo(p.basename(b.path)));
    return files;
  }

  Future<void> toggleMod(File f) async {
    if (f.path.endsWith('.disabled')) {
      await f.rename(f.path.substring(0, f.path.length - '.disabled'.length));
    } else {
      await f.rename('${f.path}.disabled');
    }
    notifyListeners();
  }

  Future<void> deleteMod(File f) async {
    await f.delete();
    notifyListeners();
  }

  /// Downloads a Modrinth mod into the selected build.
  Future<String> installMod(ModrinthHit mod) async {
    final b = selected;
    if (b == null) throw Exception('Сначала создайте сборку');
    if (b.loader != ModLoader.fabric) {
      throw Exception('Моды работают только в сборках на Fabric');
    }
    _setStatus('Установка ${mod.title}', null);
    try {
      final file = await api.modFile(mod.projectId, mcVersion: b.mcVersion);
      if (file == null) {
        throw Exception('${mod.title} нет для Minecraft ${b.mcVersion}');
      }
      await dl.download(DownloadTask(file.url, p.join(modsDir(b), file.filename),
          sha1: file.sha1));
      _setStatus('${mod.title} установлен в «${b.name}»', 1);
      return file.filename;
    } catch (e) {
      _setStatus(friendlyError(e), 0);
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // Launch
  // ---------------------------------------------------------------------------

  void _setStatus(String s, double? pr) {
    status = s;
    progress = pr;
    notifyListeners();
  }

  void log(String line) {
    console.add(line);
    if (console.length > _consoleLimit) {
      console.removeRange(0, console.length - _consoleLimit);
    }
    notifyListeners();
  }

  void clearConsole() {
    console.clear();
    notifyListeners();
  }

  Future<void> play() async {
    if (busy) return;
    if (_game != null) {
      _game!.kill();
      return;
    }
    final b = selected;
    if (b == null) {
      _setStatus('Создайте сборку, чтобы играть', 0);
      return;
    }
    busy = true;
    _setStatus('Подготовка…', null);
    try {
      if (versions.isEmpty) {
        // Without the manifest, already installed versions still start.
        try {
          versions = await api.versionManifest();
        } catch (e) {
          log('[XUI] Список версий недоступен, запуск из локальных файлов');
        }
      }
      final plan = await installer.prepare(
        build: b,
        settings: settings,
        manifest: versions,
        onStatus: _setStatus,
      );
      await _saveBuilds();
      log('[XUI] Запуск ${b.name} (${b.launchVersionId}) как ${settings.nickname}');
      log('[XUI] Java: ${plan.java}');
      if (settings.closeOnLaunch) {
        await Process.start(plan.java, plan.args,
            workingDirectory: plan.workingDir, mode: ProcessStartMode.detached);
        exit(0);
      }
      final proc = await Process.start(plan.java, plan.args,
          workingDirectory: plan.workingDir);
      _game = proc;
      b.lastPlayed = DateTime.now();
      await _saveBuilds();
      _setStatus('Игра запущена', 1);
      proc.stdout
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(log);
      proc.stderr
          .transform(const Utf8Decoder(allowMalformed: true))
          .transform(const LineSplitter())
          .listen(log);
      unawaited(proc.exitCode.then((code) {
        _game = null;
        log('[XUI] Игра завершилась с кодом $code');
        _setStatus(code == 0 ? 'Готово к игре' : 'Игра завершилась с ошибкой ($code)',
            code == 0 ? 0 : 1);
        if (code != 0) go(LauncherPage.console);
      }));
    } catch (e) {
      log('[XUI] Ошибка: $e');
      _setStatus(friendlyError(e), 0);
    } finally {
      busy = false;
      notifyListeners();
    }
  }
}
