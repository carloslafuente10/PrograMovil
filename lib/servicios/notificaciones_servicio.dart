import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TipoNotificacion {
  static const String recetaPendiente = 'recipe_pending';
  static const String recetaAprobada  = 'recipe_approved';
  static const String recetaRechazada = 'recipe_rejected';
}

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

  // ── Notificar TODOS los admins cuando llega receta pendiente ──
  // ✅ CORREGIDO: busca por campo 'rol' = 'admin' y usa el UID de Firebase Auth
  // como userId en la notificación. El admin ve la notif con su UID actual.
  static Future<void> notificarAdmins({
    required String recipeId,
    required String recipeName,
    required String usuarioEmail,
  }) async {
    // Obtener el UID actual del admin autenticado (si hay sesión admin abierta)
    // Como no podemos saber el UID del admin desde el cliente usuario,
    // guardamos la notif con userId = 'admin_broadcast' y el admin
    // la lee con su propio stream filtrado por role = 'admin'
    final adminsSnap = await FirebaseFirestore.instance
        .collection('app-usuarios')
        .where('rol', isEqualTo: 'admin')
        .get();

    for (final doc in adminsSnap.docs) {
      // El ID del documento en app-usuarios puede ser el UID de Auth
      // Guardamos también el email del admin para identificarlo
      final adminEmail = doc.data()['usuario'] ?? doc.data()['email'] ?? '';
      await _col.add({
        'userId':       doc.id, // ID del doc en app-usuarios
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

  // ── Versión legacy que acepta adminUserId directo ──
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

  // ── Usuario: receta aprobada ──
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

  // ── Usuario: receta rechazada ──
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

  // ── Contador no leídas usuario ──
  static Stream<int> streamContadorNoLeidas(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  // ── Stream notificaciones por UID ──
  static Stream<List<AppNotificacion>> streamNotificaciones(String userId) {
    return _col
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(AppNotificacion.fromDoc).toList());
  }

  // ── Stream notificaciones admin por email ──
  // ✅ NUEVO: el admin busca sus notifs por su email además de por userId
  static Stream<List<AppNotificacion>> streamNotificacionesAdmin(String adminEmail) {
    return _col
        .where('adminEmail', isEqualTo: adminEmail)
        .where('role', isEqualTo: 'admin')
        .orderBy('createdAt', descending: true)
        .limit(30)
        .snapshots()
        .map((snap) => snap.docs.map(AppNotificacion.fromDoc).toList());
  }

  // ── Contador no leídas admin por email ──
  static Stream<int> streamContadorNoLeidasAdmin(String adminEmail) {
    return _col
        .where('adminEmail', isEqualTo: adminEmail)
        .where('role', isEqualTo: 'admin')
        .where('read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  static Future<void> marcarLeida(String notifId) async {
    await _col.doc(notifId).update({'read': true});
  }

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

  static Stream<int> streamRecetasPendientesAdmin() {
    return FirebaseFirestore.instance
        .collection('recetas-pendientes')
        .where('estado', isEqualTo: 'pendiente')
        .snapshots()
        .map((snap) => snap.docs.length);
  }
}