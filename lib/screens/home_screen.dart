import 'package:flutter/material.dart';// Pantalla principal de la aplicación que muestra una lista de recetas, con la capacidad de filtrar por categoría y buscar por nombre. Utiliza Firestore para obtener las recetas en tiempo real, y permite navegar a los detalles de cada receta, así como a otras secciones de la aplicación como el perfil del usuario y la pantalla de exploración.
import 'package:firebase_auth/firebase_auth.dart';// Librería para trabajar con Firebase Authentication, que se utiliza para gestionar la autenticación de usuarios y obtener el ID del usuario actual para personalizar la experiencia en la pantalla principal, como mostrar su nombre en el saludo.
import 'package:cloud_firestore/cloud_firestore.dart';// Librería para trabajar con Firestore, la base de datos en la nube de Firebase, que se utiliza para almacenar y recuperar las recetas, categorías y otros datos necesarios para mostrar en la pantalla principal.
import 'detalle_receta_screen.dart';// Pantalla que muestra el detalle de una receta específica, incluyendo sus ingredientes, pasos de preparación, y otros detalles relevantes. Se navega a esta pantalla al seleccionar una receta en la pantalla principal, y utiliza Firestore para obtener los datos completos de la receta seleccionada.
import 'favoritos_provider.dart';// Pantalla que muestra la lista de recetas favoritas del usuario, con la capacidad de agregar o quitar recetas de favoritos. Utiliza Firestore para almacenar y recuperar las recetas favoritas del usuario, y un InheritedNotifier para gestionar el estado de los favoritos en toda la aplicación. Se puede navegar a esta pantalla desde el perfil del usuario o desde otras secciones de la aplicación donde se muestren recetas.
import 'app_main_screen.dart';// Pantalla principal de la aplicación que contiene una barra de navegación inferior para acceder a las diferentes secciones de la aplicación, incluyendo la pantalla principal (HomeScreen), la pantalla de exploración (ExplorarScreen), la pantalla de favoritos (FavoritosScreen) y el perfil del usuario (PerfilScreen). La pantalla HomeScreen es una de las secciones accesibles desde esta barra de navegación, y muestra una lista de recetas con opciones de filtrado y búsqueda.
// Pantalla principal de la aplicación que muestra una lista de recetas, con la capacidad de filtrar por categoría y buscar por nombre. Utiliza Firestore para obtener las recetas en tiempo real, y permite navegar a los detalles de cada receta, así como a otras secciones de la aplicación como el perfil del usuario y la pantalla de exploración.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}
// Estado de la pantalla HomeScreen, que maneja la lógica para filtrar las recetas por categoría, buscar por nombre, cargar las categorías desde Firestore, y navegar a los detalles de cada receta. Incluye un StreamBuilder para escuchar los cambios en Firestore y actualizar la lista de recetas en tiempo real, y métodos para manejar la interacción del usuario con el buscador y las categorías.
class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const Color _verde     = Color(0xFF2D9E73);
  static const Color _verdeOsc  = Color(0xFF1B5E20);
  static const Color _mostaza   = Color(0xFFF5A623);
  static const Color _cafe      = Color(0xFF8B5E3C);
  static const Color _crema     = Color(0xFFFFF8EE);

  String _categoriaSeleccionada = 'Todo';
  String _busqueda = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final ScrollController _carruselController = ScrollController();
  List<String> _categorias = ['Todo'];
  String _nombreUsuario = '';
  List<QueryDocumentSnapshot>? _docsCache;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
    final user = FirebaseAuth.instance.currentUser;
    _nombreUsuario = user?.displayName?.split(' ').first ?? '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _carruselController.dispose();
    super.dispose();
  }
