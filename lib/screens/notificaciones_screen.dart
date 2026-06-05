import 'package:flutter/material.dart';// Librería de Flutter para la construcción de interfaces gráficas
import 'package:firebase_auth/firebase_auth.dart';// Permite obtener el usuario autenticado mediante Firebase Authentication.
import 'package:cloud_firestore/cloud_firestore.dart';// Permite interactuar con la base de datos Firestore de Firebase para leer y escribir datos relacionados con las notificaciones.
import '../servicios/notificaciones_servicio.dart';// Servicio personalizado encargado de gestionar y consultar las notificaciones.
import 'crear_receta_usuario_screen.dart';// Pantalla para crear o editar una receta personalizada del usuario, que se muestra al intentar reenviar una receta rechazada para su revisión. Permite al usuario modificar la receta original y enviarla nuevamente para aprobación.
import 'admin_recetas_pendientes_screen.dart';// Pantalla que muestra las recetas pendientes de revisión para el administrador, a la que se puede acceder desde una notificación de nueva receta por revisar. Permite al administrador aprobar o rechazar las recetas enviadas por los usuarios.
import 'mis_recetas_screen.dart';// Pantalla que muestra las recetas personales del usuario, desde la cual se puede acceder a la pantalla de detalle de una receta personalizada. Se utiliza para mostrar el detalle de una receta rechazada y permitir al usuario editarla y reenviarla para su revisión.
import 'app_main_screen.dart';// Pantalla principal de la aplicación, a la que se redirige al usuario después de aprobar una receta para mostrarla en el catálogo. Se utiliza para actualizar la vista del catálogo después de que una receta personalizada es aprobada y se agrega al catálogo general.

// Pantalla de notificaciones para admin y usuario
class NotificacionesScreen extends StatefulWidget {
  final bool esAdmin;
  const NotificacionesScreen({super.key, required this.esAdmin});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}
