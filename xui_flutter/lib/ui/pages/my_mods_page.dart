import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/launcher_controller.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Mods installed in the selected build: enable/disable and delete.
class MyModsPage extends StatelessWidget {
  const MyModsPage({super.key, required this.c});

  final LauncherController c;

  @override
  Widget build(BuildContext context) {
    final b = c.selected;
    return GlassPanel(
      padding: EdgeInsets.all(context.u(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('МОИ МОДЫ', style: xuiText(context, size: 13, color: Colors.white)),
              SizedBox(width: context.u(10)),
              if (b != null) InfoChip('${b.name} · ${b.mcVersion} · ${b.loader.title}'),
              const Spacer(),
              if (b != null)
                GlassButton(
                  label: 'Папка модов',
                  glass: Glass.rose,
                  height: 24,
                  fontSize: 8.5,
                  onTap: () async {
                    await Directory(c.modsDir(b)).create(recursive: true);
                    await Process.start(
                      Platform.isWindows
                          ? 'explorer'
                          : Platform.isMacOS
                              ? 'open'
                              : 'xdg-open',
                      [c.modsDir(b)],
                      mode: ProcessStartMode.detached,
                    );
                  },
                ),
            ],
          ),
          SizedBox(height: context.u(10)),
          Expanded(
            child: b == null
                ? _empty(context, 'Нет выбранной сборки')
                : FutureBuilder<List<File>>(
                    // Re-read the folder on every rebuild (toggles notify).
                    future: c.listMods(b),
                    builder: (context, snap) {
                      final mods = snap.data ?? const [];
                      if (snap.connectionState != ConnectionState.done && mods.isEmpty) {
                        return const SizedBox();
                      }
                      if (mods.isEmpty) {
                        return _empty(context,
                            'В этой сборке пока нет модов.\nНайдите их в «Каталог Модов».');
                      }
                      return ListView.separated(
                        itemCount: mods.length,
                        separatorBuilder: (_, _) => SizedBox(height: context.u(5)),
                        itemBuilder: (context, i) => _ModRow(c: c, file: mods[i]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, String text) => Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: xuiText(context, size: 9, color: XuiColors.textMuted, height: 1.6)),
      );
}

class _ModRow extends StatelessWidget {
  const _ModRow({required this.c, required this.file});

  final LauncherController c;
  final File file;

  @override
  Widget build(BuildContext context) {
    final name = p.basename(file.path);
    final enabled = !name.endsWith('.disabled');
    final display = name.replaceAll('.disabled', '').replaceAll('.jar', '');
    return GlassPanel(
      radius: 10,
      padding: EdgeInsets.symmetric(horizontal: context.u(10), vertical: context.u(4)),
      child: Row(
        children: [
          Icon(Icons.extension_rounded,
              size: context.u(14),
              color: enabled ? Colors.white : Colors.white38),
          SizedBox(width: context.u(8)),
          Expanded(
            child: Text(display,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: xuiText(context,
                    size: 9, color: enabled ? Colors.white : Colors.white54)),
          ),
          Text(enabled ? 'включён' : 'выключен',
              style: xuiText(context, size: 7.5, color: XuiColors.textMuted)),
          Transform.scale(
            scale: Scale.of(context) * 0.6,
            child: Switch(
              value: enabled,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFFD69A6C),
              onChanged: (_) => c.toggleMod(file),
            ),
          ),
          IconButton(
            tooltip: 'Удалить мод',
            iconSize: context.u(13),
            color: Colors.white70,
            onPressed: () => c.deleteMod(file),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
    );
  }
}