// Método para mostrar un diálogo de selección de fecha, que permite al usuario elegir una fecha para filtrar las recetas por su fecha de creación o actualización. El diálogo muestra un calendario y botones para cancelar o confirmar la selección, y devuelve la fecha seleccionada al cerrar el diálogo.
  Future<void> _cargarCategorias() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('app-Categorías').get();
      final nombres = snap.docs
          .map((d) => (d.data()['nombre'] ?? '').toString().trim())
          .where((n) => n.isNotEmpty && n != 'Todas').toList();
      const orden = ['Desayuno','Almuerzo','Cena','Refrescos','carnes'];
      nombres.sort((a, b) {
        final iA = orden.indexWhere((o) => o.toLowerCase() == a.toLowerCase());
        final iB = orden.indexWhere((o) => o.toLowerCase() == b.toLowerCase());
        if (iA != -1 && iB != -1) return iA.compareTo(iB);
        if (iA != -1) return -1; if (iB != -1) return 1;
        return a.toLowerCase().compareTo(b.toLowerCase());
      });
      if (mounted) setState(() => _categorias = ['Todo', ...nombres]);
    } catch (_) {}
  }
// Método para limpiar el texto del buscador y restablecer la búsqueda a una cadena vacía, lo que hace que se muestren todas las recetas sin filtrar por nombre. Se llama a este método cuando el usuario presiona el botón de limpiar en el campo de búsqueda, y actualiza el estado para reflejar los cambios en la interfaz.
  void _limpiarBusqueda() { _searchController.clear(); setState(() => _busqueda = ''); }
// Método para manejar la navegación a la pantalla de detalles de una receta específica. Recibe el ID de la receta seleccionada, y utiliza Navigator.push para navegar a la pantalla DetalleRecetaScreen, pasando el ID de la receta como argumento para que la pantalla de detalles pueda cargar y mostrar la información completa de esa receta.
  void _onExplorarTap() {
    Navigator.push(context, MaterialPageRoute(
        builder: (_) => const _ExplorarGridScreen()));
  }
// Método para manejar la navegación al perfil del usuario. Busca el estado de la pantalla principal (AppMainScreenState) en el árbol de widgets, y si lo encuentra, actualiza su estado para cambiar la sección seleccionada a la del perfil del usuario (índice 3). Esto permite que el usuario acceda rápidamente a su perfil desde la pantalla principal.
  void _onPerfilTap() {
    final m = context.findAncestorStateOfType<AppMainScreenState>();
    if (m != null) m.setState(() => m.selectedIndex = 3);
  }

  // Colores por categoría
  static Color _catColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'todo':         return _verdeOsc;
      case 'desayuno':     return const Color(0xFFFF8F00);
      case 'almuerzo':     return _verde;
      case 'cena':         return const Color(0xFF3949AB);
      case 'postres':      return const Color(0xFFD81B60);
      case 'sopas':        return const Color(0xFFE64A19);
      case 'bebidas':
      case 'refrescos':    return const Color(0xFF00838F);
      case 'snacks':
      case 'refrigerios':  return const Color(0xFF6D4C41);
      case 'ensaladas':    return const Color(0xFF388E3C);
      case 'panadería':    return const Color(0xFFF57F17);
      case 'vegano':       return const Color(0xFF2E7D32);
      case 'carnes':       return const Color(0xFF4E342E);
      default:             return const Color(0xFF546E7A);
    }
  }

  // Íconos Material por categoría (más visibles que emojis en Android)
  static IconData _catIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'todo':         return Icons.restaurant_menu_rounded;
      case 'desayuno':     return Icons.light_mode_rounded;
      case 'almuerzo':     return Icons.restaurant_rounded;
      case 'cena':         return Icons.dark_mode_rounded;
      case 'postres':      return Icons.cake_rounded;
      case 'sopas':        return Icons.rice_bowl_rounded;
      case 'bebidas':
      case 'refrescos':    return Icons.local_drink_rounded;
      case 'snacks':
      case 'refrigerios':  return Icons.fastfood_rounded;
      case 'ensaladas':    return Icons.spa_rounded;
      case 'panadería':    return Icons.breakfast_dining_rounded;
      case 'vegano':       return Icons.eco_rounded;
      case 'carnes':       return Icons.set_meal_rounded;
      default:             return Icons.restaurant_menu_rounded;
    }
  }

  // Badge emoji para cards
  static String _badgeEmoji(String cat) {
    switch (cat.toLowerCase()) {
      case 'desayuno':    return '☀️';
      case 'almuerzo':    return '🍽️';
      case 'cena':        return '🌙';
      case 'postres':     return '🍰';
      case 'sopas':       return '🍲';
      case 'bebidas':
      case 'refrescos':   return '🥤';
      case 'snacks':
      case 'refrigerios': return '🧁';
      case 'ensaladas':   return '🥗';
      case 'panadería':   return '🥖';
      case 'vegano':      return '🥦';
      case 'carnes':      return '🥩';
      default:            return '🍴';
    }
  }
