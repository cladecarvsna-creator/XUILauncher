import 'package:flutter/material.dart';

/// Palette sampled from the reference design.
abstract final class XuiColors {
  static const background = Color(0xFF955432);
  static const backgroundTop = Color(0xFF965433);
  static const backgroundWarm = Color(0xFF965B32);
  static const backgroundRed = Color(0xFF934C33);
  static const text = Color(0xFF1C1612);
  static const textOnBg = Colors.white;
  static const textMuted = Color(0xCCFFFFFF);
  static const panel = Color(0x14FFFFFF);
  static const panelBorder = Color(0x26FFFFFF);
  static const accent = Color(0xFFE8B48C);
  static const danger = Color(0xFF7A2A1A);
}

const fontFamily = 'Unbounded';

/// The whole UI is laid out in the units of the reference screenshot
/// (854x493 window) and scaled with the window, so proportions always match.
class Scale extends InheritedWidget {
  const Scale({super.key, required this.k, required super.child});

  static const designWidth = 854.0;
  static const designHeight = 493.0;

  final double k;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<Scale>()?.k ?? 1;

  @override
  bool updateShouldNotify(Scale oldWidget) => oldWidget.k != k;
}

extension ScaleX on BuildContext {
  /// Converts design units to logical pixels.
  double u(double v) => v * Scale.of(this);
}

TextStyle xuiText(
  BuildContext context, {
  double size = 10.5,
  Color color = XuiColors.text,
  FontWeight weight = FontWeight.w400,
  double? height,
  double letterSpacing = 0,
}) =>
    TextStyle(
      fontFamily: fontFamily,
      fontSize: context.u(size),
      color: color,
      fontWeight: weight,
      height: height,
      letterSpacing: letterSpacing,
    );

ThemeData buildTheme() => ThemeData(
      fontFamily: fontFamily,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: XuiColors.background,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: Colors.transparent,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: Colors.white,
        selectionColor: Color(0x55FFFFFF),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(const Color(0x55FFFFFF)),
        radius: const Radius.circular(8),
        thickness: WidgetStateProperty.all(4),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: Color(0xEE3A2014),
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        textStyle: TextStyle(fontFamily: fontFamily, fontSize: 11, color: Colors.white),
      ),
    );
