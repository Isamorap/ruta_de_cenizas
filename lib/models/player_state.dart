class PlayerState {
  int currentIndex = 1;
  double health = 100.0;
  bool hasZapatosDeEscalada = true; 

  void moveToIndex(int index) {
    currentIndex = index;
  }

  void reset() {
    currentIndex = 1;
    health = 100.0;
  }
}
