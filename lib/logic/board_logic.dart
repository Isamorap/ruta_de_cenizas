import 'dart:math';
import 'package:flutter/material.dart';
import '../models/tile_type.dart';

class BoardLogic {
  final Random _rand = Random();

  List<TileData> generateBoard() {
    List<TileData> board = [];
    int specialCooldown = 0;
    int currentIndex = 1;

    // A much taller mountain: ~74 tiles
    final List<int> widths = [
      6, 6, 6, 6, // 24
      5, 5, 5, 5, // 20
      4, 4, 4,    // 12
      3, 3, 3,    // 9
      2, 2, 2,    // 6
      1, 1, 1     // 3
    ];

    for (int r = 0; r < widths.length; r++) {
      int width = widths[r];
      double startCol = -(width - 1) / 2.0;
      
      List<TileData> rowTiles = [];
      for (int i = 0; i < width; i++) {
        double col = startCol + i;
        TileType type = TileType.normal;

        if (r > 1 && specialCooldown <= 0) {
          double chance = _rand.nextDouble();
          if (chance < 0.15) { // Adjusted chance for more rows
            type = _rand.nextBool() ? TileType.barranco : TileType.atajo;
            specialCooldown = 3; 
          }
        }
        
        // Randomize surface color (Grass, Dirt)
        Color surface;
        double colorType = _rand.nextDouble();
        if (colorType < 0.5) {
          surface = Color.fromARGB(255, 60 + _rand.nextInt(30), 80 + _rand.nextInt(40), 50); // Verde pasto
        } else {
          surface = Color.fromARGB(255, 90 + _rand.nextInt(30), 70 + _rand.nextInt(20), 50); // Cafe tierra
        }

        rowTiles.add(TileData(row: r, col: col, type: type, index: 0, surfaceColor: surface));
        if (specialCooldown > 0) specialCooldown--;
      }

      if (r % 2 != 0) {
        rowTiles = rowTiles.reversed.toList();
      }

      for (var tile in rowTiles) {
        board.add(TileData(
          row: tile.row,
          col: tile.col,
          type: tile.type,
          index: currentIndex++,
          surfaceColor: tile.surfaceColor,
        ));
      }
    }
    return board;
  }
}

class TileData {
  final int row;
  final double col;
  final TileType type;
  final int index;
  final Color surfaceColor;

  TileData({
    required this.row, 
    required this.col, 
    required this.type, 
    required this.index,
    required this.surfaceColor,
  });
}
