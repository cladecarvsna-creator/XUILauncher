import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:xui_launcher/core/mod_catalog.dart';

// Trimmed copies of the structure of minecraft-inside.ru pages.
const _listing = '''
<aside><a href="https://minecraft-inside.ru/mods/94668-fabric.html">Fabric</a></aside>
<div class="post">
  <h2><a href="https://minecraft-inside.ru/mods/196602-tnt-expansion.html">TNT Expansion [26.3] [1.21.1]</a></h2>
  <a href="https://minecraft-inside.ru/mods/196602-tnt-expansion.html"><img src="https://minecraft-inside.ru/uploads/files/2026-10/6ac7c2d1b5a27.png"></a>
  <p>Мод добавляет &laquo;новые&raquo; виды динамита и взрывчатки.</p>
  <a href="https://minecraft-inside.ru/creator/king_of_ender">king_of_ender</a>
  <a href="https://minecraft-inside.ru/mods/196602-tnt-expansion.html">Подробнее</a>
</div>
<div class="post">
  <h2><a href="/mods/196605-legendares-weapons.html">Legendares Weapons [1.21.8] [1.21.1]</a></h2>
  <img data-src="/uploads/files/2026-10/abc.jpg">
  <p>Легендарное оружие с особыми способностями для выживания.</p>
  <a href="/user/martefay-dilen/">martefay-dilen</a>
</div>
''';

const _modPage = '''
<h2>Скачать TNT Expansion</h2>
<table>
  <tr><td><a href="https://minecraft-inside.ru/download/540772/">Для 26.3 forge</a></td><td>1,01 МБ</td></tr>
  <tr><td><a href="https://minecraft-inside.ru/download/540758/">Для 1.21.1 fabric</a></td><td>1,05 МБ</td></tr>
  <tr><td>Для 1.21.1 neoforge</td><td><a href="/download/540770/">Скачать</a></td></tr>
</table>
''';

void main() {
  test('parses the mod listing', () {
    final mods = MinecraftInside.parseListing(_listing);
    expect(mods.map((m) => m.id), ['196602', '196605']);
    final tnt = mods.first;
    expect(tnt.title, 'TNT Expansion');
    expect(tnt.versions, ['26.3', '1.21.1']);
    expect(tnt.url, 'https://minecraft-inside.ru/mods/196602-tnt-expansion.html');
    expect(tnt.iconUrl, 'https://minecraft-inside.ru/uploads/files/2026-10/6ac7c2d1b5a27.png');
    expect(tnt.description, 'Мод добавляет «новые» виды динамита и взрывчатки.');
    expect(tnt.author, 'king_of_ender');
    expect(mods[1].iconUrl, 'https://minecraft-inside.ru/uploads/files/2026-10/abc.jpg');
    expect(mods[1].author, 'martefay-dilen');
  });

  test('parses download links and picks the Fabric file', () {
    final files = MinecraftInside.parseFiles(_modPage);
    expect(files.length, 3);
    expect(files[2].loader, 'neoforge');
    expect(files[2].url, 'https://minecraft-inside.ru/download/540770/');
    final pick = MinecraftInside.pick(files, '1.21.1', 'fabric');
    expect(pick?.url, 'https://minecraft-inside.ru/download/540758/');
    expect(MinecraftInside.pick(files, '1.20.1', 'fabric'), isNull);
  });

  test('download follows an intermediate page and keeps the file name', () async {
    final tmp = await Directory.systemTemp.createTemp('xui_mods');
    addTearDown(() => tmp.delete(recursive: true));
    final client = MockClient((req) async {
      switch (req.url.path) {
        case '/download/540758/':
          return http.Response(
              '<a href="/uploads/mods/tnt-expansion-1.21.1-fabric.jar">Скачать</a>', 200,
              headers: {'content-type': 'text/html; charset=utf-8'});
        case '/uploads/mods/tnt-expansion-1.21.1-fabric.jar':
          return http.Response.bytes([1, 2, 3], 200, headers: {
            'content-type': 'application/java-archive',
            'content-disposition': 'attachment; filename="../tnt-expansion.jar"',
          });
      }
      return http.Response('', 404);
    });
    final path = await MinecraftInside(client).download(
      ModFile(
          url: 'https://minecraft-inside.ru/download/540758/',
          mcVersion: '1.21.1',
          loader: 'fabric'),
      tmp.path,
    );
    expect(path, '${tmp.path}/tnt-expansion.jar');
    expect(File(path).readAsBytesSync(), [1, 2, 3]);
  });
}
