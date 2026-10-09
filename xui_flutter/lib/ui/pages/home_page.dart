import 'package:flutter/material.dart';

import '../../core/launcher_controller.dart';
import '../../core/models.dart';
import '../dialogs.dart';
import '../theme.dart';
import '../widgets/glass.dart';
import '../widgets/pixel_art.dart';

/// Main page: the list of builds on the left, the selected build in the
/// middle (styled like the headline of the reference) and news below it.
class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.c});

  final LauncherController c;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: context.u(206), child: _BuildList(c: c)),
        SizedBox(width: context.u(12)),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _Hero(c: c)),
              SizedBox(height: context.u(118), child: _News(c: c)),
            ],
          ),
        ),
      ],
    );
  }
}

class _BuildList extends StatelessWidget {
  const _BuildList({required this.c});

  final LauncherController c;

  @override
  Widget build(BuildContext context) {
    final selected = c.selected;
    return GlassPanel(
      padding: EdgeInsets.all(context.u(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
                context.u(4), context.u(2), context.u(4), context.u(8)),
            child: Row(
              children: [
                Text('СБОРКИ',
                    style: xuiText(context,
                        size: 9, color: Colors.white, weight: FontWeight.w500)),
                const Spacer(),
                Text('${c.builds.length}',
                    style: xuiText(context, size: 9, color: XuiColors.textMuted)),
              ],
            ),
          ),
          Expanded(
            child: c.builds.isEmpty
                ? Center(
                    child: Text(
                      c.versionsError ?? 'Загрузка версий…',
                      textAlign: TextAlign.center,
                      style: xuiText(context, size: 8.5, color: XuiColors.textMuted),
                    ),
                  )
                : ListView.separated(
                    itemCount: c.builds.length,
                    separatorBuilder: (_, _) => SizedBox(height: context.u(5)),
                    itemBuilder: (context, i) {
                      final b = c.builds[i];
                      return _BuildTile(
                        build: b,
                        selected: b.id == selected?.id,
                        onTap: () => c.select(b),
                        onDoubleTap: () {
                          c.select(b);
                          c.play();
                        },
                        onEdit: () => showNewBuildDialog(context, c, edit: b),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _BuildTile extends StatefulWidget {
  const _BuildTile({
    required this.build,
    required this.selected,
    required this.onTap,
    required this.onDoubleTap,
    required this.onEdit,
  });

  final GameBuild build;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;
  final VoidCallback onEdit;

  @override
  State<_BuildTile> createState() => _BuildTileState();
}

class _BuildTileState extends State<_BuildTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.build;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onSecondaryTap: widget.onEdit,
        child: GlassPanel(
          radius: 11,
          highlighted: widget.selected || _hover,
          padding: EdgeInsets.all(context.u(6)),
          child: Row(
            children: [
              BlockIcon(index: b.iconIndex, size: context.u(28)),
              SizedBox(width: context.u(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: xuiText(context, size: 9, color: Colors.white)),
                    SizedBox(height: context.u(2)),
                    Text('${b.mcVersion} · ${b.loader.title}',
                        style: xuiText(context,
                            size: 7.5, color: XuiColors.textMuted)),
                  ],
                ),
              ),
              if (widget.selected || _hover)
                IconButton(
                  tooltip: 'Изменить',
                  visualDensity: VisualDensity.compact,
                  iconSize: context.u(12),
                  color: Colors.white70,
                  onPressed: widget.onEdit,
                  icon: const Icon(Icons.edit_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.c});

  final LauncherController c;

  @override
  Widget build(BuildContext context) {
    final b = c.selected;
    final title = b == null ? 'СОЗДАЙ СВОЮ ПЕРВУЮ СБОРКУ' : b.name.toUpperCase();
    final last = b?.lastPlayed;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (b != null)
          Text('ВЫБРАННАЯ СБОРКА',
              style: xuiText(context,
                  size: 8, color: XuiColors.textMuted, letterSpacing: 1.5)),
        SizedBox(height: context.u(8)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: context.u(10)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: xuiText(context, size: 25, color: Colors.white),
            ),
          ),
        ),
        SizedBox(height: context.u(12)),
        if (b != null)
          Wrap(
            alignment: WrapAlignment.center,
            spacing: context.u(6),
            runSpacing: context.u(6),
            children: [
              InfoChip('Minecraft ${b.mcVersion}', icon: Icons.layers_rounded),
              InfoChip(
                b.loader == ModLoader.fabric && b.loaderVersion != null
                    ? 'Fabric ${b.loaderVersion}'
                    : b.loader.title,
                icon: Icons.extension_rounded,
              ),
              InfoChip('${(c.settings.memoryMb / 1024).toStringAsFixed(1)} ГБ ОЗУ',
                  icon: Icons.memory_rounded),
              InfoChip(
                last == null ? 'Ещё не запускалась' : 'Играли ${_ago(last)}',
                icon: Icons.schedule_rounded,
              ),
            ],
          ),
      ],
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'только что';
    if (d.inHours < 1) return '${d.inMinutes} мин назад';
    if (d.inDays < 1) return '${d.inHours} ч назад';
    return '${d.inDays} дн назад';
  }
}

class _News extends StatelessWidget {
  const _News({required this.c});

  final LauncherController c;

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (c.newsLoading) {
      body = const Center(
          child: SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70)));
    } else if (c.news.isEmpty) {
      // Offline: show launcher tips in place of the news cards.
      body = ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _tips.length,
        separatorBuilder: (_, _) => SizedBox(width: context.u(8)),
        itemBuilder: (context, i) => _TipCard(
          icon: _tips[i].$1,
          title: _tips[i].$2,
          text: _tips[i].$3,
          onTap: i == 0 ? c.refreshNews : null,
        ),
      );
    } else {
      body = ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: c.news.length,
        separatorBuilder: (_, _) => SizedBox(width: context.u(8)),
        itemBuilder: (context, i) => _NewsCard(item: c.news[i]),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: context.u(2), bottom: context.u(6)),
          child: Text(c.news.isEmpty && !c.newsLoading ? 'ПОДСКАЗКИ' : 'НОВОСТИ MINECRAFT',
              style: xuiText(context,
                  size: 8, color: XuiColors.textMuted, letterSpacing: 1.2)),
        ),
        Expanded(child: body),
      ],
    );
  }
}

