import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../ruta_de_cenizas_game.dart';
import '../utils/perspective_utils.dart';
import 'dart:math' as math;

enum DecorationType { deadTree, ashBush, charredRock }

class TileDecoration {
  final DecorationType type;
  final double seed;
  final double offsetCol;
  final double offsetRow;

  TileDecoration({
    required this.type,
    required this.seed,
    this.offsetCol = 0,
    this.offsetRow = 0,
  });
}

class DecorationRenderer {
  static void render(Canvas canvas, DecorationType type, double seed, Vector2 pos, double scale) {
    final rand = math.Random((seed * 1000).toInt());
    
    switch (type) {
      case DecorationType.deadTree:
        _drawDeadTree(canvas, pos, scale, rand);
        break;
      case DecorationType.ashBush:
        _drawAshBush(canvas, pos, scale, rand);
        break;
      case DecorationType.charredRock:
        _drawCharredRock(canvas, pos, scale, rand);
        break;
    }
  }

  static void _drawDeadTree(Canvas canvas, Vector2 pos, double scale, math.Random rand) {
    final height = (80 + rand.nextDouble() * 60) * scale;
    final paint = Paint()
      ..color = const Color(0xFF000000)
      ..strokeWidth = 4 * scale
      ..style = PaintingStyle.stroke;

    final path = Path();
    path.moveTo(pos.x, pos.y);
    path.lineTo(pos.x, pos.y - height);

    // Branches
    for (int i = 0; i < 4; i++) {
      final bHeight = height * (0.3 + rand.nextDouble() * 0.5);
      final side = rand.nextBool() ? 1 : -1;
      final angle = (0.3 + rand.nextDouble() * 0.6) * side;
      
      path.moveTo(pos.x, pos.y - bHeight);
      path.lineTo(
        pos.x + (30 * scale * side),
        pos.y - bHeight - (20 * scale),
      );
    }
    
    canvas.drawPath(path, paint);
  }

  static void _drawAshBush(Canvas canvas, Vector2 pos, double scale, math.Random rand) {
    final size = (25 + rand.nextDouble() * 15) * scale;
    final paint = Paint()
      ..color = const Color(0xFF080808)
      ..style = PaintingStyle.fill;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(pos.x, pos.y - size/2), width: size * 1.8, height: size),
      paint,
    );

    // Little sticks poking out
    final stickPaint = Paint()
      ..color = const Color(0xFF000000)
      ..strokeWidth = 1.5 * scale;
    
    for (int i = 0; i < 8; i++) {
      final angle = rand.nextDouble() * math.pi;
      final len = size * 0.9;
      canvas.drawLine(
        Offset(pos.x, pos.y - 2),
        Offset(pos.x + math.cos(angle) * len, pos.y - size/2 - math.sin(angle) * len),
        stickPaint,
      );
    }
  }

  static void _drawCharredRock(Canvas canvas, Vector2 pos, double scale, math.Random rand) {
    final size = (15 + rand.nextDouble() * 20) * scale;
    final paint = Paint()
      ..color = const Color(0xFF000000)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(pos.x - size, pos.y);
    path.lineTo(pos.x + size, pos.y);
    path.lineTo(pos.x + size * 0.6, pos.y - size * 0.9);
    path.lineTo(pos.x - size * 0.4, pos.y - size * 1.1);
    path.close();

    canvas.drawPath(path, paint);
    
    // Highlight
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * scale;
    canvas.drawPath(path, highlightPaint);
  }
}
