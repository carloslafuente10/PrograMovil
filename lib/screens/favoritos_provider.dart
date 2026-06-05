import 'package:flutter/material.dart';// Pantalla que muestra la lista de recetas favoritas del usuario, con la capacidad de agregar o quitar recetas de favoritos. Utiliza Firestore para almacenar y recuperar las recetas favoritas del usuario, y un InheritedNotifier para gestionar el estado de los favoritos en toda la aplicación.
import 'package:cloud_firestore/cloud_firestore.dart';// Librería para trabajar con Firestore, la base de datos en la nube de Firebase, que se utiliza para almacenar y recuperar las recetas favoritas del usuario.
import 'package:firebase_auth/firebase_auth.dart';// Librería para trabajar con Firebase Authentication, que se utiliza para gestionar la autenticación de usuarios y obtener el ID del usuario actual para asociar las recetas favoritas con su cuenta.
import '../servicios/historial_servicio.dart';// Servicio personalizado para registrar las acciones del usuario en un historial, utilizado para registrar cuándo un usuario agrega o quita una receta de favoritos, lo que permite llevar un seguimiento de sus interacciones con la aplicación.
// Pantalla que muestra la lista de recetas favoritas del usuario, con la capacidad de agregar o quitar recetas de favoritos. Utiliza Firestore para almacenar y recuperar las recetas favoritas del usuario, y un InheritedNotifier para gestionar el estado de los favoritos en toda la aplicación.
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
// Estado de los favoritos del usuario, que gestiona la lista de recetas favoritas, la autenticación del usuario y las operaciones para agregar o quitar recetas de favoritos. Escucha los cambios en la autenticación para cargar los favoritos correspondientes al usuario actual, y proporciona métodos para modificar la lista de favoritos tanto en memoria como en Firestore.
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
// Método para agregar o quitar una receta de favoritos. Si la receta ya está en favoritos, se elimina; si no está, se agrega. Además, registra la acción en el historial del usuario utilizando el servicio de historial, y actualiza la base de datos en Firestore para reflejar el cambio.
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
      await HistorialService.registrar(
    accion: 'Quitó de favoritos $nombre',
    tipo: 'favoritos',
  );

      _favoritos.remove(nombre);
      notifyListeners();
      await docRef.delete();
    } else {
       await HistorialService.registrar(
    accion: 'Agregó a favoritos $nombre',
    tipo: 'favoritos',
  );
      _favoritos[nombre] = receta;
      notifyListeners();
      await docRef.set(receta);
    }
  }
}