// Método build que construye la interfaz de usuario de la pantalla, incluyendo un AppBar con el nombre del usuario y un botón para seleccionar la fecha, y un cuerpo que muestra una tabla con las actividades del usuario filtradas por la fecha seleccionada. Utiliza un StreamBuilder para escuchar los cambios en Firestore y actualizar la tabla en tiempo real.
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: _crema,
      body: SafeArea(
        child: ListView(
          children: [
            _buildEncabezado(),
            const SizedBox(height: 12),
            _buildBuscador(),
            const SizedBox(height: 16),
            _buildBannerExplorar(),
            const SizedBox(height: 22),
            _buildTituloSeccion('Categorías', _mostaza),
            const SizedBox(height: 10),
            _buildCategorias(),
            const SizedBox(height: 22),
            _buildHeaderRecetasRapidas(context),
            const SizedBox(height: 12),
            _buildCarruselDesdeFirestore(),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
// Widget que construye el encabezado de la pantalla, que incluye un saludo personalizado con el nombre del usuario y un botón para acceder al perfil del usuario. El encabezado tiene un diseño atractivo con colores y estilos de texto, y utiliza un GestureDetector para manejar la interacción del usuario al tocar el botón del perfil.
  Widget _buildEncabezado() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_nombreUsuario.isNotEmpty)
              Text('¡Hola, $_nombreUsuario! 👋',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                      color: _cafe)),
            if (_nombreUsuario.isNotEmpty) const SizedBox(height: 2),
            Text('¿Qué cocinarás hoy?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
                    color: _verdeOsc, height: 1.2)),
            const SizedBox(height: 4),
            Container(height: 3, width: 60,
                decoration: BoxDecoration(color: _mostaza,
                    borderRadius: BorderRadius.circular(2))),
          ]),
          GestureDetector(
            onTap: _onPerfilTap,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: Colors.white,
                border: Border.all(color: _mostaza.withOpacity(0.5), width: 2),
                boxShadow: [BoxShadow(color: _mostaza.withOpacity(0.15),
                    blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Icon(Icons.person_rounded, color: _verdeOsc, size: 22),
            ),
          ),
        ],
      ),
    );
  }
//  Widget que construye el buscador de recetas, que incluye un campo de texto para ingresar el término de búsqueda y un botón para limpiar el campo. El buscador tiene un diseño atractivo con colores y estilos de texto, y utiliza un TextEditingController para manejar el texto ingresado por el usuario, así como un FocusNode para gestionar el enfoque del campo de texto.
  Widget _buildBuscador() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: _cafe.withOpacity(0.08),
              blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          onChanged: (v) => setState(() => _busqueda = v),
          decoration: InputDecoration(
            hintText: 'Buscar recetas...',
            hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
            prefixIcon: Icon(Icons.search_rounded, color: _mostaza, size: 22),
            suffixIcon: _busqueda.isNotEmpty
                ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                    onPressed: _limpiarBusqueda) : null,
            filled: true, fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none),
          ),
        ),
      ),
    );
  }
// Widget que construye un banner promocional para la sección de exploración de recetas, que incluye una imagen de fondo, un texto llamativo y un botón para acceder a la pantalla de exploración. El banner tiene un diseño atractivo con colores y estilos de texto, y utiliza un Stack para superponer los elementos visuales, así como un GestureDetector para manejar la interacción del usuario al tocar el botón de exploración.
  Widget _buildBannerExplorar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: SizedBox(
          height: 165, width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            Image.asset('assets/images/banner_home.png',
                fit: BoxFit.cover, alignment: Alignment.center),
            Positioned(
              left: 0, top: 0, bottom: 0, width: 210,
              child: Container(decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                  colors: [Colors.black.withOpacity(0.48), Colors.transparent]))),
            ),
            Positioned(
              left: 18, top: 0, bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('¡Cocina las\nmejores recetas\nen casa!',
                      style: TextStyle(color: Colors.white, fontSize: 16,
                          fontWeight: FontWeight.w800, height: 1.3,
                          shadows: [Shadow(color: Colors.black45, blurRadius: 6,
                              offset: Offset(0, 1))])),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _onExplorarTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _mostaza, foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Explorar',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
// Widget que construye el título de una sección, que incluye un indicador visual (una barra vertical) y un texto con estilo. El título tiene un diseño atractivo con colores y estilos de texto, y se utiliza para separar visualmente las diferentes secciones de la pantalla principal, como la sección de categorías o la sección de recetas rápidas.
  Widget _buildTituloSeccion(String titulo, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        Container(width: 4, height: 20,
            decoration: BoxDecoration(color: accentColor,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
            color: _verdeOsc)),
      ]),
    );
  }