// Pantalla que muestra las notificaciones del usuario o administrador, con la opción de filtrar solo las no leídas. Permite al usuario ver el detalle de cada notificación y realizar acciones según el tipo de notificación (ver receta pendiente, ver motivo de rechazo, etc.). Para el administrador, muestra las notificaciones relacionadas con nuevas recetas por revisar.
class _NotificacionesScreenState extends State<NotificacionesScreen> {
  static const Color _verde = Color(0xFF2D9E73);
  bool _soloNoLeidas = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    final userId     = user.uid;
    final adminEmail = user.email ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _verde, elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context)),
        title: const Text('Notificaciones',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        actions: [
          // Botón para alternar entre todas y solo no leídas
          TextButton.icon(
            onPressed: () => setState(() => _soloNoLeidas = !_soloNoLeidas),
            icon: Icon(_soloNoLeidas ? Icons.notifications_active : Icons.notifications_none,
                color: Colors.white, size: 18),
            label: Text(_soloNoLeidas ? 'Todas' : 'No leídas',
                style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
      body: StreamBuilder<List<AppNotificacion>>(
        // Usa stream distinto según si es admin o usuario
        stream: widget.esAdmin
            ? NotificacionesServicio.streamNotificacionesAdmin(adminEmail)
            : NotificacionesServicio.streamNotificaciones(userId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _verde));
          }
          var notifs = snap.data ?? [];
          if (_soloNoLeidas) notifs = notifs.where((n) => !n.read).toList();

          if (notifs.isEmpty) {
            return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.notifications_off_outlined, size: 60, color: Colors.grey[300]),
              const SizedBox(height: 12),
              Text(_soloNoLeidas ? 'No tienes notificaciones sin leer' : 'Sin notificaciones',
                  style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            ]));
          }

          final noLeidas = notifs.where((n) => !n.read).length;

          return Column(children: [
            // Barra superior con contador y opción de marcar todas
            if (noLeidas > 0)
              Container(
                width: double.infinity, color: const Color(0xFFE8F7F1),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  const Icon(Icons.circle, color: _verde, size: 8),
                  const SizedBox(width: 8),
                  Text('$noLeidas sin leer',
                      style: const TextStyle(color: _verde, fontSize: 12, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => widget.esAdmin
                        ? NotificacionesServicio.marcarTodasLeidasAdmin(adminEmail)
                        : NotificacionesServicio.marcarTodasLeidas(userId),
                    child: const Text('Marcar todas como leídas',
                        style: TextStyle(color: _verde, fontSize: 12,
                            decoration: TextDecoration.underline))),
                ])),
            Expanded(child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: notifs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _NotifCard(
                notif: notifs[i],
                esAdmin: widget.esAdmin,
                onTap: () => _manejarTap(context, notifs[i]),
              ))),
          ]);
        },
      ),
    );
  }

  //Maneja el tap en una notificacion segun su tipo
  Future<void> _manejarTap(BuildContext context, AppNotificacion notif) async {
    final nav = Navigator.of(context);
    final scaffoldMsg = ScaffoldMessenger.of(context);

    switch (notif.type) {

      case TipoNotificacion.recetaPendiente:
        if (!notif.read) NotificacionesServicio.marcarLeida(notif.id);
        showDialog(
          context: context,
          builder: (dlgCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(children: [
              Icon(Icons.pending_actions_rounded, color: Color(0xFF0D6EFD)),
              SizedBox(width: 8),
              Expanded(
                child: Text('Nueva receta por revisar',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notif.recipeName,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 8),
                Text(notif.message,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700])),
                const SizedBox(height: 4),
                Text(_formatFecha(notif.createdAt),
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: Text('Cerrar', style: TextStyle(color: Colors.grey[600]))),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dlgCtx);
                  nav.push(MaterialPageRoute(
                      builder: (_) => const AdminRecetasPendientesScreen()));
                },
                icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                label: const Text('Ir a revisar',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D6EFD),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                )),
            ],
          ),
        );
        break;
  
      case TipoNotificacion.recetaAprobada:
        if (!notif.read) NotificacionesServicio.marcarLeida(notif.id);
        nav.popUntil((route) => route.isFirst);
        AppMainScreen.globalKey.currentState?.setState(() {
          AppMainScreen.globalKey.currentState!.selectedIndex = 0;
        });
        scaffoldMsg.showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text('Tu receta "${notif.recipeName}" ya está en el catálogo')),
          ]),
          backgroundColor: const Color(0xFF2D9E73),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4)));
        break;
  
      case TipoNotificacion.recetaRechazada:
        if (!notif.read) NotificacionesServicio.marcarLeida(notif.id);
        _mostrarMotivoYNavegar(nav, notif);
        break;
    }
  }

  // Formatea la fecha de la notificación en texto relativo
  String _formatFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diff  = ahora.difference(fecha);
    if (diff.inMinutes < 1)  return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7)     return 'Hace ${diff.inDays} días';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  // Diálogo para receta rechazada
 void _mostrarMotivoYNavegar(NavigatorState nav, AppNotificacion notif) {
    showDialog(
      context: nav.context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.cancel_rounded, color: Color(0xFFE53935)),
          SizedBox(width: 8),
          Text('Receta rechazada',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notif.recipeName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            const SizedBox(height: 10),
            const Text('Motivo:', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(notif.motivoRechazo ?? 'Sin motivo especificado',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFFE53935), height: 1.4))),
            const SizedBox(height: 12),
            if (notif.origenPersonalDocId != null &&
                notif.origenPersonalDocId!.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(dlgCtx);
                    try {
                      final doc = await FirebaseFirestore.instance
                          .collection('recetas_personales')
                          .doc(notif.origenPersonalDocId)
                          .get();
                      if (doc.exists) {
                        nav.push(MaterialPageRoute(
                            builder: (_) => CrearRecetaUsuarioScreen(
                                recetaExistente: doc.data(),
                                recetaPersonalId: doc.id)));
                      }
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                  label: const Text('Editar y reenviar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D9E73),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 12)))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx),
            child: Text('Entendido', style: TextStyle(color: Colors.grey[600]))),
        ],
      ),
    );
  }
}

// Tarjeta individual de notificación
class _NotifCard extends StatelessWidget {
  final AppNotificacion notif;
  final bool esAdmin;
  final VoidCallback onTap;

