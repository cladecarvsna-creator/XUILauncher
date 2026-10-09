import 'package:flutter/material.dart';

import '../../core/launcher_controller.dart';
import '../../core/offline_uuid.dart';
import '../theme.dart';
import '../widgets/glass.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.c});

  final LauncherController c;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final s = widget.c.settings;
  late final _nick = TextEditingController(text: s.nickname);
  late final _java = TextEditingController(text: s.javaPath);
  late final _jvm = TextEditingController(text: s.jvmArgs);
  late final _w = TextEditingController(text: '${s.width}');
  late final _h = TextEditingController(text: '${s.height}');

  static final _nickPattern = RegExp(r'^[A-Za-z0-9_]{3,16}$');

  void _save() => widget.c.saveSettings();

  @override
  Widget build(BuildContext context) {
    final nickOk = _nickPattern.hasMatch(_nick.text);
    return GlassPanel(
      padding: EdgeInsets.all(context.u(12)),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('НАСТРОЙКИ', style: xuiText(context, size: 13, color: Colors.white)),
            SizedBox(height: context.u(12)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Section(
                    title: 'ИГРОК',
                    children: [
                      GlassField(
                        controller: _nick,
                        hint: 'Ник (3–16 символов: A-Z, 0-9, _)',
                        onChanged: (v) {
                          setState(() {});
                          if (_nickPattern.hasMatch(v)) {
                            s.nickname = v;
                            _save();
                          }
                        },
                      ),
                      SizedBox(height: context.u(5)),
                      Text(
                        nickOk
                            ? 'Офлайн-режим · UUID ${dashedUuid(offlineUuid(_nick.text))}'
                            : 'Ник должен быть 3–16 символов: латиница, цифры, _',
                        style: xuiText(context,
                            size: 7,
                            color: nickOk ? XuiColors.textMuted : const Color(0xFFFFD0B0)),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.u(14)),
                Expanded(
                  child: _Section(
                    title: 'ПАМЯТЬ · ${(s.memoryMb / 1024).toStringAsFixed(1)} ГБ',
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: const Color(0xFFE9B38A),
                          inactiveTrackColor: const Color(0x33FFFFFF),
                          thumbColor: Colors.white,
                          overlayColor: const Color(0x22FFFFFF),
                          trackHeight: context.u(4),
                        ),
                        child: Slider(
                          min: 1024,
                          max: 16384,
                          divisions: 30,
                          value: s.memoryMb.toDouble().clamp(1024, 16384),
                          onChanged: (v) => setState(() => s.memoryMb = v.round()),
                          onChangeEnd: (_) => _save(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: context.u(12)),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _Section(
                    title: 'JAVA',
                    children: [
                      GlassField(
                        controller: _java,
                        hint: 'Пусто = скачать нужную Java автоматически',
                        onChanged: (v) {
                          s.javaPath = v;
                          _save();
                        },
                      ),
                      SizedBox(height: context.u(6)),
                      GlassField(
                        controller: _jvm,
                        hint: 'Доп. аргументы JVM, например -XX:+UseG1GC',
                        onChanged: (v) {
                          s.jvmArgs = v;
                          _save();
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(width: context.u(14)),
                Expanded(
                  child: _Section(
                    title: 'ОКНО ИГРЫ',
                    children: [
                      Row(
                        children: [
                          Expanded(child: _numberField(_w, (v) => s.width = v)),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: context.u(6)),
                            child: Text('×',
                                style: xuiText(context, size: 10, color: Colors.white)),
                          ),
                          Expanded(child: _numberField(_h, (v) => s.height = v)),
                        ],
                      ),
                      _toggle(context, 'Полный экран', s.fullscreen,
                          (v) => s.fullscreen = v),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: context.u(8)),
            _Section(
              title: 'ЛАУНЧЕР',
              children: [
                _toggle(context, 'Закрывать лаунчер после запуска игры',
                    s.closeOnLaunch, (v) => s.closeOnLaunch = v),
                _toggle(context, 'Показывать снапшоты в списке версий',
                    s.showSnapshots, (v) => s.showSnapshots = v),
                Row(
                  children: [
                    Expanded(
                      child: Text(widget.c.paths.root,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: xuiText(context, size: 7.5, color: XuiColors.textMuted)),
                    ),
                    GlassButton(
                      label: 'Открыть папку',
                      glass: Glass.rose,
                      height: 24,
                      fontSize: 8.5,
                      onTap: () => widget.c.openFolder(),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController ctl, void Function(int) set) => GlassField(
        controller: ctl,
        keyboardType: TextInputType.number,
        onChanged: (v) {
          final n = int.tryParse(v);
          if (n != null && n > 0) {
            set(n);
            _save();
          }
        },
      );

  Widget _toggle(BuildContext context, String label, bool value, void Function(bool) set) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: xuiText(context, size: 8.5, color: Colors.white)),
        ),
        Transform.scale(
          scale: Scale.of(context) * 0.6,
          child: Switch(
            value: value,
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFFD69A6C),
            onChanged: (v) {
              setState(() => set(v));
              _save();
            },
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(title,
            style: xuiText(context,
                size: 7.5, color: XuiColors.textMuted, letterSpacing: 0.8)),
        SizedBox(height: context.u(6)),
        ...children,
      ],
    );
  }
}