// Widget que construye una cuadrícula de ingredientes seleccionables y un botón de confirmación. Permite al usuario seleccionar los ingredientes que tiene disponibles, y luego confirmar su selección para mostrar recetas que se pueden preparar con esos ingredientes. Utiliza un GridView.builder para generar dinámicamente los chips de ingredientes disponibles, y un ElevatedButton para confirmar la selección de ingredientes.
  Widget _buildCategorias() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categorias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = _categorias[i];
          final activo = cat == _categoriaSeleccionada;
          final color = _catColor(cat);
          final icon = _catIcon(cat);
          return GestureDetector(
            onTap: () {
              setState(() {
                _categoriaSeleccionada = cat;
                if (_carruselController.hasClients) _carruselController.jumpTo(0);
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 0),
              decoration: BoxDecoration(
                color: activo ? color : color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                    color: activo ? color : color.withOpacity(0.3), width: 1.5),
                boxShadow: activo ? [BoxShadow(color: color.withOpacity(0.35),
                    blurRadius: 8, offset: const Offset(0, 3))] : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, size: 17, color: activo ? Colors.white : color),
                const SizedBox(width: 5),
                Text(cat, style: TextStyle(
                  fontSize: 12,
                  fontWeight: activo ? FontWeight.w700 : FontWeight.w600,
                  color: activo ? Colors.white : color,
                )),
              ]),
            ),
          );
        },
      ),
    );
  }
// Widget que construye el encabezado de la sección de recetas rápidas, que incluye un indicador visual y un texto con estilo. El encabezado tiene un diseño atractivo con colores y estilos de texto, y se utiliza para separar visualmente la sección de recetas rápidas de las demás secciones de la pantalla principal.
  Widget _buildHeaderRecetasRapidas(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(children: [
            Container(width: 4, height: 20,
                decoration: BoxDecoration(color: _verde,
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            Text('Rápido y fácil de preparar',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                    color: _verdeOsc)),
          ]),
          GestureDetector(
            onTap: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => _VerTodasRecetasScreen(verde: _verde))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text('Ver todo', style: TextStyle(
                  fontSize: 13, color: _verdeOsc, fontWeight: FontWeight.w700)),
              const SizedBox(width: 4),
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(
                      color: Color(0xFFF5A623), shape: BoxShape.circle)),
            ]),
          ),
        ],
      ),
    );
  }
