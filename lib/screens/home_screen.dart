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
    {"nombre": "Arepas rellenas", "img": "assets/images/platos/Arepas rellenas.jpg", "calorias": "320", "tiempo": "15", "categoria": "Almuerzo"},
    {"nombre": "Ceviche Peruano", "img": "assets/images/platos/Ceviche peruano.webp", "calorias": "210", "tiempo": "20", "categoria": "Almuerzo"},
    {"nombre": "Ensalada César", "img": "assets/images/platos/Ensalada César.jpg", "calorias": "180", "tiempo": "10", "categoria": "Almuerzo"},
    {"nombre": "Majadito", "img": "assets/images/platos/Majadito.jpg", "calorias": "450", "tiempo": "35", "categoria": "Almuerzo"},
    {"nombre": "Pique macho", "img": "assets/images/platos/Pique macho.jpg", "calorias": "600", "tiempo": "40", "categoria": "Cena"},
    {"nombre": "Quesadillas", "img": "assets/images/platos/Quesadillas.webp", "calorias": "350", "tiempo": "15", "categoria": "Cena"},
    {"nombre": "Salteña", "img": "assets/images/platos/Salteña.jpg", "calorias": "280", "tiempo": "25", "categoria": "Desayuno"},
    {"nombre": "Silpancho", "img": "assets/images/platos/Silpancho.jpg", "calorias": "520", "tiempo": "30", "categoria": "Almuerzo"},
    {"nombre": "Sopa de maní", "img": "assets/images/platos/Sopa de mani.jpg", "calorias": "390", "tiempo": "45", "categoria": "Almuerzo"},
    {"nombre": "Tacos al pastor", "img": "assets/images/platos/Tacos al pastor.jpg", "calorias": "250", "tiempo": "20", "categoria": "Cena"},
    {"nombre": "Trancapecho", "img": "assets/images/platos/Trancapecho.jpg", "calorias": "480", "tiempo": "10", "categoria": "Desayuno"},
    {"nombre": "Anticucho", "img": "assets/images/platos/Anticucho.webp", "calorias": "310", "tiempo": "25", "categoria": "Cena"},
  ];

  final List<String> _categorias = ['Todo', 'Cena', 'Almuerzo', 'Desayuno'];
  final Color _verde = const Color(0xFF2D9E73);

  List<Map<String, String>> get _recetasFiltradas {
    return _recetas.where((r) {
      final coincideCategoria =
          _categoriaSeleccionada == 'Todo' || r['categoria'] == _categoriaSeleccionada;
      final coincideBusqueda =
          r['nombre']!.toLowerCase().contains(_busqueda.toLowerCase());
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

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '¿Qué cocinarás\nhoy?',
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
                    child: Icon(Icons.person_outline, color: Colors.grey[600], size: 22),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                onChanged: (v) => setState(() => _busqueda = v),
                decoration: InputDecoration(
                  hintText: 'Buscar recetas...',
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 20),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
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
                    onTap: () => setState(() => _categoriaSeleccionada = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: activo ? _verde : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 12,
                          color: activo ? Colors.white : Colors.grey[700],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              height: 200,
              child: _recetasFiltradas.isEmpty
                  ? const Center(child: Text('No se encontraron recetas'))
                  : ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _recetasFiltradas.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
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

  bool _favorito = false;

  @override
  Widget build(BuildContext context) {

    return Container(
      width: 150,

      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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

                child: Image.asset(
                  widget.receta['img']!,
                  width: 150,
                  height: 110,
                  fit: BoxFit.cover,
                ),
              ),

              Positioned(
                top: 8,
                right: 8,

                child: GestureDetector(

                  onTap: (){
                    setState(() {
                      _favorito = !_favorito;
                    });
                  },

                  child: Icon(
                    _favorito
                        ? Icons.favorite
                        : Icons.favorite_border,
                    color: Colors.red,
                    size: 18,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),

                Row(
                  children: [

                    const Icon(Icons.local_fire_department, size: 12),

                    Text(
                      '${widget.receta['calorias']} Cal',
                    ),

                    const SizedBox(width: 6),

                    const Icon(Icons.access_time, size: 12),

                    Text(
                      '${widget.receta['tiempo']} Min',
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