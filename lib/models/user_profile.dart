import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfile {
  String name;
  int xp;
  List<bool> historyFragments; // Length 10
  int onlineWins;
  int localWins;
  int totalTilesClimbed;
  int localGamesPlayed;
  int selectedCosmeticId;
  bool hasSeenHistoriaTutorial;

  UserProfile({
    this.name = "Explorador",
    this.xp = 0,
    List<bool>? historyFragments,
    this.onlineWins = 0,
    this.localWins = 0,
    this.totalTilesClimbed = 0,
    this.localGamesPlayed = 0,
    this.selectedCosmeticId = 0,
    this.isMuted = false,
    this.isFirstTimeStory = true,
    this.hasSeenHistoriaTutorial = false,
  }) : this.historyFragments = historyFragments ?? List.generate(10, (_) => false);

  bool isMuted;
  bool isFirstTimeStory;
  
  List<String> get earnedTitles {
    List<String> titles = ["Novato"];
    if (localGamesPlayed >= 1) titles.add("Iniciado");
    if (localGamesPlayed >= 5) titles.add("Escalador");
    if (localGamesPlayed >= 10) titles.add("Veterano de la Ceniza");
    if (allFragmentsUnlocked) titles.add("Erudito de la Montaña");
    if (onlineWins > 0) titles.add("Campeón del Vacío");
    return titles;
  }

  int get level => (xp / 500).floor() + 1;
  int get xpToNextLevel => 500 - (xp % 500);
  bool get allFragmentsUnlocked => historyFragments.every((unlocked) => unlocked);

  Map<String, dynamic> toJson() => {
    'name': name,
    'xp': xp,
    'historyFragments': historyFragments,
    'onlineWins': onlineWins,
    'localWins': localWins,
    'totalTilesClimbed': totalTilesClimbed,
    'localGamesPlayed': localGamesPlayed,
    'selectedCosmeticId': selectedCosmeticId,
    'isMuted': isMuted,
    'isFirstTimeStory': isFirstTimeStory,
    'hasSeenHistoriaTutorial': hasSeenHistoriaTutorial,
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      name: json['name'] ?? "Explorador",
      xp: json['xp'] ?? 0,
      historyFragments: List<bool>.from(json['historyFragments'] ?? List.generate(10, (_) => false)),
      onlineWins: json['onlineWins'] ?? 0,
      localWins: json['localWins'] ?? 0,
      totalTilesClimbed: json['totalTilesClimbed'] ?? 0,
      localGamesPlayed: json['localGamesPlayed'] ?? 0,
      selectedCosmeticId: json['selectedCosmeticId'] ?? 0,
      isMuted: json['isMuted'] ?? false,
      isFirstTimeStory: json['isFirstTimeStory'] ?? true,
      hasSeenHistoriaTutorial: json['hasSeenHistoriaTutorial'] ?? false,
    );
  }

  static Future<UserProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonStr = prefs.getString('user_profile');
    if (jsonStr == null) return UserProfile();
    try {
      return UserProfile.fromJson(jsonDecode(jsonStr));
    } catch (e) {
      return UserProfile();
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_profile', jsonEncode(toJson()));
  }

  void addXp(int amount) {
    xp += amount;
  }

  void unlockFragment(int index) {
    if (index >= 0 && index < historyFragments.length) {
      historyFragments[index] = true;
    }
  }
}
