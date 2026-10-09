import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/launcher_controller.dart';
import '../theme.dart';
import '../widgets/glass.dart';

/// Game and launcher log.
class ConsolePage extends StatefulWidget {
  const ConsolePage({super.key, required this.c});

  final LauncherController c;

  @override
  State<ConsolePage> createState() => _ConsolePageState();
}

class _ConsolePageState extends State<ConsolePage> {
  final _scroll = ScrollController();
  bool _follow = true;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Color _lineColor(String l) {
    if (l.startsWith('[XUI]')) return const Color(0xFFFFD9B8);
    if (l.contains('ERROR') || l.contains('Exception')) return const Color(0xFFFFA28A);
    if (l.contains('WARN')) return const Color(0xFFFFE08A);
    return const Color(0xE6FFFFFF);
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.c.console;
    if (_follow) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
      });
    }
    return GlassPanel(
      padding: EdgeInsets.all(context.u(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('КОНСОЛЬ', style: xuiText(context, size: 13, color: Colors.white)),
              SizedBox(width: context.u(10)),
              InfoChip(widget.c.gameRunning ? 'игра запущена' : 'игра не запущена',
                  icon: Icons.circle),
              const Spacer(),
              GlassButton(
                label: _follow ? 'Автопрокрутка: вкл' : 'Автопрокрутка: выкл',
                glass: Glass.rose,
                height: 24,
                fontSize: 8,
                onTap: () => setState(() => _follow = !_follow),
              ),
              SizedBox(width: context.u(6)),
              GlassButton(
                label: 'Копировать',
                glass: Glass.rose,
                height: 24,
                fontSize: 8,
                onTap: () => Clipboard.setData(ClipboardData(text: lines.join('\n'))),
              ),
              SizedBox(width: context.u(6)),
              GlassButton(
                label: 'Очистить',
                glass: Glass.rose,
                height: 24,
                fontSize: 8,
                onTap: widget.c.clearConsole,
              ),
            ],
          ),
          SizedBox(height: context.u(8)),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0x40200C04),
                borderRadius: BorderRadius.circular(context.u(10)),
              ),
              padding: EdgeInsets.all(context.u(8)),
              child: lines.isEmpty
                  ? Center(
                      child: Text('Здесь появится лог игры после запуска',
                          style: xuiText(context, size: 8.5, color: XuiColors.textMuted)))
                  : SelectionArea(
                      child: ListView.builder(
                        controller: _scroll,
                        itemCount: lines.length,
                        itemBuilder: (context, i) => Text(
                          lines[i],
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: context.u(7.5),
                            height: 1.35,
                            color: _lineColor(lines[i]),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
