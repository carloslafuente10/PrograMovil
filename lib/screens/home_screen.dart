import 'package:flutter/material.dart';
import 'detalle_receta_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _categoriaSeleccionada = 'Todo';
  final TextEditingController _searchController = TextEditingController();
  String _busqueda = '';

  final List<Map<String, String>> _recetas = [
    {
      "nombre": "Arepas rellenas",
      "img": "assets/images/platos/Arepas rellenas.jpg",
      "calorias": "320",
      "tiempo": "15",
      "categoria": "Almuerzo",
    },
    {
      "nombre": "Ceviche Peruano",
      "img": "assets/images/platos/Ceviche peruano.webp",
      "calorias": "210",
      "tiempo": "20",
      "categoria": "Almuerzo",
    },
    {
      "nombre": "Ensalada César",
      "img": "assets/images/platos/Ensalada César.jpg",
      "calorias": "180",
      "tiempo": "10",
      "categoria": "Almuerzo",
    },
    {
      "nombre": "Majadito",
      "img": "assets/images/platos/Majadito.jpg",
      "calorias": "450",
      "tiempo": "35",
      "categoria": "Almuerzo",
    },
    {
      "nombre": "Pique macho",
      "img": "assets/images/platos/Pique macho.jpg",
      "calorias": "600",
      "tiempo": "40",
      "categoria": "Cena",
    },
    {
      "nombre": "Quesadillas",
      "img": "assets/images/platos/Quesadillas.webp",
      "calorias": "350",
      "tiempo": "15",
      "categoria": "Cena",
    },
    {
      "nombre": "Salteña",
      "img": "assets/images/platos/Salteña.jpg",
      "calorias": "280",
      "tiempo": "25",
      "categoria": "Desayuno",
    },
    {
      "nombre": "Silpancho",
      "img": "assets/images/platos/Silpancho.jpg",
      "calorias": "520",
      "tiempo": "30",
      "categoria": "Almuerzo",
    },
    {
      "nombre": "Sopa de maní",
      "img": "assets/images/platos/Sopa de mani.jpg",
      "calorias": "390",
      "tiempo": "45",
      "categoria": "Almuerzo",
    },
    {
      "nombre": "Tacos al pastor",
      "img": "assets/images/platos/Tacos al pastor.jpg",
      "calorias": "250",
      "tiempo": "20",
      "categoria": "Cena",
    },
    {
      "nombre": "Trancapecho",
      "img": "assets/images/platos/Trancapecho.jpg",
      "calorias": "480",
      "tiempo": "10",
      "categoria": "Desayuno",
    },
    {
      "nombre": "Anticucho",
      "img": "assets/images/platos/Anticucho.webp",
      "calorias": "310",
      "tiempo": "25",
      "categoria": "Cena",
    },
  ];

  final List<String> _categorias = ['Todo', 'Desayuno', 'Almuerzo', 'Cena'];
  final Color _verde = const Color(0xFF2D9E73);

  List<Map<String, String>> get _recetasFiltradas {
    return _recetas.where((r) {
      final coincideCategoria =
          _categoriaSeleccionada == 'Todo' ||
          r['categoria'] == _categoriaSeleccionada;
      final coincideBusqueda = r['nombre']!.toLowerCase().contains(
        _busqueda.toLowerCase(),
      );
      return coincideCategoria && coincideBusqueda;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      body: SafeArea(
        child: ListView(
          children: [
            // Header
            Padding(
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
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFE8E8E8),
                    child: Icon(
                      Icons.person_outline,
                      color: Colors.grey[600],
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),

            // Barra de búsqueda
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _busqueda = v),
                decoration: InputDecoration(
                  hintText: 'Buscar recetas...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(
                    Icons.search,
                    color: Colors.grey[400],
                    size: 20,
                  ),
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
            ),

            const SizedBox(height: 16),

            // Banner verde
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                // height: 130, /esta comentado para que no salga bottom overflowed por ahora
                decoration: BoxDecoration(
                  color: _verde,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                  onPressed: () {},
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
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
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
                          // Imagen del banner (aun no hay imagen, luego la pongo)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 90,
                              height: 90,
                              color: Colors.white.withOpacity(0.15),
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
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Categorías de recetas
            const Padding(
              padding: EdgeInsets.only(left: 20, bottom: 10),
              child: Text(
                'Categorías',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _categorias.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final cat = _categorias[i];
                  final activo = cat == _categoriaSeleccionada;
                  return GestureDetector(
                    onTap: () => setState(() => _categoriaSeleccionada = cat),
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
            ),

            const SizedBox(height: 20),

            // Rápido y fácil (recetas filtradas sugeridas por tiempo)
            Padding(
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
                  Text(
                    'Ver todo',
                    style: TextStyle(
                      fontSize: 12,
                      color: _verde,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Tarjetas de recetas
            SizedBox(
              height: 200,
              child: _recetasFiltradas.isEmpty
                  ? Center(
                      child: Text(
                        'No se encontraron recetas',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _recetasFiltradas.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) {
                        final r = _recetasFiltradas[i];
                        return GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DetalleRecetaScreen(
                                nombreReceta: r['nombre']!,
                              ),
                            ),
                          ),
                          child: _RecetaCard(receta: r, verde: _verde),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// Widgets para las recetas
class _RecetaCard extends StatefulWidget {
  final Map<String, String> receta;
  final Color verde;
  const _RecetaCard({required this.receta, required this.verde});

  @override
  State<_RecetaCard> createState() => _RecetaCardState();
}

class _RecetaCardState extends State<_RecetaCard> {
  bool _favorito = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 150,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(14),
                ),
                child: Image.asset(
                  widget.receta['img']!,
                  width: 150,
                  height: 110,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 150,
                    height: 110,
                    color: const Color(0xFFE8E8E8),
                    child: const Icon(
                      Icons.fastfood,
                      size: 40,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
              // Botón favorito
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => setState(() => _favorito = !_favorito),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _favorito ? Icons.favorite : Icons.favorite_border,
                      size: 16,
                      color: _favorito ? Colors.red : Colors.grey,
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Info
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
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.access_time, size: 12, color: Colors.grey[400]),
                    const SizedBox(width: 2),
                    Text(
                      '${widget.receta['tiempo']} Min',
                      style: TextStyle(fontSize: 10, color: Colors.grey[500]),
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
}
