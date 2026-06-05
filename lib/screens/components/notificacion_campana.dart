import 'package:flutter/material.dart';//Componentes visuales de Flutter Material Design.
import 'package:firebase_auth/firebase_auth.dart';//Permite obtener el usuario autenticado mediante Firebase Authentication.
import '../../servicios/notificaciones_servicio.dart';//Servicio personalizado encargado de gestionar y consultar las notificaciones.
import '../notificaciones_screen.dart';//Pantalla donde se muestran las notificaciones del usuario o administrador.
// Widget que muestra una campana de notificaciones con contador de mensajes no leídos.

class NotificacionCampana extends StatelessWidget {

    // Obtiene el usuario autenticado actualmente.
  final bool esAdmin;
  const NotificacionCampana({super.key, required this.esAdmin});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();
// Escucha en tiempo real la cantidad de notificaciones no leídas.
    return StreamBuilder<int>(
      stream: esAdmin
          ? NotificacionesServicio.streamContadorNoLeidasAdmin(user.email ?? '')
          : NotificacionesServicio.streamContadorNoLeidas(user.uid),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(// Navega a la pantalla de notificaciones al presionar la campana.
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificacionesScreen(esAdmin: esAdmin),
                ),
              ),
            ),
             // Muestra el contador cuando existen notificaciones pendientes.
            if (count > 0)
              Positioned(
                top: 6, right: 6,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE53935), shape: BoxShape.circle),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center),
                ),
              ),
          ],
        );
      },
    );
  }
}