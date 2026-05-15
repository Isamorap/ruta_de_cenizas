import 'package:flutter/material.dart';

class CharacterData {
  final String id;
  final String displayName;
  final String description;
  final Color color;
  final IconData icon;

  const CharacterData(this.id, this.displayName, this.description, this.color, this.icon);
}

const List<CharacterData> kCharacters = [
  CharacterData('char0', 'El Viajero',   'Un alma errante que busca redención en las cenizas. Su pasado es un mapa borroso.', Color(0xFFE8E8E8), Icons.person_outline),
  CharacterData('char1', 'La Vidente',   'Sus ojos han visto el fin del mundo, y ahora buscan el inicio de algo nuevo.', Color(0xFF9B59B6), Icons.visibility),
  CharacterData('char2', 'El Guardián',  'Antiguo protector de los templos de la cima. Su fe es tan pesada como su armadura.', Color(0xFF2980B9), Icons.shield_outlined),
  CharacterData('char3', 'La Cazadora',  'Rastreadora de bestias y susurros. Conoce el lenguaje del viento y la muerte.', Color(0xFF27AE60), Icons.track_changes),
  CharacterData('char4', 'El Herrero',   'Forjador de esperanzas rotas. Sus manos guardan el calor de un fuego que ya no existe.', Color(0xFFE67E22), Icons.hardware),
  CharacterData('char5', 'La Hechicera', 'Manipuladora de las cenizas ardientes. El fuego no la quema, la reconoce.', Color(0xFFE74C3C), Icons.auto_fix_high),
  CharacterData('char6', 'El Mercader',  'Intercambia recuerdos por supervivencia. En la montaña, todo tiene un precio.', Color(0xFFF1C40F), Icons.monetization_on_outlined),
  CharacterData('char7', 'El Ermitaño',  'Ha vivido tanto tiempo en la pendiente que sus huesos son parte de la piedra.', Color(0xFF7F8C8D), Icons.elderly),
];

const List<Color> kAvailableColors = [
  Color(0xFFE8E8E8), // Blanco/Plata
  Color(0xFFE74C3C), // Rojo
  Color(0xFF3498DB), // Azul
  Color(0xFF2ECC71), // Verde
  Color(0xFFF1C40F), // Amarillo
  Color(0xFF9B59B6), // Púrpura
  Color(0xFFE67E22), // Naranja
  Color(0xFF1ABC9C), // Turquesa
];

CharacterData characterById(String id) {
  return kCharacters.firstWhere(
    (c) => c.id == id,
    orElse: () => kCharacters.first,
  );
}