  const _NotifCard({required this.notif, required this.esAdmin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final config = _config();
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          // Fondo distinto si está leída o no
          color: notif.read ? Colors.white : config.bgColor,
          borderRadius: BorderRadius.circular(16),
          border: notif.read ? Border.all(color: Colors.grey[200]!) : Border.all(color: config.borderColor),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))]),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: config.iconBg, shape: BoxShape.circle),
                child: Icon(config.icon, color: config.iconColor, size: 20)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(config.titulo,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: config.iconColor))),
                // Punto indicador de no leída
                if (!notif.read)
                  Container(width: 8, height: 8,
                      decoration: BoxDecoration(color: config.iconColor, shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 4),
              Text(notif.message, style: TextStyle(fontSize: 12, color: Colors.grey[700], height: 1.4)),
              // Muestra el motivo de rechazo si existe
              if (notif.motivoRechazo != null && notif.motivoRechazo!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFFE53935), size: 13),
                    const SizedBox(width: 6),
                    Expanded(child: Text(notif.motivoRechazo!,
                        style: const TextStyle(fontSize: 11, color: Color(0xFFE53935), fontWeight: FontWeight.w500))),
                  ])),
              ],
              const SizedBox(height: 4),
              Text(_hintAccion(), style: TextStyle(fontSize: 10, color: config.iconColor.withOpacity(0.7))),
              const SizedBox(height: 2),
              Text(_formatFecha(notif.createdAt), style: TextStyle(fontSize: 10, color: Colors.grey[400])),
            ])),
          ]),
        ),
      ),
    );
  }

  // Texto de ayuda según el tipo de notificación
  String _hintAccion() {
    switch (notif.type) {
      case TipoNotificacion.recetaPendiente: return 'Toca para ver el detalle';
      case TipoNotificacion.recetaAprobada:  return 'Toca para ver en el catálogo';
      case TipoNotificacion.recetaRechazada: return 'Toca para ver el motivo';
      default: return '';
    }
  }

  // Configuración visual según el tipo de notificación
  _NotifConfig _config() {
    switch (notif.type) {
      case TipoNotificacion.recetaPendiente:
        return _NotifConfig(titulo: 'Nueva receta por revisar',
            icon: Icons.pending_actions_rounded, iconColor: const Color(0xFF0D6EFD),
            iconBg: const Color(0xFFE8F4FD), bgColor: const Color(0xFFF0F7FF),
            borderColor: const Color(0xFFBDD7FF));
      case TipoNotificacion.recetaAprobada:
        return _NotifConfig(titulo: '¡Receta aprobada!',
            icon: Icons.check_circle_rounded, iconColor: const Color(0xFF2D9E73),
            iconBg: const Color(0xFFE8F7F1), bgColor: const Color(0xFFF0FFF8),
            borderColor: const Color(0xFFB2DFCF));
      case TipoNotificacion.recetaRechazada:
        return _NotifConfig(titulo: 'Receta rechazada',
            icon: Icons.cancel_rounded, iconColor: const Color(0xFFE53935),
            iconBg: const Color(0xFFFFEBEE), bgColor: const Color(0xFFFFF5F5),
            borderColor: const Color(0xFFFFCDD2));
      default:
        return _NotifConfig(titulo: 'Notificación',
            icon: Icons.notifications_rounded, iconColor: Colors.grey,
            iconBg: Colors.grey[100]!, bgColor: Colors.white, borderColor: Colors.grey[200]!);
    }
  }

  // Convierte fecha a texto relativo
  String _formatFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final diff  = ahora.difference(fecha);
    if (diff.inMinutes < 1)  return 'Ahora mismo';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24)   return 'Hace ${diff.inHours} h';
    if (diff.inDays < 7)     return 'Hace ${diff.inDays} días';
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }
}

// Configuración visual de cada tipo de notificación
class _NotifConfig {
  final String titulo;
  final IconData icon;
  final Color iconColor, iconBg, bgColor, borderColor;
  const _NotifConfig({required this.titulo, required this.icon,
      required this.iconColor, required this.iconBg,
      required this.bgColor, required this.borderColor});
}