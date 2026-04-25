import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'models/tile_type.dart';
import 'ruta_de_cenizas_game.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: GameWidget<RutaDeCenizasGame>(
          game: RutaDeCenizasGame(),
          overlayBuilderMap: {
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
            'DiceUI': (context, game) {
              return const SizedBox.shrink();
            },
            'EventMessageOverlay': (context, game) {
              return ListenableBuilder(
                listenable: game,
                builder: (context, _) {
                  if (game.eventMessage == null) return const SizedBox.shrink();
                  
                  final isAtajo = game.currentEventType == TileType.atajo;
                  final accentColor = isAtajo ? const Color(0xFF00CED1) : const Color(0xFFFF4500);
                  final icon = isAtajo ? Icons.auto_awesome : Icons.warning_amber_rounded;

                  return Center(
                    child: Container(
                      width: 300, // Fixed width for stability
                      padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 25),
                      decoration: BoxDecoration(
                        color: const Color(0xFF121212).withValues(alpha: 0.95),
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
                                isAtajo ? "FORTUNA" : "PELIGRO",
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              height: 1.5,
                              fontWeight: FontWeight.w300,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 25),
                          Container(height: 1, width: 40, color: Colors.white.withValues(alpha: 0.2)),
                          const SizedBox(height: 15),
                          Text(
                            "TOCA LOS DADOS PARA CONTINUAR",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
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
          },
          initialActiveOverlays: const ['DiceUI', 'EventMessageOverlay'],
        ),
      ),
    ),
  );
}
