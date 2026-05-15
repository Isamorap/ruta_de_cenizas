import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flame/components.dart';
import '../ruta_de_cenizas_game.dart';
import '../models/tile_type.dart';
import '../models/item_type.dart';
import '../utils/perspective_utils.dart';

class TableroTile extends PositionComponent with HasGameReference<RutaDeCenizasGame> {
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
  void onMount() {
    super.onMount();
    // Establecer un tamaño grande para que el componente no sea descartado por 'culling'
    // ya que usamos coordenadas absolutas proyectadas.
    size = game.canvasSize;
  }

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
    final baseColor = _getTileColor();
    final topPaint = Paint()..color = baseColor;
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.8) // Borde más marcado
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Draw face (Solo la cara superior para estilo Flat)
    canvas.drawPath(topPath, topPaint);

    if (isRevealed) {
      // 1. Efecto de Relieve (Sutil para estilo Flat)
      final lightPaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawLine(p1, p2, lightPaint);

      final rnd = math.Random(index);

      // 2. Textura de Ceniza
      _drawAshDetails(canvas, p1, p2, p3, p4, rnd);

      // 3. Grietas
      if (rnd.nextDouble() < 0.25) {
        _drawCracks(canvas, p1, p2, p3, p4, rnd);
      }

      // 4. Rocas Flat
      if (type == TileType.normal && rnd.nextDouble() < 0.15) {
        _drawFlatRock(canvas, p1, p2, p3, p4, rnd);
      }
    }
    
    // Draw borders (Solo el borde superior)
    canvas.drawPath(topPath, borderPaint);

    // Draw index
    if (isVisited) {
      _drawIndex(canvas, p1, p2, p3, p4);
    }

    if (isRevealed && type == TileType.consumible && !itemCollected && item != null) {
      _drawItemIcon(canvas, p1, p2, p3, p4);
    }
  }

  void _drawAshDetails(Canvas canvas, Offset p1, Offset p2, Offset p3, Offset p4, math.Random rnd) {
    final ashPaint = Paint()..color = Colors.black.withValues(alpha: 0.3);
    for (int i = 0; i < 12; i++) { // Aumentado a 12 puntos
      double u = rnd.nextDouble();
      double v = rnd.nextDouble();
      double x = (1 - u) * (1 - v) * p1.dx + u * (1 - v) * p2.dx + u * v * p3.dx + (1 - u) * v * p4.dx;
      double y = (1 - u) * (1 - v) * p1.dy + u * (1 - v) * p2.dy + u * v * p3.dy + (1 - u) * v * p4.dy;
      canvas.drawCircle(Offset(x, y), 0.3 + rnd.nextDouble() * 2.0, ashPaint);
    }
  }

  void _drawCracks(Canvas canvas, Offset p1, Offset p2, Offset p3, Offset p4, math.Random rnd) {
    final crackPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    double u = 0.2 + rnd.nextDouble() * 0.6;
    double v = 0.2 + rnd.nextDouble() * 0.6;
    double startX = (1 - u) * (1 - v) * p1.dx + u * (1 - v) * p2.dx + u * v * p3.dx + (1 - u) * v * p4.dx;
    double startY = (1 - u) * (1 - v) * p1.dy + u * (1 - v) * p2.dy + u * v * p3.dy + (1 - u) * v * p4.dy;

    void branch(double x, double y, int depth) {
      if (depth <= 0) return;
      double endX = x + (rnd.nextDouble() - 0.5) * 25;
      double endY = y + (rnd.nextDouble() - 0.5) * 20;
      canvas.drawLine(Offset(x, y), Offset(endX, endY), crackPaint);
      if (rnd.nextDouble() < 0.6) branch(endX, endY, depth - 1);
      if (rnd.nextDouble() < 0.3) branch(endX, endY, depth - 1); // Ramificación extra
    }

    branch(startX, startY, 4);
  }

  void _drawFlatRock(Canvas canvas, Offset p1, Offset p2, Offset p3, Offset p4, math.Random rnd) {
    final scale = PerspectiveUtils.getScale(row.toDouble(), cameraRowOffset: game.cameraRowOffset);
    final rockSize = (10 + rnd.nextDouble() * 12) * scale;
    double cx = (p1.dx + p2.dx + p3.dx + p4.dx) / 4;
    double cy = (p1.dy + p2.dy + p3.dy + p4.dy) / 4;

    final rockPaint = Paint()..color = const Color(0xFF222222);
    final shadePaint = Paint()..color = Colors.black.withValues(alpha: 0.3);
    
    final rockPath = Path();
    int sides = 3 + rnd.nextInt(4);
    List<Offset> points = [];
    for (int i = 0; i < sides; i++) {
      double angle = (i * 2 * math.pi / sides) + rnd.nextDouble() * 0.5;
      double dist = rockSize * (0.8 + rnd.nextDouble() * 0.4);
      points.add(Offset(cx + math.cos(angle) * dist, cy + math.sin(angle) * dist));
    }
    
    rockPath.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) rockPath.lineTo(points[i].dx, points[i].dy);
    rockPath.close();

    canvas.drawPath(rockPath, rockPaint);
    
    // Sombreado de "volumen" en la roca
    final shadowPath = Path()..moveTo(cx, cy);
    shadowPath.lineTo(points[rnd.nextInt(points.length)].dx, points[rnd.nextInt(points.length)].dy);
    shadowPath.lineTo(points[rnd.nextInt(points.length)].dx, points[rnd.nextInt(points.length)].dy);
    shadowPath.close();
    canvas.drawPath(shadowPath, shadePaint);

    canvas.drawPath(rockPath, Paint()..color = Colors.white12..style = PaintingStyle.stroke..strokeWidth = 0.5);
  }

  void _drawItemIcon(Canvas canvas, Offset p1, Offset p2, Offset p3, Offset p4) {
    final centerX = (p1.dx + p2.dx + p3.dx + p4.dx) / 4;
    final centerY = (p1.dy + p2.dy + p3.dy + p4.dy) / 4;

    IconData icon;
    Color color;

    switch (item!) {
      case ItemType.zapatosDeEscalada:
        icon = Icons.hiking;
        color = const Color(0xFF8B4513);
        break;
      case ItemType.lazoDelMalvado:
        icon = Icons.all_inclusive;
        color = const Color(0xFF8A2BE2);
        break;
      case ItemType.voluntadDeLosAntiguos:
        icon = Icons.shield;
        color = const Color(0xFFFFD700);
        break;
    }

    canvas.drawCircle(Offset(centerX, centerY), 12, Paint()..color = Colors.white.withValues(alpha: 0.8));
    canvas.drawCircle(Offset(centerX, centerY), 12, Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = 2);

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

    final tp = TextPainter(
      text: TextSpan(
        text: index.toString(),
        style: TextStyle(color: Colors.white.withValues(alpha: 0.15), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    );
    tp.layout();
    tp.paint(canvas, Offset(centerX - tp.width / 2, centerY - tp.height / 2));
  }

  void _drawAshTrail(Canvas canvas, Offset p1, Offset p2, Offset p3, Offset p4) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.2);
    final centerX = (p1.dx + p2.dx + p3.dx + p4.dx) / 4;
    final centerY = (p1.dy + p2.dy + p3.dy + p4.dy) / 4;
    canvas.drawCircle(Offset(centerX - 5, centerY + 2), 3, paint);
    canvas.drawCircle(Offset(centerX + 8, centerY - 4), 2, paint);
    canvas.drawCircle(Offset(centerX - 2, centerY - 6), 4, paint);
  }

  Color _getTileColor() {
    if (!isRevealed) return const Color(0xFF242424);
    switch (type) {
      case TileType.barranco: return const Color(0xFF1A1A1A);
      case TileType.atajo: return const Color(0xFF2C3E50);
      case TileType.historia: return const Color(0xFF4A4439);
      case TileType.consumible: return const Color(0xFF3D2B56);
      default: return surfaceColor;
    }
  }
}
