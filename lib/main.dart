import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:window_manager/window_manager.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/tile_type.dart';
import 'models/player_state.dart';
import 'models/character_data.dart';
import 'models/user_profile.dart';
import 'ruta_de_cenizas_game.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && Platform.isLinux) {
    await windowManager.ensureInitialized();
    WindowOptions windowOptions = const WindowOptions(
      size: Size(450, 800), // Proporción 9:16 para capturas verticales.
      center: true,
      title: "Ruta de Cenizas - Recording Mode",
    );
    windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setAspectRatio(9 / 16);
    });
  }

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  final profile = await UserProfile.load();
  final game = RutaDeCenizasGame();
  game.userProfile = profile;

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        textTheme: GoogleFonts.cinzelTextTheme(ThemeData.dark().textTheme),
      ),
      home: Scaffold(
        body: GameWidget<RutaDeCenizasGame>(
          game: game,
          overlayBuilderMap: {
            'DiceUI': (context, game) =>
                DiceUI(game: game as RutaDeCenizasGame),
            'EventMessageOverlay': (context, game) =>
                EventMessageOverlay(game: game as RutaDeCenizasGame),
            'InventoryButton': (context, game) =>
                InventoryButton(game: game as RutaDeCenizasGame),
            'BackToMenuButton': (context, game) =>
                BackToMenuButton(game: game as RutaDeCenizasGame),
            'NarrativeOverlay': (context, game) =>
                NarrativeOverlay(game: game as RutaDeCenizasGame),
            'SoloSetupOverlay': (context, game) =>
                SoloSetupOverlay(game: game as RutaDeCenizasGame),
            'LobbyOverlay': (context, game) =>
                LobbyOverlay(game: game as RutaDeCenizasGame),
            'ExtrasOverlay': (context, game) =>
                ExtrasOverlay(game: game as RutaDeCenizasGame),
            'InventoryMenu': (context, game) =>
                InventoryMenu(game: game as RutaDeCenizasGame),
            'InventoryPrompt': (context, game) =>
                InventoryPrompt(game: game as RutaDeCenizasGame),
            'SettingsOverlay': (context, game) =>
                SettingsOverlay(game: game as RutaDeCenizasGame),
            'MainMenuOverlay': (context, game) =>
                MainMenuOverlay(game: game as RutaDeCenizasGame),
            'LazoDefenseOverlay': (context, game) =>
                LazoDefenseOverlay(game: game as RutaDeCenizasGame),
            'GameSummaryOverlay': (context, game) =>
                GameSummaryOverlay(game: game as RutaDeCenizasGame),
            'CosmeticShopOverlay': (context, game) =>
                CosmeticShopOverlay(game: game as RutaDeCenizasGame),
            'GlossaryOverlay': (context, game) =>
                GlossaryOverlay(game: game as RutaDeCenizasGame),
          },
          initialActiveOverlays: const [
            'MainMenuOverlay',
            'DiceUI',
            'EventMessageOverlay',
            'InventoryButton',
            'BackToMenuButton',
          ],
        ),
      ),
    ),
  );
}

