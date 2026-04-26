import 'package:flutter/material.dart';

class CharacterData {
  final String id;
  final String displayName;
  final Color color;
  final IconData icon;

  const CharacterData(this.id, this.displayName, this.color, this.icon);
}

const List<CharacterData> kCharacters = [
  CharacterData('char0', 'El Viajero',   Color(0xFFE8E8E8), Icons.person_outline),
  CharacterData('char1', 'La Vidente',   Color(0xFF9B59B6), Icons.visibility),
  CharacterData('char2', 'El Guardián',  Color(0xFF2980B9), Icons.shield_outlined),
  CharacterData('char3', 'La Cazadora',  Color(0xFF27AE60), Icons.track_changes),
  CharacterData('char4', 'El Herrero',   Color(0xFFE67E22), Icons.hardware),
  CharacterData('char5', 'La Hechicera', Color(0xFFE74C3C), Icons.auto_fix_high),
  CharacterData('char6', 'El Mercader',  Color(0xFFF1C40F), Icons.monetization_on_outlined),
  CharacterData('char7', 'El Ermitaño',  Color(0xFF7F8C8D), Icons.elderly),
];

CharacterData characterById(String id) {
  return kCharacters.firstWhere(
    (c) => c.id == id,
    orElse: () => kCharacters.first,
  );
}