// Widget que construye un carrusel horizontal de recetas obtenidas desde Firestore, filtradas por la categoría seleccionada y el término de búsqueda ingresado por el usuario. Utiliza un StreamBuilder para escuchar los cambios en la colección de recetas en Firestore, y muestra las recetas en tarjetas personalizadas con su imagen, nombre, calorías, tiempo de preparación y categoría. Permite al usuario navegar a la pantalla de detalles de cada receta al tocar su tarjeta.
  Widget _buildCarruselDesdeFirestore() {
    return SizedBox(
      height: 210,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('app-recetas-completas').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _docsCache == null) {
            return Center(child: CircularProgressIndicator(color: _verde));
          }
          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            _docsCache = snapshot.data!.docs;
          }
          final sourceDocs = _docsCache ?? [];
          if (sourceDocs.isEmpty) {
            return Center(child: Text('No hay recetas disponibles',
                style: TextStyle(color: Colors.grey[500])));
          }
          final docs = sourceDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final nombre = (data['nombre'] ?? '').toString();
            final categoria =
                (data['categoría'] ?? data['categoria'] ?? '').toString();
            return (_categoriaSeleccionada == 'Todo' ||
                    categoria == _categoriaSeleccionada) &&
                nombre.toLowerCase().contains(_busqueda.toLowerCase());
          }).toList()
            ..sort((a, b) {
              final na =
                  ((a.data() as Map)['nombre'] ?? '').toString().toLowerCase();
              final nb =
                  ((b.data() as Map)['nombre'] ?? '').toString().toLowerCase();
              return na.compareTo(nb);
            });
          if (docs.isEmpty) {
            return Center(child: Text('No se encontraron recetas',
                style: TextStyle(color: Colors.grey[500])));
          }
          return ListView.separated(
            controller: _carruselController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final recetaMap = {
                'nombre':    data['nombre']?.toString() ?? '',
                'img':       data['imagen']?.toString() ?? '',
                'calorias':  (data['calorías'] ?? data['calorias'])?.toString() ?? '—',
                'tiempo':    data['tiempo']?.toString() ?? '—',
                'categoria': (data['categoría'] ?? data['categoria'])?.toString() ?? '',
              };
              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => DetalleRecetaScreen(
                        nombreReceta: recetaMap['nombre']!,
                        recetaId: docs[i].id))),
                child: _RecetaCard(receta: recetaMap,
                    badgeEmoji: _badgeEmoji(recetaMap['categoria'] ?? '')),
              );
            },
          );
        },
      ),
    );
  }
}
// Widget que construye una tarjeta personalizada para mostrar la información de una receta, incluyendo su imagen, nombre, calorías, tiempo de preparación y categoría. La tarjeta tiene un diseño atractivo con colores y estilos de texto, y utiliza un Stack para superponer un botón de favorito en la esquina superior derecha. Permite al usuario marcar o desmarcar la receta como favorita al tocar el botón de favorito, y muestra un emoji de categoría como badge en la esquina superior izquierda.
class _RecetaCard extends StatefulWidget {
  final Map<String, String> receta;
  final String badgeEmoji;
  const _RecetaCard({required this.receta, required this.badgeEmoji});
  @override
  State<_RecetaCard> createState() => _RecetaCardState();
}
// Estado de la tarjeta de receta, que maneja la lógica para mostrar la información de la receta, marcar o desmarcar como favorita, y mostrar un placeholder si la imagen no está disponible. Utiliza el estado de favoritos proporcionado por FavoritosProvider para determinar si la receta es favorita o no, y actualiza el icono del botón de favorito en consecuencia.
class _RecetaCardState extends State<_RecetaCard> {
  static const Color _mostaza = Color(0xFFF5A623);
  static const Color _cafe    = Color(0xFF8B5E3C);

  static Color _badgeColor(String cat) {
    switch (cat.toLowerCase()) {
      case 'desayuno':    return const Color(0xFFFF8F00);
      case 'almuerzo':    return const Color(0xFF2D9E73);
      case 'cena':        return const Color(0xFF3949AB);
      case 'postres':     return const Color(0xFFD81B60);
      case 'sopas':       return const Color(0xFFE64A19);
      case 'bebidas':
      case 'refrescos':   return const Color(0xFF00838F);
      case 'snacks':
      case 'refrigerios': return const Color(0xFF6D4C41);
      case 'ensaladas':   return const Color(0xFF388E3C);
      default:            return const Color(0xFF546E7A);
    }
  }
// Método build que construye la interfaz de usuario de la tarjeta de receta, mostrando la imagen de la receta (o un placeholder si no está disponible), el nombre de la receta, las calorías, el tiempo de preparación, y un botón para marcar o desmarcar como favorita. Utiliza un Stack para superponer el botón de favorito en la esquina superior derecha, y muestra un badge con un emoji de categoría en la esquina superior izquierda.
  @override
  Widget build(BuildContext context) {
    final favState  = FavoritosProvider.of(context);
    final esFav     = favState.esFavorito(widget.receta['nombre']!);
    final img       = widget.receta['img'] ?? '';
    final esNetwork = img.startsWith('http');
    final categoria = widget.receta['categoria'] ?? '';
    final badgeCol  = _badgeColor(categoria);

    return Container(
      width: 155,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: _cafe.withOpacity(0.14), blurRadius: 18, offset: const Offset(0, 6)),
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 4, offset: const Offset(0, 1)),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Stack(children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: img.isNotEmpty
                ? (esNetwork
                    ? Image.network(img, width: 155, height: 115,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder())
                    : Image.asset(img, width: 155, height: 115,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder()))
                : _placeholder(),
          ),
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: () => favState.toggle(widget.receta),
              child: Container(
                width: 30, height: 30,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: Icon(esFav ? Icons.favorite : Icons.favorite_border,
                    size: 16, color: esFav ? Colors.red : Colors.grey[400]),
              ),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.receta['nombre']!,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                    color: Color(0xFF2C1A0E)),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Row(children: [
              Icon(Icons.local_fire_department_rounded, size: 13, color: _mostaza),
              const SizedBox(width: 3),
              Text('${widget.receta['calorias']} Cal',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600],
                      fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Icon(Icons.access_time_rounded, size: 13, color: Colors.grey[400]),
              const SizedBox(width: 3),
              Text('${widget.receta['tiempo']} Min',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600])),
            ]),
          ]),
        ),
      ]),
    );
  }
