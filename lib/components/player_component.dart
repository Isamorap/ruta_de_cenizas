import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../ruta_de_cenizas_game.dart';
import '../utils/perspective_utils.dart';
import '../models/player_state.dart';
import '../models/character_data.dart';

class PlayerComponent extends Component
    with HasGameReference<RutaDeCenizasGame> {
  final PlayerState playerState;

  Vector2? _visualPos;
  double _visualScale = 1.0;
  final List<int> _moveQueue = [];
  int _currentPathIndex = -1;
  double _moveCooldown = 0;
  final List<_DustParticle> _dust = [];

  PlayerComponent({required this.playerState});

  double get visualRow {
    final tile = game.tiles.firstWhere(
      (t) => t.index == _currentPathIndex,
      orElse: () => game.tiles.first,
    );
    return tile.row.toDouble();
  }

  @override
  void update(double dt) {
    super.update(dt);
    final state = playerState;

    // Handle movement queue
    if (_moveQueue.isEmpty && _currentPathIndex != state.currentIndex) {
      int diff =
          state.currentIndex -
          (_currentPathIndex == -1 ? state.currentIndex : _currentPathIndex);
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
      _moveCooldown -= dt * state.moveSpeedMultiplier;
      if (_moveCooldown <= 0) {
        final oldIndex = _currentPathIndex;
        _currentPathIndex = _moveQueue.removeAt(0);
        _moveCooldown = 0.4; // Time per tile

        // Si estamos retrocediendo, perdemos integridad
        if (_currentPathIndex < oldIndex) {
          playerState.health -= 3;
          if (playerState.health < 0) playerState.health = 0;
          game.notifyListeners();
        }

        // Mark as visited
        game.tiles.firstWhere((t) => t.index == _currentPathIndex).isVisited =
            true;

        if (_moveQueue.isEmpty) {
          game.tiles
                  .firstWhere((t) => t.index == _currentPathIndex)
                  .isRevealed =
              true;
          // Restore speed
          state.moveSpeedMultiplier = 1.0;
          // Only trigger event if this is the CURRENT player
          if (game.players[game.currentPlayerIndex] == playerState &&
              game.isMoving) {
            game.onPlayerMovementFinished();
          }
        }
      }
    } else if (_currentPathIndex == -1) {
      _currentPathIndex = state.currentIndex;
    }

    // Interpolate visual position
    final screenSize = game.canvasSize.toSize();
    final offset = game.cameraRowOffset;
    final targetTile = game.tiles.firstWhere(
      (t) => t.index == _currentPathIndex,
      orElse: () => game.tiles.first,
    );

    // Add a slight offset based on player index to avoid stacking exactly on top of each other
    int pIndex = game.players.indexOf(playerState);
    double colOffset = targetTile.col;
    if (pIndex == 0) colOffset -= 0.2;
    if (pIndex == 1) colOffset += 0.2;
    if (pIndex == 2) colOffset -= 0.1;
    if (pIndex == 3) colOffset += 0.1;

    final targetPos = PerspectiveUtils.project(
      targetTile.row.toDouble(),
      colOffset,
      screenSize,
      cameraRowOffset: offset,
    );
    final targetScale = PerspectiveUtils.getScale(
      targetTile.row.toDouble(),
      cameraRowOffset: offset,
    );

    if (_visualPos == null) {
      _visualPos = Vector2(targetPos.dx, targetPos.dy);
      _visualScale = targetScale;
    } else {
      double lerpFactor = 10 * dt;
      _visualPos!.x = game.lerp(lerpFactor, _visualPos!.x, targetPos.dx);
      _visualPos!.y = game.lerp(lerpFactor, _visualPos!.y, targetPos.dy);
      _visualScale = game.lerp(lerpFactor, _visualScale, targetScale);

      if (_moveQueue.isNotEmpty || _moveCooldown > 0) {
        _dust.add(_DustParticle(Offset(_visualPos!.x, _visualPos!.y)));
      }
    }

    // Update dialog timer
    if (state.currentDialog != null) {
      state.dialogTimer -= dt;
      if (state.dialogTimer <= 0) {
        state.currentDialog = null;
      }
    }

    for (final d in _dust) {
      d.update(dt);
    }
    _dust.removeWhere((d) => d.life <= 0);
  }

  @override
  void render(Canvas canvas) {
    if (_visualPos == null) return;

    for (final d in _dust) {
      d.render(canvas);
    }

    final char = characterById(playerState.characterId);
    final size = 32.0 * _visualScale;

    // Sombra de fondo
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(
      Offset(_visualPos!.x, _visualPos!.y - size * 0.6),
      size * 0.65,
      shadowPaint,
    );

    // Círculo de fondo con el color del personaje (personalizado)
    final bgPaint = Paint()..color = playerState.color.withValues(alpha: 0.65);
    canvas.drawCircle(
      Offset(_visualPos!.x, _visualPos!.y - size * 0.6),
      size * 0.65,
      bgPaint,
    );

    // Borde del círculo
    final borderPaint = Paint()
      ..color = playerState.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0 * _visualScale;
    canvas.drawCircle(
      Offset(_visualPos!.x, _visualPos!.y - size * 0.6),
      size * 0.65,
      borderPaint,
    );

    // Ícono del personaje
    final iconString = String.fromCharCode(char.icon.codePoint);
    final iconSpan = TextSpan(
      text: iconString,
      style: TextStyle(
        fontFamily: char.icon.fontFamily,
        package: char.icon.fontPackage,
        fontSize: size * 0.9,
        color: Colors.white,
      ),
    );
    final tp = TextPainter(text: iconSpan, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(
      canvas,
      Offset(
        _visualPos!.x - tp.width / 2,
        _visualPos!.y - size * 0.6 - tp.height / 2,
      ),
    );

    // Render Dialog
    if (playerState.currentDialog != null) {
      _renderDialog(canvas, _visualPos!, size);
    }
  }

  void _renderDialog(Canvas canvas, Vector2 pos, double charSize) {
    final textSpan = TextSpan(
      text: playerState.currentDialog,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    );
    final tp = TextPainter(text: textSpan, textDirection: TextDirection.ltr);
    tp.layout(maxWidth: 150);

    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        pos.x - tp.width / 2 - 10,
        pos.y - charSize - tp.height - 25,
        tp.width + 20,
        tp.height + 15,
      ),
      const Radius.circular(8),
    );

    // Bubble background
    canvas.drawRRect(
      bubbleRect,
      Paint()..color = Colors.black.withValues(alpha: 0.8),
    );
    canvas.drawRRect(
      bubbleRect,
      Paint()
        ..color = playerState.color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke,
    );

    // Little triangle
    final path = Path()
      ..moveTo(pos.x - 5, pos.y - charSize - 10)
      ..lineTo(pos.x + 5, pos.y - charSize - 10)
      ..lineTo(pos.x, pos.y - charSize);
    canvas.drawPath(path, Paint()..color = Colors.black.withValues(alpha: 0.8));

    tp.paint(
      canvas,
      Offset(pos.x - tp.width / 2, pos.y - charSize - tp.height - 18),
    );
  }
}

class _DustParticle {
  Offset pos;
  double life = 1.0;
  final Offset velocity;

  _DustParticle(this.pos)
    : velocity = Offset((DateTime.now().millisecond % 20 - 10) / 10, -0.5);

  void update(double dt) {
    pos += velocity;
    life -= dt * 2;
  }

  void render(Canvas canvas) {
    canvas.drawCircle(
      pos,
      2,
      Paint()..color = Colors.white.withValues(alpha: life * 0.3),
    );
  }
}
