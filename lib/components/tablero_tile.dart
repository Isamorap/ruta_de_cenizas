import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import '../ruta_de_cenizas_game.dart';
import '../models/tile_type.dart';
import '../models/item_type.dart';
import '../utils/perspective_utils.dart';

class TableroTile extends Component with HasGameReference<RutaDeCenizasGame> {
  final int row;
  final double col;
  final TileType type;
  final int index;
  final Color surfaceColor;
  final ItemType? item;
  bool isRevealed = false;
  bool isVisited = false;
  bool itemCollected = false;
  final double blockHeight = 40.0;

  TableroTile({
    required this.row,
    required this.col,
    required this.type,
    required this.index,
    required this.surfaceColor,
    this.item,
    this.isRevealed = false,
  });

  @override
  void render(Canvas canvas) {
    final screenSize = game.canvasSize.toSize();
    final offset = game.cameraRowOffset;
    
    // Calculate 4 corners of the TOP face
    final p1 = PerspectiveUtils.project(row.toDouble(), col - 0.5, screenSize, cameraRowOffset: offset);
    final p2 = PerspectiveUtils.project(row.toDouble(), col + 0.5, screenSize, cameraRowOffset: offset);
    final p3 = PerspectiveUtils.project(row.toDouble() + 1, col + 0.5, screenSize, cameraRowOffset: offset);
    final p4 = PerspectiveUtils.project(row.toDouble() + 1, col - 0.5, screenSize, cameraRowOffset: offset);

    final topPath = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..lineTo(p4.dx, p4.dy)
      ..close();

    // Front Face (Thickness)
    final scaleFront = PerspectiveUtils.getScale(row.toDouble(), cameraRowOffset: offset);
    final h = blockHeight * scaleFront;
    
    final pf1 = Offset(p1.dx, p1.dy + h);
    final pf2 = Offset(p2.dx, p2.dy + h);

    final frontPath = Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(pf2.dx, pf2.dy)
      ..lineTo(pf1.dx, pf1.dy)
      ..close();

    // Side Face (only if not centered)
    Path? sidePath;
    if (col != 0) {
      if (col > 0) {
        // Right of center, show left side
        sidePath = Path()
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(pf1.dx, pf1.dy)
          ..lineTo(PerspectiveUtils.project(row + 1, col - 0.5, screenSize, cameraRowOffset: offset).dx, PerspectiveUtils.project(row + 1, col - 0.5, screenSize, cameraRowOffset: offset).dy + h) // approx
          ..lineTo(p4.dx, p4.dy)
          ..close();
      } else {
        // Left of center, show right side
        sidePath = Path()
          ..moveTo(p2.dx, p2.dy)
          ..lineTo(pf2.dx, pf2.dy)
          ..lineTo(PerspectiveUtils.project(row + 1, col + 0.5, screenSize, cameraRowOffset: offset).dx, PerspectiveUtils.project(row + 1, col + 0.5, screenSize, cameraRowOffset: offset).dy + h) // approx
          ..lineTo(p3.dx, p3.dy)
          ..close();
      }
    }

    // Paints
    final topPaint = Paint()..color = _getTileColor();
    final frontPaint = Paint()..color = _getTileColor().withAlpha(180);
    final sidePaint = Paint()..color = _getTileColor().withAlpha(120);
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw faces
    if (sidePath != null) canvas.drawPath(sidePath, sidePaint);
    canvas.drawPath(frontPath, frontPaint);
    canvas.drawPath(topPath, topPaint);
    
    if (isVisited) {
      _drawAshTrail(canvas, p1, p2, p3, p4);
    }
    
    // Draw borders for definition
    canvas.drawPath(topPath, borderPaint);
    canvas.drawPath(frontPath, borderPaint);

    // Draw index number
    if (isVisited) {
      _drawIndex(canvas, p1, p2, p3, p4);
    }

    if (isRevealed && type == TileType.consumible && !itemCollected && item != null) {
      _drawItemIcon(canvas, p1, p2, p3, p4);
    }
  }

  void _drawItemIcon(Canvas canvas, Offset p1, Offset p2, Offset p3, Offset p4) {
    final centerX = (p1.dx + p2.dx + p3.dx + p4.dx) / 4;
    final centerY = (p1.dy + p2.dy + p3.dy + p4.dy) / 4;

    IconData icon;
    Color color;

    switch (item!) {
      case ItemType.zapatosDeEscalada:
        icon = Icons.hiking;
        color = const Color(0xFF8B4513); // Brown
        break;
      case ItemType.lazoDelMalvado:
        icon = Icons.all_inclusive; // representing lasso
        color = const Color(0xFF8A2BE2); // Purple
        break;
      case ItemType.voluntadDeLosAntiguos:
        icon = Icons.shield;
        color = const Color(0xFFFFD700); // Gold
        break;
    }

    // Paint background circle
    canvas.drawCircle(Offset(centerX, centerY), 12, Paint()..color = Colors.white.withValues(alpha: 0.8));
    canvas.drawCircle(Offset(centerX, centerY), 12, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);

    // Draw icon using text painter since it's an IconData
    final iconString = String.fromCharCode(icon.codePoint);
    final span = TextSpan(
      text: iconString,
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: 16,
        color: color,
      ),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(centerX - tp.width / 2, centerY - tp.height / 2));
  }

  void _drawIndex(Canvas canvas, Offset p1, Offset p2, Offset p3, Offset p4) {
    final centerX = (p1.dx + p2.dx + p3.dx + p4.dx) / 4;
    final centerY = (p1.dy + p2.dy + p3.dy + p4.dy) / 4;

    final span = TextSpan(
      text: index.toString(),
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.15),
        fontSize: 10,
        fontWeight: FontWeight.normal,
      ),
    );
    final tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(centerX - tp.width / 2, centerY - tp.height / 2));
  }

  void _drawAshTrail(Canvas canvas, Offset p1, Offset p2, Offset p3, Offset p4) {
    // Draw some random-looking dark gray spots to represent ash accumulation
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.2);
    
    // We can just draw a few small circles near the center
    final centerX = (p1.dx + p2.dx + p3.dx + p4.dx) / 4;
    final centerY = (p1.dy + p2.dy + p3.dy + p4.dy) / 4;
    
    canvas.drawCircle(Offset(centerX - 5, centerY + 2), 3, paint);
    canvas.drawCircle(Offset(centerX + 8, centerY - 4), 2, paint);
    canvas.drawCircle(Offset(centerX - 2, centerY - 6), 4, paint);
  }

  Color _getTileColor() {
    if (!isRevealed) return const Color(0xFF242424); // Dark charcoal for unknown

    switch (type) {
      case TileType.barranco:
        return const Color(0xFFB22222); 
      case TileType.atajo:
        return const Color(0xFF4682B4); 
      case TileType.suceso:
        return const Color(0xFFC0C0C0);
      case TileType.historia:
        return const Color(0xFFDAA520); // Amber/Golden for history
      case TileType.consumible:
        return const Color(0xFF9370DB); // Medium purple for items
      case TileType.normal:
        return surfaceColor; 
    }
  }
}
