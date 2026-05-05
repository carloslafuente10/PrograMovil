import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'favoritos_screen.dart';
import 'login_page.dart';
import 'sugerencias_chat_screen.dart';

class AppMainScreen extends StatefulWidget {
  const AppMainScreen({super.key});

  @override
  State<AppMainScreen> createState() => AppMainScreenState();
}

class AppMainScreenState extends State<AppMainScreen> {
  int selectedIndex = 0;
  late final List<Widget> page;

  @override
  void initState() {
    super.initState();
    // Las páginas ahora son widgets simples que se inyectan en el body
    page = [
      HomeScreen(),
      const FavoritosScreen(),
      const _PlanScreen(),
      const _AjustesScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      // El body cambia según el índice seleccionado
      body: page[selectedIndex],

      // --- CORRECCIÓN: El FAB y la ubicación van en el Scaffold principal ---
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF2D9E73),
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 30),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const SugerenciasChatScreen(),
             ), 
            );
          }, 
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // --- CORRECCIÓN: Reemplazo de BottomNavigationBar por BottomAppBar para el diseño con "Notch" ---
      bottomNavigationBar: BottomAppBar(
        padding: const EdgeInsets.symmetric(horizontal: 5),
        height: 65,
        color: Colors.white,
        shape: const CircularNotchedRectangle(),
        notchMargin: 6,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            // Grupo Izquierdo
            Row(
              children: [
                _buildNavItem(0, Icons.home, 'Inicio'),
                const SizedBox(width: 5),
                _buildNavItem(1, Icons.favorite_border, 'Favoritos'),
              ],
            ),
            // Espacio central para el botón flotante
            const SizedBox(width: 60),
            // Grupo Derecho
            Row(
              children: [
                _buildNavItem(2, Icons.calendar_month_outlined, 'Plan'),
                const SizedBox(width: 5),
                _buildNavItem(3, Icons.settings_outlined, 'Ajustes'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Método para construir los items de navegación con setState centralizado
  Widget _buildNavItem(int index, IconData icon, String label) {
    bool isSelected = selectedIndex == index;
    return MaterialButton(
      minWidth: 40,
      onPressed: () => setState(() => selectedIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isSelected ? const Color(0xFF2D9E73) : Colors.grey,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? const Color(0xFF2D9E73) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

// --- PANTALLA DE PLAN (Limpia) ---
class _PlanScreen extends StatelessWidget {
  const _PlanScreen();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Contenido de Planes',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// --- PANTALLA DE AJUSTES ---
class _AjustesScreen extends StatelessWidget {
  static const Color _verde = Color(0xFF2D9E73);

  const _AjustesScreen();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final nombre = user?.displayName ?? 'Usuario';
    final email = user?.email ?? '';
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Mi perfil',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 20),
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: _verde,
                  child: Text(
                    inicial,
                    style: const TextStyle(
                      fontSize: 32,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.person_outline,
                  label: 'Nombre',
                  valor: nombre,
                ),
                Divider(height: 1, color: Colors.grey[100]),
                _InfoTile(
                  icon: Icons.email_outlined,
                  label: 'Correo',
                  valor: email,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (!context.mounted) return;
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (_) => false,
                );
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Cerrar sesión',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2D9E73)),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 11, color: Colors.grey[400]),
              ),
              const SizedBox(height: 2),
              Text(
                valor.isNotEmpty ? valor : '—',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}