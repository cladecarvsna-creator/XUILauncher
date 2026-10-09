import 'package:flutter/material.dart';

import '../core/launcher_controller.dart';
import '../core/models.dart';
import 'theme.dart';
import 'widgets/glass.dart';
import 'widgets/pixel_art.dart';

/// Dialog frame in the launcher palette.
class XuiDialog extends StatelessWidget {
  const XuiDialog({
    super.key,
    required this.title,
    required this.child,
    required this.actions,
    this.width = 380,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: context.u(width),
        padding: EdgeInsets.all(context.u(14)),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(context.u(18)),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFA2603C), Color(0xFF8E4C30)],
          ),
          border: Border.all(color: const Color(0x55FFD9BC)),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 30, offset: Offset(0, 10)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title.toUpperCase(),
                style: xuiText(context, size: 13, color: Colors.white)),
            SizedBox(height: context.u(12)),
            child,
            SizedBox(height: context.u(14)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                for (final a in actions) ...[SizedBox(width: context.u(6)), a],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

Text _label(BuildContext context, String text) => Text(text,
    style: xuiText(context, size: 8, color: XuiColors.textMuted, letterSpacing: 0.8));

/// Creates a build, or edits [edit] when given.
Future<void> showNewBuildDialog(
  BuildContext context,
  LauncherController c, {
  GameBuild? edit,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _NewBuildDialog(c: c, edit: edit),
  );
}

class _NewBuildDialog extends StatefulWidget {
  const _NewBuildDialog({required this.c, this.edit});

  final LauncherController c;
  final GameBuild? edit;

  @override
  State<_NewBuildDialog> createState() => _NewBuildDialogState();
}

class _NewBuildDialogState extends State<_NewBuildDialog> {
  late final _name = TextEditingController(
      text: widget.edit?.name ?? 'Сборка ${widget.c.builds.length + 1}');
  final _search = TextEditingController();
  late ModLoader _loader = widget.edit?.loader ?? ModLoader.vanilla;
  late bool _snapshots = widget.c.settings.showSnapshots;
  late String? _version = widget.edit?.mcVersion ??
      widget.c.versions.where((v) => v.isRelease).firstOrNull?.id;
  late int _icon = widget.edit?.iconIndex ?? widget.c.builds.length % BlockIcon.count;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final q = _search.text.trim();
    final versions = c.versions
        .where((v) => (_snapshots || v.isRelease) && (q.isEmpty || v.id.contains(q)))
        .toList();
    return XuiDialog(
      title: widget.edit == null ? 'Новая сборка' : 'Изменить сборку',
      width: 400,
      actions: [
        GlassButton(
          label: 'Отмена',
          glass: Glass.rose,
          height: 26,
          fontSize: 9.5,
          onTap: () => Navigator.pop(context),
        ),
        GlassButton(
          label: widget.edit == null ? 'Создать' : 'Сохранить',
          glass: Glass.play,
          height: 26,
          fontSize: 9.5,
          onTap: _version == null || _name.text.trim().isEmpty ? null : _submit,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(context, 'НАЗВАНИЕ'),
          SizedBox(height: context.u(5)),
          Row(
            children: [
              MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => setState(() => _icon = (_icon + 1) % BlockIcon.count),
                  child: Tooltip(
                    message: 'Сменить иконку',
                    child: BlockIcon(index: _icon, size: context.u(26)),
                  ),
                ),
              ),
              SizedBox(width: context.u(8)),
              Expanded(
                child: GlassField(
                  controller: _name,
                  autofocus: widget.edit == null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          SizedBox(height: context.u(12)),
          _label(context, 'ЗАГРУЗЧИК'),
          SizedBox(height: context.u(5)),
          Row(
            children: [
              for (final l in ModLoader.values) ...[
                GlassButton(
                  label: l.title,
                  glass: _loader == l ? Glass.play : Glass.rose,
                  height: 24,
                  width: 90,
                  fontSize: 9,
                  onTap: () => setState(() => _loader = l),
                ),
                SizedBox(width: context.u(6)),
              ],
            ],
          ),
          SizedBox(height: context.u(12)),
          Row(
            children: [
              _label(context, 'ВЕРСИЯ MINECRAFT'),
              const Spacer(),
              _label(context, 'СНАПШОТЫ'),
              Transform.scale(
                scale: Scale.of(context) * 0.6,
                child: Switch(
                  value: _snapshots,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFFD69A6C),
                  onChanged: (v) => setState(() => _snapshots = v),
                ),
              ),
            ],
          ),
          GlassField(
            controller: _search,
            hint: 'Поиск версии',
            prefix: Icon(Icons.search_rounded,
                size: context.u(12), color: XuiColors.text),
            onChanged: (_) => setState(() {}),
          ),
          SizedBox(height: context.u(6)),
          SizedBox(
            height: context.u(130),
            child: GlassPanel(
              padding: EdgeInsets.all(context.u(4)),
              child: c.versions.isEmpty
                  ? Center(
                      child: Text(c.versionsError ?? 'Загрузка…',
                          style: xuiText(context,
                              size: 8.5, color: XuiColors.textMuted)))
                  : ListView.builder(
                      itemCount: versions.length,
                      itemBuilder: (context, i) {
                        final v = versions[i];
                        final sel = v.id == _version;
                        return InkWell(
                          borderRadius: BorderRadius.circular(context.u(8)),
                          onTap: () => setState(() => _version = v.id),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: context.u(8), vertical: context.u(5)),
                            decoration: BoxDecoration(
                              color: sel ? const Color(0x33FFE2C8) : null,
                              borderRadius: BorderRadius.circular(context.u(8)),
                            ),
                            child: Row(
                              children: [
                                Text(v.id,
                                    style: xuiText(context,
                                        size: 9, color: Colors.white)),
                                const Spacer(),
                                Text(
                                  v.isRelease ? 'релиз' : v.type,
                                  style: xuiText(context,
                                      size: 7.5, color: XuiColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          if (_loader == ModLoader.fabric)
            Padding(
              padding: EdgeInsets.only(top: context.u(6)),
              child: Text(
                'Fabric установится при первом запуске. Моды ставятся из «Каталог Модов».',
                style: xuiText(context, size: 7.5, color: XuiColors.textMuted),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    final c = widget.c;
    final e = widget.edit;
    final name = _name.text.trim();
    if (e == null) {
      final b = await c.createBuild(name: name, version: _version!, loader: _loader);
      b.iconIndex = _icon;
      await c.updateBuild(b);
    } else {
      if (e.mcVersion != _version || e.loader != _loader) e.loaderVersion = null;
      e
        ..name = name
        ..mcVersion = _version!
        ..loader = _loader
        ..iconIndex = _icon;
      await c.updateBuild(e);
    }
    if (mounted) Navigator.pop(context);
  }
}

Future<void> confirmDeleteBuild(
  BuildContext context,
  LauncherController c,
  GameBuild b,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => XuiDialog(
      title: 'Удалить сборку?',
      width: 330,
      actions: [
        GlassButton(
          label: 'Отмена',
          glass: Glass.rose,
          height: 26,
          fontSize: 9.5,
          onTap: () => Navigator.pop(context),
        ),
        GlassButton(
          label: 'Удалить',
          glass: Glass.play,
          height: 26,
          fontSize: 9.5,
          onTap: () {
            Navigator.pop(context);
            c.deleteBuild(b);
          },
        ),
      ],
      child: Text(
        '«${b.name}» и её папка (миры, моды, настройки) будут удалены навсегда.',
        style: xuiText(context, size: 9, color: Colors.white, height: 1.5),
      ),
    ),
  );
}

Future<void> showNewsDialog(BuildContext context, NewsItem item) {
  return showDialog<void>(
    context: context,
    builder: (context) => XuiDialog(
      title: item.title,
      width: 460,
      actions: [
        GlassButton(
          label: 'Закрыть',
          glass: Glass.rose,
          height: 26,
          fontSize: 9.5,
          onTap: () => Navigator.pop(context),
        ),
      ],
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: context.u(260)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (item.imageUrl != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(context.u(10)),
                  child: Image.network(item.imageUrl!,
                      height: context.u(120),
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox()),
                ),
              SizedBox(height: context.u(8)),
              Text(item.text,
                  style: xuiText(context, size: 8.5, color: Colors.white, height: 1.6)),
            ],
          ),
        ),
      ),
    ),
  );
}