class MainMenuOverlay extends StatelessWidget {
  final RutaDeCenizasGame game;
  const MainMenuOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        final profile = game.userProfile;
        return Stack(
          children: [
            Container(
              color: const Color(0xFF0A0A0A),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      "RUTA\nDE CENIZAS",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w200,
                        letterSpacing: 12,
                        height: 1.6,
                        color: Colors.white,
                        shadows: [
                          Shadow(
                            color: Colors.white.withValues(alpha: 0.15),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      "PreAlpha 0.0.5",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w100,
                        letterSpacing: 12,
                        height: 1.6,
                        color: Colors.amber,
                        shadows: [
                          Shadow(
                            color: Colors.amber.withValues(alpha: 0.15),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 60),
                    _menuButton("HISTORIA", () {
                      game.overlays.add('SoloSetupOverlay');
                      game.overlays.remove('MainMenuOverlay');
                    }),
                    _menuButton("MULTIJUGADOR LOCAL", () {
                      game.overlays.add('LobbyOverlay');
                      game.overlays.remove('MainMenuOverlay');
                    }),
                    _menuButton("MULTIJUGADOR ONLINE", null), // Próximamente
                    _menuButton("CARRERA", () {
                      game.overlays.add('ExtrasOverlay');
                      game.overlays.remove('MainMenuOverlay');
                    }),
                    _menuButton("GLOSARIO", () {
                      game.overlays.add('GlossaryOverlay');
                      game.overlays.remove('MainMenuOverlay');
                    }),
                    _menuButton("ACERCA DE", () {
                      game.overlays.add('SettingsOverlay');
                      game.overlays.remove('MainMenuOverlay');
                    }),
                  ],
                ),
              ),
            ),
            // Mute button in the same position as Extras
            Positioned(
              top: 30,
              right: 30,
              child: IconButton(
                onPressed: () {
                  profile.isMuted = !profile.isMuted;
                  profile.save();
                  game.updateAudioVolume();
                  game.notifyListeners(); // Trigger rebuild for ListenableBuilder
                },
                icon: Icon(
                  profile.isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white54,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _menuButton(String text, VoidCallback? onPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: SizedBox(
        width: 250,
        child: OutlinedButton(
          onPressed: onPressed,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            side: const BorderSide(color: Colors.white24, width: 0.5),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.zero,
            ),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white24,
          ),
          child: Text(
            text,
            style: const TextStyle(
              letterSpacing: 4,
              fontSize: 12,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
      ),
    );
  }
}

class LobbyOverlay extends StatefulWidget {
  final RutaDeCenizasGame game;
  const LobbyOverlay({super.key, required this.game});

  @override
  State<LobbyOverlay> createState() => _LobbyOverlayState();
}

class _LobbyOverlayState extends State<LobbyOverlay> {
  int _playerCount = 2;
  bool _isConfiguring = false;
  late List<TextEditingController> _nameCtrls;
  late List<int> _selectedChars;
  late List<Color> _selectedColors;

  @override
  void initState() {
    super.initState();
    _nameCtrls = List.generate(
      4,
      (i) => TextEditingController(
        text: i == 0 ? widget.game.userProfile.name : "Jugador ${i + 1}",
      ),
    );
    _selectedChars = List.generate(4, (i) => i);
    _selectedColors = List.generate(4, (i) => kCharacters[i % kCharacters.length].color);
  }

  @override
  void dispose() {
    for (var ctrl in _nameCtrls) {
      ctrl.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0A).withValues(alpha: 0.98),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _isConfiguring ? _buildStep2() : _buildStep1(),
          ),
        ),
      ),
    );
  }

  // PASO 1: Selección de cantidad de jugadores
  Widget _buildStep1() {
    return Container(
      key: const ValueKey('step1'),
      width: 350,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(border: Border.all(color: Colors.white10)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "MULTIJUGADOR LOCAL",
            style: TextStyle(
              letterSpacing: 4,
              fontSize: 14,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "¿Cuántos escaladores subirán hoy?",
            style: TextStyle(fontSize: 10, color: Colors.white54),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [2, 3, 4].map((n) {
              final selected = _playerCount == n;
              return GestureDetector(
                onTap: () => setState(() => _playerCount = n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? Colors.amber : Colors.white10,
                      width: selected ? 2 : 1,
                    ),
                    color: selected
                        ? Colors.amber.withValues(alpha: 0.1)
                        : Colors.transparent,
                  ),
                  child: Center(
                    child: Text(
                      n.toString(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: selected ? Colors.amber : Colors.white24,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 50),
          OutlinedButton(
            onPressed: () => setState(() => _isConfiguring = true),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white24),
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
            ),
            child: const Text("CONTINUAR", style: TextStyle(letterSpacing: 2)),
          ),
          TextButton(
            onPressed: () {
              widget.game.overlays.add('MainMenuOverlay');
              widget.game.overlays.remove('LobbyOverlay');
            },
            child: const Text(
              "VOLVER",
              style: TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  // PASO 2: Configuración de cada jugador
  Widget _buildStep2() {
    return Container(
      key: const ValueKey('step2'),
      width: 450,
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "CONFIGURAR EQUIPO",
            style: TextStyle(
              letterSpacing: 4,
              fontSize: 14,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 30),
          ...List.generate(_playerCount, (i) => _buildPlayerConfig(i)),
          const SizedBox(height: 40),
          OutlinedButton(
            onPressed: () {
              final players = List.generate(_playerCount, (i) {
                final char = kCharacters[_selectedChars[i]];
                return PlayerState(
                  name: _nameCtrls[i].text.trim().isEmpty
                      ? "Jugador ${i + 1}"
                      : _nameCtrls[i].text.trim(),
                  color: _selectedColors[i],
                  characterId: char.id,
                  isBot: false,
                );
              });
              widget.game.isStoryMode = false;
              widget.game.startGame(players);
              widget.game.overlays.remove('LobbyOverlay');
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.amber),
              foregroundColor: Colors.amber,
              padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 20),
            ),
            child: const Text(
              "INICIAR EXPEDICIÓN",
              style: TextStyle(letterSpacing: 2, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => _isConfiguring = false),
            child: const Text(
              "ATRÁS",
              style: TextStyle(color: Colors.white24, fontSize: 10),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerConfig(int i) {
    final char = kCharacters[_selectedChars[i]];
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "JUGADOR ${i + 1}",
            style: TextStyle(
              fontSize: 10,
              color: char.color,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Selector de Personaje (Mini)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedChars[i] =
                        (_selectedChars[i] + 1) % kCharacters.length;
                  });
                },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: char.color.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: char.color, width: 1.5),
                  ),
                  child: Icon(char.icon, color: char.color, size: 24),
                ),
              ),
              const SizedBox(width: 15),
              // Nombre
              Expanded(
                child: TextField(
                  controller: _nameCtrls[i],
                  style: const TextStyle(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: "Nombre",
                    hintStyle: const TextStyle(color: Colors.white24),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.white10),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: char.color),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // Selector de Color para este jugador
          SizedBox(
            height: 24,
            child: Row(
              children: [
                const Text(
                  "COLOR:",
                  style: TextStyle(fontSize: 8, color: Colors.white24, letterSpacing: 1),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: kAvailableColors.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, colorIndex) {
                      final color = kAvailableColors[colorIndex];
                      final isSelected = _selectedColors[i] == color;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedColors[i] = color),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsOverlay extends StatelessWidget {
  final RutaDeCenizasGame game;
  const SettingsOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "ACERCA DE",
              style: TextStyle(
                letterSpacing: 4,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 40),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(
                    height: 1.8,
                    fontWeight: FontWeight.w200,
                    fontStyle: FontStyle.italic,
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                  children: [
                    const TextSpan(
                      text:
                          "Este juego es una reinterpretación atmosférica y estratégica del clásico ",
                    ),
                    const TextSpan(
                      text: "Serpientes y Escaleras",
                      style: TextStyle(
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                    const TextSpan(text: ".\nDesarrollado por "),
                    TextSpan(
                      text: "Isaac Mora",
                      style: const TextStyle(
                        color: Colors.blueAccent, // Color de link
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w400,
                      ),
                      recognizer: TapGestureRecognizer()
                        ..onTap = () async {
                          final Uri url = Uri.parse(
                            'https://github.com/Isamorap/ruta_de_cenizas',
                          );
                          if (!await launchUrl(url)) {
                            throw Exception('No se pudo abrir $url');
                          }
                        },
                    ),
                    const TextSpan(
                      text: " como un proyecto personal sin fines de lucro.",
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 60),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white30),
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
              ),
              onPressed: () {
                game.overlays.add('MainMenuOverlay');
                game.overlays.remove('SettingsOverlay');
              },
              child: const Text(
                "VOLVER AL MENÚ",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildInventoryItem(
  IconData icon,
  Color color,
  String name,
  int count, {
  VoidCallback? onTap,
}) {
  return InkWell(
    onTap: count > 0 ? onTap : null,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 4, left: 4, right: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: count > 0 ? Colors.white : Colors.white54,
                  fontSize: 13,
                ),
              ),
              if (onTap != null && count > 0)
                const Text(
                  "Toca para usar",
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.amber,
                    letterSpacing: 1,
                  ),
                ),
            ],
          ),
          const Spacer(),
          Text(
            "x$count",
            style: TextStyle(
              color: count > 0 ? Colors.white : Colors.white54,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── Pantalla de preparación para 1 jugador ──────────────────────────────────
class SoloSetupOverlay extends StatefulWidget {
  final RutaDeCenizasGame game;
  const SoloSetupOverlay({super.key, required this.game});

  @override
  State<SoloSetupOverlay> createState() => _SoloSetupOverlayState();
}

class _SoloSetupOverlayState extends State<SoloSetupOverlay> {
  int _selectedChar = 0;
  late Color _customColor;
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _customColor = kCharacters[_selectedChar].color;
    _nameCtrl = TextEditingController(text: widget.game.userProfile.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final char = kCharacters[_selectedChar];
    return Container(
      color: const Color(0xFF0A0A0A),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Título ────────────────────────────────────
              const Text(
                'ELIGE TU PERSONAJE',
                style: TextStyle(
                  letterSpacing: 4,
                  fontSize: 13,
                  color: Colors.white54,
                ),
              ),
              const SizedBox(height: 30),

              // ── Previsualización del personaje seleccionado ─
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: char.color, width: 2),
                  color: char.color.withValues(alpha: 0.1),
                ),
                child: Icon(char.icon, color: char.color, size: 48),
              ),
              const SizedBox(height: 12),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: char.color,
                  fontSize: 16,
                  letterSpacing: 3,
                ),
                child: Text(char.displayName.toUpperCase()),
              ),
              const SizedBox(height: 30),

              // ── Grid de selección ──────────────────────────
              SizedBox(
                width: 320,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 12,
                  runSpacing: 12,
                  children: List.generate(kCharacters.length, (i) {
                    final c = kCharacters[i];
                    final selected = i == _selectedChar;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedChar = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected ? c.color : Colors.white12,
                            width: selected ? 2.5 : 1,
                          ),
                          color: selected
                              ? c.color.withValues(alpha: 0.2)
                              : Colors.white.withValues(alpha: 0.03),
                        ),
                        child: Icon(
                          c.icon,
                          color: selected ? c.color : Colors.white24,
                          size: 28,
                        ),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 35),

              // ── Selector de Color ──────────────────────────
              const Text(
                'COLOR DE FICHA',
                style: TextStyle(
                  letterSpacing: 2,
                  fontSize: 10,
                  color: Colors.white24,
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: 320,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: kAvailableColors.map((color) {
                    final isSelected = _customColor == color;
                    return GestureDetector(
                      onTap: () => setState(() => _customColor = color),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.white10,
                            width: isSelected ? 2 : 1,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 10,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 35),

              // ── Nombre del jugador ─────────────────────────
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _nameCtrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    letterSpacing: 2,
                    fontSize: 14,
                  ),
                  maxLength: 20,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'TU NOMBRE',
                    hintStyle: TextStyle(
                      color: Colors.white24,
                      letterSpacing: 2,
                      fontSize: 12,
                    ),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(
                        color: char.color.withValues(alpha: 0.5),
                      ),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: char.color),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // ── Botón iniciar ──────────────────────────────
              OutlinedButton(
                onPressed: () {
                  final name = _nameCtrl.text.trim().isEmpty
                      ? 'Explorador'
                      : _nameCtrl.text.trim();
                  widget.game.userProfile.name = name;
                  widget.game.userProfile.save();

                  final players = [
                    PlayerState(
                      name: name,
                      color: _customColor,
                      characterId: char.id,
                      isBot: false,
                    ),
                    PlayerState(
                      name: "La Sombra",
                      color: Colors.redAccent,
                      characterId: 'char7',
                      isBot: true,
                    ),
                  ];

                  widget.game.isStoryMode = true;
                  if (widget.game.userProfile.isFirstTimeStory) {
                    widget.game.overlays.add('NarrativeOverlay');
                    // Store players to start after intro
                    widget.game.pendingPlayers = players;
                  } else {
                    widget.game.startGame(players);
                  }
                  widget.game.overlays.remove('SoloSetupOverlay');
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: char.color.withValues(alpha: 0.6)),
                  foregroundColor: char.color,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: const Text(
                  'INICIAR EXPEDICIÓN',
                  style: TextStyle(letterSpacing: 3, fontSize: 11),
                ),
              ),
              const SizedBox(height: 16),

              // ── Volver ─────────────────────────────────────
              TextButton(
                onPressed: () {
                  widget.game.overlays.add('MainMenuOverlay');
                  widget.game.overlays.remove('SoloSetupOverlay');
                },
                child: const Text(
                  'VOLVER',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: 10,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExtrasOverlay extends StatefulWidget {
  final RutaDeCenizasGame game;
  const ExtrasOverlay({super.key, required this.game});

  @override
  State<ExtrasOverlay> createState() => _ExtrasOverlayState();
}

class _ExtrasOverlayState extends State<ExtrasOverlay> {
  late final TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.game.userProfile.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.game.userProfile;
    return Container(
      color: const Color(0xFF0A0A0A),
      child: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 400,
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "CARRERA",
                      style: TextStyle(letterSpacing: 4, fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Perfil
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white10),
                    color: Colors.white.withValues(alpha: 0.02),
                  ),
                  child: Column(
                    children: [
                      // Nombre Editable
                      TextField(
                        controller: _nameCtrl,
                        textAlign: TextAlign.center,
                        maxLength: 15,
                        style: const TextStyle(
                          fontSize: 20,
                          letterSpacing: 2,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          counterText: "",
                          hintText: "Tu Nombre",
                          hintStyle: TextStyle(
                            color: Colors.white24,
                            fontSize: 14,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.save,
                              color: Colors.amber,
                              size: 20,
                            ),
                            onPressed: () {
                              if (_nameCtrl.text.trim().isNotEmpty) {
                                widget.game.userProfile.name = _nameCtrl.text
                                    .trim();
                                widget.game.userProfile.save();
                                widget.game.notifyListeners();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("Nombre guardado"),
                                  ),
                                );
                                setState(() {});
                              }
                            },
                          ),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white10),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.amber),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "NIVEL ${profile.level}",
                        style: const TextStyle(
                          color: Colors.amber,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      LinearProgressIndicator(
                        value: (profile.xp % 500) / 500,
                        backgroundColor: Colors.white10,
                        valueColor: const AlwaysStoppedAnimation(Colors.amber),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "${profile.xp % 500} / 500 XP",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white38,
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "TÍTULOS DESBLOQUEADOS",
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.white24,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 5,
                        children: profile.earnedTitles
                            .map(
                              (t) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.amber.withValues(alpha: 0.3),
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  t,
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Colors.amber,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Estadísticas
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat("LOCAL", profile.localWins.toString()),
                    _stat("ONLINE", profile.onlineWins.toString()),
                    _stat("ESCALADO", "${profile.totalTilesClimbed * 50}m"),
                  ],
                ),

                const SizedBox(height: 30),

                // Fragmentos
                const Text(
                  "FRAGMENTOS DE HISTORIA",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white54,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  children: List.generate(
                    10,
                    (i) => Icon(
                      Icons.menu_book,
                      size: 20,
                      color: profile.historyFragments[i]
                          ? Colors.amber
                          : Colors.white10,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                if (profile.allFragmentsUnlocked)
                  OutlinedButton(
                    onPressed: () {
                      // TODO: Implement shop
                    },
                    child: const Text(
                      "TIENDA DE EXTRAS",
                      style: TextStyle(color: Colors.cyanAccent),
                    ),
                  )
                else
                  const Text(
                    "Completa la historia para desbloquear la tienda",
                    style: TextStyle(fontSize: 10, color: Colors.white24),
                  ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: () {
                    widget.game.overlays.add('MainMenuOverlay');
                    widget.game.overlays.remove('ExtrasOverlay');
                  },
                  child: const Text(
                    "VOLVER",
                    style: TextStyle(color: Colors.white24),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: Colors.white38,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

// ─── Pantalla Narrativa / Tutorial ───────────────────────────────────────────
class NarrativeOverlay extends StatefulWidget {
  final RutaDeCenizasGame game;
  const NarrativeOverlay({super.key, required this.game});

  @override
  State<NarrativeOverlay> createState() => _NarrativeOverlayState();
}

class _NarrativeOverlayState extends State<NarrativeOverlay> {
  int _step = 0;
  late final List<String> _dialogs;

  @override
  void initState() {
    super.initState();
    final name = widget.game.userProfile.name;
    _dialogs = [
      'Bienvenido, $name. En un mundo acabado por las guerras y con la magia desaparecida de la faz de la tierra, buscas la luz una vez más.',
      'Una densa capa de cenizas ha cubierto el mundo, pero tienes la esperanza de que en la cima el aire pueda ser respirable.',
      'Hay más habitantes queriendo escalar, pero no todos tienen buenas intenciones. Suerte.',
      'TUTORIAL: Lanza los dados y escala la montaña.',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.9),
      child: Center(
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white10),
            color: const Color(0xFF0A0A0A),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_stories, color: Colors.amber, size: 32),
              const SizedBox(height: 30),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                child: Text(
                  _dialogs[_step],
                  key: ValueKey(_step),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                    fontStyle: FontStyle.italic,
                    color: Colors.white70,
                  ),
                ),
              ),
              const SizedBox(height: 40),
              OutlinedButton(
                onPressed: () {
                  if (_step < _dialogs.length - 1) {
                    setState(() => _step++);
                  } else {
                    widget.game.userProfile.isFirstTimeStory = false;
                    widget.game.userProfile.save();
                    if (widget.game.pendingPlayers != null) {
                      widget.game.startGame(widget.game.pendingPlayers!);
                      widget.game.pendingPlayers = null;
                    }
                    widget.game.overlays.remove('NarrativeOverlay');
                  }
                },
                child: Text(
                  _step == _dialogs.length - 1 ? "EMPEZAR" : "SIGUIENTE",
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Botón Volver al Menú ──────────────────────────────────────────────────
class BackToMenuButton extends StatelessWidget {
  final RutaDeCenizasGame game;
  const BackToMenuButton({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        if (!game.isGameStarted) return const SizedBox.shrink();
        return Positioned(
          top: 20,
          left: 20,
          child: GestureDetector(
            onTap: () => game.returnToMenu(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                border: Border.all(color: Colors.white12),
                borderRadius: BorderRadius.circular(2),
              ),
              child: const Icon(Icons.menu, color: Colors.white54, size: 18),
            ),
          ),
        );
      },
    );
  }
}

// ─── Menú de Inventario ─────────────────────────────────────────────────────
class InventoryMenu extends StatelessWidget {
  final RutaDeCenizasGame game;
  const InventoryMenu({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        // En modo historia/solo, siempre mostramos el inventario del jugador humano
        final humanPlayer = game.players.firstWhere(
          (p) => !p.isBot,
          orElse: () => game.currentPlayer,
        );

        return Center(
          child: Container(
            width: 320,
            height: 480, // Slightly taller for defense info
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: const Color(0xFF121212).withValues(alpha: 0.98),
              border: Border.all(color: Colors.white10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "INVENTARIO",
                      style: TextStyle(
                        letterSpacing: 2,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54),
                      onPressed: () => game.overlays.remove('InventoryMenu'),
                    ),
                  ],
                ),
                const Divider(color: Colors.white10),
                const SizedBox(height: 10),
                _buildInventoryItem(
                  Icons.hiking,
                  const Color(0xFF8B4513),
                  "Zapatos de Escalada",
                  humanPlayer.zapatosDeEscaladaCount,
                  desc: "Te protegen de las caídas en barrancos.",
                ),
                _buildInventoryItem(
                  Icons.all_inclusive,
                  const Color(0xFF8A2BE2),
                  "Lazo del Malvado",
                  humanPlayer.lazoDelMalvadoCount,
                  desc: "Atrapa al líder y tráelo a tu posición.",
                  onTap: () {
                    if (game.currentPlayer.isBot) return;
                    game.requestUseLazo();
                    game.overlays.remove('InventoryMenu');
                  },
                ),
                _buildInventoryItem(
                  Icons.shield,
                  const Color(0xFFFFD700),
                  "Voluntad de los Antiguos",
                  humanPlayer.voluntadDeLosAntiguosCount,
                  desc: "Te protege del Lazo del Malvado.",
                ),
                const Spacer(),
                const Text(
                  "HISTORIA",
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.white24,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: game.currentHistoryIndex,
                    itemBuilder: (context, i) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.menu_book,
                        size: 16,
                        color: Colors.amber,
                      ),
                      title: Text(
                        "Fragmento ${i + 1}",
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                        ),
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1A1A1A),
                            title: Text(
                              "FRAGMENTO ${i + 1}",
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 14,
                              ),
                            ),
                            content: Text(
                              game.fragmentosHistoria[i],
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text("CERRAR"),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInventoryItem(
    IconData icon,
    Color color,
    String name,
    int count, {
    String? desc,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: count > 0 ? onTap : null,
        child: Opacity(
          opacity: count > 0 ? 1.0 : 0.3,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (desc != null)
                      Text(
                        desc,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white38,
                        ),
                      ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text("x$count", style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Defensa del Lazo ────────────────────────────────────────────────────────
class LazoDefenseOverlay extends StatelessWidget {
  final RutaDeCenizasGame game;
  const LazoDefenseOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 300,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          border: Border.all(color: Colors.amber),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.2),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield, color: Colors.amber, size: 48),
            const SizedBox(height: 20),
            const Text(
              "¡ATAQUE DETECTADO!",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: Colors.amber,
              ),
            ),
            const SizedBox(height: 15),
            const Text(
              "Alguien está intentando usar el Lazo del Malvado contra ti. ¿Quieres usar tu Voluntad de los Antiguos para protegerte?",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.white),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
              ),
              onPressed: () {
                game.resolveLazo(defended: true);
                game.overlays.remove('LazoDefenseOverlay');
              },
              child: const Text("USAR VOLUNTAD"),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () {
                game.resolveLazo(defended: false);
                game.overlays.remove('LazoDefenseOverlay');
              },
              child: const Text(
                "NO HACER NADA",
                style: TextStyle(color: Colors.white24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Prompt de Zapatos ──────────────────────────────────────────────────────
class InventoryPrompt extends StatelessWidget {
  final RutaDeCenizasGame game;
  const InventoryPrompt({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.warning_amber, color: Colors.amber, size: 40),
            const SizedBox(height: 20),
            const Text("¿USAR ZAPATOS?", style: TextStyle(letterSpacing: 2)),
            const SizedBox(height: 15),
            const Text(
              "Puedes gastar tu zapato para evitar la caída del barranco.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
            const SizedBox(height: 30),
            OutlinedButton(
              onPressed: () {
                game.useZapatos();
                game.overlays.remove('InventoryPrompt');
              },
              child: const Text("USAR ZAPATO"),
            ),
            TextButton(
              onPressed: () {
                game.overlays.remove('InventoryPrompt');
                game.triggerFall();
              },
              child: const Text(
                "ARRIESGARSE",
                style: TextStyle(color: Colors.white24),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Indicador de Turno ───────────────────────────────────────────────────
class DiceUI extends StatelessWidget {
  final RutaDeCenizasGame game;
  const DiceUI({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        if (!game.isGameStarted || game.players.length <= 1)
          return const SizedBox.shrink();
        return Positioned(
          top: 20,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: game.currentPlayer.color.withValues(alpha: 0.15),
                border: Border.all(
                  color: game.currentPlayer.color.withValues(alpha: 0.5),
                ),
                borderRadius: BorderRadius.circular(2),
              ),
              child: Text(
                'TURNO DE ${game.currentPlayer.name.toUpperCase()}',
                style: TextStyle(
                  color: game.currentPlayer.color,
                  fontSize: 11,
                  letterSpacing: 3,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Mensajes de Evento ─────────────────────────────────────────────────────
class EventMessageOverlay extends StatelessWidget {
  final RutaDeCenizasGame game;
  const EventMessageOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        if (game.eventMessage == null) return const SizedBox.shrink();

        final isAtajo = game.currentEventType == TileType.atajo;
        final isHistoria = game.currentEventType == TileType.historia;
        final isConsumible = game.currentEventType == TileType.consumible;
        final isWin = game.eventMessage?.contains("HA CONQUISTADO") ?? false;

        Color bgColor = const Color(0xFF121212).withValues(alpha: 0.95);
        Color accentColor = isAtajo
            ? const Color(0xFF00CED1)
            : const Color(0xFFFF4500);
        Color textColor = Colors.white;
        IconData icon = isAtajo
            ? Icons.auto_awesome
            : Icons.warning_amber_rounded;
        String title = isAtajo ? "FORTUNA" : "PELIGRO";

        if (isWin) {
          accentColor = Colors.amber;
          icon = Icons.emoji_events;
          title = "VICTORIA";
        } else if (isConsumible) {
          accentColor = const Color(0xFF9370DB);
          icon = Icons.auto_awesome;
          title = "OBJETO";
        } else if (isHistoria) {
          bgColor = const Color(0xFFE6D5B8).withValues(alpha: 0.95);
          accentColor = const Color(0xFF5D4037);
          textColor = const Color(0xFF3E2723);
          icon = Icons.menu_book;
          title = "FRAGMENTO";
        }

        return Center(
          child: Container(
            width: 320,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: bgColor,
              border: Border.all(color: accentColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: accentColor, size: 48),
                const SizedBox(height: 15),
                Text(
                  title,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 14,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                const Divider(color: Colors.white10),
                const SizedBox(height: 15),
                Text(
                  game.eventMessage ?? "",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.9),
                    fontSize: 15,
                    height: 1.5,
                    fontStyle: isHistoria ? FontStyle.italic : FontStyle.normal,
                  ),
                ),
                const SizedBox(height: 30),
                if (isWin)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 15,
                      ),
                      shape: const RoundedRectangleBorder(),
                    ),
                    onPressed: () {
                      game.eventMessage = null;
                      game.isGameStarted = false;
                      game.overlays.add('MainMenuOverlay');
                      game.overlays.remove('EventMessageOverlay');
                    },
                    child: const Text(
                      "VOLVER AL MENÚ",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  )
                else
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: accentColor),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 40,
                        vertical: 12,
                      ),
                      shape: const RoundedRectangleBorder(),
                    ),
                    onPressed: () => game.dismissEvent(),
                    child: Text(
                      "CONTINUAR",
                      style: TextStyle(color: accentColor, letterSpacing: 2),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── Botón de Inventario ────────────────────────────────────────────────────
class InventoryButton extends StatelessWidget {
  final RutaDeCenizasGame game;
  const InventoryButton({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        if (!game.isGameStarted) return const SizedBox.shrink();

        // El botón solo debe ser interactuable en el turno del humano
        final isHumanTurn = !game.currentPlayer.isBot;

        return Positioned(
          bottom: 20,
          right: 20,
          child: Opacity(
            opacity: isHumanTurn ? 1.0 : 0.5,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFF121212).withValues(alpha: 0.9),
              mini: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.backpack_outlined, color: Colors.white),
              onPressed: () {
                if (!isHumanTurn) return;
                if (game.overlays.isActive('InventoryMenu')) {
                  game.overlays.remove('InventoryMenu');
                } else {
                  game.overlays.add('InventoryMenu');
                }
              },
            ),
          ),
        );
      },
    );
  }
}

// ─── Resumen de Partida ─────────────────────────────────────────────────────
class GameSummaryOverlay extends StatelessWidget {
  final RutaDeCenizasGame game;
  const GameSummaryOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 350,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          border: Border.all(color: Colors.amber, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.1),
              blurRadius: 30,
              spreadRadius: 10,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, color: Colors.amber, size: 60),
            const SizedBox(height: 20),
            const Text(
              "RESUMEN DE LA ASCENSIÓN",
              style: TextStyle(
                color: Colors.amber,
                fontSize: 18,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Divider(color: Colors.white24),
            const SizedBox(height: 20),
            _buildStatRow("Turnos jugados", "${game.sessionTurns}"),
            _buildStatRow("Objetos encontrados", "${game.sessionItemsUsed}"),
            _buildStatRow("Casillas perdidas", "${game.sessionTilesLost}"),
            _buildStatRow("Nivel actual", "${game.userProfile.level}"),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 50,
                  vertical: 15,
                ),
                shape: const RoundedRectangleBorder(),
              ),
              onPressed: () {
                game.returnToMenu();
                game.overlays.remove('GameSummaryOverlay');
                game.overlays.add('MainMenuOverlay');
              },
              child: const Text(
                "VOLVER AL MENÚ",
                style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tienda de Cosméticos (Placeholder) ──────────────────────────────────────
class CosmeticShopOverlay extends StatelessWidget {
  final RutaDeCenizasGame game;
  const CosmeticShopOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 380,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: const Color(0xFF121212),
          border: Border.all(color: Colors.white24, width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 40,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "TIENDA DE RECUERDOS",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    letterSpacing: 2,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => game.overlays.remove('CosmeticShopOverlay'),
                ),
              ],
            ),
            const Divider(color: Colors.white12),
            const SizedBox(height: 40),
            const Icon(Icons.storefront, color: Colors.white24, size: 80),
            const SizedBox(height: 20),
            const Text(
              "ESTÁ TODO LLENO DE CENIZAS",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "La tienda se abrirá apenas logremos limpiar los restos de la montaña.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white38,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 50),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 15,
                ),
                shape: const RoundedRectangleBorder(),
              ),
              onPressed: () => game.overlays.remove('CosmeticShopOverlay'),
              child: const Text(
                "VOLVER",
                style: TextStyle(color: Colors.white, letterSpacing: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Glosario de la Montaña ──────────────────────────────────────────────────
class GlossaryOverlay extends StatelessWidget {
  final RutaDeCenizasGame game;
  const GlossaryOverlay({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0A),
      child: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              const Text(
                "GUÍA DEL ESCALADOR",
                style: TextStyle(
                  letterSpacing: 6,
                  fontSize: 18,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Conocimiento esencial para sobrevivir a la ceniza.",
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.white38,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 20),
              const Divider(color: Colors.white10),
              Expanded(
                child: ListView(
                  children: [
                    _sectionTitle("CASILLAS"),
                    _glossaryItem(
                      Icons.terrain,
                      Colors.grey,
                      "BARRANCO",
                      "Terreno inestable. Si caes aquí, deberás lanzar los dados (2D6) y retroceder esa cantidad de casillas. Pierdes integridad en el proceso.",
                    ),
                    _glossaryItem(
                      Icons.trending_up,
                      Colors.greenAccent,
                      "ATAJO",
                      "Una ruta más rápida. Te permite lanzar dados extra (2D6) para avanzar de inmediato.",
                    ),
                    _glossaryItem(
                      Icons.menu_book,
                      Colors.amber,
                      "HISTORIA",
                      "Restos de expediciones pasadas. Recuperas un poco de integridad y vuelves a lanzar el dado.",
                    ),
                    _glossaryItem(
                      Icons.inventory_2,
                      Colors.cyan,
                      "OBJETOS",
                      "Casillas que contienen herramientas útiles para tu ascenso.",
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle("OBJETOS"),
                    _glossaryItem(
                      Icons.hiking,
                      Colors.orangeAccent,
                      "ZAPATOS DE ESCALADA",
                      "Permiten evitar un retroceso por barranco. Se consumen tras el uso.",
                    ),
                    _glossaryItem(
                      Icons.gesture,
                      Colors.purpleAccent,
                      "LAZO DEL MALVADO",
                      "Atrapa al jugador que va liderando y lo arrastra hasta tu posición actual.",
                    ),
                    _glossaryItem(
                      Icons.shield,
                      Colors.blueAccent,
                      "VOLUNTAD DE LOS ANTIGUOS",
                      "Protege contra efectos malintencionados, como el Lazo del Malvado.",
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () {
                  game.overlays.add('MainMenuOverlay');
                  game.overlays.remove('GlossaryOverlay');
                },
                child: const Text("VOLVER"),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 12,
          letterSpacing: 4,
          color: Colors.white54,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _glossaryItem(IconData icon, Color color, String name, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
