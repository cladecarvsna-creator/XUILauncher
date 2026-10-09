import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/launcher_controller.dart';
import '../../core/errors.dart';
import '../../core/mod_catalog.dart';
import '../../core/models.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Mod catalog from minecraft-inside.ru, filtered to the selected build.
class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, required this.c});

  final LauncherController c;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _query = TextEditingController();
  List<ModEntry> _hits = [];
  int _page = 1;
  bool _loadingMore = false;
  bool _loading = false;
  String? _error;
  Timer? _debounce;
  final Set<String> _installing = {};
  final Set<String> _installed = {};
  String? _searchedFor;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final build = widget.c.selected;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final q = _query.text.trim();
      final hits = q.isEmpty
          ? await widget.c.catalog.browse(mcVersion: build?.mcVersion)
          : await widget.c.catalog.search(q, mcVersion: build?.mcVersion);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _page = 1;
        _searchedFor = build?.id;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Каталог недоступен. ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Next listing page (only when browsing, not searching).
  Future<void> _more() async {
    setState(() => _loadingMore = true);
    try {
      final next = await widget.c.catalog
          .browse(mcVersion: widget.c.selected?.mcVersion, page: _page + 1);
      if (!mounted) return;
      final have = _hits.map((m) => m.id).toSet();
      setState(() {
        _hits = [..._hits, ...next.where((m) => !have.contains(m.id))];
        _page++;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _install(ModEntry m) async {
    setState(() => _installing.add(m.id));
    try {
      await widget.c.installMod(m);
      _installed.add(m.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _installing.remove(m.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final build = widget.c.selected;
    if (build != null && _searchedFor != null && _searchedFor != build.id) {
      // Selected build changed while the page was open.
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
      _searchedFor = build.id;
    }
    final fabric = build?.loader == ModLoader.fabric;
    return GlassPanel(
      padding: EdgeInsets.all(context.u(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('КАТАЛОГ МОДОВ',
                  style: xuiText(context, size: 13, color: Colors.white)),
              SizedBox(width: context.u(10)),
              if (build != null)
                InfoChip('${build.name} · ${build.mcVersion} · ${build.loader.title}'),
              const Spacer(),
              SizedBox(
                width: context.u(240),
                child: GlassField(
                  controller: _query,
                  hint: 'Найти мод на minecraft-inside.ru',
                  prefix: Icon(Icons.search_rounded,
                      size: context.u(12), color: XuiColors.text),
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), _search);
                  },
                  onSubmitted: (_) => _search(),
                ),
              ),
            ],
          ),
          if (!fabric)
            Padding(
              padding: EdgeInsets.only(top: context.u(8)),
              child: Text(
                'Моды работают в сборках на Fabric. Создайте такую сборку или измените текущую.',
                style: xuiText(context, size: 8, color: const Color(0xFFFFE0C4)),
              ),
            ),
          SizedBox(height: context.u(10)),
          Expanded(child: _results(context, fabric)),
        ],
      ),
    );
  }

  Widget _results(BuildContext context, bool canInstall) {
    if (_loading && _hits.isEmpty) {
      return const Center(
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70));
    }
    if (_error != null) {
      return Center(
          child: Text(_error!,
              textAlign: TextAlign.center,
              style: xuiText(context, size: 9, color: XuiColors.textMuted)));
    }
    if (_hits.isEmpty) {
      return Center(
          child: Text('Ничего не найдено',
              style: xuiText(context, size: 9, color: XuiColors.textMuted)));
    }
    return LayoutBuilder(builder: (context, box) {
      final columns = (box.maxWidth / context.u(260)).floor().clamp(1, 4);
      final canLoadMore = _query.text.trim().isEmpty;
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: context.u(62),
          crossAxisSpacing: context.u(8),
          mainAxisSpacing: context.u(8),
        ),
        itemCount: _hits.length + (canLoadMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _hits.length) {
            return Center(
              child: GlassButton(
                label: _loadingMore ? 'Загрузка…' : 'Показать ещё',
                glass: Glass.rose,
                height: 26,
                fontSize: 8.5,
                onTap: _loadingMore ? null : _more,
              ),
            );
          }
          final m = _hits[i];
          final busy = _installing.contains(m.id);
          final done = _installed.contains(m.id);
          return GlassPanel(
            radius: 11,
            padding: EdgeInsets.all(context.u(7)),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(context.u(8)),
                  child: SizedBox.square(
                    dimension: context.u(44),
                    child: m.iconUrl == null
                        ? const ColoredBox(color: Color(0x22FFFFFF))
                        : Image.network(m.iconUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                const ColoredBox(color: Color(0x22FFFFFF))),
                  ),
                ),
                SizedBox(width: context.u(8)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(m.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: xuiText(context, size: 9, color: Colors.white)),
                      SizedBox(height: context.u(2)),
                      Text(m.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: xuiText(context,
                              size: 7, color: XuiColors.textMuted, height: 1.3)),
                      SizedBox(height: context.u(2)),
                      Text(
                          [
                            if (m.author.isNotEmpty) m.author,
                            if (m.versions.isNotEmpty) m.versions.take(4).join(', '),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: xuiText(context,
                              size: 6.5, color: const Color(0x99FFFFFF))),
                    ],
                  ),
                ),
                SizedBox(width: context.u(6)),
                GlassButton(
                  label: done
                      ? 'Готово'
                      : busy
                          ? '…'
                          : 'Установить',
                  glass: Glass.play,
                  height: 24,
                  fontSize: 8,
                  onTap: canInstall && !busy && !done ? () => _install(m) : null,
                ),
              ],
            ),
          );
        },
      );
    });
  }
}
