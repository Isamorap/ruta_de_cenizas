import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../ruta_de_cenizas_game.dart';

class DiceComponent extends PositionComponent
    with TapCallbacks, HasGameReference<RutaDeCenizasGame> {
  int value1 = 1;
  int value2 = 1;
  int numDice = 1;
  bool isRolling = false;
  double rollTimer = 0;
  final Random _rand = Random();

  DiceComponent() : super(size: Vector2(180, 80));

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    // Centrar horizontalmente y bajar un poco más para que no tape tanto
    position = Vector2((size.x - this.size.x) / 2, 80);
  }

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
    if (game.currentPlayer.isBot) return;
    game.rollAndMove();
  }

  @override
  void render(Canvas canvas) {
    if (game.players.isEmpty) return;

    final canRoll = !isRolling && !game.isMoving;
    final showTwoDice = numDice == 2;
    final dieSize = 66.0;
    final spacing = 15.0; // Espacio entre dados

    // Cálculo de centrado dinámico dentro del componente (ancho 180)
    double startX;
    if (showTwoDice) {
      final totalWidth = (dieSize * 2) + spacing;
      startX = (size.x - totalWidth) / 2;
    } else {
      startX = (size.x - dieSize) / 2;
    }

    if (canRoll) {
      final glowPaint = Paint()
        ..color = Colors.yellow.withValues(alpha: 0.15 + (sin(game.elapsedTime * 5).abs() * 0.2))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
      
      if (showTwoDice) {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(startX, 0, dieSize, dieSize).inflate(8), const Radius.circular(12)), glowPaint);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(startX + dieSize + spacing, 0, dieSize, dieSize).inflate(8), const Radius.circular(12)), glowPaint);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(startX, 0, dieSize, dieSize).inflate(8), const Radius.circular(12)), glowPaint);
      }
    }

    if (showTwoDice) {
      _drawDie(canvas, Offset(startX, 0), value1, dieSize);
      _drawDie(canvas, Offset(startX + dieSize + spacing, 0), value2, dieSize);
    } else {
      _drawDie(canvas, Offset(startX, 0), value1, dieSize);
    }
  }

  void _drawDie(Canvas canvas, Offset offset, int value, double size) {
    if (game.players.isEmpty) return;
    final rect = Rect.fromLTWH(offset.dx, offset.dy, size, size);
    
    if (isRolling) {
      canvas.save();
      canvas.translate(_rand.nextDouble() * 6 - 3, _rand.nextDouble() * 6 - 3);
    }

    final playerColor = game.currentPlayer.color;
    final isColorBright = playerColor.computeLuminance() > 0.5;

    // Cuerpo del dado (Texturizado con el color del jugador)
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          playerColor.withValues(alpha: 0.9),
          playerColor.withValues(alpha: 0.7).withValues(alpha: 0.8), // Simular profundidad
          const Color(0xFF000000).withValues(alpha: 0.9),
        ],
        center: Alignment.topLeft,
        radius: 1.5,
      ).createShader(rect);
    
    final borderPaint = Paint()
      ..color = isColorBright ? Colors.black26 : Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;

    // Sombra interna/profundidad
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
    canvas.drawRRect(rrect, paint);
    canvas.drawRRect(rrect, borderPaint);
    canvas.drawRRect(rrect.shift(const Offset(2, 2)), shadowPaint);

    // Dibujar puntos con contraste
    final dotPaint = Paint()
      ..color = isColorBright ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0)
      ..maskFilter = const MaskFilter.blur(BlurStyle.inner, 1);
    
    final dotShadowPaint = Paint()
      ..color = isColorBright ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    _drawDots(canvas, rect, value, dotPaint, dotShadowPaint, size);

    if (isRolling) {
      canvas.restore();
    }
  }

  void _drawDots(
    Canvas canvas,
    Rect rect,
    int value,
    Paint paint,
    Paint shadowPaint,
    double size,
  ) {
    final center = rect.center;
    final r = size * 0.08; // Proporcional al tamaño
    final dist = size * 0.22;

    void dot(double dx, double dy) {
      // Pequeña sombra para efecto de grabado
      canvas.drawCircle(center + Offset(dx + 1, dy + 1), r, shadowPaint);
      canvas.drawCircle(center + Offset(dx, dy), r, paint);
    }

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
