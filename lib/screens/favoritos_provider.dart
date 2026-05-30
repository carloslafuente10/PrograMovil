import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FavoritosProvider extends InheritedNotifier<FavoritosState> {
  const FavoritosProvider({
    super.key,
    required FavoritosState notifier,
    required super.child,
  }) : super(notifier: notifier);

  static FavoritosState of(BuildContext context) {
    final notifier = context
        .dependOnInheritedWidgetOfExactType<FavoritosProvider>()
        ?.notifier;
    assert(notifier != null, 'FavoritosProvider no encontrado en el árbol');
    return notifier!;
  }
}

class FavoritosState extends ChangeNotifier {
  final Map<String, Map<String, dynamic>> _favoritos = {};
  String? _userId;

  FavoritosState() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        _userId = user.uid;
        _descargarFavoritos();
      } else {
        _userId = null;
        _favoritos.clear();
        notifyListeners();
      }
    });
  }

  List<Map<String, dynamic>> get lista => _favoritos.values.toList();

  bool esFavorito(String nombre) => _favoritos.containsKey(nombre);

  Future<void> _descargarFavoritos() async {
    if (_userId == null) return;
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('app-usuarios')
          .doc(_userId)
          .collection('favoritos')
          .get();

      _favoritos.clear();
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final nombre = data['nombre']?.toString().trim() ?? '';
        if (nombre.isNotEmpty) {
          _favoritos[doc.id] = data;
        } else {
          await doc.reference.delete();
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error al descargar favoritos: $e');
    }
  }

  Future<void> toggle(Map<String, dynamic> receta) async {
    if (_userId == null) return;
    final nombre = receta['nombre'].toString().trim();
    if (nombre.isEmpty) return;

    final docRef = FirebaseFirestore.instance
        .collection('app-usuarios')
        .doc(_userId)
        .collection('favoritos')
        .doc(nombre);

    if (_favoritos.containsKey(nombre)) {
      _favoritos.remove(nombre);
      notifyListeners();
      await docRef.delete();
    } else {
      _favoritos[nombre] = receta;
      notifyListeners();
      await docRef.set(receta);
    }
  }
}
