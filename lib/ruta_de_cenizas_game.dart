import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart' hide PlayerState;
import 'package:flutter/material.dart' hide Path; // Avoid conflict with dart:ui if any
import 'package:flutter/services.dart';
import 'components/tablero_tile.dart';
import 'models/tile_type.dart';
import 'utils/perspective_utils.dart';
import 'logic/board_logic.dart';
import 'models/player_state.dart';
import 'components/dice_component.dart';
import 'components/player_component.dart';

class RutaDeCenizasGame extends FlameGame with KeyboardEvents, ChangeNotifier {
  final PlayerState playerState = PlayerState();
  DiceComponent dice = DiceComponent();
  final List<TableroTile> tiles = [];
  double cameraRowOffset = 0.0;
  double elapsedTime = 0.0;

  bool isMoving = false;
  bool waitingForEventRoll = false;
  String? eventMessage;
  TileType? currentEventType;

  final List<String> _barrancoMessages = [
    "El suelo se deshace en ceniza... estás cayendo.",
    "Un mal paso en la roca suelta y la gravedad hace el resto.",
    "La montaña reclama su tributo. Te deslizas hacia el vacío.",
    "El cansancio te vence y pierdes el equilibrio... abajo.",
    "Una grieta oculta bajo el polvo se traga tu avance.",
    "Tus dedos resbalan en la piedra fría. El descenso es inevitable.",
    "La neblina te confunde y tropiezas con el abismo."
  ];

  final List<String> _atajoMessages = [
    "Una corriente de aire cálido te eleva por la ladera.",
    "Encuentras una vieja cuerda de escalada aún firme. ¡Sube!",
    "El espíritu de la montaña te favorece con un camino firme.",
    "Una grieta estable te permite trepar varios metros de golpe.",
    "La ceniza se asienta y revela un sendero oculto hacia arriba.",
    "Un momento de claridad te permite encontrar un paso rápido.",
    "Sientes una fuerza renovada en tus piernas. ¡Avanza!"
  ];

  final math.Random _rand = math.Random();
  Color backgroundColor() => Colors.black;

  @override
  Future<void> onLoad() async {
    final boardLogic = BoardLogic();
    final boardData = boardLogic.generateBoard();

    for (var data in boardData) {
      final tile = TableroTile(
        row: data.row,
        col: data.col,
        type: data.type,
        index: data.index,
        surfaceColor: data.surfaceColor,
      );
      tile.priority = 100 - data.row; // Closer rows (lower index) rendered on top
      tiles.add(tile);
      add(tile);
    }

    // Reveal starting tile
    _getTileAtIndex(1)?.isRevealed = true;

    add(PlayerComponent()..priority = 200); // Above tiles
    dice.position = Vector2(20, canvasSize.y - 80);
    dice.priority = 400; // Above everything visual
    add(dice);
    
    // Add Ash Fog Overlay
    add(AshFogOverlay()..priority = 300); // Above player and tiles
    
    // Add MiniMap
    add(MiniMapComponent()..priority = 500); // Top layer HUD
    
    // Add AguanteBar
    add(AguanteBarComponent()..priority = 500); // Top layer HUD
    
    // Configurar e intentar cargar audios
    try {
      await FlameAudio.audioCache.loadAll([
        'ambient.mp3',
        'move.wav',
        'fall.wav',
        'shortcut.wav'
      ]);
      FlameAudio.bgm.initialize();
      FlameAudio.bgm.play('ambient.mp3', volume: 0.5);
    } catch (e) {
      print('Aviso: No se pudieron cargar o reproducir los audios. Asegúrate de añadirlos en assets/audio/. Error: $e');
    }
  }

  TableroTile? _getTileAtIndex(int index) {
    try {
      return tiles.firstWhere((t) => t.index == index);
    } catch (_) {
      return null;
    }
  }

