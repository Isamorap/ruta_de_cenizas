import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NetworkManager {
  static final NetworkManager _instance = NetworkManager._internal();
  factory NetworkManager() => _instance;

  NetworkManager._internal();

  bool isInitialized = false;

  Future<void> initialize() async {
    if (isInitialized) return;
    try {
      await Firebase.initializeApp();
      isInitialized = true;
      print("Firebase initialized.");
    } catch (e) {
      print("Error initializing Firebase: $e");
    }
  }

  // TODO: Añadir métodos para crear sala, unirse a sala y escuchar cambios de estado.
}
