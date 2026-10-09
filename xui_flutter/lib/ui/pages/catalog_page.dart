import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/launcher_controller.dart';
import '../../core/errors.dart';
import '../../core/models.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Mod catalog backed by Modrinth, filtered to the selected build.
class CatalogPage extends StatefulWidget {
  const CatalogPage({super.key, required this.c});

  final LauncherController c;

  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  final _query = TextEditingController();
  List<ModrinthHit> _hits = [];
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
      final hits = await widget.c.api
          .searchMods(_query.text.trim(), mcVersion: build?.mcVersion);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _searchedFor = build?.id;
      });
    } catch (e) {
      if (mounted) setState(() => _error = 'Каталог недоступен. ${friendlyError(e)}');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _install(ModrinthHit m) async {
    setState(() => _installing.add(m.projectId));
    try {
      await widget.c.installMod(m);
      _installed.add(m.projectId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _installing.remove(m.projectId));
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
                  hint: 'Найти мод на Modrinth',
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
      return GridView.builder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: columns,
          mainAxisExtent: context.u(62),
          crossAxisSpacing: context.u(8),
          mainAxisSpacing: context.u(8),
        ),
        itemCount: _hits.length,
        itemBuilder: (context, i) {
          final m = _hits[i];
          final busy = _installing.contains(m.projectId);
          final done = _installed.contains(m.projectId);
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
                      Text('${m.author} · ${_downloads(m.downloads)}',
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

  static String _downloads(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M загрузок';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(0)}K загрузок';
    return '$n загрузок';
  }
}
