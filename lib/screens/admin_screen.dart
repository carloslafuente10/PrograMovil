import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'admin_recetas_screen.dart';
import 'admin_categorias_screen.dart';
import 'reportes_screen.dart';
import 'admin_recetas_pendientes_screen.dart';
import 'components/notificacion_campana.dart';
import 'gestionar_usuarios_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  static const Color _verde      = Color(0xFF2D9E73);
  static const Color _verdeOsc   = Color(0xFF1B5E20);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  static const Color _mostaza    = Color(0xFFF5A623);
  static const Color _fondo      = Color(0xFFF5F6FA);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    // Nombre de display: preferir displayName, sino extraer parte antes del @
    final String nombreDisplay = user?.displayName?.isNotEmpty == true
        ? user!.displayName!
        : (user?.email ?? 'Administrador').split('@').first;

    final String emailCompleto = user?.email ?? '';

    // Inicial para el avatar
    final String inicial = nombreDisplay.isNotEmpty
        ? nombreDisplay[0].toUpperCase()
        : 'A';

    return Scaffold(
      backgroundColor: _fondo,
      body: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF2D9E73), Color(0xFF1B5E20)],
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AppBar manual
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Panel de administración',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        const NotificacionCampana(esAdmin: true),
                        const SizedBox(width: 8),
                        // Avatar con inicial
                        user?.photoURL != null
                            ? CircleAvatar(
                                radius: 18,
                                backgroundImage: NetworkImage(user!.photoURL!),
                              )
                            : Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    width: 1.5,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    inicial,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Saludo + info admin
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '¡Bienvenido de vuelta!',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                nombreDisplay,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (emailCompleto.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.mail_outline_rounded,
                                        size: 11,
                                        color: Colors.white.withValues(alpha: 0.6)),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        emailCompleto,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.65),
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              const SizedBox(height: 8),
                              // Badge "Administrador"
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _mostaza.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _mostaza.withValues(alpha: 0.5),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.shield_rounded,
                                        size: 11, color: _mostaza),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Administrador',
                                      style: TextStyle(
                                        color: _mostaza,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Cerrar sesión como botón compacto
                        GestureDetector(
                          onTap: () async {
                            await FirebaseAuth.instance.signOut();
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const LoginPage()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE53935),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFC62828),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.logout_rounded,
                                    color: Colors.white,
                                    size: 13),
                                const SizedBox(width: 4),
                                const Text(
                                  'Salir',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
              child: Column(
                children: [
                  _AdminCard(
                    titulo: 'Gestionar recetas',
                    subtitulo: 'Añadir, editar o eliminar platos del catálogo',
                    icono: Icons.restaurant_menu_rounded,
                    color: const Color(0xFF2D9E73),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AdminRecetasScreen())),
                  ),
                  const SizedBox(height: 12),
                  _AdminCard(
                    titulo: 'Categorías',
                    subtitulo: 'Organizar recetas por tipo de comida',
                    icono: Icons.grid_view_rounded,
                    color: const Color(0xFF00838F),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AdminCategoriasScreen())),
                  ),
                  const SizedBox(height: 12),
                  _AdminCard(
                    titulo: 'Recetas por aprobar',
                    subtitulo: 'Revisar y publicar recetas enviadas por usuarios',
                    icono: Icons.pending_actions_rounded,
                    color: const Color(0xFFE65100),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const AdminRecetasPendientesScreen())),
                  ),
                  const SizedBox(height: 12),
                  _AdminCard(
                    titulo: 'Reportes',
                    subtitulo: 'Estadísticas, actividad y exportación de datos',
                    icono: Icons.bar_chart_rounded,
                    color: const Color(0xFF4527A0),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const ReportesScreen())),
                  ),
                  const SizedBox(height: 12),
                  _AdminCard(
                    titulo: 'Gestionar usuarios',
                    subtitulo: 'Administrar roles, permisos y accesos',
                    icono: Icons.admin_panel_settings_rounded,
                    color: const Color(0xFF1565C0),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(builder: (_) => const GestionarUsuariosScreen())),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final Color color;
  final VoidCallback onTap;

  const _AdminCard({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        splashColor: color.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              // Ícono con color único por tarjeta
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icono, color: color, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitulo,
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Flecha con color de la tarjeta
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: color,
                  size: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}