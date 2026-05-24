import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../servicios/notificaciones_servicio.dart';
import '../notificaciones_screen.dart';

class NotificacionCampana extends StatelessWidget {
  final bool esAdmin;
  const NotificacionCampana({super.key, required this.esAdmin});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return const SizedBox.shrink();

    return StreamBuilder<int>(
      stream: esAdmin
          ? NotificacionesServicio.streamContadorNoLeidasAdmin(user.email ?? '')
          : NotificacionesServicio.streamContadorNoLeidas(user.uid),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined, color: Colors.white),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => NotificacionesScreen(esAdmin: esAdmin),
                ),
              ),
            ),
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