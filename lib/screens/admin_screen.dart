import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'admin_recetas_screen.dart';
import 'admin_categorias_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  static const Color _fondo = Color(0xFFF5F6FA);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _verde,
        elevation: 0,
        title: const Text(
          'Panel Administrador',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: CircleAvatar(
              backgroundColor: Colors.white24,
              radius: 18,
              child: user?.photoURL != null
                  ? ClipOval(
                      child: Image.network(user!.photoURL!, fit: BoxFit.cover),
                    )
                  : const Icon(
                      Icons.person_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header verde
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: _verde,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¡Bienvenido de vuelta!',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    user?.displayName ?? user?.email ?? 'Administrador',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '¿Qué deseas gestionar hoy?',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Cerrar sesión
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 16, 4),
              child: Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () async {
                    await FirebaseAuth.instance.signOut();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginPage()),
                    );
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(
                        Icons.logout_rounded,
                        color: Color(0xFFE53935),
                        size: 15,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Cerrar sesión',
                        style: TextStyle(
                          color: Color(0xFFE53935),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Grid 3 tarjetas
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 20),
              child: Column(
                children: [
                  // Fila 1: Gestionar Recetas (ancho completo)
                  _AdminCard(
                    titulo: 'Gestionar Recetas',
                    subtitulo: 'Añadir, editar o eliminar tus platos',
                    icono: Icons.restaurant_menu_rounded,
                    fullWidth: true,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AdminRecetasScreen(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Fila 2: Categorías y Reportes
                  Row(
                    children: [
                      Expanded(
                        child: _AdminCard(
                          titulo: 'Categorías',
                          subtitulo: 'Organizar por tipo de comida',
                          icono: Icons.grid_view_rounded,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AdminCategoriasScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _AdminCard(
                          titulo: 'Reportes',
                          subtitulo: 'Estadísticas y actividad',
                          icono: Icons.bar_chart_rounded,
                          onTap: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminCard extends StatelessWidget {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final VoidCallback onTap;
  final bool fullWidth;

  const _AdminCard({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.onTap,
    this.fullWidth = false,
  });

  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        splashColor: _verdeClaro,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 44, 24),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _verdeClaro,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icono,
                      color: _verde,
                      size: fullWidth ? 26 : 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: fullWidth ? 15 : 13,
                            color: const Color(0xFF1A1A2E),
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
                ],
              ),
            ),
            // Acento verde esquina inferior derecha
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 30,
                height: 18,
                decoration: const BoxDecoration(
                  color: _verde,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                child: const Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white,
                  size: 9,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
