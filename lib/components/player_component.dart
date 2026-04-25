import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../ruta_de_cenizas_game.dart';
import '../utils/perspective_utils.dart';

class PlayerComponent extends Component with HasGameReference<RutaDeCenizasGame> {
  Vector2? _visualPos;
  double _visualScale = 1.0;
  final List<int> _moveQueue = [];
  int _currentPathIndex = -1;
  double _moveCooldown = 0;
  final List<_DustParticle> _dust = [];

  double get visualRow {
    final tile = game.tiles.firstWhere((t) => t.index == _currentPathIndex, orElse: () => game.tiles.first);
    return tile.row.toDouble();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final state = game.playerState;

    // Handle movement queue
    if (_moveQueue.isEmpty && _currentPathIndex != state.currentIndex) {
      // Something changed externally (e.g. initial teleport or event)
      // For now, if it's a jump, we'll just teleport or queue the path
      // If the difference is small, queue the path
      int diff = state.currentIndex - (_currentPathIndex == -1 ? state.currentIndex : _currentPathIndex);
      if (diff.abs() > 0 && diff.abs() <= 12) {
        int sign = diff.sign;
        for (int i = 1; i <= diff.abs(); i++) {
          _moveQueue.add(_currentPathIndex + (i * sign));
        }
      } else {
        _currentPathIndex = state.currentIndex;
      }
    }

    if (_moveQueue.isNotEmpty) {
      _moveCooldown -= dt;
      if (_moveCooldown <= 0) {
        _currentPathIndex = _moveQueue.removeAt(0);
        _moveCooldown = 0.2; // Time per tile
        
        // Mark as visited
        game.tiles.firstWhere((t) => t.index == _currentPathIndex).isVisited = true;
        // User said "solo cuando aterrice", but for animation it looks better if they reveal.
        // I'll stick to reveal only on landing as requested previously.
        if (_moveQueue.isEmpty) {
          game.tiles.firstWhere((t) => t.index == _currentPathIndex).isRevealed = true;
          game.onPlayerMovementFinished();
        }
      }
    } else if (_currentPathIndex == -1) {
      _currentPathIndex = state.currentIndex;
    }

    // Interpolate visual position
    final screenSize = game.canvasSize.toSize();
    final offset = game.cameraRowOffset;
    final targetTile = game.tiles.firstWhere((t) => t.index == _currentPathIndex);
    final targetPos = PerspectiveUtils.project(targetTile.row.toDouble(), targetTile.col, screenSize, cameraRowOffset: offset);
    final targetScale = PerspectiveUtils.getScale(targetTile.row.toDouble(), cameraRowOffset: offset);

    if (_visualPos == null) {
      _visualPos = Vector2(targetPos.dx, targetPos.dy);
      _visualScale = targetScale;
    } else {
      // Smooth interpolation
      double lerpFactor = 10 * dt;
      _visualPos!.x = lerp(lerpFactor, _visualPos!.x, targetPos.dx);
      _visualPos!.y = lerp(lerpFactor, _visualPos!.y, targetPos.dy);
      _visualScale = lerp(lerpFactor, _visualScale, targetScale);
      
      // Spawn dust if moving
      if (_moveQueue.isNotEmpty || _moveCooldown > 0) {
        _dust.add(_DustParticle(Offset(_visualPos!.x, _visualPos!.y)));
      }
    }
    
    // Update dust
    for (final d in _dust) {
      d.update(dt);
    }
    _dust.removeWhere((d) => d.life <= 0);
  }

  double lerp(double t, double a, double b) => a + (b - a) * t.clamp(0.0, 1.0);

  @override
  void render(Canvas canvas) {
    if (_visualPos == null) return;
    
    // Render dust first
    for (final d in _dust) {
      d.render(canvas);
    }

    final paint = Paint()..color = const Color(0xFF1A1A1A);
    final borderPaint = Paint()
      ..color = const Color(0xFFC0C0C0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    final size = 30.0 * _visualScale;

    final path = Path()
      ..moveTo(_visualPos!.x, _visualPos!.y - size)
      ..lineTo(_visualPos!.x - size / 2, _visualPos!.y)
      ..lineTo(_visualPos!.x + size / 2, _visualPos!.y)
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }
}

class _DustParticle {
  Offset pos;
  double life = 1.0;
  final Offset velocity;

  _DustParticle(this.pos) : velocity = Offset((DateTime.now().millisecond % 20 - 10) / 10, -0.5);

  void update(double dt) {
    pos += velocity;
    life -= dt * 2;
  }

  void render(Canvas canvas) {
    canvas.drawCircle(pos, 2, Paint()..color = Colors.white.withValues(alpha: life * 0.3));
  }
}
