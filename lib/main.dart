import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'models/tile_type.dart';
import 'models/player_state.dart';
import 'models/character_data.dart';
import 'ruta_de_cenizas_game.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Ocultar status bar y navigation bar para máxima inmersión
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        textTheme: GoogleFonts.cinzelTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      home: Scaffold(
        body: GameWidget<RutaDeCenizasGame>(
          game: RutaDeCenizasGame(),
          overlayBuilderMap: {
            'MainMenuOverlay': (context, game) => MainMenuOverlay(game: game),
            'LobbyOverlay': (context, game) => LobbyOverlay(game: game),
            'SoloSetupOverlay': (context, game) => SoloSetupOverlay(game: game),
            'SettingsOverlay': (context, game) => SettingsOverlay(game: game),
            'InventoryPrompt': (context, game) {
              return Center(
                child: Container(
                  width: 300,
                  padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 25),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121212).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(4),
                    border: const Border(left: BorderSide(color: Color(0xFF4682B4), width: 4)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.6),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.inventory_2_outlined, color: Color(0xFF4682B4), size: 24),
                          const SizedBox(width: 12),
                          Text(
                            "INVENTARIO",
                            style: TextStyle(
                              color: Color(0xFF4682B4),
                              letterSpacing: 4,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "EL TERRENO ES INESTABLE. ¿QUIERES USAR TUS BOTAS?",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w300,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF4682B4),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                          ),
                          onPressed: () {
                            game.useZapatos();
                            game.overlays.remove('InventoryPrompt');
                          },
                          child: const Text("USAR ZAPATOS DE ESCALADA", style: TextStyle(fontSize: 12, letterSpacing: 1)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          game.overlays.remove('InventoryPrompt');
                          game.triggerFall();
                        },
                        child: Text(
                          "ARRIESGARSE A CAER", 
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10, letterSpacing: 2)
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            // TurnIndicator: muestra el nombre del jugador activo sin duplicar el dado
            'DiceUI': (context, game) {
              return ListenableBuilder(
                listenable: game,
                builder: (context, _) {
                  if (!game.isGameStarted || game.players.length <= 1) return const SizedBox.shrink();
                  return Positioned(
                    top: 20,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: game.currentPlayer.color.withValues(alpha: 0.15),
                          border: Border.all(color: game.currentPlayer.color.withValues(alpha: 0.5)),
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
            },
            'EventMessageOverlay': (context, game) {
              return ListenableBuilder(
                listenable: game,
                builder: (context, _) {
                  if (game.eventMessage == null) return const SizedBox.shrink();
                  
                  final isAtajo = game.currentEventType == TileType.atajo;
                  final isHistoria = game.currentEventType == TileType.historia;
                  final isConsumible = game.currentEventType == TileType.consumible;
                  
                  Color bgColor = const Color(0xFF121212).withValues(alpha: 0.95);
                  Color accentColor = isAtajo ? const Color(0xFF00CED1) : const Color(0xFFFF4500);
                  Color textColor = Colors.white;
                  IconData icon = isAtajo ? Icons.auto_awesome : Icons.warning_amber_rounded;
                  String title = isAtajo ? "FORTUNA" : "PELIGRO";
                  
                  if (isHistoria) {
                    bgColor = const Color(0xFFE6D5B8).withValues(alpha: 0.95); // Parchment
                    accentColor = const Color(0xFF5D4037); // Dark brown
                    textColor = const Color(0xFF3E2723); // Very dark brown
                    icon = Icons.menu_book;
                    title = "FRAGMENTO\nENCONTRADO";
                  } else if (isConsumible) {
                    accentColor = const Color(0xFF9370DB); // Purple for items
                    icon = Icons.shopping_bag_outlined;
                    title = "OBJETO\nENCONTRADO";
                  }

                  return Center(
                    child: Container(
                      width: 300, // Fixed width for stability
                      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 25),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(4),
                        border: Border(left: BorderSide(color: accentColor, width: 4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(icon, color: accentColor, size: 24),
                              const SizedBox(width: 12),
                              Text(
                                title,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: accentColor,
                                  letterSpacing: 4,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            game.eventMessage!.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: textColor,
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 25),
                          Container(height: 1, width: 40, color: textColor.withValues(alpha: 0.2)),
                          const SizedBox(height: 15),
                          const Text(
                            "LANZA LOS DADOS PARA CONTINUAR",
                            style: TextStyle(
                              color: Colors.white24,
                              fontSize: 9,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            'InventoryButton': (context, game) {
              return ListenableBuilder(
                listenable: game,
                builder: (context, _) {
                  if (!game.isGameStarted) return const SizedBox.shrink();
                  return Positioned(
                    bottom: 20,
                    right: 20,
                    child: FloatingActionButton(
                      backgroundColor: const Color(0xFF121212).withValues(alpha: 0.9),
                      mini: true,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.backpack_outlined, color: Colors.white),
                      onPressed: () {
                        if (game.overlays.isActive('InventoryMenu')) {
                          game.overlays.remove('InventoryMenu');
                        } else {
                          game.overlays.add('InventoryMenu');
                        }
                      },
                    ),
                  );
                }
              );
            },
            'InventoryMenu': (context, game) {
              return ListenableBuilder(
                listenable: game,
                builder: (context, _) {
                  return Center(
                    child: Container(
                      width: 320,
                      height: 450,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A).withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 20),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("INVENTARIO", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2)),
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(Icons.close, color: Colors.white54),
                                onPressed: () => game.overlays.remove('InventoryMenu'),
                              ),
                            ],
                          ),
                          const Divider(color: Colors.white24, height: 20),
                          const Text("OBJETOS", style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1)),
                          const SizedBox(height: 10),
                          _buildInventoryItem(Icons.hiking, const Color(0xFF8B4513), "Zapatos de Escalada", game.currentPlayer.zapatosDeEscaladaCount),
                          _buildInventoryItem(Icons.all_inclusive, const Color(0xFF8A2BE2), "Lazo del Malvado", game.currentPlayer.lazoDelMalvadoCount),
                          _buildInventoryItem(Icons.shield, const Color(0xFFFFD700), "Voluntad de los Antiguos", game.currentPlayer.voluntadDeLosAntiguosCount),
                          const SizedBox(height: 20),
                          const Text("FRAGMENTOS DE HISTORIA", style: TextStyle(color: Colors.white54, fontSize: 11, letterSpacing: 1)),
                          const SizedBox(height: 10),
                          Expanded(
                            child: game.currentHistoryIndex == 0 
                                ? const Center(child: Text("Aún no has encontrado fragmentos.", style: TextStyle(color: Colors.white38, fontSize: 12)))
                                : ListView.builder(
                                    itemCount: game.currentHistoryIndex,
                                    itemBuilder: (context, index) {
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 8.0),
                                        child: InkWell(
                                          onTap: () {
                                            showDialog(
                                              context: context, 
                                              builder: (context) => AlertDialog(
                                                backgroundColor: const Color(0xFFE6D5B8),
                                                title: Text("Fragmento ${index + 1}", style: const TextStyle(color: Color(0xFF3E2723), fontWeight: FontWeight.bold)),
                                                content: Text(game.fragmentosHistoria[index], style: const TextStyle(color: Color(0xFF3E2723), height: 1.5)),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context), 
                                                    child: const Text("CERRAR", style: TextStyle(color: Color(0xFF3E2723), fontWeight: FontWeight.bold))
                                                  )
                                                ],
                                              )
                                            );
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.05),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              children: [
                                                const Icon(Icons.menu_book, color: Color(0xFFDAA520), size: 18),
                                                const SizedBox(width: 12),
                                                Text("Fragmento ${index + 1}", style: const TextStyle(color: Colors.white, fontSize: 13)),
                                                const Spacer(),
                                                const Icon(Icons.chevron_right, color: Colors.white54, size: 16),
                                              ],
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
                  );
                },
              );
            },
            'BackToMenuButton': (context, game) {
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
            },
          },
          initialActiveOverlays: const ['MainMenuOverlay', 'DiceUI', 'EventMessageOverlay', 'InventoryButton', 'BackToMenuButton'],
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
    return Container(
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
            const SizedBox(height: 60),
            _menuButton("UN JUGADOR", () {
              game.overlays.add('SoloSetupOverlay');
              game.overlays.remove('MainMenuOverlay');
            }),
            _menuButton("MULTIJUGADOR LOCAL", () {
              game.overlays.add('LobbyOverlay');
              game.overlays.remove('MainMenuOverlay');
            }),
            _menuButton("MULTIJUGADOR ONLINE", null), // Próximamente
            _menuButton("AJUSTES", () {
              game.overlays.add('SettingsOverlay');
              game.overlays.remove('MainMenuOverlay');
            }),
          ],
        ),
      ),
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
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white24,
          ),
          child: Text(
            text,
            style: const TextStyle(letterSpacing: 4, fontSize: 12, fontWeight: FontWeight.w300),
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
  int playerCount = 2;
  final List<String> names = ["Jugador 1", "Jugador 2", "Jugador 3", "Jugador 4"];
  final List<Color> colors = [Colors.red, Colors.blue, Colors.white, Colors.amber];
  final List<int> charIdx = [0, 1, 2, 3];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A0A0A).withValues(alpha: 0.95),
      child: Center(
        child: Container(
          width: 350,
          padding: const EdgeInsets.all(30),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("PREPARACIÓN", style: TextStyle(letterSpacing: 4, fontSize: 14)),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("JUGADORES: "),
                  DropdownButton<int>(
                    value: playerCount,
                    items: [2, 3, 4].map((e) => DropdownMenuItem(value: e, child: Text(e.toString()))).toList(),
                    onChanged: (v) => setState(() => playerCount = v!),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Aquí simplificamos, pero podrías añadir inputs para nombres
              Text("Color de Ficha:", style: TextStyle(color: Colors.white54, fontSize: 10)),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: colors.map((c) => Container(margin: const EdgeInsets.all(5), width: 20, height: 20, color: c)).toList(),
              ),
              const SizedBox(height: 40),
              OutlinedButton(
                onPressed: () {
                  final list = List.generate(playerCount, (i) => PlayerState(
                    name: names[i],
                    color: colors[i],
                    characterId: "char${charIdx[i]}",
                  ));
                  widget.game.startGame(list);
                  widget.game.overlays.remove('LobbyOverlay');
                },
                child: const Text("INICIAR EXPEDICIÓN", style: TextStyle(letterSpacing: 2)),
              ),
              TextButton(
                onPressed: () {
                  widget.game.overlays.add('MainMenuOverlay');
                  widget.game.overlays.remove('LobbyOverlay');
                },
                child: const Text("VOLVER", style: TextStyle(color: Colors.white24, fontSize: 10)),
              ),
            ],
          ),
        ),
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
            const Text("AJUSTES Y CRÉDITOS", style: TextStyle(letterSpacing: 4)),
            const SizedBox(height: 40),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                "Este proyecto fue realizado con fines no lucrativos, nacido por las ganas de jugar serpientes y escaleras como en la infancia.",
                textAlign: TextAlign.center,
                style: TextStyle(height: 1.8, fontWeight: FontWeight.w200, fontStyle: FontStyle.italic, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 60),
            OutlinedButton(
              onPressed: () {
                game.overlays.add('MainMenuOverlay');
                game.overlays.remove('SettingsOverlay');
              },
              child: const Text("VOLVER AL MENÚ"),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildInventoryItem(IconData icon, Color color, String name, int count) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12.0),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Text(name, style: TextStyle(color: count > 0 ? Colors.white : Colors.white54, fontSize: 13)),
        const Spacer(),
        Text("x$count", style: TextStyle(color: count > 0 ? Colors.white : Colors.white54, fontWeight: FontWeight.bold)),
      ],
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
  final _nameCtrl = TextEditingController(text: 'Explorador');

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
              const Text('ELIGE TU PERSONAJE',
                  style: TextStyle(letterSpacing: 4, fontSize: 13, color: Colors.white54)),
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
                        child: Icon(c.icon, color: selected ? c.color : Colors.white24, size: 28),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 35),

              // ── Nombre del jugador ─────────────────────────
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _nameCtrl,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, letterSpacing: 2, fontSize: 14),
                  maxLength: 20,
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: 'TU NOMBRE',
                    hintStyle: TextStyle(color: Colors.white24, letterSpacing: 2, fontSize: 12),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: char.color.withValues(alpha: 0.5)),
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
                  final name = _nameCtrl.text.trim().isEmpty ? 'Explorador' : _nameCtrl.text.trim();
                  widget.game.startGame([
                    PlayerState(
                      name: name,
                      color: char.color,
                      characterId: char.id,
                    ),
                  ]);
                  widget.game.overlays.remove('SoloSetupOverlay');
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: char.color.withValues(alpha: 0.6)),
                  foregroundColor: char.color,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                child: const Text('INICIAR EXPEDICIÓN', style: TextStyle(letterSpacing: 3, fontSize: 11)),
              ),
              const SizedBox(height: 16),

              // ── Volver ─────────────────────────────────────
              TextButton(
                onPressed: () {
                  widget.game.overlays.add('MainMenuOverlay');
                  widget.game.overlays.remove('SoloSetupOverlay');
                },
                child: const Text('VOLVER', style: TextStyle(color: Colors.white24, fontSize: 10, letterSpacing: 2)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
