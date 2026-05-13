import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../ruta_de_cenizas_game.dart';
import '../utils/perspective_utils.dart';
import '../models/player_state.dart';

class BeastComponent extends Component with HasGameReference<RutaDeCenizasGame> {
  final PlayerState targetPlayer;
  final VoidCallback onFinished;

  Vector2? _visualPos;
  double _visualScale = 1.0;
  bool _grabbing = false;
  double _timer = 0;
  
  // Beast state: 0=appearing, 1=moving to player, 2=grabbing, 3=moving to start, 4=finished
  int _state = 0;

  BeastComponent({required this.targetPlayer, required this.onFinished});

  @override
  void update(double dt) {
    super.update(dt);
    final screenSize = game.canvasSize.toSize();
    final offset = game.cameraRowOffset;

    // Start position (off-screen top)
    final startProjected = PerspectiveUtils.project(-5.0, 2.5, screenSize, cameraRowOffset: offset);
    
    // Player position
    final playerTile = game.tiles.firstWhere((t) => t.index == targetPlayer.currentIndex);
    final playerProjected = PerspectiveUtils.project(playerTile.row.toDouble(), playerTile.col, screenSize, cameraRowOffset: offset);

    // Initial position
    if (_visualPos == null) {
      _visualPos = Vector2(startProjected.dx, startProjected.dy);
    }

    switch (_state) {
      case 0: // Appearing
        _timer += dt;
        if (_timer > 0.5) _state = 1;
        break;
      
      case 1: // Moving to player
        double lerpFactor = 5 * dt;
        _visualPos!.x = game.lerp(lerpFactor, _visualPos!.x, playerProjected.dx);
        _visualPos!.y = game.lerp(lerpFactor, _visualPos!.y, playerProjected.dy - 50);
        
        if ((_visualPos!.x - playerProjected.dx).abs() < 5 && (_visualPos!.y - (playerProjected.dy - 50)).abs() < 5) {
          _state = 2;
          _timer = 0;
        }
        break;

      case 2: // Grabbing
        _timer += dt;
        _grabbing = true;
        if (_timer > 0.8) {
          _state = 3;
          targetPlayer.moveSpeedMultiplier = 15.0; // Fast drag
          targetPlayer.currentIndex = 1;
          game.notifyListeners();
        }
        break;

      case 3: // Moving to start (dragging player)
        final startTile = game.tiles.firstWhere((t) => t.index == 1);
        final startPos = PerspectiveUtils.project(startTile.row.toDouble(), startTile.col, screenSize, cameraRowOffset: offset);
        
        double lerpFactor = 6 * dt;
        _visualPos!.x = game.lerp(lerpFactor, _visualPos!.x, startPos.dx);
        _visualPos!.y = game.lerp(lerpFactor, _visualPos!.y, startPos.dy - 50);

        if ((_visualPos!.x - startPos.dx).abs() < 10 && (_visualPos!.y - (startPos.dy - 50)).abs() < 10) {
          _state = 4;
          _timer = 0;
        }
        break;

      case 4: // Disappearing
        _timer += dt;
        if (_timer > 0.5) {
          removeFromParent();
          onFinished();
        }
        break;
    }

    _visualScale = PerspectiveUtils.getScale(-2.0, cameraRowOffset: offset) * 1.5;
  }

  @override
  void render(Canvas canvas) {
    if (_visualPos == null) return;

    final size = 80.0 * _visualScale;
    
    // Draw "The Beast" (A dark, ominous shadow/creature)
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.9)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // Body
    canvas.drawOval(
      Rect.fromCenter(center: Offset(_visualPos!.x, _visualPos!.y), width: size, height: size * 1.2),
      paint,
    );

    // Glowing Eyes
    final eyePaint = Paint()..color = Colors.redAccent.withValues(alpha: 0.8);
    canvas.drawCircle(Offset(_visualPos!.x - size * 0.2, _visualPos!.y - size * 0.1), size * 0.08, eyePaint);
    canvas.drawCircle(Offset(_visualPos!.x + size * 0.2, _visualPos!.y - size * 0.1), size * 0.08, eyePaint);

    // "Claws" if grabbing
    if (_grabbing) {
      final clawPaint = Paint()
        ..color = Colors.black.withValues(alpha: 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * _visualScale;
      
      final path = Path();
      path.moveTo(_visualPos!.x - size * 0.3, _visualPos!.y + size * 0.2);
      path.lineTo(_visualPos!.x - size * 0.4, _visualPos!.y + size * 0.6);
      path.moveTo(_visualPos!.x + size * 0.3, _visualPos!.y + size * 0.2);
      path.lineTo(_visualPos!.x + size * 0.4, _visualPos!.y + size * 0.6);
      canvas.drawPath(path, clawPaint);
    }
  }
}
