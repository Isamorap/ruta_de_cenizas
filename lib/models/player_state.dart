import 'package:flutter/material.dart';

class PlayerState {
  String name;
  Color color;
  String characterId;
  
  int currentIndex = 1;
  double health = 100.0;
  
  // Ambient dialogues
  String? currentDialog;
  double dialogTimer = 0;
  
  // Movement settings
  double moveSpeedMultiplier = 1.0;
  
  // Inventory
  int zapatosDeEscaladaCount = 0;
  int lazoDelMalvadoCount = 0;
  int voluntadDeLosAntiguosCount = 0;
  bool isBot;

  PlayerState({
    required this.name,
    required this.color,
    required this.characterId,
    this.isBot = false,
  });

  void moveToIndex(int index) {
    currentIndex = index;
  }

  void reset() {
    currentIndex = 1;
    health = 100.0;
    zapatosDeEscaladaCount = 0;
    lazoDelMalvadoCount = 0;
    voluntadDeLosAntiguosCount = 0;
  }
}