// Widget que construye un placeholder para la imagen de la receta, que se muestra cuando la imagen no está disponible o no se puede cargar. El placeholder tiene un diseño simple con un fondo de color y un ícono de comida, y se utiliza para mantener la consistencia visual de las tarjetas de recetas incluso cuando no se pueden mostrar las imágenes.
  Widget _placeholder() => Container(
    width: 155, height: 115,
    decoration: const BoxDecoration(color: Color(0xFFFFF0DC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    child: Icon(Icons.fastfood_rounded, size: 40,
        color: Color(0xFFF5A623).withOpacity(0.5)),
  );
}
// Pantalla de exploración de recetas, que muestra una cuadrícula de recetas obtenidas desde Firestore, filtradas por categoría y búsqueda. Permite al usuario navegar a la pantalla de detalles de cada receta al tocar su tarjeta, y utiliza un StreamBuilder para escuchar los cambios en la colección de recetas en Firestore y actualizar la cuadrícula en tiempo real.
class _ExplorarGridScreen extends StatefulWidget {
  const _ExplorarGridScreen();
  @override
  State<_ExplorarGridScreen> createState() => _ExplorarGridScreenState();
}
// Pantalla de exploración de recetas, que muestra una cuadrícula de recetas obtenidas desde Firestore, filtradas por categoría y búsqueda. Permite al usuario navegar a la pantalla de detalles de cada receta al tocar su tarjeta, y utiliza un StreamBuilder para escuchar los cambios en la colección de recetas en Firestore y actualizar la cuadrícula en tiempo real.
class _ExplorarGridScreenState extends State<_ExplorarGridScreen> {
  static const Color _verde    = Color(0xFF2D9E73);
  static const Color _verdeOsc = Color(0xFF1B5E20);
  static const Color _mostaza  = Color(0xFFF5A623);
  static const Color _cafe     = Color(0xFF8B5E3C);
  static const Color _crema    = Color(0xFFFFF8EE);

  String _busqueda = '';
  String _categoriaFiltro = 'Todo';
  final TextEditingController _ctrl = TextEditingController();
  final List<String> _categorias = ['Todo'];

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _cargarCategorias() async {
    try {
      final snap = await FirebaseFirestore.instance.collection('app-Categorías').get();
      final nombres = snap.docs
          .map((d) => (d.data()['nombre'] ?? '').toString().trim())
          .where((n) => n.isNotEmpty && n != 'Todas').toList();
      nombres.sort();
      if (mounted) setState(() => _categorias..addAll(nombres));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _crema,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _verdeOsc,
        elevation: 0,
        title: Text('Explorar recetas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _verdeOsc)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: SizedBox(
            height: 46,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              itemCount: _categorias.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final cat = _categorias[i];
                final activo = cat == _categoriaFiltro;
                return GestureDetector(
                  onTap: () => setState(() => _categoriaFiltro = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: activo ? _verde : Colors.grey[100],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: activo ? _verde : Colors.grey[300]!, width: 1),
                    ),
                    child: Text(cat, style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: activo ? Colors.white : Colors.grey[700],
                    )),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: _cafe.withOpacity(0.08), blurRadius: 8)],
            ),
            child: TextField(
              controller: _ctrl,
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: InputDecoration(
                hintText: 'Buscar receta...',
                prefixIcon: Icon(Icons.search_rounded, color: _mostaza, size: 22),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, color: Colors.grey, size: 20),
                        onPressed: () { _ctrl.clear(); setState(() => _busqueda = ''); })
                    : null,
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('app-recetas-completas').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(color: _verde));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No hay recetas disponibles'));
              }
              final docs = snapshot.data!.docs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final nombre = (data['nombre'] ?? '').toString().toLowerCase();
                final categoria = (data['categoría'] ?? data['categoria'] ?? '').toString();
                return nombre.contains(_busqueda.toLowerCase()) &&
                    (_categoriaFiltro == 'Todo' || categoria == _categoriaFiltro);
              }).toList()
                ..sort((a, b) {
                  final na = ((a.data() as Map)['nombre'] ?? '').toString().toLowerCase();
                  final nb = ((b.data() as Map)['nombre'] ?? '').toString().toLowerCase();
                  return na.compareTo(nb);
                });

              if (docs.isEmpty) {
                return Center(child: Text('Sin resultados',
                    style: TextStyle(color: Colors.grey[500])));
              }

              return GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.78,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final nombre   = data['nombre']?.toString() ?? '';
                  final imagen   = data['imagen']?.toString() ?? '';
                  final calorias = (data['calorías'] ?? data['calorias'])?.toString() ?? '—';
                  final tiempo   = data['tiempo']?.toString() ?? '—';
                  final categoria = (data['categoría'] ?? data['categoria'])?.toString() ?? '';

                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => DetalleRecetaScreen(
                            nombreReceta: nombre, recetaId: docs[i].id))),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(color: _cafe.withOpacity(0.10),
                              blurRadius: 12, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(18)),
                              child: imagen.isNotEmpty
                                  ? Image.network(imagen,
                                      width: double.infinity, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _gridPlaceholder())
                                  : _gridPlaceholder(),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (categoria.isNotEmpty)
                                  Text(categoria, style: TextStyle(
                                      fontSize: 9, color: _verde,
                                      fontWeight: FontWeight.w700)),
                                Text(nombre,
                                    style: const TextStyle(fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF2C1A0E)),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Row(children: [
                                  Icon(Icons.local_fire_department_rounded,
                                      size: 11, color: _mostaza),
                                  const SizedBox(width: 2),
                                  Text('$calorias Cal',
                                      style: TextStyle(fontSize: 9,
                                          color: Colors.grey[600])),
                                  const SizedBox(width: 6),
                                  Icon(Icons.access_time_rounded,
                                      size: 11, color: Colors.grey[400]),
                                  const SizedBox(width: 2),
                                  Text('$tiempo min',
                                      style: TextStyle(fontSize: 9,
                                          color: Colors.grey[600])),
                                ]),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }

  Widget _gridPlaceholder() => Container(
    color: const Color(0xFFFFF0DC),
    child: Center(child: Icon(Icons.fastfood_rounded, size: 40,
        color: const Color(0xFFF5A623).withOpacity(0.5))),
  );
}
// Pantalla que muestra todas las recetas en una lista, con un campo de búsqueda para filtrar las recetas por nombre. Utiliza un StreamBuilder para escuchar los cambios en la colección de recetas en Firestore y actualizar la lista en tiempo real, y permite al usuario navegar a la pantalla de detalles de cada receta al tocar su tarjeta.
class _VerTodasRecetasScreen extends StatefulWidget {
  final Color verde;
  const _VerTodasRecetasScreen({required this.verde});
  @override
  State<_VerTodasRecetasScreen> createState() => _VerTodasRecetasScreenState();
}
// Estado de la pantalla de ver todas las recetas, que maneja la lógica para mostrar la lista de recetas obtenidas desde Firestore, filtrar por búsqueda, y navegar a la pantalla de detalles de cada receta. Utiliza un StreamBuilder para escuchar los cambios en la colección de recetas en Firestore y actualizar la lista en tiempo real, y muestra un indicador de carga mientras se obtienen los datos.
class _VerTodasRecetasScreenState extends State<_VerTodasRecetasScreen> {
  static const Color _mostaza = Color(0xFFF5A623);
  static const Color _cafe    = Color(0xFF8B5E3C);
  static const Color _crema   = Color(0xFFFFF8EE);
  static const Color _verdeOsc = Color(0xFF1B5E20);