  void rollAndMove() {
    if (dice.isRolling || isMoving) return;
    
    print("Iniciando rollAndMove. Esperando evento: $waitingForEventRoll");
    eventMessage = null;
    
    // Use 2 dice for events, 1 die for normal movement
    dice.roll(diceCount: waitingForEventRoll ? 2 : 1);
    
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 700), () {
      final total = waitingForEventRoll ? (dice.value1 + dice.value2) : dice.value1;
      
      if (waitingForEventRoll) {
        waitingForEventRoll = false;
        currentEventType = null; // Reset type
        eventMessage = null;
        
        final currentTile = _getTileAtIndex(playerState.currentIndex);
        print("Resolviendo evento en casilla ${currentTile?.index} (Tipo: ${currentTile?.type})");
        if (currentTile?.type == TileType.barranco) {
          print("Barranco detectado: retrocediendo $total casillas");
          _processMovement(-total);
        } else {
          print("Atajo detectado: avanzando $total casillas");
          _processMovement(total);
        }
      } else {
        print("Movimiento normal: avanzando $total casillas");
        try { FlameAudio.play('move.wav'); } catch (e) {}
        _processMovement(total);
      }
      notifyListeners();
    });
  }

  void _processMovement(int steps) {
    isMoving = true;
    notifyListeners();

    // Damage on fall: lose 5 HP per step
    if (steps < 0) {
      playerState.health += (steps * 5); // steps is negative
      if (playerState.health < 0) playerState.health = 0;
    }

    int targetIndex = playerState.currentIndex + steps;
    if (targetIndex < 1) targetIndex = 1;
    if (targetIndex > tiles.length) targetIndex = tiles.length;

    print("Moviendo de ${playerState.currentIndex} a $targetIndex (Pasos: $steps)");
    final targetTile = _getTileAtIndex(targetIndex);
    if (targetTile != null) {
      playerState.currentIndex = targetIndex;
      // targetTile.row will be used by the smooth follow in update()
      
      notifyListeners();
    } else {
      isMoving = false;
      notifyListeners();
    }
  }

  void onPlayerMovementFinished() {
    isMoving = false;
    notifyListeners();

    // Check for Game Over (Zero health)
    if (playerState.health <= 0) {
      _triggerGameOver();
      return;
    }

    // Resolve tile effect only NOW that the player has physically arrived
    final currentTile = _getTileAtIndex(playerState.currentIndex);
    if (currentTile != null) {
      currentTile.isRevealed = true;
      
      // Update dice count visually for the next turn
      if (currentTile.type == TileType.normal) {
        dice.numDice = 1;
      }
      
      _resolveTileEffect(currentTile);
    }
  }

  void _triggerGameOver() {
    final gameOverMessages = [
      "No resistes más, un helicóptero vendrá a tu rescate.",
      "Sientes que te desvaneces... la montaña ha sido demasiado dura.",
      "Tus fuerzas se agotan. Debes descender para recuperarte.",
      "El frío y el cansancio te vencen. Despiertas en la base."
    ];
    eventMessage = gameOverMessages[_rand.nextInt(gameOverMessages.length)];
    
    // Reset after a delay
    Future.delayed(const Duration(seconds: 3), () {
      playerState.reset();
      cameraRowOffset = 0;
      eventMessage = null;
      notifyListeners();
    });
  }

  @override
  void update(double dt) {
    super.update(dt);
    elapsedTime += dt;
    
    // Smooth camera follow based on visual row of the player
    final player = children.whereType<PlayerComponent>().firstOrNull;
    if (player != null) {
      final targetRow = player.visualRow - 1.0; // Offset camera to show some rows below
      if ((cameraRowOffset - targetRow).abs() > 0.01) {
        cameraRowOffset = lerp(5 * dt, cameraRowOffset, targetRow);
      }
    }
  }

  double lerp(double t, double a, double b) => a + (b - a) * t.clamp(0.0, 1.0);

  void _resolveTileEffect(TableroTile tile) {
    if (tile.type == TileType.barranco) {
      if (playerState.hasZapatosDeEscalada) {
        overlays.add('InventoryPrompt');
        return;
      }
      try { FlameAudio.play('fall.wav'); } catch (e) {}
      waitingForEventRoll = true;
      dice.numDice = 2;
      currentEventType = TileType.barranco;
      eventMessage = _barrancoMessages[_rand.nextInt(_barrancoMessages.length)];
      notifyListeners();
    } else if (tile.type == TileType.atajo) {
      print("¡ATAJO DETECTADO! Activando evento.");
      try { FlameAudio.play('shortcut.wav'); } catch (e) {}
      waitingForEventRoll = true;
      dice.numDice = 2;
      currentEventType = TileType.atajo;
      eventMessage = _atajoMessages[_rand.nextInt(_atajoMessages.length)];
      notifyListeners();
    }
  }

  void useZapatos() {
    print("¡Barranco evitado gracias a los Zapatos de Escalada!");
    // Consume item? User didn't specify, I'll keep it for now.
  }

  void triggerFall() {
    waitingForEventRoll = true;
    dice.numDice = 2;
    currentEventType = TileType.barranco;
    eventMessage = _barrancoMessages[_rand.nextInt(_barrancoMessages.length)];
    notifyListeners();
  }

  @override
  KeyEventResult onKeyEvent(KeyEvent event, Set<LogicalKeyboardKey> keysPressed) {
    if (event is KeyDownEvent && keysPressed.contains(LogicalKeyboardKey.space)) {
      rollAndMove();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

class AshFogOverlay extends Component with HasGameReference<RutaDeCenizasGame> {
  final List<_AshParticle> _particles = List.generate(150, (_) => _AshParticle());

  @override
  void update(double dt) {
    for (var p in _particles) {
      p.update(dt, game.canvasSize.toSize());
    }
  }

  @override
  void render(Canvas canvas) {
    final size = game.canvasSize.toSize();
    
    for (var p in _particles) {
      p.render(canvas);
    }

    // Fog starts clearing at current row and becomes opaque at row + 3
    final playerY = PerspectiveUtils.project(game.cameraRowOffset, 0, size, cameraRowOffset: game.cameraRowOffset).dy;
    final limitY = PerspectiveUtils.project(game.cameraRowOffset + 3, 0, size, cameraRowOffset: game.cameraRowOffset).dy;

    double stop1 = (playerY / size.height).clamp(0.0, 1.0);
    double stop2 = (limitY / size.height).clamp(0.0, 1.0);

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.95), // Denser
          Colors.black,
          Colors.black,
        ],
        stops: [0.0, 1.0 - stop1, 1.0 - stop2, 0.95, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }
}

class _AshParticle {
  Offset pos = Offset.zero;
  double speed = 0;
  double size = 0;
  double drift = 0;
  final math.Random _rand = math.Random();

  _AshParticle() {
    pos = Offset(_rand.nextDouble() * 1000, _rand.nextDouble() * 1000);
    _reset();
  }

  void _reset([Size? screenSize]) {
    speed = 20 + _rand.nextDouble() * 50;
    size = 1 + _rand.nextDouble() * 3;
    drift = (_rand.nextDouble() - 0.5) * 20;
    if (screenSize != null) {
      pos = Offset(_rand.nextDouble() * screenSize.width, -10);
    }
  }

  void update(double dt, Size screenSize) {
    pos += Offset(drift * dt, speed * dt);
    if (pos.dy > screenSize.height || pos.dx < 0 || pos.dx > screenSize.width) {
      _reset(screenSize);
    }
  }

  void render(Canvas canvas) {
    canvas.drawCircle(
      pos,
      size,
      Paint()..color = Colors.white.withValues(alpha: 0.3),
    );
  }
}

class MiniMapComponent extends Component with HasGameReference<RutaDeCenizasGame> {
  @override
  void render(Canvas canvas) {
    final size = game.canvasSize;
    const mapWidth = 10.0;
    const mapHeight = 200.0;
    final mapX = 20.0;
    final mapY = size.y / 2 - mapHeight / 2;

    // Background bar (mountain outline)
    final bgPaint = Paint()..color = Colors.white.withValues(alpha: 0.1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(mapX, mapY, mapWidth, mapHeight), const Radius.circular(5)),
      bgPaint,
    );

    // Player marker
    final playerRow = game.cameraRowOffset; // Use camera offset as smooth reference
    final totalRows = 16.0;
    final progress = (playerRow / (totalRows - 1)).clamp(0.0, 1.0);
    
    final markerY = mapY + mapHeight - (progress * mapHeight);
    final markerPaint = Paint()..color = const Color(0xFFB22222);
    canvas.drawCircle(Offset(mapX + mapWidth / 2, markerY), 4, markerPaint);
    
    // Top indicator (Cima)
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'CIMA',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(mapX - 5, mapY - 15));
  }
}

class AguanteBarComponent extends Component with HasGameReference<RutaDeCenizasGame> {
  @override
  void render(Canvas canvas) {
    final size = game.canvasSize;
    const barWidth = 10.0;
    const barHeight = 200.0;
    final barX = size.x - 30.0;
    final barY = size.y / 2 - barHeight / 2;

    // Background bar
    final bgPaint = Paint()..color = Colors.white.withValues(alpha: 0.1);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(barX, barY, barWidth, barHeight), const Radius.circular(5)),
      bgPaint,
    );

    // Health (Aguante) Fill
    final health = game.playerState.health;
    final fillHeight = (health / 100.0) * barHeight;
    
    final fillPaint = Paint()..color = const Color(0xFF2E8B57); // Sea Green / Forest for stamina
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY + barHeight - fillHeight, barWidth, fillHeight), 
        const Radius.circular(5)
      ),
      fillPaint,
    );
    
    // Indicator (AGUANTE)
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'AGUANTE',
        style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(barX - 45, barY - 15));
  }
}
