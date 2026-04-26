import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ruta_de_cenizas_game.dart';

class DiceComponent extends PositionComponent with TapCallbacks, HasGameReference<RutaDeCenizasGame> {
  int value1 = 1;
  int value2 = 1;
  int numDice = 1;
  bool isRolling = false;
  double rollTimer = 0;
  final Random _rand = Random();

  DiceComponent() : super(size: Vector2(130, 60), position: Vector2(20, 20));

  void roll({int diceCount = 1}) {
    numDice = diceCount;
    isRolling = true;
    rollTimer = 0.6; // Roll for 0.6 seconds
    HapticFeedback.lightImpact();
  }

  @override
  void update(double dt) {
    if (isRolling) {
      rollTimer -= dt;
      if (rollTimer <= 0) {
        isRolling = false;
        value1 = _rand.nextInt(6) + 1;
        value2 = _rand.nextInt(6) + 1;
        HapticFeedback.mediumImpact();
      } else {
        // Randomize values while rolling for visual effect
        value1 = _rand.nextInt(6) + 1;
        value2 = _rand.nextInt(6) + 1;
      }
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    game.rollAndMove();
  }

  @override
  void render(Canvas canvas) {
    final canRoll = !isRolling && !game.isMoving;
    final showTwoDice = numDice == 2;
    
    if (canRoll) {
      // Draw a subtle yellow glow individual to this die
      final glowPaint = Paint()
        ..color = Colors.yellow.withValues(alpha: 0.15 + (sin(game.elapsedTime * 5).abs() * 0.2))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      
      if (showTwoDice) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, 50, 50).inflate(4), const Radius.circular(10)), glowPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(70, 0, 50, 50).inflate(4), const Radius.circular(10)), glowPaint);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(40, 0, 50, 50).inflate(4), const Radius.circular(10)), glowPaint);
      }
    }

    if (showTwoDice) {
      _drawDie(canvas, Offset(0, 0), value1);
      _drawDie(canvas, Offset(70, 0), value2);
    } else {
      _drawDie(canvas, Offset(40, 0), value1);
    }
  }

  void _drawDie(Canvas canvas, Offset offset, int value) {
    final rect = Rect.fromLTWH(offset.dx, offset.dy, 50, 50);
    
    // Die background (Ash themed, worn)
    final paint = Paint()
      ..color = const Color(0xFF2F2F2F)
      ..style = PaintingStyle.fill;
    
    final borderPaint = Paint()
      ..color = const Color(0xFF555555)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    if (isRolling) {
      // Add jitter
      canvas.save();
      canvas.translate(_rand.nextDouble() * 4 - 2, _rand.nextDouble() * 4 - 2);
    }

    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), paint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(8)), borderPaint);

    // Draw dots
    final dotPaint = Paint()..color = const Color(0xFFC0C0C0);
    _drawDots(canvas, rect, value, dotPaint);

    if (isRolling) {
      canvas.restore();
    }
  }

  void _drawDots(Canvas canvas, Rect rect, int value, Paint paint) {
    final center = rect.center;
    final r = 4.0;
    final dist = 12.0;

    void dot(double dx, double dy) => canvas.drawCircle(center + Offset(dx, dy), r, paint);

    if (value % 2 != 0) dot(0, 0);
    if (value > 1) {
      dot(-dist, -dist);
      dot(dist, dist);
    }
    if (value > 3) {
      dot(dist, -dist);
      dot(-dist, dist);
    }
    if (value == 6) {
      dot(-dist, 0);
      dot(dist, 0);
    }
  }
}
