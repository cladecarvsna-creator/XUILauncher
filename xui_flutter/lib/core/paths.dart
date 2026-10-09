import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Directory layout of the launcher. Libraries, assets, versions and Java
/// runtimes are shared between builds; every build gets its own game folder.
class LauncherPaths {
  LauncherPaths(this.root);

  final String root;

  static Future<LauncherPaths> resolve() async {
    final base = await getApplicationSupportDirectory();
    final paths = LauncherPaths(p.join(base.path, 'minecraft'));
    await Directory(paths.root).create(recursive: true);
    return paths;
  }

  String get settingsFile => p.join(root, 'settings.json');
  String get buildsFile => p.join(root, 'builds.json');
  String get versions => p.join(root, 'versions');
  String get libraries => p.join(root, 'libraries');
  String get assets => p.join(root, 'assets');
  String get runtimes => p.join(root, 'runtime');
  String get instances => p.join(root, 'instances');

  String versionDir(String id) => p.join(versions, id);
  String versionJson(String id) => p.join(versions, id, '$id.json');
  String versionJar(String id) => p.join(versions, id, '$id.jar');
  String instanceDir(String id) => p.join(instances, id);
  String nativesDir(String instanceId) =>
      p.join(instances, instanceId, '.natives');
}
