import 'dart:math';
import 'package:flutter/material.dart';
import '../models/tile_type.dart';
import '../models/item_type.dart';

class BoardLogic {
  final Random _rand = Random();

  List<TileData> generateBoard({bool isStoryMode = true}) {
    List<TileData> board = [];
    int specialCooldown = 0;
    int currentIndex = 1;

    // taller mountain: ~100 tiles, max width 6
    final List<int> widths = [
      6, 6, 6, 6, 6, // 30
      5, 5, 5, 5, 5, // 25
      4, 4, 4, 4, 4, // 20
      3, 3, 3, 3, // 12
      2, 2, 2, 2, // 8
      1, 1, 1, 1, 1, // 5
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
          if (chance < 0.15) {
            type = _rand.nextBool() ? TileType.barranco : TileType.atajo;
            specialCooldown = 3;
          }
        }

        // Randomize surface color (Grass, Dirt)
        Color surface;
        double colorType = _rand.nextDouble();
        if (colorType < 0.5) {
          surface = Color.fromARGB(
            255,
            60 + _rand.nextInt(30),
            80 + _rand.nextInt(40),
            50,
          ); // Verde pasto
        } else {
          surface = Color.fromARGB(
            255,
            90 + _rand.nextInt(30),
            70 + _rand.nextInt(20),
            50,
          ); // Cafe tierra
        }

        rowTiles.add(
          TileData(
            row: r,
            col: col,
            type: type,
            index: 0,
            surfaceColor: surface,
          ),
        );
        if (specialCooldown > 0) specialCooldown--;
      }

      if (r % 2 != 0) {
        rowTiles = rowTiles.reversed.toList();
      }

      for (var tile in rowTiles) {
        board.add(
          TileData(
            row: tile.row,
            col: tile.col,
            type: tile.type,
            index: currentIndex++,
            surfaceColor: tile.surfaceColor,
          ),
        );
      }
    }

    // Place history tiles (Only in Story Mode)
    List<int> normalIndices = [];
    for (int i = 0; i < board.length; i++) {
      if (board[i].type == TileType.normal && board[i].row > 1) {
        normalIndices.add(i);
      }
    }

    if (isStoryMode) {
      normalIndices.sort();

      final historyCount = min(15, normalIndices.length);
      double step = normalIndices.length / historyCount;
      List<int> selectedIndices = [];

      for (int i = 0; i < historyCount; i++) {
        selectedIndices.add(normalIndices[(i * step).toInt()]);
      }

      for (var idx in selectedIndices) {
        board[idx] = board[idx].copyWith(type: TileType.historia);
        normalIndices.remove(idx);
      }
    }

    // Place items
    List<int> earlyIndices = [];
    for (int i = 0; i < board.length; i++) {
      if (board[i].type == TileType.normal &&
          board[i].row < 4 &&
          board[i].row > 0) {
        earlyIndices.add(i);
      }
    }
    if (earlyIndices.isNotEmpty) {
      earlyIndices.shuffle(_rand);
      int idx = earlyIndices.first;
      board[idx] = board[idx].copyWith(
        type: TileType.consumible,
        item: ItemType.zapatosDeEscalada,
      );
      normalIndices.remove(idx);
    }

    normalIndices.shuffle(_rand);

    int lazosToPlace = isStoryMode ? 6 : 4; // More items in story mode
    lazosToPlace = min(lazosToPlace, normalIndices.length);
    for (int i = 0; i < lazosToPlace; i++) {
      int idx = normalIndices.removeLast();
      board[idx] = board[idx].copyWith(
        type: TileType.consumible,
        item: ItemType.lazoDelMalvado,
      );
    }

    int voluntadToPlace = isStoryMode ? 4 : 3;
    voluntadToPlace = min(voluntadToPlace, normalIndices.length);
    for (int i = 0; i < voluntadToPlace; i++) {
      int idx = normalIndices.removeLast();
      board[idx] = board[idx].copyWith(
        type: TileType.consumible,
        item: ItemType.voluntadDeLosAntiguos,
      );
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
  final ItemType? item;

  TileData({
    required this.row,
    required this.col,
    required this.type,
    required this.index,
    required this.surfaceColor,
    this.item,
  });

  TileData copyWith({
    int? row,
    double? col,
    TileType? type,
    int? index,
    Color? surfaceColor,
    ItemType? item,
  }) {
    return TileData(
      row: row ?? this.row,
      col: col ?? this.col,
      type: type ?? this.type,
      index: index ?? this.index,
      surfaceColor: surfaceColor ?? this.surfaceColor,
      item: item ?? this.item,
    );
  }
}
