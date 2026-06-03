import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Tipos de notificación que maneja el sistema
class TipoNotificacion {
  static const String recetaPendiente = 'recipe_pending';
  static const String recetaAprobada  = 'recipe_approved';
  static const String recetaRechazada = 'recipe_rejected';
}

// Modelo de notificación que se usa en toda la app
class AppNotificacion {
  final String id;
  final String userId;
  final String role;
  final String type;
  final String message;
  final String recipeId;
  final String recipeName;
  final bool read;
  final DateTime createdAt;
  final String? motivoRechazo;
  final String? origenPersonalDocId;

  AppNotificacion({
    required this.id,
    required this.userId,
    required this.role,
    required this.type,
    required this.message,
    required this.recipeId,
    required this.recipeName,
    required this.read,
    required this.createdAt,
    this.motivoRechazo,
    this.origenPersonalDocId,
  });

  // Construye una notificación desde un documento de Firestore
  factory AppNotificacion.fromDoc(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return AppNotificacion(
      id:                  doc.id,
      userId:              d['userId']             ?? '',
      role:                d['role']               ?? 'user',
      type:                d['type']               ?? '',
      message:             d['message']            ?? '',
      recipeId:            d['recipeId']           ?? '',
      recipeName:          d['recipeName']         ?? '',
      read:                d['read']               ?? false,
      createdAt:           (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      motivoRechazo:       d['motivoRechazo'],
      origenPersonalDocId: d['origenPersonalDocId'],
    );
  }
}

class NotificacionesServicio {
  static final _col = FirebaseFirestore.instance.collection('notifications');

  // Notifica a todos los admins cuando un usuario envía una receta a revisión
  static Future<void> notificarAdmins({
    required String recipeId,
    required String recipeName,
    required String usuarioEmail,
  }) async {
    final adminsSnap = await FirebaseFirestore.instance
        .collection('app-usuarios')
        .where('rol', isEqualTo: 'admin')
        .get();

    for (final doc in adminsSnap.docs) {
      final adminEmail = doc.data()['correo'] ?? doc.data()['email'] ?? doc.data()['usuario'] ?? '';
      await _col.add({
        'userId':       doc.id,
        'adminEmail':   adminEmail,
        'role':         'admin',
        'type':         TipoNotificacion.recetaPendiente,
        'message':      '$usuarioEmail envió "$recipeName" para revisión',
        'recipeId':     recipeId,
        'recipeName':   recipeName,
        'read':         false,
        'createdAt':    FieldValue.serverTimestamp(),
      });
    }
  }

  // Notifica a un admin específico por su ID
  static Future<void> notificarAdminRecetaPendiente({
    required String adminUserId,
    required String recipeId,
    required String recipeName,
    required String usuarioEmail,
  }) async {
    await _col.add({
      'userId':     adminUserId,
      'role':       'admin',
      'type':       TipoNotificacion.recetaPendiente,
      'message':    '$usuarioEmail envió "$recipeName" para revisión',
      'recipeId':   recipeId,
      'recipeName': recipeName,
      'read':       false,
      'createdAt':  FieldValue.serverTimestamp(),
    });
  }

  // Notifica al usuario que su receta fue aprobada y publicada
  static Future<void> notificarUsuarioAprobada({
    required String userId,
    required String recipeId,
    required String recipeName,
  }) async {
    await _col.add({
      'userId':     userId,
      'role':       'user',
      'type':       TipoNotificacion.recetaAprobada,
      'message':    '¡Tu receta "$recipeName" fue aprobada y publicada!',
      'recipeId':   recipeId,
      'recipeName': recipeName,
      'read':       false,
      'createdAt':  FieldValue.serverTimestamp(),
    });
  }

  // Notifica al usuario que su receta fue rechazada, con el motivo y el ID de origen
  static Future<void> notificarUsuarioRechazada({
    required String userId,
    required String recipeId,
    required String recipeName,
    required String motivo,
    String? origenPersonalDocId,
  }) async {
    await _col.add({
      'userId':              userId,
      'role':                'user',
      'type':                TipoNotificacion.recetaRechazada,
      'message':             'Tu receta "$recipeName" fue rechazada.',
      'recipeId':            recipeId,
      'recipeName':          recipeName,
      'motivoRechazo':       motivo,
      'origenPersonalDocId': origenPersonalDocId ?? '',
      'read':                false,
      'createdAt':           FieldValue.serverTimestamp(),
    });
  }

  // Stream con el contador de notificaciones no leídas del usuario
  static Stream<int> streamContadorNoLeidas(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // Stream con todas las notificaciones del usuario, ordenadas por fecha
  static Stream<List<AppNotificacion>> streamNotificaciones(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(AppNotificacion.fromDoc).toList());
  }

  // Stream con notificaciones del admin filtradas por su correo
  static Stream<List<AppNotificacion>> streamNotificacionesAdmin(String adminEmail) {
    return _col
        .where('adminEmail', isEqualTo: adminEmail)
        .where('role', isEqualTo: 'admin')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(AppNotificacion.fromDoc).toList());
  }

  // Stream con el contador de notificaciones no leídas del admin
  static Stream<int> streamContadorNoLeidasAdmin(String adminEmail) {
    return _col
        .where('adminEmail', isEqualTo: adminEmail)
        .where('role', isEqualTo: 'admin')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // Marca una notificación individual como leída
  static Future<void> marcarLeida(String notifId) async {
    await _col.doc(notifId).update({'read': true});
  }

  // Marca todas las notificaciones del usuario como leídas en batch
  static Future<void> marcarTodasLeidas(String userId) async {
    final snap = await _col
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // Marca todas las notificaciones del admin como leídas en batch
  static Future<void> marcarTodasLeidasAdmin(String adminEmail) async {
    final snap = await _col
        .where('adminEmail', isEqualTo: adminEmail)
        .where('read', isEqualTo: false)
        .get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }

  // Stream con el total de recetas pendientes de revisión
  static Stream<int> streamRecetasPendientesAdmin() {
    return FirebaseFirestore.instance
        .collection('recetas-pendientes')
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}