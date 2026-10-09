import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xui_launcher/core/game.dart';
import 'package:xui_launcher/core/offline_uuid.dart';
import 'package:xui_launcher/core/platform_info.dart';

void main() {
  test('offline UUID matches the vanilla server', () {
    // Known value for "Notch" in offline mode.
    expect(dashedUuid(offlineUuid('Notch')), 'b50ad385-829d-3141-a216-7e7d7539ba7f');
  });

  test('rules: allow on matching OS only', () {
    final rules = [
      {'action': 'allow'},
      {
        'action': 'disallow',
        'os': {'name': PlatformInfo.osName},
      },
    ];
    expect(GameInstaller.rulesAllow(rules), isFalse);
    expect(GameInstaller.rulesAllow(null), isTrue);
    expect(
      GameInstaller.rulesAllow([
        {
          'action': 'allow',
          'features': {'has_custom_resolution': true},
        },
      ], features: {'has_custom_resolution': true}),
      isTrue,
    );
    expect(Platform.isLinux || Platform.isMacOS || Platform.isWindows, isTrue);
  });
}