class _NewsCard extends StatelessWidget {
  const _NewsCard({required this.item});

  final NewsItem item;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => showNewsDialog(context, item),
        child: SizedBox(
          width: context.u(176),
          child: GlassPanel(
            padding: EdgeInsets.zero,
            radius: 11,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(context.u(11)),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (item.imageUrl != null)
                    Image.network(
                      item.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const SizedBox(),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x00000000), Color(0xCC3A1A0C)],
                        stops: [0.3, 1],
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.all(context.u(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: xuiText(context,
                                size: 8.5, color: Colors.white, height: 1.25)),
                        if (item.category != null) ...[
                          SizedBox(height: context.u(3)),
                          Text(item.category!,
                              style: xuiText(context,
                                  size: 7, color: XuiColors.textMuted)),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _tips = [
  (Icons.wifi_off_rounded, 'Новости недоступны', 'Нажмите, чтобы попробовать ещё раз'),
  (Icons.ads_click_rounded, 'Двойной клик', 'по сборке сразу запускает игру'),
  (Icons.extension_rounded, 'Моды', 'ставятся в сборки на Fabric из «Каталог Модов»'),
  (Icons.coffee_rounded, 'Java не нужна', 'лаунчер сам скачает подходящую версию'),
  (Icons.edit_rounded, 'Правый клик', 'по сборке открывает её настройки'),
];

class _TipCard extends StatelessWidget {
  const _TipCard({
    required this.icon,
    required this.title,
    required this.text,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: context.u(150),
          child: GlassPanel(
            radius: 11,
            padding: EdgeInsets.all(context.u(9)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, size: context.u(16), color: const Color(0xFFFFE2C8)),
                const Spacer(),
                Text(title,
                    style: xuiText(context, size: 9, color: Colors.white)),
                SizedBox(height: context.u(3)),
                Text(text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: xuiText(context,
                        size: 7, color: XuiColors.textMuted, height: 1.35)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
