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
import 'models/user_profile.dart';

class RutaDeCenizasGame extends FlameGame with KeyboardEvents, ChangeNotifier {
  List<PlayerState> players = [];
  int currentPlayerIndex = 0;
  bool isGameStarted = false;
  UserProfile userProfile = UserProfile();

  PlayerState get currentPlayer => players[currentPlayerIndex];

  // Session Stats
  int sessionTurns = 0;
  int sessionItemsUsed = 0;
  int sessionTilesLost = 0;

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
    "Si alguien encuentra este diario... no mires hacia abajo. La luz está ahí, a solo unos pasos. No te detengas.",
  ];

  int currentHistoryIndex = 0;
  List<PlayerState>? pendingPlayers;

  final math.Random _rand = math.Random();
  @override
  Color backgroundColor() {
    if (!isGameStarted) return const Color(0xFF0A0A0A); // Casi negro, permite ver partículas
    final progress = (cameraRowOffset / 27.0).clamp(0.0, 1.0);
    
    if (progress >= 0.99) {
      return const Color(0xFF87CEEB); // Sky Blue (vibrante)
    }
    
    // De negro absoluto a un azul de madrugada/claro al subir
    return Color.lerp(const Color(0xFF0A0A0A), const Color(0xFF1B263B), progress) ??
        const Color(0xFF0A0A0A);
  }

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
        'dice_roll.mp3',
        'fall.mp3',
        'shortcut.mp3',
        'paper_sound.mp3',
        'win.mp3',
      ]);
      FlameAudio.bgm.initialize();
      updateAudioVolume();
    } catch (e) {
      print('Aviso: Audios no cargados. Error: $e');
    }
  }

  void startGame(List<PlayerState> newPlayers) {
    // Reset board and players
    children.whereType<PlayerComponent>().forEach((p) => p.removeFromParent());
    children.whereType<TableroTile>().forEach((t) => t.removeFromParent());
    tiles.clear();

    final isStory = newPlayers.any((p) => p.isBot);
    final boardLogic = BoardLogic();
    final boardData = boardLogic.generateBoard(isStoryMode: isStory);

    for (var data in boardData) {
      final tile = TableroTile(
        row: data.row,
        col: data.col,
        type: data.type,
        index: data.index,
        surfaceColor: data.surfaceColor,
        item: data.item,
      );
      tile.priority = 100 - data.row;
      tiles.add(tile);
      add(tile);
    }
    _getTileAtIndex(1)?.isRevealed = true;

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

    if (players.length > 1) {
      userProfile.localGamesPlayed++;
      userProfile.save();
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
    if (!isGameStarted || dice.isRolling || isMoving || eventMessage != null)
      return;

    print(
      "Iniciando rollAndMove de ${currentPlayer.name}. Esperando evento: $waitingForEventRoll",
    );
    eventMessage = null;

    final isTwoDiceEvent =
        waitingForEventRoll &&
        currentEventType != TileType.historia &&
        currentEventType != TileType.consumible;
    final wasWaitingForEvent = waitingForEventRoll;
    final eventType = currentEventType;
    waitingForEventRoll = false; 
    
    dice.roll(diceCount: isTwoDiceEvent ? 2 : 1);
    _playSound('dice_roll.mp3', volume: 0.5);
    notifyListeners();

    Future.delayed(const Duration(milliseconds: 700), () {
      final total = isTwoDiceEvent ? (dice.value1 + dice.value2) : dice.value1;

      if (wasWaitingForEvent) {
        currentEventType = null;
        eventMessage = null;

        if (eventType == TileType.barranco) {
          _processMovement(-total);
        } else {
          _processMovement(total);
        }
      } else {
        _processMovement(total);
      }
      notifyListeners();
    });
  }

  void _processMovement(int steps) {
    isMoving = true;
    if (steps > 0) {
      userProfile.totalTilesClimbed += steps;
    }
    notifyListeners();

    if (steps < 0) {
      currentPlayer.health += (steps * 5); // steps is negative
      if (currentPlayer.health < 0) currentPlayer.health = 0;
      sessionTilesLost += steps.abs();
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
      
      // Si es una casilla normal, el turno termina.
      // Si es una especial pero NO se dispara efecto (ej: item ya recolectado), también debe terminar.
      bool eventTriggered = _resolveTileEffect(currentTile);
      
      if (currentTile.type == TileType.normal || !eventTriggered) {
        dice.numDice = 1;
        _endTurn();
      }
    } else {
      _endTurn();
    }
  }

  void _endTurn() {
    if (!waitingForEventRoll) {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
      print("Turno de: ${currentPlayer.name} (Bot: ${currentPlayer.isBot})");
      notifyListeners();
      sessionTurns++;

      // Si el siguiente jugador es un Bot, programar su movimiento
      if (currentPlayer.isBot && isGameStarted) {
        Future.delayed(const Duration(seconds: 2), () {
          if (isGameStarted &&
              currentPlayer.isBot &&
              !isMoving &&
              !dice.isRolling) {
            rollAndMove();
          }
        });
      }
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
    eventMessage =
        "¡${currentPlayer.name.toUpperCase()} HA CONQUISTADO LA CIMA!\n\nNo hay tanto oxígeno aquí arriba... pero el aire es respirable. Has escapado de las cenizas.";
    _playSound('win.mp3');
    
    // Victory dialogue
    currentPlayer.currentDialog = "¡Lo logré! El aire... es tan puro...";
    currentPlayer.dialogTimer = 10.0;
    
    notifyListeners();

    // Show summary after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      overlays.add('GameSummaryOverlay');
    });

    // XP Rewards based on rank (simplified for local/solo)
    // In multiplayer we would check position. Here we just give a win bonus.
    if (players.length > 1) {
      userProfile.localWins += 1;
      userProfile.addXp(100); // 1st place
    } else {
      // Solo mode (History)
      userProfile.addXp(50);
    }
    userProfile.save();
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
    userProfile.save(); // Save progress when returning to menu
    overlays.add('MainMenuOverlay');
    notifyListeners();
  }

  @override
  void update(double dt) {
    super.update(dt);
    elapsedTime += dt;

    if (!isGameStarted) return;

    final playerComps = children.whereType<PlayerComponent>();
    final activePlayerComp = playerComps
        .where((p) => p.playerState == currentPlayer)
        .firstOrNull;

    if (activePlayerComp != null) {
      final targetRow = activePlayerComp.visualRow - 1.0;
      if ((cameraRowOffset - targetRow).abs() > 0.01) {
        cameraRowOffset = lerp(5 * dt, cameraRowOffset, targetRow);
      }
    }

    _updateAmbientDialogs(dt);
  }

  double _dialogTimer = 10.0;
  final List<String> _ambientDialogs = [
    "Siento que me falta el aire...",
    "Estoy cansado...",
    "Deseo subir pronto.",
    "¿Cuánto falta para la cima?",
    "La ceniza es espesa hoy.",
    "Mis piernas pesan...",
    "No debo detenerme.",
    "Por fin... un poco de luz.",
    "¿Hay alguien ahí?",
    "El silencio es ensordecedor.",
    "Debo seguir escalando.",
    "¿Veré el cielo azul algún día?",
    "Mis botas están llenas de polvo.",
    "Cada paso es una victoria.",
    "No mires hacia abajo...",
    "El aire quema en los pulmones.",
    "Un poco más... solo un poco más.",
    "La montaña nunca duerme.",
    "Extraño el olor a tierra mojada.",
    "Este frío cala hasta los huesos.",
    "¿Seguirán ahí las estrellas?",
    "La esperanza es lo único que no pesa.",
    "A veces escucho voces en el viento.",
    "Mis manos están entumecidas.",
    "La cumbre me llama.",
    "Casi puedo sentir el sol.",
    "El viento susurra mi nombre...",
    "¿Y si soy el último?",
    "La ceniza lo borra todo.",
    "Busco el calor entre las piedras.",
    "Subir es la única salida.",
    "Mi voluntad es más fuerte que el frío."
  ];

  void _updateAmbientDialogs(double dt) {
    if (isGameStarted && cameraRowOffset > 26.5) return; // No ambient dialogs at the top
    _dialogTimer -= dt;
    if (_dialogTimer <= 0) {
      _dialogTimer = 8.0 + _rand.nextDouble() * 10.0; // Random interval
      if (players.isNotEmpty) {
        final p = players[_rand.nextInt(players.length)];
        if (p.currentDialog == null) {
          p.currentDialog = _ambientDialogs[_rand.nextInt(_ambientDialogs.length)];
          p.dialogTimer = 4.0; // Show for 4 seconds
          notifyListeners();
        }
      }
    }
  }

  double lerp(double t, double a, double b) => a + (b - a) * t.clamp(0.0, 1.0);

  bool _resolveTileEffect(TableroTile tile) {
    final screenSize = canvasSize.toSize();
    final offset = cameraRowOffset;

    if (tile.type == TileType.barranco) {
      if (!currentPlayer.isBot && currentPlayer.zapatosDeEscaladaCount > 0) {
        overlays.add('InventoryPrompt');
        return true;
      }
      _playSound('fall.mp3');
      waitingForEventRoll = true;
      dice.numDice = 2;
      currentEventType = TileType.barranco;
      eventMessage =
          "¡PELIGRO: BARRANCO!\n\nEl terreno ha cedido bajo tus pies. Solo puedes evitar la caída si tienes 'Zapatos de Escalada' en tu inventario. Si no los tienes (o decides no usarlos), deberás lanzar los dados dobles (2D6) para determinar cuántas casillas retrocedes. Además, perderás integridad por el esfuerzo de no caer al vacío.";
      notifyListeners();
      overlays.add('EventMessageOverlay');
      _automationBot();
      return true;
    } else if (tile.type == TileType.atajo) {
      _playSound('shortcut.mp3');
      waitingForEventRoll = true;
      dice.numDice = 2;
      currentEventType = TileType.atajo;
      eventMessage =
          "¡FORTUNA: ATAJO!\n\nHas encontrado una ruta más directa entre las rocas. Parece arriesgado, pero la suerte favorece a los audaces. Debes lanzar los dados dobles (2D6) para avanzar casillas extra de inmediato.";
      notifyListeners();
      overlays.add('EventMessageOverlay');
      _automationBot();
      return true;
    } else if (tile.type == TileType.historia) {
      _playSound('paper_sound.mp3');
      waitingForEventRoll = true;
      dice.numDice = 1;
      currentEventType = TileType.historia;
      String historiaText = "FRAGMENTO DE HISTORIA:\n\n${fragmentosHistoria[currentHistoryIndex]}";
      if (!userProfile.hasSeenHistoriaTutorial) {
        historiaText += "\n\nEstos restos son historia de otro escalador. No todos son reconfortantes, pero te dan una nueva oportunidad de avanzar y recuperas un poco de integridad. Vuelve a lanzar el dado.";
        userProfile.hasSeenHistoriaTutorial = true;
        userProfile.save();
      } else {
        historiaText += "\n\n(Recuperas integridad y vuelves a lanzar el dado).";
      }
      
      eventMessage = historiaText;
      userProfile.unlockFragment(currentHistoryIndex);
      currentHistoryIndex =
          (currentHistoryIndex + 1) % fragmentosHistoria.length;
      notifyListeners();
      overlays.add('EventMessageOverlay');
      _automationBot();
      return true;
    } else if (tile.type == TileType.consumible &&
        !tile.itemCollected &&
        tile.item != null) {
      tile.itemCollected = true;

      String itemName = "";
      String itemDesc = "";
      switch (tile.item!) {
        case ItemType.zapatosDeEscalada:
          currentPlayer.zapatosDeEscaladaCount++;
          itemName = "Zapato de Escalada";
          itemDesc =
              "Puedes usarlo para no caer de un barranco. Solo es un zapato, ni siquiera es un par.";
          break;
        case ItemType.lazoDelMalvado:
          currentPlayer.lazoDelMalvadoCount++;
          itemName = "Lazo del Malvado";
          itemDesc =
              "Este objeto no deberías usarlo si eres alguien bueno, pero te permite atrapar al oponente que vaya liderando y traerlo hasta tu posición actual.";
          break;
        case ItemType.voluntadDeLosAntiguos:
          currentPlayer.voluntadDeLosAntiguosCount++;
          itemName = "Voluntad de los Antiguos";
          itemDesc =
              "Este es un ítem antiguo que aún alberga magia. Te permite resistir un ataque malintencionado, especialmente del Lazo del Malvado.";
          break;
      }

      final startPos = PerspectiveUtils.project(
        tile.row.toDouble(),
        tile.col,
        screenSize,
        cameraRowOffset: offset,
      );
      add(
        ItemPickupAnimation(startPos: startPos, item: tile.item!)
          ..priority = 600,
      );

      currentEventType = TileType.consumible;
      eventMessage = "Has encontrado: $itemName.\n\n$itemDesc";
      notifyListeners();
      overlays.add('EventMessageOverlay');

      // Auto-continuar si es un bot
      if (currentPlayer.isBot) {
        Future.delayed(const Duration(seconds: 4), () {
          if (eventMessage != null && eventMessage!.contains(itemName)) {
            eventMessage = null;
            endTurnExternal();
            overlays.remove('EventMessageOverlay');
            notifyListeners();
          }
        });
      }
      return true;
    }

    return false;
  }

  void _automationBot() {
    // Automatización del BOT en eventos
    if (currentPlayer.isBot && waitingForEventRoll) {
      _checkBotEventRoll();

      // Fallback: Si el mensaje no se cierra en 5 segundos, auto-continuar para el bot
      if (eventMessage != null) {
        Future.delayed(const Duration(seconds: 5), () {
          if (isGameStarted && currentPlayer.isBot && eventMessage != null) {
            eventMessage = null;
            if (currentEventType == TileType.consumible) {
              endTurnExternal();
            }
            overlays.remove('EventMessageOverlay');
            notifyListeners();
          }
        });
      }
    }
  }

  void _checkBotEventRoll() {
    if (!isGameStarted || !currentPlayer.isBot || !waitingForEventRoll) return;
    
    // Si hay un mensaje activo, esperamos un poco más para que el usuario lea
    if (eventMessage != null) {
      Future.delayed(const Duration(milliseconds: 500), _checkBotEventRoll);
      return;
    }

    Future.delayed(const Duration(milliseconds: 800), () {
      if (currentPlayer.isBot && waitingForEventRoll && eventMessage == null) {
        rollAndMove();
      }
    });
  }

  void updateAudioVolume() {
    if (userProfile.isMuted) {
      FlameAudio.bgm.stop();
    } else {
      if (!FlameAudio.bgm.isPlaying) {
        FlameAudio.bgm.play('ambient.mp3', volume: 0.6);
      }
    }
  }

  double _lastSoundTime = 0;
  void _playSound(String name, {double volume = 1.0}) {
    if (!userProfile.isMuted) {
      // Evitar saturación si se disparan sonidos idénticos muy rápido
      if (elapsedTime - _lastSoundTime < 0.1) return;
      _lastSoundTime = elapsedTime;

      try {
        FlameAudio.play(name, volume: volume);
      } catch (_) {}
    }
  }

  void endTurnExternal() {
    _endTurn();
  }

  PlayerState? _pendingLazoUser;
  PlayerState? _pendingLazoTarget;

  void requestUseLazo() {
    if (currentPlayer.lazoDelMalvadoCount <= 0) return;

    // Buscar al líder (el que tiene el mayor índice de casilla)
    PlayerState? leader;
    int maxIndex = -1;
    for (var p in players) {
      if (p.currentIndex > maxIndex) {
        maxIndex = p.currentIndex;
        leader = p;
      }
    }

    if (leader == null || leader == currentPlayer) {
      eventMessage = "Ya eres el líder. No puedes usar el lazo ahora.";
      notifyListeners();
      Future.delayed(const Duration(seconds: 2), () => eventMessage = null);
      return;
    }

    _pendingLazoUser = currentPlayer;
    _pendingLazoTarget = leader;

    // Verificar si el líder tiene Voluntad de los Antiguos
    if (leader.voluntadDeLosAntiguosCount > 0 && !leader.isBot) {
      // Pedir defensa al humano
      overlays.add('LazoDefenseOverlay');
    } else {
      // El bot no defiende automáticamente por ahora (según lore "independiente")
      // o simplemente procedemos si el líder es un bot.
      resolveLazo(defended: false);
    }
  }

  void resolveLazo({required bool defended}) {
    if (_pendingLazoUser == null || _pendingLazoTarget == null) return;

    final user = _pendingLazoUser!;
    final target = _pendingLazoTarget!;

    user.lazoDelMalvadoCount--;

    if (defended) {
      target.voluntadDeLosAntiguosCount--;
      eventMessage =
          "${target.name} usó la VOLUNTAD DE LOS ANTIGUOS para anular el Lazo de ${user.name}.";
      _playSound('shortcut.mp3'); // Reuse sound for positive effect
    } else {
      // Efecto del lazo: Traer al líder a la posición del usuario
      // Aumentamos la velocidad para el efecto de "tirón"
      target.moveSpeedMultiplier = 8.0; 
      target.currentIndex = user.currentIndex;
      eventMessage =
          "${user.name} ha atrapado a ${target.name} con el LAZO y lo ha arrastrado hasta su posición.";
      _playSound('fall.mp3');
    }

    _pendingLazoUser = null;
    _pendingLazoTarget = null;
    notifyListeners();

    Future.delayed(const Duration(seconds: 4), () {
      eventMessage = null;
      notifyListeners();
    });
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
    final progress = (game.cameraRowOffset / 27.0).clamp(0.0, 1.0);
    if (progress >= 0.99) return; // Summit is clear!

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

    final fogOpacity = (0.82 * (1.0 - progress)).clamp(0.2, 0.82);
    final fogOpaque = (0.98 * (1.0 - progress)).clamp(0.4, 0.98);

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Colors.transparent,
          Colors.transparent,
          Colors.black.withValues(alpha: fogOpacity),
          Colors.black.withValues(alpha: fogOpaque),
          Colors.black.withValues(alpha: 1.0),
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

    // Markers for ALL players
    final totalTiles = game.tiles.length.toDouble();
    if (totalTiles <= 1) return;

    for (var p in game.players) {
      final progress = ((p.currentIndex - 1) / (totalTiles - 1)).clamp(0.0, 1.0);
      final markerY = mapY + mapHeight - (progress * mapHeight);
      
      // Marker circle
      final markerPaint = Paint()..color = p.color;
      canvas.drawCircle(Offset(mapX + mapWidth / 2, markerY), 4, markerPaint);

      // Glow only for the current player or human
      if (p == game.currentPlayer || !p.isBot) {
        final glowPaint = Paint()
          ..color = p.color.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        canvas.drawCircle(Offset(mapX + mapWidth / 2, markerY), 7, glowPaint);
      }
    }

    // Top indicator (CIMA)
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'CIMA',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(mapX - 12, mapY - 20));
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
      if (_timer > 5.0 && _rand.nextDouble() < 0.01) {
        // Rare event (approx every 5+ secs, low chance)
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
    final progress = (game.cameraRowOffset / 27.0).clamp(0.0, 1.0);
    final isSummit = progress >= 0.95;
    
    if (_opacity > 0 || isSummit) {
      final size = game.canvasSize.toSize();
      final effectiveOpacity = isSummit ? 0.3 : _opacity;
      
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: effectiveOpacity),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * (isSummit ? 1.0 : 0.5)));

      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height * 0.5),
        paint,
      );
    }
  }
}

class ItemPickupAnimation extends Component
    with HasGameReference<RutaDeCenizasGame> {
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
