import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:xui_launcher/core/api.dart';
import 'package:xui_launcher/core/downloader.dart';
import 'package:xui_launcher/core/game.dart';
import 'package:xui_launcher/core/models.dart';
import 'package:xui_launcher/core/paths.dart';
import 'package:xui_launcher/core/platform_info.dart';

void main() {
  test('prepare downloads a version and builds the offline command line', () async {
    final tmp = await Directory.systemTemp.createTemp('xui_test');
    addTearDown(() => tmp.delete(recursive: true));
    final paths = LauncherPaths(tmp.path);

    final libBytes = utf8.encode('library');
    final jarBytes = utf8.encode('client');
    final assetBytes = utf8.encode('sound');
    final assetHash = sha1.convert(assetBytes).toString();
    final nativesZip = ZipEncoder().encode(Archive()
      ..addFile(ArchiveFile('liblwjgl${PlatformInfo.nativeLibExtension}', 3, [1, 2, 3]))
      ..addFile(ArchiveFile('META-INF/MANIFEST.MF', 1, [0])));

    final assetIndex = jsonEncode({
      'objects': {
        'minecraft/sounds/a.ogg': {'hash': assetHash, 'size': assetBytes.length},
      },
    });

    Map<String, dynamic> artifact(String path, List<int> bytes) => {
          'path': path,
          'url': 'https://libs/$path',
          'sha1': sha1.convert(bytes).toString(),
          'size': bytes.length,
        };

    final version = jsonEncode({
      'id': '1.0-test',
      'type': 'release',
      'mainClass': 'net.minecraft.client.main.Main',
      'assetIndex': {'id': '5', 'url': 'https://meta/assets/5.json'},
      'downloads': {
        'client': {
          'url': 'https://meta/client.jar',
          'sha1': sha1.convert(jarBytes).toString(),
          'size': jarBytes.length,
        },
      },
      'javaVersion': {'component': 'java-runtime-delta', 'majorVersion': 21},
      'libraries': [
        {
          'name': 'com.example:lib:1.0',
          'downloads': {'artifact': artifact('com/example/lib/1.0/lib-1.0.jar', libBytes)},
        },
        {
          'name': 'com.example:other-os:1.0',
          'downloads': {'artifact': artifact('com/example/other.jar', libBytes)},
          'rules': [
            {'action': 'allow', 'os': {'name': 'nonexistent-os'}},
          ],
        },
        {
          'name': 'org.lwjgl:lwjgl:3.3.3:natives-${PlatformInfo.osName}',
          'downloads': {'artifact': artifact('org/lwjgl/natives.jar', nativesZip)},
        },
      ],
      'arguments': {
        'game': [
          '--username', r'${auth_player_name}',
          '--uuid', r'${auth_uuid}',
          '--assetsDir', r'${assets_root}',
          {
            'rules': [
              {'action': 'allow', 'features': {'is_demo_user': true}},
            ],
            'value': '--demo',
          },
          {
            'rules': [
              {'action': 'allow', 'features': {'has_custom_resolution': true}},
            ],
            'value': ['--width', r'${resolution_width}'],
          },
        ],
        'jvm': [r'-Djava.library.path=${natives_directory}', '-cp', r'${classpath}'],
      },
    });

    final requested = <String>[];
    final client = MockClient((req) async {
      final url = req.url.toString();
      requested.add(url);
      if (url == 'https://meta/1.0-test.json') return http.Response(version, 200);
      if (url == 'https://meta/assets/5.json') return http.Response(assetIndex, 200);
      if (url == 'https://meta/client.jar') return http.Response.bytes(jarBytes, 200);
      if (url.endsWith('lib-1.0.jar')) return http.Response.bytes(libBytes, 200);
      if (url.endsWith('natives.jar')) return http.Response.bytes(nativesZip, 200);
      if (url.contains(assetHash)) return http.Response.bytes(assetBytes, 200);
      return http.Response('not found', 404);
    });
    final dl = Downloader(client: client);
    final installer = GameInstaller(paths, dl, Api(dl));

    final plan = await installer.prepare(
      build: GameBuild(id: 'b1', name: 'Test', mcVersion: '1.0-test'),
      settings: LauncherSettings(nickname: 'Steve', javaPath: '/usr/bin/java'),
      manifest: [
        VersionEntry('1.0-test', 'release', 'https://meta/1.0-test.json', null,
            DateTime(2024)),
      ],
      onStatus: (_, _) {},
    );

    expect(plan.java, '/usr/bin/java');
    expect(plan.workingDir, paths.instanceDir('b1'));
    final args = plan.args;
    expect(args, contains('net.minecraft.client.main.Main'));
    expect(args[args.indexOf('--username') + 1], 'Steve');
    expect(args, isNot(contains('--demo')));
    expect(args[args.indexOf('--width') + 1], '1280');
    final cp = args[args.indexOf('-cp') + 1].split(PlatformInfo.classpathSeparator);
    expect(cp.first, p.join(paths.libraries, 'com/example/lib/1.0/lib-1.0.jar'));
    expect(cp.last, paths.versionJar('1.0-test'));
    expect(cp.any((e) => e.contains('other.jar')), isFalse);
    expect(requested.any((u) => u.contains('other.jar')), isFalse);

    expect(
      File(p.join(paths.nativesDir('b1'), 'liblwjgl${PlatformInfo.nativeLibExtension}'))
          .existsSync(),
      isTrue,
    );
    expect(
      File(p.join(paths.assets, 'objects', assetHash.substring(0, 2), assetHash))
          .readAsStringSync(),
      'sound',
    );
  });
}
