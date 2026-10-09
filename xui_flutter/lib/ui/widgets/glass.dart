import 'package:flutter/material.dart';

import '../theme.dart';

/// The glossy pill materials used in the reference design.
enum Glass {
  /// Top bar: warm orange, same tone as the play button.
  bar(
    body: [Color(0xFFBA805A), Color(0xFFC98F69)],
    rim: [Color(0xFFC58B65), Color(0xFFE4AA83)],
  ),

  /// Top menu buttons: light beige.
  light(
    body: [Color(0xFFC9A992), Color(0xFFD9B9A3)],
    rim: [Color(0xFFD9B8A2), Color(0xFFEDCCB4)],
    outline: Color(0x55703516),
  ),

  /// Bottom-left buttons: pinkish beige.
  rose(
    body: [Color(0xFFC4A396), Color(0xFFD5B4A7)],
    rim: [Color(0xFFD3B2A5), Color(0xFFE6C5B8)],
    outline: Color(0x66652A18),
  ),

  /// Progress/status track.
  track(
    body: [Color(0xFFC4A893), Color(0xFFD8BCA8)],
    rim: [Color(0xFFF5D1B7), Color(0xFFDFC3AF)],
    outline: Color(0x88733F1E),
  ),

  /// The big play button.
  play(
    body: [Color(0xFFB98258), Color(0xFFCC946B)],
    rim: [Color(0xFFC79066), Color(0xFFDFA77D)],
    outline: Color(0xCC7E441F),
  );

  const Glass({required this.body, required this.rim, this.outline});

  final List<Color> body;
  final List<Color> rim;
  final Color? outline;
}

/// A pill with a vertical gloss gradient and a 1px light rim.
class GlassBox extends StatelessWidget {
  const GlassBox({
    super.key,
    required this.glass,
    this.child,
    this.width,
    this.height,
    this.radius,
    this.padding,
    this.brightness = 0,
  });

  final Glass glass;
  final Widget? child;
  final double? width;
  final double? height;

  /// In design units; defaults to a full pill.
  final double? radius;
  final EdgeInsetsGeometry? padding;

  /// -1..1, used for hover/press feedback.
  final double brightness;

  Color _shade(Color c) => brightness >= 0
      ? Color.lerp(c, Colors.white, brightness)!
      : Color.lerp(c, Colors.black, -brightness)!;

  @override
  Widget build(BuildContext context) {
    final r = radius == null
        ? BorderRadius.circular(context.u(100))
        : BorderRadius.circular(context.u(radius!));
    final rimWidth = context.u(1).clamp(1.0, 2.0);
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: glass.rim.map(_shade).toList(),
        ),
        boxShadow: [
          if (glass.outline != null)
            BoxShadow(color: glass.outline!, spreadRadius: rimWidth * 0.8),
          BoxShadow(
            color: const Color(0x33401A08),
            blurRadius: context.u(3),
            offset: Offset(0, context.u(1)),
          ),
        ],
      ),
      padding: EdgeInsets.all(rimWidth),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: r,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: glass.body.map(_shade).toList(),
          ),
        ),
        padding: padding,
        alignment: Alignment.center,
        child: child,
      ),
    );
  }
}

/// Clickable glass pill with a text label.
class GlassButton extends StatefulWidget {
  const GlassButton({
    super.key,
    required this.label,
    required this.onTap,
    this.glass = Glass.light,
    this.width,
    required this.height,
    this.fontSize = 10.5,
    this.active = false,
    this.tooltip,
    this.leading,
  });

  final String label;
  final VoidCallback? onTap;
  final Glass glass;

  /// Design units; null = fit the label.
  final double? width;
  final double height;
  final double fontSize;

  /// Highlighted (e.g. the current page).
  final bool active;
  final String? tooltip;
  final Widget? leading;

  @override
  State<GlassButton> createState() => _GlassButtonState();
}

class _GlassButtonState extends State<GlassButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    var b = 0.0;
    if (widget.active) b += 0.16;
    if (_hover && enabled) b += 0.08;
    if (_down && enabled) b = -0.06;

    Widget label = Text(
      widget.label,
      maxLines: 1,
      style: xuiText(
        context,
        size: widget.fontSize,
        color: enabled ? XuiColors.text : XuiColors.text.withValues(alpha: 0.45),
      ),
    );
    if (widget.leading != null) {
      label = Row(
        mainAxisSize: MainAxisSize.min,
        children: [widget.leading!, SizedBox(width: context.u(4)), label],
      );
    }

    Widget button = MouseRegion(
      cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down && enabled ? 0.97 : 1,
          duration: const Duration(milliseconds: 90),
          child: GlassBox(
            glass: widget.glass,
            width: widget.width == null ? null : context.u(widget.width!),
            height: context.u(widget.height),
            brightness: b,
            padding: EdgeInsets.symmetric(horizontal: context.u(widget.height * 0.32)),
            child: FittedBox(fit: BoxFit.scaleDown, child: label),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      button = Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

/// Translucent panel used for the content invented for the middle area.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding,
    this.radius = 14,
    this.highlighted = false,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: padding ?? EdgeInsets.all(context.u(10)),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(context.u(radius)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: highlighted
              ? const [Color(0x33FFE2C8), Color(0x22FFE2C8)]
              : const [Color(0x16FFFFFF), Color(0x0CFFFFFF)],
        ),
        border: Border.all(
          color: highlighted ? const Color(0x77FFE2C8) : XuiColors.panelBorder,
          width: 1,
        ),
      ),
      child: child,
    );
  }
}

/// Text field styled to sit on glass panels.
class GlassField extends StatelessWidget {
  const GlassField({
    super.key,
    required this.controller,
    this.hint,
    this.onChanged,
    this.onSubmitted,
    this.prefix,
    this.keyboardType,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? prefix;
  final TextInputType? keyboardType;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return GlassBox(
      glass: Glass.track,
      height: context.u(26),
      padding: EdgeInsets.symmetric(horizontal: context.u(10)),
      child: Row(
        children: [
          if (prefix != null) ...[prefix!, SizedBox(width: context.u(6))],
          Expanded(
            child: TextField(
              controller: controller,
              autofocus: autofocus,
              onChanged: onChanged,
              onSubmitted: onSubmitted,
              keyboardType: keyboardType,
              cursorColor: XuiColors.text,
              style: xuiText(context, size: 10),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                hintText: hint,
                hintStyle: xuiText(context,
                    size: 10, color: XuiColors.text.withValues(alpha: 0.45)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Small label/value chip on panels.
class InfoChip extends StatelessWidget {
  const InfoChip(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: context.u(8), vertical: context.u(3.5)),
      decoration: BoxDecoration(
        color: const Color(0x1FFFFFFF),
        borderRadius: BorderRadius.circular(context.u(100)),
        border: Border.all(color: const Color(0x33FFFFFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: context.u(10), color: XuiColors.textMuted),
            SizedBox(width: context.u(4)),
          ],
          Text(text,
              style: xuiText(context, size: 8, color: XuiColors.textMuted)),
        ],
      ),
    );
  }
}
