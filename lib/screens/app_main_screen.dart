import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';
import 'favoritos_screen.dart';
import 'plan_screen.dart';
import 'login_page.dart';
import 'sugerencias_chat_screen.dart';
import 'mis_recetas_screen.dart';
import 'package:lottie/lottie.dart';
import 'components/notificacion_campana.dart';

class AppMainScreen extends StatefulWidget {
  const AppMainScreen({super.key});
  static final GlobalKey<AppMainScreenState> globalKey =
      GlobalKey<AppMainScreenState>();

  @override
  State<AppMainScreen> createState() => AppMainScreenState();
}

class AppMainScreenState extends State<AppMainScreen> {
  int selectedIndex = 0;
  final List<Widget> _pages = const [
    HomeScreen(),
    FavoritosScreen(),
    PlanScreen(),
    _AjustesScreen(),
  ];

  DateTime? _ultimaVezAtras;

  void _manejarAtras() {
    if (selectedIndex != 0) {
      setState(() => selectedIndex = 0);
      return;
    }

    final ahora = DateTime.now();
    if (_ultimaVezAtras == null ||
        ahora.difference(_ultimaVezAtras!) > const Duration(seconds: 2)) {
      _ultimaVezAtras = ahora;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Presiona atrás de nuevo para salir'),
          duration: const Duration(seconds: 2),
          backgroundColor: const Color(0xFF2D9E73),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _manejarAtras();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F5),
        body: IndexedStack(index: selectedIndex, children: _pages),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        floatingActionButton: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 2500),
          tween: Tween(begin: 0.0, end: 1.0),
          curve: Curves.elasticOut,
          builder: (context, value, child) {
            return Transform.scale(
              scale: value,
              child: GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SugerenciasChatScreen(),
                  ),
                ),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF2D9E73).withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: OverflowBox(
                      minWidth: 0.0,
                      minHeight: 0.0,
                      maxWidth: 160,
                      maxHeight: 160,
                      child: Lottie.asset(
                        'assets/animations/animation.json',
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.5),
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.smart_toy,
                            color: Color(0xFF2D9E73),
                            size: 40,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        bottomNavigationBar: BottomAppBar(
          padding: const EdgeInsets.symmetric(horizontal: 5),
          height: 65,
          color: Colors.white,
          shape: const CircularNotchedRectangle(),
          notchMargin: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Row(
                children: [
                  _buildNavItem(0, Icons.home_outlined, Icons.home, 'Inicio'),
                  const SizedBox(width: 5),
                  _buildNavItem(
                    1,
                    Icons.favorite_border,
                    Icons.favorite,
                    'Favoritos',
                  ),
                ],
              ),
              const SizedBox(width: 60),
              Row(
                children: [
                  _buildNavItem(
                    2,
                    Icons.calendar_month_outlined,
                    Icons.calendar_month,
                    'Plan',
                  ),
                  const SizedBox(width: 5),
                  _buildNavItem(
                    3,
                    Icons.settings_outlined,
                    Icons.settings,
                    'Ajustes',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData iconInactivo,
    IconData iconActivo,
    String label,
  ) {
    final bool isSelected = selectedIndex == index;
    return MaterialButton(
      minWidth: 40,
      onPressed: () => setState(() => selectedIndex = index),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? iconActivo : iconInactivo,
            color: isSelected ? const Color(0xFF2D9E73) : Colors.grey,
            size: 24,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? const Color(0xFF2D9E73) : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _AjustesScreen extends StatefulWidget {
  const _AjustesScreen();

  @override
  State<_AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<_AjustesScreen> {
  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final nombre = user?.displayName ?? 'Usuario';
    final email = user?.email ?? '';
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: _verde,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [NotificacionCampana(esAdmin: false)],
                    ),
                    // Avatar
                    CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.white24,
                      child: user?.photoURL != null
                          ? ClipOval(
                              child: Image.network(
                                user!.photoURL!,
                                fit: BoxFit.cover,
                                width: 76,
                                height: 76,
                              ),
                            )
                          : Text(
                              inicial,
                              style: const TextStyle(
                                fontSize: 30,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              _SectionLabel('MI CUENTA'),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _PerfilCard(
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

              const SizedBox(height: 24),

              _SectionLabel('MIS RECETAS'),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _PerfilCard(
                  children: [
                    _ActionTile(
                      icon: Icons.restaurant_menu_rounded,
                      label: 'Mis recetas personales',
                      sublabel: 'Crea, edita y organiza tus propias recetas',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MisRecetasScreen(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 50,
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          title: const Text(
                            'Cerrar sesión',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          content: const Text(
                            '¿Estás seguro que deseas cerrar sesión?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(
                                'Cancelar',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text(
                                'Cerrar sesión',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirmar == true) {
                        await FirebaseAuth.instance.signOut();
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                          (_) => false,
                        );
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
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
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String texto;
  const _SectionLabel(this.texto);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Text(
      texto,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey[500],
        letterSpacing: 0.8,
      ),
    ),
  );
}

class _PerfilCard extends StatelessWidget {
  final List<Widget> children;
  const _PerfilCard({required this.children});

  @override
  Widget build(BuildContext context) => Container(
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
    child: Column(children: children),
  );
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

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: const Color(0xFF2D9E73)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sublabel,
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey[400],
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
