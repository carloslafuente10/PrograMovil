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
import 'package:cloud_firestore/cloud_firestore.dart';
import '../servicios/historial_servicio.dart';

class AppMainScreen extends StatefulWidget {
  const AppMainScreen({super.key});
  static final GlobalKey<AppMainScreenState> globalKey =
      GlobalKey<AppMainScreenState>();
  @override
  State<AppMainScreen> createState() => AppMainScreenState();
}

class AppMainScreenState extends State<AppMainScreen> {
  int selectedIndex = 0;

  static const Color _verde    = Color(0xFF2D9E73);
  static const Color _verdeOsc = Color(0xFF1B5E20);
  static const Color _mostaza  = Color(0xFFF5A623);
  static const Color _cafe     = Color(0xFF8B5E3C);

  static const List<Color> _tabColors = [
    Color(0xFF1B5E20),
    Color(0xFFD81B60),
    Color(0xFF1565C0),
    Color(0xFF6D4C41),
  ];

  static const List<IconData> _tabIconsOff = [
    Icons.home_outlined,
    Icons.favorite_border,
    Icons.calendar_month_outlined,
    Icons.settings_outlined,
  ];

  static const List<IconData> _tabIconsOn = [
    Icons.home_rounded,
    Icons.favorite_rounded,
    Icons.calendar_month_rounded,
    Icons.settings_rounded,
  ];

