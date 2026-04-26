import 'dart:math' as math;
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame_audio/flame_audio.dart' hide PlayerState;
import 'package:flutter/material.dart'
    hide Path; // Avoid conflict with dart:ui if any
import 'package:flutter/services.dart';
import 'components/tablero_tile.dart';
import 'models/tile_type.dart';
import 'models/item_type.dart';
import 'utils/perspective_utils.dart';
import 'logic/board_logic.dart';
import 'models/player_state.dart';
import 'components/dice_component.dart';
import 'components/player_component.dart';

class RutaDeCenizasGame extends FlameGame with KeyboardEvents, ChangeNotifier {
  List<PlayerState> players = [];
  int currentPlayerIndex = 0;
  bool isGameStarted = false;

  PlayerState get currentPlayer => players[currentPlayerIndex];

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
    "La neblina te confunde y tropiezas con el abismo.",
  ];

  final List<String> _atajoMessages = [
    "Una corriente de aire cálido te eleva por la ladera.",
    "Encuentras una vieja cuerda de escalada aún firme. ¡Sube!",
    "El espíritu de la montaña te favorece con un camino firme.",
    "Una grieta estable te permite trepar varios metros de golpe.",
    "La ceniza se asienta y revela un sendero oculto hacia arriba.",
    "Un momento de claridad te permite encontrar un paso rápido.",
    "Sientes una fuerza renovada en tus piernas. ¡Avanza!",
  ];

  final List<String> fragmentosHistoria = [
    "Día 1. El peso de la mochila no es nada comparado con el frío que sube por mis piernas. La ceniza lo cubre todo, como un manto de olvido.",
    "Día 4. He perdido el rastro del viejo camino. Otros lo intentaron antes; he visto sus huellas petrificadas. Todos miraban hacia arriba.",
    "Día 9. El aire sabe a metal y azufre. Dicen que en la cima el cielo es azul, pero ya no recuerdo cómo se ve el color azul.",
    "He encontrado un zapato de niño medio enterrado. Me pregunto si quien lo llevaba logró ver la luz del sol una última vez.",
    "La soledad aquí arriba tiene voz. Susurra promesas de descanso, pero si me detengo, la ceniza me convertirá en parte de la montaña.",
    "Día 15. Mis manos sangran, pero la piedra aquí arriba es distinta. Es más cálida. Estoy cerca del corazón del volcán.",
    "Vi un destello entre las nubes negras. Un rayo de luz real. Hacía años que no lloraba, pero mis lágrimas se secaron antes de caer.",
    "Ya no siento mis pies. Camino por inercia. Solo el pensamiento de que él me espera en el refugio me mantiene erguido.",
    "La pendiente es casi vertical ahora. El viento aúlla como un animal herido. He dejado atrás todo lo que poseía, excepto mi esperanza.",
    "Si alguien encuentra este diario... no mires hacia abajo. La luz está ahí, a solo unos pasos. No te detengas."
  ];

  int currentHistoryIndex = 0;

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
        item: data.item,
      );
      tile.priority =
          100 - data.row; // Closer rows (lower index) rendered on top
      tiles.add(tile);
      add(tile);
    }

    // Reveal starting tile
    _getTileAtIndex(1)?.isRevealed = true;

    dice.position = Vector2((canvasSize.x - 130) / 2, canvasSize.y - 80);
    dice.priority = 400; // Above everything visual
    add(dice);

    add(SunRayOverlay()..priority = 350);
    add(AshFogOverlay()..priority = 300); // Above player and tiles

    add(MiniMapComponent()..priority = 500); // Top layer HUD
    add(IntegridadBarComponent()..priority = 500); // Top layer HUD

    try {
      await FlameAudio.audioCache.loadAll([
        'ambient.mp3',
        'move.mp3',
        'fall.mp3',
        'shortcut.mp3',
        'paper_sound.mp3',
      ]);
      FlameAudio.bgm.initialize();
      FlameAudio.bgm.play('ambient.mp3', volume: 0.6);
    } catch (e) {
      print('Aviso: Audios no cargados. Error: $e');
    }
  }

  void startGame(List<PlayerState> newPlayers) {
    // Limpiar jugadores previos si existen
    children.whereType<PlayerComponent>().forEach((p) => p.removeFromParent());
    
    players = newPlayers;
    currentPlayerIndex = 0;
    isGameStarted = true;
    isMoving = false;
    waitingForEventRoll = false;
    currentEventType = null;
    eventMessage = null;
    cameraRowOffset = 0.0;

    for (var player in players) {
      player.reset();
      add(PlayerComponent(playerState: player)..priority = 200);
    }
    
    notifyListeners();
  }

  TableroTile? _getTileAtIndex(int index) {
    try {
      return tiles.firstWhere((t) => t.index == index);
    } catch (_) {
      return null;
    }
  }

  void rollAndMove() {
    if (!isGameStarted || dice.isRolling || isMoving) return;

    print("Iniciando rollAndMove de ${currentPlayer.name}. Esperando evento: $waitingForEventRoll");
    eventMessage = null;

    final isTwoDiceEvent = waitingForEventRoll && currentEventType != TileType.historia && currentEventType != TileType.consumible;
    dice.roll(diceCount: isTwoDiceEvent ? 2 : 1);

    notifyListeners();

    Future.delayed(const Duration(milliseconds: 700), () {
      final total = isTwoDiceEvent
          ? (dice.value1 + dice.value2)
          : dice.value1;

      if (waitingForEventRoll) {
        waitingForEventRoll = false;
        currentEventType = null;
        eventMessage = null;

        final currentTile = _getTileAtIndex(currentPlayer.currentIndex);
        if (currentTile?.type == TileType.barranco) {
          _processMovement(-total);
        } else if (currentTile?.type == TileType.atajo) {
          _processMovement(total);
        } else {
          _processMovement(total);
        }
      } else {
        try { FlameAudio.play('move.mp3'); } catch (_) {}
        _processMovement(total);
      }
      notifyListeners();
    });
  }

  void _processMovement(int steps) {
    isMoving = true;
    notifyListeners();

    if (steps < 0) {
      currentPlayer.health += (steps * 5); // steps is negative
      if (currentPlayer.health < 0) currentPlayer.health = 0;
    }

    int targetIndex = currentPlayer.currentIndex + steps;
    if (targetIndex < 1) targetIndex = 1;
    if (targetIndex > tiles.length) targetIndex = tiles.length;

    final targetTile = _getTileAtIndex(targetIndex);
    if (targetTile != null) {
      currentPlayer.currentIndex = targetIndex;
      notifyListeners();
    } else {
      isMoving = false;
      _endTurn();
      notifyListeners();
    }
  }

  void onPlayerMovementFinished() {
    isMoving = false;
    notifyListeners();

    if (currentPlayer.health <= 0) {
      _triggerGameOver();
      return;
    }

    if (currentPlayer.currentIndex == tiles.length) {
      _triggerWin();
      return;
    }

    final currentTile = _getTileAtIndex(currentPlayer.currentIndex);
    if (currentTile != null) {
      currentTile.isRevealed = true;
      if (currentTile.type == TileType.normal) {
        dice.numDice = 1;
        _endTurn(); // Termina el turno en casilla normal
      } else {
        _resolveTileEffect(currentTile);
      }
    } else {
      _endTurn();
    }
  }
  
  void _endTurn() {
    if (!waitingForEventRoll) {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
      print("Turno de: ${currentPlayer.name}");
      notifyListeners();
    }
  }

  void _triggerGameOver() {
    eventMessage = "${currentPlayer.name} ha caído exhausto.";
    Future.delayed(const Duration(seconds: 3), () {
      currentPlayer.reset();
      eventMessage = null;
      _endTurn();
      notifyListeners();
    });
  }

  void _triggerWin() {
    eventMessage = "¡${currentPlayer.name.toUpperCase()} HA CONQUISTADO LA CIMA!";
    Future.delayed(const Duration(seconds: 5), () {
      returnToMenu();
    });
  }

  void returnToMenu() {
    children.whereType<PlayerComponent>().forEach((p) => p.removeFromParent());
    isGameStarted = false;
    players = [];
    currentPlayerIndex = 0;
    eventMessage = null;
    waitingForEventRoll = false;
    isMoving = false;
    cameraRowOffset = 0;
    overlays.add('MainMenuOverlay');
    notifyListeners();
  }

  @override
  void update(double dt) {
    super.update(dt);
    elapsedTime += dt;

    if (!isGameStarted) return;

    final playerComps = children.whereType<PlayerComponent>();
    final activePlayerComp = playerComps.where((p) => p.playerState == currentPlayer).firstOrNull;
    
    if (activePlayerComp != null) {
      final targetRow = activePlayerComp.visualRow - 1.0; 
      if ((cameraRowOffset - targetRow).abs() > 0.01) {
        cameraRowOffset = lerp(5 * dt, cameraRowOffset, targetRow);
      }
    }
  }

  double lerp(double t, double a, double b) => a + (b - a) * t.clamp(0.0, 1.0);

  void _resolveTileEffect(TableroTile tile) {
    if (tile.type == TileType.barranco) {
      if (currentPlayer.zapatosDeEscaladaCount > 0) {
        overlays.add('InventoryPrompt');
        return;
      }
      try {
        FlameAudio.play('fall.mp3');
      } catch (e) {}
      waitingForEventRoll = true;
      dice.numDice = 2;
      currentEventType = TileType.barranco;
      eventMessage = _barrancoMessages[_rand.nextInt(_barrancoMessages.length)];
      notifyListeners();
    } else if (tile.type == TileType.atajo) {
      try {
        FlameAudio.play('shortcut.mp3');
      } catch (e) {}
      waitingForEventRoll = true;
      dice.numDice = 2;
      currentEventType = TileType.atajo;
      eventMessage = _atajoMessages[_rand.nextInt(_atajoMessages.length)];
      notifyListeners();
    } else if (tile.type == TileType.historia) {
      try {
        FlameAudio.play('paper_sound.mp3');
      } catch (e) {}
      waitingForEventRoll = true;
      dice.numDice = 1;
      currentEventType = TileType.historia;
      eventMessage = fragmentosHistoria[currentHistoryIndex];
      if (currentHistoryIndex < fragmentosHistoria.length - 1) {
        currentHistoryIndex++;
      }
      currentPlayer.health = (currentPlayer.health + 5).clamp(0, 100);
      notifyListeners();
    } else if (tile.type == TileType.consumible && !tile.itemCollected && tile.item != null) {
      tile.itemCollected = true;
      
      String itemName = "";
      switch (tile.item!) {
        case ItemType.zapatosDeEscalada:
          if (currentPlayer.zapatosDeEscaladaCount == 0) {
            currentPlayer.zapatosDeEscaladaCount++;
          }
          itemName = "Zapatos de Escalada";
          break;
        case ItemType.lazoDelMalvado:
          if (currentPlayer.lazoDelMalvadoCount == 0) {
            currentPlayer.lazoDelMalvadoCount++;
          }
          itemName = "Lazo del Malvado";
          break;
        case ItemType.voluntadDeLosAntiguos:
          if (currentPlayer.voluntadDeLosAntiguosCount == 0) {
            currentPlayer.voluntadDeLosAntiguosCount++;
          }
          itemName = "Voluntad de los Antiguos";
          break;
      }

      final screenSize = canvasSize.toSize();
      final offset = cameraRowOffset;
      final startPos = PerspectiveUtils.project(tile.row.toDouble(), tile.col, screenSize, cameraRowOffset: offset);
      add(ItemPickupAnimation(startPos: startPos, item: tile.item!)..priority = 600);

      waitingForEventRoll = true;
      dice.numDice = 1;
      currentEventType = TileType.consumible;
      eventMessage = "Has encontrado: $itemName.";
      notifyListeners();
    }
  }

  void useZapatos() {
    print("¡Barranco evitado!");
    currentPlayer.zapatosDeEscaladaCount--;
    _endTurn();
  }

  void triggerFall() {
    waitingForEventRoll = true;
    dice.numDice = 2;
    currentEventType = TileType.barranco;
    eventMessage = _barrancoMessages[_rand.nextInt(_barrancoMessages.length)];
    notifyListeners();
  }

  @override
  KeyEventResult onKeyEvent(
    KeyEvent event,
    Set<LogicalKeyboardKey> keysPressed,
  ) {
    if (event is KeyDownEvent &&
        keysPressed.contains(LogicalKeyboardKey.space)) {
      rollAndMove();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

class AshFogOverlay extends Component with HasGameReference<RutaDeCenizasGame> {
  final List<_AshParticle> _particles = List.generate(
    50,
    (_) => _AshParticle(),
  );

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
    final playerY = PerspectiveUtils.project(
      game.cameraRowOffset,
      0,
      size,
      cameraRowOffset: game.cameraRowOffset,
    ).dy;
    final limitY = PerspectiveUtils.project(
      game.cameraRowOffset + 3,
      0,
      size,
      cameraRowOffset: game.cameraRowOffset,
    ).dy;

    double stop1 = (playerY / size.height).clamp(0.0, 1.0);
    double stop2 = (limitY / size.height).clamp(0.0, 1.0);

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: 0.82), // Softer fog
          Colors.black.withValues(alpha: 0.95),
          Colors.black.withValues(alpha: 0.98),
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

class MiniMapComponent extends Component
    with HasGameReference<RutaDeCenizasGame> {
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
      RRect.fromRectAndRadius(
        Rect.fromLTWH(mapX, mapY, mapWidth, mapHeight),
        const Radius.circular(5),
      ),
      bgPaint,
    );

    // Player marker
    final playerRow =
        game.cameraRowOffset; // Use camera offset as smooth reference
    final totalRows = 16.0;
    final progress = (playerRow / (totalRows - 1)).clamp(0.0, 1.0);

    final markerY = mapY + mapHeight - (progress * mapHeight);
    final markerPaint = Paint()..color = const Color(0xFFB22222);
    canvas.drawCircle(Offset(mapX + mapWidth / 2, markerY), 4, markerPaint);

    // Top indicator (Cima)
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'CIMA',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(mapX - 5, mapY - 15));
  }
}

