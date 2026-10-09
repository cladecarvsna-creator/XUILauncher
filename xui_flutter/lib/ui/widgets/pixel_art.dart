import 'package:flutter/material.dart';

/// Paints an 8x8 (or any square) grid of colors.
class _PixelPainter extends CustomPainter {
  _PixelPainter(this.rows, this.palette);

  final List<String> rows;
  final Map<String, Color> palette;

  @override
  void paint(Canvas canvas, Size size) {
    final n = rows.length;
    final cell = size.width / n;
    final paint = Paint()..isAntiAlias = false;
    for (var y = 0; y < n; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        paint.color = palette[rows[y][x]] ?? Colors.transparent;
        // Overlap by a hair so no seams show between cells when scaled.
        canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell + 0.5, cell + 0.5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_PixelPainter old) => old.rows != rows;
}

/// Steve's face, used as the player avatar.
class SteveAvatar extends StatelessWidget {
  const SteveAvatar({super.key, required this.size});

  final double size;

  static const _rows = [
    'HHHHHHHH',
    'HHHHHHHH',
    'HhSSSShH',
    'SSSSSSSS',
    'SWBSSBWS',
    'SSSNNSSS',
    'SSMmmMSS',
    'SSMMMMSS',
  ];
  static const _palette = {
    'H': Color(0xFF2E1F10),
    'h': Color(0xFF3E2A14),
    'S': Color(0xFFB98A6E),
    'W': Color(0xFFF2F2F2),
    'B': Color(0xFF4A3B86),
    'N': Color(0xFF8E5A44),
    'M': Color(0xFF5B3424),
    'm': Color(0xFF7A4A36),
  };

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: CustomPaint(
        size: Size.square(size),
        painter: _PixelPainter(_rows, _palette),
      ),
    );
  }
}

/// Pixel block icons for builds: grass, stone, wood, diamond, netherrack, tnt.
class BlockIcon extends StatelessWidget {
  const BlockIcon({super.key, required this.index, required this.size});

  final int index;
  final double size;

  static const _blocks = [
    // Grass block
    (
      ['GgGGgGGg', 'gGGgGGgG', 'DGdDgDGD', 'DDdDDdDD', 'dDDdDDDd', 'DDDDdDdD', 'DdDDDDDD', 'DDdDDdDD'],
      {'G': Color(0xFF6AA83E), 'g': Color(0xFF59932F), 'D': Color(0xFF8B5E3C), 'd': Color(0xFF6E4A2E)},
    ),
    // Stone
    (
      ['SSsSSSSs', 'SsSSdSSS', 'SSSsSSsS', 'dSSSSSSS', 'SSsSSdSS', 'SSSSsSSS', 'SdSSSSsS', 'SSSsSSSS'],
      {'S': Color(0xFF8E8E8E), 's': Color(0xFF7A7A7A), 'd': Color(0xFF6A6A6A)},
    ),
    // Oak planks
    (
      ['PPPPPPPP', 'pPPPpPPP', 'dddddddd', 'PPPpPPPP', 'PPPPPPpP', 'dddddddd', 'PpPPPPPP', 'PPPPpPPP'],
      {'P': Color(0xFFB48A52), 'p': Color(0xFF9C7542), 'd': Color(0xFF7A5A32)},
    ),
    // Diamond ore
    (
      ['SSsSSSSs', 'SDDSSSSS', 'SDdSSDDS', 'SSSSSDdS', 'SsSSSSSS', 'SSDDSSsS', 'SSDdSSSS', 'sSSSSSSS'],
      {'S': Color(0xFF8E8E8E), 's': Color(0xFF7A7A7A), 'D': Color(0xFF6FE3E0), 'd': Color(0xFF2FB5B0)},
    ),
    // Netherrack
    (
      ['RRrRRRRr', 'RrRRdRRR', 'RRRrRRrR', 'dRRRRRRR', 'RRrRRdRR', 'RRRRrRRR', 'RdRRRRrR', 'RRRrRRRR'],
      {'R': Color(0xFF8A3A36), 'r': Color(0xFF6F2C29), 'd': Color(0xFFA54B44)},
    ),
    // TNT
    (
      ['RRrRRrRR', 'RRrRRrRR', 'WWWWWWWW', 'WKKWKWKK', 'WWKWKWWK', 'WWWWWWWW', 'RRrRRrRR', 'RRrRRrRR'],
      {'R': Color(0xFFD0412E), 'r': Color(0xFFA83322), 'W': Color(0xFFEDEDED), 'K': Color(0xFF2A2A2A)},
    ),
  ];

  static int get count => _blocks.length;

  @override
  Widget build(BuildContext context) {
    final b = _blocks[index % _blocks.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: CustomPaint(size: Size.square(size), painter: _PixelPainter(b.$1, b.$2)),
    );
  }
}