  static const List<String> _tabLabels = [
    'Inicio', 'Favoritos', 'Plan', 'Ajustes'
  ];

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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Presiona atrás de nuevo para salir'),
        duration: const Duration(seconds: 2),
        backgroundColor: _verde,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
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
        backgroundColor: const Color(0xFFFFF8EE),
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
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(
                        builder: (context) => SugerenciasChatScreen())),
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [BoxShadow(
                        color: _verde.withOpacity(0.3),
                        blurRadius: 15, spreadRadius: 2)],
                  ),
                  child: ClipOval(
                    child: OverflowBox(
                      minWidth: 0, minHeight: 0,
                      maxWidth: 160, maxHeight: 160,
                      child: Lottie.asset(
                        'assets/animations/animation.json',
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.5),
                        errorBuilder: (_, __, ___) => const Icon(
                            Icons.smart_toy, color: Color(0xFF2D9E73), size: 40),
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
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 0, bottom: 0,
                child: Opacity(
                  opacity: 0.25,
                  child: Image.asset('assets/images/vegetables_botton.png',
                      height: 62, fit: BoxFit.fitHeight),
                ),
              ),
              Positioned(
                right: 0, bottom: 0,
                child: Opacity(
                  opacity: 0.25,
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.rotationY(3.14159),
                    child: Image.asset('assets/images/vegetables_botton.png',
                        height: 62, fit: BoxFit.fitHeight),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Row(children: [
                    _buildNavItem(0),
                    const SizedBox(width: 5),
                    _buildNavItem(1),
                  ]),
                  const SizedBox(width: 60),
                  Row(children: [
                    _buildNavItem(2),
                    const SizedBox(width: 5),
                    _buildNavItem(3),
                  ]),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final bool isSelected = selectedIndex == index;
    final color = _tabColors[index];
    return GestureDetector(
      onTap: () => setState(() => selectedIndex = index),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: isSelected ? 44 : 36,
              height: isSelected ? 36 : 32,
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.13) : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: color.withOpacity(0.3), width: 1.5)
                    : null,
              ),
              child: Center(
                child: Icon(
                  isSelected ? _tabIconsOn[index] : _tabIconsOff[index],
                  color: isSelected ? color : Colors.grey[600],
                  size: isSelected ? 26 : 22,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              _tabLabels[index],
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                color: isSelected ? color : Colors.grey[600],
              ),
            ),
          ],
        ),
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
  static const Color _verde      = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  static const Color _mostaza    = Color(0xFFF5A623);
  static const Color _cafe       = Color(0xFF8B5E3C);
  static const Color _verdeOsc   = Color(0xFF1B5E20);

  bool _guardandoNombre = false;

  // Editar nombre — guarda en Firebase Auth
  Future<void> _editarNombre(BuildContext context, String nombreActual) async {
    final ctrl = TextEditingController(
        text: nombreActual == 'Usuario' ? '' : nombreActual);

    final nuevoNombre = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Editar nombre',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Cómo quieres que te llamemos?',
                style: TextStyle(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 30,
              decoration: InputDecoration(
                hintText: 'Tu nombre...',
                prefixIcon: Icon(Icons.person_rounded,
                    color: _verdeOsc, size: 20),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _verde, width: 1.5)),
                counterText: '',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar',
                style: TextStyle(color: Colors.grey[600]))),
          ElevatedButton(
            onPressed: () {
              final texto = ctrl.text.trim();
              if (texto.isEmpty) return;
              Navigator.pop(ctx, texto);
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: _verde,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
            child: const Text('Guardar',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (nuevoNombre == null || nuevoNombre.isEmpty) return;
    if (!mounted) return;

    setState(() => _guardandoNombre = true);
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      await FirebaseAuth.instance.currentUser?.updateDisplayName(nuevoNombre);
      await FirebaseAuth.instance.currentUser?.reload();
      if (uid != null) {
         await FirebaseFirestore.instance
           .collection('app-usuarios')
           .doc(uid)
           .update({'nombre': nuevoNombre});
      }
      if (mounted) {
        setState(() => _guardandoNombre = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('¡Nombre actualizado a "$nuevoNombre"!'),
          backgroundColor: _verde,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _guardandoNombre = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Error al actualizar el nombre'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final nombre = user?.displayName ?? 'Usuario';
    final email = user?.email ?? '';
    final inicial = nombre.isNotEmpty ? nombre[0].toUpperCase() : '?';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8EE),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header gradiente verde
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF1B5E20), Color(0xFF2D9E73)],
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(28),
                    bottomRight: Radius.circular(28),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
                child: Column(children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [NotificacionCampana(esAdmin: false)],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _mostaza, width: 3),
                      boxShadow: [BoxShadow(
                          color: _mostaza.withOpacity(0.3), blurRadius: 12)],
                    ),
                    child: CircleAvatar(
                      radius: 38,
                      backgroundColor: Colors.white24,
                      child: user?.photoURL != null
                          ? ClipOval(child: Image.network(user!.photoURL!,
                              fit: BoxFit.cover, width: 76, height: 76))
                          : Text(inicial, style: const TextStyle(
                              fontSize: 30, color: Colors.white,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Nombre con botón de editar inline
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(nombre,
                            style: const TextStyle(fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      if (_guardandoNombre)
                        const SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(
                                color: Colors.white70, strokeWidth: 2))
                      else
                        GestureDetector(
                          onTap: () => _editarNombre(context, nombre),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.edit_rounded,
                                color: Colors.white, size: 14),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(email, style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.9))),
                  ),
                ]),
              ),

              const SizedBox(height: 24),

              _SectionLabel('MI CUENTA', _mostaza),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _PerfilCard(children: [
                  // Nombre tocable para editar
                  _EditableTile(
                    icon: Icons.person_rounded,
                    label: 'Nombre',
                    valor: nombre,
                    color: const Color(0xFF3949AB),
                    onTap: () => _editarNombre(context, nombre),
                  ),
                  Divider(height: 1, color: Colors.grey[100]),
                  _InfoTile(
                    icon: Icons.email_rounded,
                    label: 'Correo',
                    valor: email,
                    color: const Color(0xFF1565C0),
                  ),
                ]),
              ),

              const SizedBox(height: 24),

              _SectionLabel('MIS RECETAS', _verde),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _PerfilCard(children: [
                  _ActionTile(
                    icon: Icons.restaurant_menu_rounded,
                    label: 'Mis recetas personales',
                    sublabel: 'Crea, edita y organiza tus propias recetas',
                    iconColor: const Color(0xFFF5A623),
                    iconBg: const Color(0xFFFFF3DC),
                    onTap: () => Navigator.push(context,
                        MaterialPageRoute(
                            builder: (context) => const MisRecetasScreen())),
                  ),
                ]),
              ),

              const SizedBox(height: 32),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 50, width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final confirmar = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          title: const Text('Cerrar sesión',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          content: const Text(
                              '¿Estás seguro que deseas cerrar sesión?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text('Cancelar',
                                  style: TextStyle(color: Colors.grey[600]))),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10))),
                              child: const Text('Cerrar sesión',
                                  style: TextStyle(color: Colors.white))),
                          ],
                        ),
                      );
                      if (confirmar == true) {
                        await HistorialService.registrar(
                           accion: 'Cerró sesión',
                           tipo: 'logout',
                          );
                          
                        await FirebaseAuth.instance.signOut();
                        if (!context.mounted) return;
                        Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const LoginPage()),
                            (_) => false);
                      }
                    },
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Cerrar sesión',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
  final Color color;
  const _SectionLabel(this.texto, this.color);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(children: [
      Container(width: 3, height: 14,
          decoration: BoxDecoration(color: color,
              borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 6),
      Text(texto, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
          color: Colors.grey[500], letterSpacing: 0.8)),
    ]),
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
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05),
          blurRadius: 8, offset: const Offset(0, 2))],
    ),
    child: Column(children: children),
  );
}

// Tile editable con ícono de lápiz
class _EditableTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;
  final Color color;
  final VoidCallback onTap;

  const _EditableTile({required this.icon, required this.label,
      required this.valor, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              const SizedBox(height: 2),
              Text(valor.isNotEmpty ? valor : '—',
                  style: const TextStyle(fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1A1A1A))),
            ],
          )),
          Icon(Icons.edit_rounded, size: 16,
              color: color.withOpacity(0.6)),
        ]),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;
  final Color color;

  const _InfoTile({required this.icon, required this.label,
      required this.valor, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[400])),
          const SizedBox(height: 2),
          Text(valor.isNotEmpty ? valor : '—',
              style: const TextStyle(fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A))),
        ])),
      ]),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color iconColor;
  final Color iconBg;
  final VoidCallback onTap;

  const _ActionTile({required this.icon, required this.label,
      required this.sublabel, required this.iconColor,
      required this.iconBg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(color: iconBg,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 14,
                fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 2),
            Text(sublabel,
                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          ])),
          Icon(Icons.chevron_right_rounded,
              color: Colors.grey[400], size: 20),
        ]),
      ),
    );
  }
}