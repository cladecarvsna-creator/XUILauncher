import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import '../core/launcher_controller.dart';
import 'dialogs.dart';
import 'pages/catalog_page.dart';
import 'pages/console_page.dart';
import 'pages/home_page.dart';
import 'pages/my_mods_page.dart';
import 'pages/settings_page.dart';
import 'theme.dart';
import 'widgets/glass.dart';
import 'widgets/pixel_art.dart';

/// The launcher window: rounded warm background, top bar, page area and the
/// bottom controls, laid out exactly like the reference screenshot.
class LauncherShell extends StatelessWidget {
  const LauncherShell({super.key, required this.c});

  final LauncherController c;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => _Window(c: c),
    );
  }
}

class _Window extends StatelessWidget {
  const _Window({required this.c});

  final LauncherController c;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(context.u(16));
    return ClipRRect(
      borderRadius: radius,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [XuiColors.backgroundTop, XuiColors.background],
          ),
        ),
        child: Stack(
          children: [
            // Lower half: reddish on the left, warmer on the right.
            Positioned.fill(
              child: ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (r) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black],
                  stops: [0.35, 0.65],
                ).createShader(r),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        XuiColors.backgroundRed,
                        XuiColors.backgroundRed,
                        XuiColors.backgroundWarm,
                        XuiColors.background,
                      ],
                      stops: [0, 0.44, 0.56, 1],
                    ),
                  ),
                ),
              ),
            ),
            // Top bar.
            Positioned(
              left: context.u(10),
              right: context.u(6),
              top: context.u(7),
              height: context.u(38),
              child: _TopBar(c: c),
            ),
            // Page area between the bars.
            Positioned(
              left: context.u(11),
              right: context.u(11),
              top: context.u(53),
              bottom: context.u(84),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                layoutBuilder: (current, previous) => Stack(
                  fit: StackFit.expand,
                  children: [...previous, ?current],
                ),
                child: KeyedSubtree(
                  key: ValueKey(c.page),
                  child: _page(),
                ),
              ),
            ),
            // Bottom-left: new build.
            Positioned(
              left: context.u(11),
              bottom: context.u(37),
              child: GlassButton(
                label: '+ Новая сборка',
                glass: Glass.rose,
                width: 134,
                height: 32,
                fontSize: 11.5,
                onTap: () => showNewBuildDialog(context, c),
              ),
            ),
            // Bottom row: folder, delete, progress.
            Positioned(
              left: context.u(11),
              right: context.u(17),
              bottom: context.u(6),
              height: context.u(25),
              child: Row(
                children: [
                  GlassButton(
                    label: 'Папка',
                    glass: Glass.rose,
                    width: 61,
                    height: 25,
                    fontSize: 10.5,
                    tooltip: 'Открыть папку сборки',
                    onTap: () => c.openFolder(c.selected),
                  ),
                  SizedBox(width: context.u(4)),
                  GlassButton(
                    label: 'Удалить',
                    glass: Glass.rose,
                    width: 67,
                    height: 25,
                    fontSize: 10,
                    tooltip: 'Удалить выбранную сборку',
                    onTap: c.selected == null
                        ? null
                        : () => confirmDeleteBuild(context, c, c.selected!),
                  ),
                  SizedBox(width: context.u(5)),
                  Expanded(child: _ProgressBar(c: c)),
                ],
              ),
            ),
            // Play.
            Positioned(
              right: context.u(16),
              bottom: context.u(37),
              child: GlassButton(
                label: c.gameRunning
                    ? 'Стоп'
                    : c.busy
                        ? 'Загрузка'
                        : 'Играть',
                glass: Glass.play,
                width: 118,
                height: 41,
                fontSize: 19,
                onTap: c.busy ? null : c.play,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _page() => switch (c.page) {
        LauncherPage.home => HomePage(c: c),
        LauncherPage.catalog => CatalogPage(c: c),
        LauncherPage.myMods => MyModsPage(c: c),
        LauncherPage.settings => SettingsPage(c: c),
        LauncherPage.console => ConsolePage(c: c),
      };
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.c});

  final LauncherController c;

  @override
  Widget build(BuildContext context) {
    Widget nav(String label, double width, LauncherPage page) => GlassButton(
          label: label,
          width: width,
          height: 28,
          active: c.page == page,
          onTap: () => c.go(page),
        );

    final bar = GlassBox(
      glass: Glass.bar,
      padding: EdgeInsets.only(left: context.u(5), right: context.u(4)),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: () => c.go(LauncherPage.settings),
              child: Row(
                children: [
                  SteveAvatar(size: context.u(27)),
                  SizedBox(width: context.u(5)),
                  Text(
                    c.settings.nickname,
                    style: xuiText(context, size: 10, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _MenuButton(c: c),
          SizedBox(width: context.u(6)),
          nav('Каталог Модов', 114, LauncherPage.catalog),
          SizedBox(width: context.u(7)),
          nav('Мои моды', 79, LauncherPage.myMods),
          SizedBox(width: context.u(11)),
          nav('Настройки', 85, LauncherPage.settings),
          SizedBox(width: context.u(5)),
          nav('Консоль', 107, LauncherPage.console),
        ],
      ),
    );
    // The window has no system title bar, so the top bar moves it.
    return isDesktop ? DragToMoveArea(child: bar) : bar;
  }
}

bool get isDesktop => Platform.isLinux || Platform.isWindows || Platform.isMacOS;

/// "Меню": main page plus window actions (the window has no title bar).
class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.c});

  final LauncherController c;

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) {
      return GlassButton(
        label: 'Меню',
        width: 68,
        height: 28,
        active: c.page == LauncherPage.home,
        onTap: () async {
          final box = context.findRenderObject()! as RenderBox;
          final pos = box.localToGlobal(Offset(0, box.size.height + 6));
          final choice = await showMenu<String>(
            context: context,
            color: const Color(0xF2B07A55),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.u(12))),
            position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
            items: [
              _item(context, 'home', 'Главная', Icons.home_rounded),
              _item(context, 'folder', 'Папка лаунчера', Icons.folder_rounded),
              _item(context, 'min', 'Свернуть', Icons.minimize_rounded),
              _item(context, 'max', 'Развернуть', Icons.crop_square_rounded),
              _item(context, 'exit', 'Выход', Icons.close_rounded),
            ],
          );
          switch (choice) {
            case 'home':
              c.go(LauncherPage.home);
            case 'folder':
              await c.openFolder();
            case 'min':
              await windowManager.minimize();
            case 'max':
              if (await windowManager.isMaximized()) {
                await windowManager.unmaximize();
              } else {
                await windowManager.maximize();
              }
            case 'exit':
              await windowManager.close();
          }
        },
      );
    });
  }

  PopupMenuItem<String> _item(
          BuildContext context, String value, String label, IconData icon) =>
      PopupMenuItem(
        value: value,
        height: context.u(30),
        child: Row(
          children: [
            Icon(icon, size: context.u(13), color: XuiColors.text),
            SizedBox(width: context.u(8)),
            Text(label, style: xuiText(context, size: 9.5)),
          ],
        ),
      );
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.c});

  final LauncherController c;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      glass: Glass.track,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (c.progress != null)
              Align(
                alignment: Alignment.centerLeft,
                child: AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 200),
                  widthFactor: c.progress!.clamp(0, 1),
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(context.u(100)),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFD69A6C), Color(0xFFE9B38A)],
                      ),
                    ),
                  ),
                ),
              )
            else
              const _IndeterminateFill(),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: context.u(10)),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  c.status,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: xuiText(context,
                      size: 8, color: XuiColors.text.withValues(alpha: 0.7)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IndeterminateFill extends StatefulWidget {
  const _IndeterminateFill();

  @override
  State<_IndeterminateFill> createState() => _IndeterminateFillState();
}

class _IndeterminateFillState extends State<_IndeterminateFill>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      return AnimatedBuilder(
        animation: _a,
        builder: (context, _) {
          final w = box.maxWidth * 0.25;
          final x = (box.maxWidth + w) * _a.value - w;
          return Stack(children: [
            Positioned(
              left: x,
              top: 0,
              bottom: 0,
              width: w,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(context.u(100)),
                  gradient: const LinearGradient(colors: [
                    Color(0x00E9B38A),
                    Color(0xFFE2A97E),
                    Color(0x00E9B38A),
                  ]),
                ),
              ),
            ),
          ]);
        },
      );
    });
  }
}
