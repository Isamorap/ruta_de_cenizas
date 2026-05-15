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
import 'components/beast_component.dart';
import 'models/user_profile.dart';

class RutaDeCenizasGame extends FlameGame
    with TapCallbacks, KeyboardEvents, ChangeNotifier {
  List<PlayerState> players = [];
  int currentPlayerIndex = 0;
  bool isGameStarted = false;
  bool isStoryMode = false;
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
    "El Inicio: La Era del Sol\n\n\"Hubo un tiempo donde el cielo era un lienzo azul infinito. No valorábamos la luz porque pensábamos que era eterna. Esa fue nuestra primera falta.\"",
    "Conflicto: Vientos de Hierro\n\n\"La diplomacia murió en el frío invierno. Las naciones dejaron de hablar con palabras y empezaron a hablar con uranio y acero.\"",
    "Desastre: El Gran Incendio\n\n\"No fueron bombas lo que destruyó los bosques, sino el 'Fuego Químico'. Una sustancia diseñada para no apagarse nunca. El mundo ardió por dentro.\"",
    "Consecuencia: Manto de Muerte\n\n\"La ceniza no tardó en llegar. Primero fueron los pulmones de los débiles, luego las cosechas, y finalmente, la esperanza de volver a ver una estrella.\"",
    "Supervivencia: Éxodo Vertical\n\n\"Cuando las llanuras se volvieron cementerios de polvo, la mirada de los pocos que quedamos se dirigió hacia arriba. Solo las cumbres ofrecían una tregua.\"",
    "Misterio: El Proyecto Arca\n\n\"Escuché grabaciones de radio sobre búnkeres en las cimas. Decían que allí se guardaba el código genético de lo que alguna vez fue verde. Nunca los encontramos.\"",
    "Terror: Sombras Vivientes\n\n\"La ceniza no es solo residuo, es reactiva. Los animales que no murieron... cambiaron. Sus ojos ahora brillan con un hambre que no es de este mundo.\"",
    "La Bestia: El Guardián\n\n\"He visto a la Bestia de las Cenizas de cerca. No es un animal, parece una amalgama de metal viejo y odio. Se asegura de que nadie abandone el purgatorio de la base.\"",
    "Pérdida: El Silencio de las Máquinas\n\n\"Hoy dejó de funcionar el último satélite. La tecnología de nuestros antepasados es ahora solo chatarra que nos recuerda lo mucho que hemos caído.\"",
    "Desesperanza: Hambre de Espíritu\n\n\"Ya no peleamos por ideologías, peleamos por un poco de agua filtrada. El lazo del malvado no es un arma, es el símbolo de nuestra desesperación.\"",
    "Revelación: Las Cumbres Grises\n\n\"A esta altura, el viento aúlla canciones de guerra. Es como si la montaña misma recordara los gritos de los que intentaron subir antes que yo.\"",
    "Sacrificio: Huellas de Sangre\n\n\"Encontré un campamento. Estaba vacío, pero los suministros estaban intactos. Alguien prefirió morir de frío antes que seguir robando a otros escaladores.\"",
    "Cercanía: La Barrera de Nubes\n\n\"Estoy atravesando el manto negro. Mis manos están cubiertas de hollín, pero por primera vez en años, siento que el aire no quema mis pulmones al respirar.\"",
    "Fe: El Calor del Sol\n\n\"Vi un destello naranja entre las nubes. No es fuego de guerra, es el Sol. Existe. Sigue ahí. Esperándonos para que lo volvamos a reclamar.\"",
    "El Legado: La Última Estación\n\n\"Si logras llegar aquí, no mires atrás. La ceniza se quedará abajo, pero lleva contigo la lección: la cima no es para ser dueño del mundo, sino para cuidarlo.\"",
  ];

  int currentHistoryIndex = 0;
  List<PlayerState>? pendingPlayers;

  final math.Random _rand = math.Random();
  @override
  Color backgroundColor() {
    if (!isGameStarted)
      return const Color(0xFF0A0A0A); // Casi negro, permite ver partículas
    final progress = (cameraRowOffset / 27.0).clamp(0.0, 1.0);

    if (progress >= 0.99) {
      return const Color(0xFF87CEEB); // Sky Blue (vibrante)
    }

    // De negro absoluto a un azul de madrugada/claro al subir
    return Color.lerp(
          const Color(0xFF0A0A0A),
          const Color(0xFF1B263B),
          progress,
        ) ??
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

      tile.priority = 100 - data.row;
      tiles.add(tile);
      add(tile);
    }

    _getTileAtIndex(1)?.isRevealed = true;

    dice.position = Vector2((canvasSize.x - 180) / 2, canvasSize.y - 100);
    dice.priority = 400;
    add(dice);

    add(SunRayOverlay()..priority = 350);
    add(AshFogOverlay()..priority = 300);

    add(MiniMapComponent()..priority = 500);
    add(IntegridadBarComponent()..priority = 500);

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
    // Mantenemos isMoving en true durante el pequeño retardo para bloquear acciones
    Future.delayed(const Duration(milliseconds: 500), () {
      isMoving = false;
      notifyListeners();

      if (currentPlayer.health <= 0) {
        _triggerBeastAnimation();
        return;
      }

      if (currentPlayer.currentIndex == tiles.length) {
        _triggerWin();
        return;
      }

      final currentTile = _getTileAtIndex(currentPlayer.currentIndex);
      if (currentTile != null) {
        currentTile.isRevealed = true;

        bool eventTriggered = _resolveTileEffect(currentTile);

        if (currentTile.type == TileType.normal || !eventTriggered) {
          dice.numDice = 1;
          _endTurn();
        }
      } else {
        _endTurn();
      }
    });
  }

  void _endTurn() {
    if (!waitingForEventRoll) {
      currentPlayerIndex = (currentPlayerIndex + 1) % players.length;
      notifyListeners();
      sessionTurns++;

      if (currentPlayer.isBot && isGameStarted) {
        _performBotAI();
      }
    }
  }

  bool _botActionPending = false;
  void _performBotAI() {
    if (!currentPlayer.isBot || !isGameStarted || isMoving || dice.isRolling || eventMessage != null || _botActionPending)
      return;

    _botActionPending = true;
    Future.delayed(const Duration(milliseconds: 800), () {
      _botActionPending = false;
      if (!isGameStarted || !currentPlayer.isBot || eventMessage != null || isMoving || dice.isRolling)
        return;

      if (currentPlayer.lazoDelMalvadoCount > 0) {
        PlayerState? leader;
        int maxIndex = -1;
        for (var p in players) {
          if (p.currentIndex > maxIndex) {
            maxIndex = p.currentIndex;
            leader = p;
          }
        }

        if (leader != null &&
            leader != currentPlayer &&
            (leader.currentIndex - currentPlayer.currentIndex) > 10) {
          requestUseLazo();
          return;
        }
      }

      if (eventMessage == null) {
        rollAndMove();
      }
    });
  }

  void _triggerBeastAnimation() {
    eventMessage =
        "LA INTEGRIDAD SE HA DESVANECIDO.\n\nLa Bestia de las Cenizas huele tu cansancio, tu debilidad... y viene a reclamar lo que queda de ti.";
    _playSound('fall.mp3');
    notifyListeners();
    overlays.add('EventMessageOverlay');

    add(
      BeastComponent(
        targetPlayer: currentPlayer,
        onFinished: () {
          currentPlayer.reset();
          eventMessage = null;
          _endTurn();
          notifyListeners();
        },
      )..priority = 1000,
    );
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
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    dice.position = Vector2((size.x - 130) / 2, size.y - 80);
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

    // Chequeo proactivo del Bot: si es su turno y no está haciendo nada, que actúe
    if (isGameStarted && currentPlayer.isBot && !isMoving && !dice.isRolling && eventMessage == null) {
      _performBotAI();
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
    "Mi voluntad es más fuerte que el frío.",
  ];

  void _updateAmbientDialogs(double dt) {
    if (isGameStarted && cameraRowOffset > 26.5)
      return; // No ambient dialogs at the top
    _dialogTimer -= dt;
    if (_dialogTimer <= 0) {
      _dialogTimer = 8.0 + _rand.nextDouble() * 10.0; // Random interval
      if (players.isNotEmpty) {
        final p = players[_rand.nextInt(players.length)];
        if (p.currentDialog == null) {
          p.currentDialog =
              _ambientDialogs[_rand.nextInt(_ambientDialogs.length)];
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
      final msg = _barrancoMessages[_rand.nextInt(_barrancoMessages.length)];
      eventMessage = "¡BARRANCO!\n\n$msg";
      notifyListeners();
      overlays.add('EventMessageOverlay');
      _automationBot();
      return true;
    } else if (tile.type == TileType.atajo) {
      _playSound('shortcut.mp3');
      waitingForEventRoll = true;
      dice.numDice = 2;
      currentEventType = TileType.atajo;
      final msg = _atajoMessages[_rand.nextInt(_atajoMessages.length)];
      eventMessage = "¡ATAJO!\n\n$msg";
      notifyListeners();
      overlays.add('EventMessageOverlay');
      _automationBot();
      return true;
    } else if (tile.type == TileType.historia) {
      _playSound('paper_sound.mp3');
      waitingForEventRoll = true;
      currentEventType = TileType.historia;
      dice.numDice = 1;
      String historiaText;

      if (isStoryMode) {
        historiaText =
            "FRAGMENTO DE HISTORIA:\n\n${fragmentosHistoria[currentHistoryIndex]}";
      } else {
        historiaText =
            "¡FRAGMENTO ENCONTRADO!\n\nHas hallado restos de una expedición pasada. Tienes otro turno.";
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
      eventMessage = "Has encontrado: $itemName";
      notifyListeners();
      overlays.add('EventMessageOverlay');

      return true;
    }

    return false;
  }

  void dismissEvent() {
    if (eventMessage == null) return;

    final wasConsumible = currentEventType == TileType.consumible;
    final wasHistoria = currentEventType == TileType.historia;

    eventMessage = null;
    overlays.remove('EventMessageOverlay');

    // Si había un lazo pendiente que mostró un mensaje, lo resolvemos ahora
    if (_pendingLazoUser != null && _pendingLazoTarget != null) {
      resolveLazo(defended: false);
      return;
    }

    if (wasConsumible || wasHistoria) {
      if (wasHistoria) {
        if (currentPlayer.isBot) {
          rollAndMove();
        }
      } else {
        _endTurn();
      }
    } else if (waitingForEventRoll) {
      if (currentPlayer.isBot) {
        rollAndMove();
      }
    } else {
      _endTurn();
    }

    // Activar IA si sigue el turno de un bot y no hay mensajes
    if (currentPlayer.isBot &&
        isGameStarted &&
        !isMoving &&
        !dice.isRolling &&
        eventMessage == null) {
      _performBotAI();
    }

    notifyListeners();
  }

  void _automationBot() {
    // Los bots ya no cierran mensajes solos.
    // Ahora esperan a que el humano presione "Continuar" por ellos
    // o a que se llame a dismissEvent().
  }

  void _checkBotEventRoll() {
    // Ya no es necesaria la comprobación recursiva automática
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

    // Si el objetivo es un bot, resolvemos según si tiene el ítem
    if (leader.isBot) {
      if (leader.voluntadDeLosAntiguosCount > 0) {
        resolveLazo(defended: true);
      } else {
        resolveLazo(defended: false);
      }
      return;
    }

    // Si el objetivo es un humano, siempre notificamos
    if (leader.voluntadDeLosAntiguosCount > 0) {
      // El humano tiene defensa, mostramos el overlay de decisión
      overlays.add('LazoDefenseOverlay');
    } else {
      // El humano NO tiene defensa, mostramos mensaje de evento y luego resolvemos
      eventMessage =
          "¡${currentPlayer.name} ha lanzado el LAZO DEL MALVADO contra ti!\n\nNo tienes nada para defenderte...";
      notifyListeners();
      overlays.add('EventMessageOverlay');
      // resolveLazo se llamará desde dismissEvent si detecta que hay un lazo pendiente
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

    // Mostrar el resultado del lazo
    overlays.add('EventMessageOverlay');
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
      if (currentPlayer.isBot) return KeyEventResult.ignored;
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
    if (game.players.isEmpty) return;
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
      final progress = ((p.currentIndex - 1) / (totalTiles - 1)).clamp(
        0.0,
        1.0,
      );
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
    if (game.players.isEmpty) return;
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
    final progress = (game.cameraRowOffset / 27.0).clamp(0.0, 1.0);
    if (progress >= 0.99) {
      _opacity = 0;
      _isFlashing = false;
      return;
    }

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
