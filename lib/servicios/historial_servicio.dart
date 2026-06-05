import 'package:cloud_firestore/cloud_firestore.dart';// Permite acceder y almacenar información en Firebase Firestore.
import 'package:firebase_auth/firebase_auth.dart';// Permite obtener información del usuario autenticado mediante Firebase Authentication.
// Servicio encargado de registrar actividades y acciones realizadas por los usuarios.
class HistorialService {

  static Future<void>
      registrar({

    required String accion,

    required String tipo,

  }) async {

    try {

      final user =
          FirebaseAuth
              .instance
              .currentUser;

      if (user == null) return;

      final usuarioDoc =
          await FirebaseFirestore
              .instance
              .collection(
                'app-usuarios',
              )
              .doc(user.uid)
              .get();

      final data =
          usuarioDoc.data();

      await FirebaseFirestore
    .instance
    .collection(
      'app-historial',
    )
    .add({

  'uid':
      user.uid,

  'rol':
      data?['rol'] ??
          'user',

  'usuario':
      data?['nombre'] ??
          'Sin nombre',

  'correo':
      user.email ?? '',

  'accion':
      accion,

  'tipo':
      tipo,

  'fecha':
      Timestamp.now(),
});
    } catch (e) {

      print(
        'Error historial: $e',
      );
    }
  }
}