import 'package:flutter/material.dart';

class PlayerState {
  String name;
  Color color;
  String characterId;
  
  int currentIndex = 1;
  double health = 100.0;
  
  // Inventory
  int zapatosDeEscaladaCount = 0;
  int lazoDelMalvadoCount = 0;
  int voluntadDeLosAntiguosCount = 0;

  PlayerState({
    required this.name,
    required this.color,
    required this.characterId,
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