  String _busqueda = '';
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _crema,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _verdeOsc,
        elevation: 0,
        title: Text('Todas las recetas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                color: _verdeOsc)),
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: _cafe.withOpacity(0.08),
                    blurRadius: 8)]),
            child: TextField(
              controller: _ctrl,
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: InputDecoration(
                hintText: 'Buscar receta...',
                prefixIcon: Icon(Icons.search_rounded, color: _mostaza, size: 22),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear,
                        color: Colors.grey, size: 20),
                        onPressed: () { _ctrl.clear();
                          setState(() => _busqueda = ''); }) : null,
                filled: true, fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('app-recetas-completas').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Center(child: CircularProgressIndicator(
                    color: widget.verde));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No hay recetas disponibles'));
              }
              final docs = snapshot.data!.docs.where((doc) {
                final nombre = ((doc.data() as Map)['nombre'] ?? '')
                    .toString().toLowerCase();
                return nombre.contains(_busqueda.toLowerCase());
              }).toList()
                ..sort((a, b) {
                  final na = ((a.data() as Map)['nombre'] ?? '')
                      .toString().toLowerCase();
                  final nb = ((b.data() as Map)['nombre'] ?? '')
                      .toString().toLowerCase();
                  return na.compareTo(nb);
                });
              if (docs.isEmpty) {
                return Center(child: Text('Sin resultados para "$_busqueda"',
                    style: TextStyle(color: Colors.grey[500])));
              }
              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                itemCount: docs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final data = docs[i].data() as Map<String, dynamic>;
                  final nombre = data['nombre']?.toString() ?? 'Sin nombre';
                  final imagen = data['imagen']?.toString() ?? '';
                  final calorias =
                      (data['calorías'] ?? data['calorias'])?.toString() ?? '—';
                  final tiempo = data['tiempo']?.toString() ?? '—';
                  return GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                        builder: (_) => DetalleRecetaScreen(
                            nombreReceta: nombre, recetaId: docs[i].id))),
                    child: Container(
                      decoration: BoxDecoration(color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [BoxShadow(color: _cafe.withOpacity(0.07),
                              blurRadius: 10, offset: const Offset(0, 2))]),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(16)),
                          child: imagen.isNotEmpty
                              ? Image.network(imagen, width: 90, height: 90,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => _imgPlaceholder())
                              : _imgPlaceholder(),
                        ),
                        const SizedBox(width: 14),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(nombre, style: TextStyle(fontSize: 14,
                                fontWeight: FontWeight.w700, color: _verdeOsc),
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 6),
                            Row(children: [
                              Icon(Icons.local_fire_department_rounded,
                                  size: 13, color: _mostaza),
                              const SizedBox(width: 3),
                              Text('$calorias Cal', style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600])),
                              const SizedBox(width: 12),
                              Icon(Icons.access_time_rounded, size: 13,
                                  color: Colors.grey[400]),
                              const SizedBox(width: 3),
                              Text('$tiempo min', style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600])),
                            ]),
                          ],
                        )),
                        Padding(
                          padding: const EdgeInsets.only(right: 14),
                          child: Icon(Icons.arrow_forward_ios_rounded,
                              size: 14, color: _mostaza),
                        ),
                      ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
// Widget que construye un placeholder para la imagen de la receta en la lista de todas las recetas, que se muestra cuando la imagen no está disponible o no se puede cargar. El placeholder tiene un diseño simple con un fondo de color y un ícono de comida, y se utiliza para mantener la consistencia visual de las tarjetas de recetas incluso cuando no se pueden mostrar las imágenes.
  Widget _imgPlaceholder() => Container(
    width: 90, height: 90,
    decoration: const BoxDecoration(color: Color(0xFFFFF0DC),
        borderRadius: BorderRadius.horizontal(left: Radius.circular(16))),
    child: Icon(Icons.fastfood_rounded, size: 32,
        color: Color(0xFFF5A623).withOpacity(0.5)),
  );
}