class IntegridadBarComponent extends Component
    with HasGameReference<RutaDeCenizasGame> {
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
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barY, barWidth, barHeight),
        const Radius.circular(5),
      ),
      bgPaint,
    );

    // Health (Aguante) Fill
    final health = game.isGameStarted ? game.currentPlayer.health : 100.0;
    final fillHeight = (health / 100.0) * barHeight;

    final fillPaint = Paint()
      ..color = const Color(0xFF2E8B57); // Sea Green / Forest for stamina
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          barX,
          barY + barHeight - fillHeight,
          barWidth,
          fillHeight,
        ),
        const Radius.circular(5),
      ),
      fillPaint,
    );

    // Indicator (INTEGRIDAD)
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'INTEGRIDAD',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 10,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(barX - 45, barY - 15));
  }
}

class SunRayOverlay extends Component with HasGameReference<RutaDeCenizasGame> {
  final math.Random _rand = math.Random();
  double _timer = 0;
  double _opacity = 0;
  bool _isFlashing = false;

  @override
  void update(double dt) {
    if (!_isFlashing) {
      _timer += dt;
      if (_timer > 5.0 && _rand.nextDouble() < 0.01) { // Rare event (approx every 5+ secs, low chance)
        _isFlashing = true;
        _opacity = 0.15 + _rand.nextDouble() * 0.1; // 0.15 to 0.25 opacity
        _timer = 0;
      }
    } else {
      _opacity -= dt * 0.15; // Fade out slowly
      if (_opacity <= 0) {
        _opacity = 0;
        _isFlashing = false;
      }
    }
  }

