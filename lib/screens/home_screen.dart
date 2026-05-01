import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detalle_receta_screen.dart';
import 'favoritos_provider.dart';
import 'app_main_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  String _categoriaSeleccionada = 'Todo';
  String _busqueda = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _carruselController = ScrollController();

  final Color _verde = const Color(0xFF2D9E73);
  List<String> _categorias = ['Todo'];

  List<QueryDocumentSnapshot>? _docsCache;

  @override
  void initState() {
    super.initState();
    _cargarCategorias();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _carruselController.dispose();
    super.dispose();
  }

  Future<void> _cargarCategorias() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('app-Categorías')
          .get();
      final nombres = snap.docs
          .map((d) => (d.data()['nombre'] ?? '').toString().trim())
          .where((n) => n.isNotEmpty && n != 'Todas')
          .toList()
        ..sort();
      if (mounted) {
        setState(() {
          _categorias = ['Todo', ...nombres];
        });
      }
    } catch (_) {}
  }

  void _limpiarBusqueda() {
    _searchController.clear();
    setState(() => _busqueda = '');
  }

  void _onExplorarTap() {
    _limpiarBusqueda();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('¡Busca tu receta favorita arriba! 🍽️'),
        backgroundColor: _verde,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _onPerfilTap() {
    final mainScreen = context.findAncestorStateOfType<AppMainScreenState>();
    if (mainScreen != null) {
      mainScreen.setState(() => mainScreen.selectedIndex = 3);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); 
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      body: SafeArea(
        child: ListView(
          children: [
            _buildEncabezado(),
            _buildBuscador(),
            const SizedBox(height: 16),
            _buildBannerExplorar(),
            const SizedBox(height: 20),
            _buildTituloSeccion('Categorías'),
            _buildCategorias(),
            const SizedBox(height: 20),
            _buildHeaderRecetasRapidas(context),
            const SizedBox(height: 12),
            _buildCarruselDesdeFirestore(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEncabezado() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¿Qué cocinarás hoy?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
              height: 1.3,
            ),
          ),
          GestureDetector(
            onTap: _onPerfilTap,
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFE8E8E8),
              child: Icon(
                Icons.person_outline,
                color: Colors.grey[600],
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuscador() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _busqueda = v),
        decoration: InputDecoration(
          hintText: 'Buscar recetas...',
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon:
              Icon(Icons.search, color: Colors.grey[400], size: 20),
          suffixIcon: _busqueda.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: Colors.grey,
                    size: 20,
                  ),
                  onPressed: _limpiarBusqueda,
                )
              : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _verde, width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildBannerExplorar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: _verde,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '¡Cocina las\nmejores\nrecetas en casa!',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton(
                      onPressed: _onExplorarTap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _verde,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Explorar',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 90,
                  height: 90,
                  color: Colors.white.withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.restaurant,
                    size: 48,
                    color: Colors.white70,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTituloSeccion(String titulo) {
    return Padding(
      padding: const EdgeInsets.only(left: 20, bottom: 10),
      child: Text(
        titulo,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  Widget _buildCategorias() {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _categorias.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final cat = _categorias[i];
          final activo = cat == _categoriaSeleccionada;
          return GestureDetector(
            onTap: () {
              setState(() {
                _categoriaSeleccionada = cat;
                if (_carruselController.hasClients) {
                  _carruselController.jumpTo(0);
                }
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: activo ? _verde : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: activo ? _verde : Colors.grey[300]!,
                ),
              ),
              child: Text(
                cat,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: activo ? Colors.white : Colors.grey[700],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeaderRecetasRapidas(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Rápido y fácil de preparar',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => _VerTodasRecetasScreen(verde: _verde),
                ),
              );
            },
            child: Text(
              'Ver todo',
              style: TextStyle(
                fontSize: 12,
                color: _verde,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarruselDesdeFirestore() {
    return SizedBox(
      height: 200,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('app-recetas-completas')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              _docsCache == null) {
            return Center(
              child: CircularProgressIndicator(color: _verde),
            );
          }

          if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
            _docsCache = snapshot.data!.docs;
          }

          final sourceDocs = _docsCache ?? [];

          if (sourceDocs.isEmpty) {
            return Center(
              child: Text(
                'No hay recetas disponibles',
                style: TextStyle(color: Colors.grey[500]),
              ),
            );
          }

          final docs = sourceDocs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final nombre = (data['nombre'] ?? '').toString();
            final categoria =
                (data['categoría'] ?? data['categoria'] ?? '').toString();
            final coincideCategoria = _categoriaSeleccionada == 'Todo' ||
                categoria == _categoriaSeleccionada;
            final coincideBusqueda =
                nombre.toLowerCase().contains(_busqueda.toLowerCase());
            return coincideCategoria && coincideBusqueda;
          }).toList()
            ..sort((a, b) {
              final na = ((a.data() as Map)['nombre'] ?? '')
                  .toString()
                  .toLowerCase();
              final nb = ((b.data() as Map)['nombre'] ?? '')
                  .toString()
                  .toLowerCase();
              return na.compareTo(nb);
            });

          if (docs.isEmpty) {
            return Center(
              child: Text(
                'No se encontraron recetas',
                style: TextStyle(color: Colors.grey[500]),
              ),
            );
          }

          return ListView.separated(
            controller: _carruselController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final recetaMap = {
                'nombre': data['nombre']?.toString() ?? '',
                'img': data['imagen']?.toString() ?? '',
                'calorias':
                    (data['calorías'] ?? data['calorias'])?.toString() ??
                    '—',
                'tiempo': data['tiempo']?.toString() ?? '—',
                'categoria':
                    (data['categoría'] ?? data['categoria'])?.toString() ??
                    '',
              };

              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DetalleRecetaScreen(
                        nombreReceta: recetaMap['nombre']!,
                      ),
                    ),
                  );
                },
                child: _RecetaCard(
                  receta: recetaMap,
                  verde: _verde,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _RecetaCard extends StatefulWidget {
  final Map<String, String> receta;
  final Color verde;

  const _RecetaCard({
    required this.receta,
    required this.verde,
  });

  @override
  State<_RecetaCard> createState() => _RecetaCardState();
}

class _RecetaCardState extends State<_RecetaCard> {
  @override
  Widget build(BuildContext context) {
    final favState = FavoritosProvider.of(context);
    final esFav = favState.esFavorito(widget.receta['nombre']!);
    final String img = widget.receta['img'] ?? '';
    final bool esNetwork = img.startsWith('http');

    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: img.isNotEmpty
                    ? (esNetwork
                        ? Image.network(
                            img,
                            width: 150,
                            height: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          )
                        : Image.asset(
                            img,
                            width: 150,
                            height: 110,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _placeholder(),
                          ))
                    : _placeholder(),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => favState.toggle(widget.receta),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      esFav ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: esFav ? Colors.red : Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.receta['nombre']!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A1A1A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(
                      Icons.local_fire_department,
                      size: 12,
                      color: Colors.orange[400],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${widget.receta['calorias']} Cal',
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${widget.receta['tiempo']} Min',
                      style:
                          TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 150,
      height: 110,
      color: const Color(0xFFE8E8E8),
      child: const Icon(Icons.fastfood, size: 40, color: Colors.white70),
    );
  }
}


class _VerTodasRecetasScreen extends StatefulWidget {
  final Color verde;
  const _VerTodasRecetasScreen({required this.verde});

  @override
  State<_VerTodasRecetasScreen> createState() => _VerTodasRecetasScreenState();
}

class _VerTodasRecetasScreenState extends State<_VerTodasRecetasScreen> {
  String _busqueda = '';
  final TextEditingController _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text(
          'Todas las recetas',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _ctrl,
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: InputDecoration(
                hintText: 'Buscar...',
                prefixIcon:
                    Icon(Icons.search, color: Colors.grey[400], size: 20),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(
                          Icons.clear,
                          color: Colors.grey,
                          size: 20,
                        ),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() => _busqueda = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: widget.verde, width: 1.5),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('app-recetas-completas')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child:
                        CircularProgressIndicator(color: widget.verde),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No hay recetas disponibles'),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre =
                      (data['nombre'] ?? '').toString().toLowerCase();
                  return nombre.contains(_busqueda.toLowerCase());
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      'Sin resultados para "$_busqueda"',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final nombre =
                        data['nombre']?.toString() ?? 'Sin nombre';
                    final imagen = data['imagen']?.toString() ?? '';
                    final calorias =
                        (data['calorías'] ?? data['calorias'])
                            ?.toString() ??
                        '—';
                    final tiempo = data['tiempo']?.toString() ?? '—';

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                DetalleRecetaScreen(nombreReceta: nombre),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(14),
                              ),
                              child: imagen.isNotEmpty
                                  ? Image.network(
                                      imagen,
                                      width: 90,
                                      height: 90,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _imgPlaceholder(),
                                    )
                                  : _imgPlaceholder(),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombre,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.local_fire_department,
                                        size: 13,
                                        color: Colors.orange[400],
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$calorias Cal',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Icon(
                                        Icons.access_time,
                                        size: 13,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$tiempo min',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 14,
                                color: Colors.grey[400],
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
        ],
      ),
    );
  }

  Widget _imgPlaceholder() {
    return Container(
      width: 90,
      height: 90,
      color: const Color(0xFFE8E8E8),
      child: const Icon(Icons.fastfood, size: 32, color: Colors.white70),
    );
  }
}