  @override
  void render(Canvas canvas) {
    if (_opacity > 0) {
      final size = game.canvasSize.toSize();
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: _opacity),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.5));
      
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.5), paint);
    }
  }
}

class ItemPickupAnimation extends Component with HasGameReference<RutaDeCenizasGame> {
  Vector2 pos;
  final ItemType item;
  double _life = 1.0;
  
  ItemPickupAnimation({required Offset startPos, required this.item})
      : pos = Vector2(startPos.dx, startPos.dy);

  @override
  void update(double dt) {
    _life -= dt * 0.8;
    // Move towards bottom-right (inventory area)
    final targetX = game.canvasSize.x - 50;
    final targetY = game.canvasSize.y - 50;
    
    pos.x = game.lerp(5 * dt, pos.x, targetX);
    pos.y = game.lerp(5 * dt, pos.y, targetY);

    if (_life <= 0) {
      removeFromParent();
    }
  }

  @override
  void render(Canvas canvas) {
    if (_life <= 0) return;
    
    IconData icon;
    Color color;

    switch (item) {
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

    final alpha = (_life.clamp(0.0, 1.0) * 255).toInt();
    
    // Draw icon
    final iconString = String.fromCharCode(icon.codePoint);
    final span = TextSpan(
      text: iconString,
      style: TextStyle(
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        fontSize: 30 * _life, // Scales down as it moves
        color: color.withAlpha(alpha),
      ),
    );
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr);
    tp.layout();
    tp.paint(canvas, Offset(pos.x - tp.width / 2, pos.y - tp.height / 2));
  }
}
