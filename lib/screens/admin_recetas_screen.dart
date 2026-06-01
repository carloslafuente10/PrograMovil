import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ver_receta_admin_screen.dart';
import 'crear_receta_admin_screen.dart';

class AdminRecetasScreen extends StatefulWidget {
  const AdminRecetasScreen({super.key});

  @override
  State<AdminRecetasScreen> createState() => _AdminRecetasScreenState();
}

class _AdminRecetasScreenState extends State<AdminRecetasScreen> {
  static const Color _verde      = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  static const Color _pizarra    = Color(0xFF455A64);
  static const Color _fondo      = Color(0xFFF5F6FA);

  String _buscar  = '';
  final  _buscarCtrl = TextEditingController();

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _verde,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Gestionar Recetas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: _verde,
            child: Container(
              decoration: const BoxDecoration(
                color: _fondo,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
              child: Column(
                children: [
                  // Contador + badge solo lectura
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('app-recetas-completas')
                        .snapshots(),
                    builder: (context, snapshot) {
                      final count = snapshot.data?.docs.length ?? 0;
                      return Row(
                        children: [
                          const Icon(Icons.restaurant_menu_rounded, color: _verde, size: 16),
                          const SizedBox(width: 6),
                          Text('$count recetas en total',
                              style: const TextStyle(
                                  color: _verde, fontWeight: FontWeight.w600, fontSize: 13)),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                                color: _verdeClaro, borderRadius: BorderRadius.circular(20)),
                            child: const Row(
                              children: [
                                Icon(Icons.lock_outline_rounded, color: _verde, size: 12),
                                SizedBox(width: 4),
                                Text('Solo lectura',
                                    style: TextStyle(
                                        color: _verde, fontSize: 11, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 10),

                  // Buscador
                  TextField(
                    controller: _buscarCtrl,
                    decoration: InputDecoration(
                      hintText: 'Buscar receta...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400], size: 20),
                      suffixIcon: _buscar.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded, color: Colors.grey[400], size: 18),
                              onPressed: () => setState(() {
                                _buscar = '';
                                _buscarCtrl.clear();
                              }),
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: (v) => setState(() => _buscar = v.toLowerCase()),
                  ),
                ],
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
                  return const Center(child: CircularProgressIndicator(color: _verde));
                }

                var docs = snapshot.data?.docs ?? [];

                // Filtrar por búsqueda
                if (_buscar.isNotEmpty) {
                  docs = docs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final nombre    = (data['nombre']    ?? '').toString().toLowerCase();
                    final categoria = (data['categoria'] ?? '').toString().toLowerCase();
                    return nombre.contains(_buscar) || categoria.contains(_buscar);
                  }).toList();
                }

                // Ordenar A→Z / Z→A
                docs = List.from(docs)..sort((a, b) {
                  final da = a.data() as Map<String, dynamic>;
                  final db = b.data() as Map<String, dynamic>;
                  final na = (da['nombre'] ?? '').toString().toLowerCase();
                  final nb = (db['nombre'] ?? '').toString().toLowerCase();
                  if (na.isEmpty) return 1;
                  if (nb.isEmpty) return -1;
                  return na.compareTo(nb);
                });

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 56, color: Colors.grey[300]),
                        const SizedBox(height: 12),
                        Text(
                          _buscar.isNotEmpty
                              ? 'Sin resultados para "$_buscar"'
                              : 'No hay recetas aún',
                          style: TextStyle(
                              color: Colors.grey[500], fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                        if (_buscar.isEmpty) ...[
                          const SizedBox(height: 6),
                          Text('Toca + para agregar tu primera receta',
                              style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                        ],
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 242,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    return _RecetaCard(docId: docs[i].id, data: data);
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _verde,
        elevation: 4,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CrearRecetaAdminScreen()),
        ),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: const Text('Nueva receta',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    );
  }
}

class _RecetaCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;

  static const Color _verde      = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);

  const _RecetaCard({required this.docId, required this.data});

  @override
  Widget build(BuildContext context) {
    final img      = data['imagen']?.toString() ?? '';
    final nombre   = data['nombre']?.toString() ?? '';
    final calorias = (data['calorias'] ?? data['calorías'])?.toString() ?? '0';
    final categoria = data['categoria']?.toString() ?? '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VerRecetaAdminScreen(recetaId: docId, nombreReceta: nombre),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: SizedBox(
                    height: 105,
                    width: double.infinity,
                    child: img.isNotEmpty
                        ? Image.network(img, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _Placeholder())
                        : _Placeholder(),
                  ),
                ),
                Positioned(
                  top: 8, right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6)),
                    child: const Icon(Icons.lock_rounded, color: Colors.white, size: 12),
                  ),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (categoria.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        margin: const EdgeInsets.only(bottom: 4),
                        decoration: BoxDecoration(
                            color: _verdeClaro, borderRadius: BorderRadius.circular(5)),
                        child: Text(categoria,
                            style: const TextStyle(
                                color: _verde, fontSize: 9, fontWeight: FontWeight.w600)),
                      ),
                    Text(nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                            color: Color(0xFF1A1A2E))),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            color: Color(0xFFFF6B35), size: 12),
                        const SizedBox(width: 2),
                        Text('$calorias Cal',
                            style: TextStyle(
                                fontSize: 10.5,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500)),
                        const Spacer(),
                        _MiniBtn(
                          icono: Icons.delete_rounded,
                          color: const Color(0xFFE53935),
                          bg: const Color(0xFFFFEBEE),
                          onTap: () => _confirmarEliminar(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmarEliminar(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar receta', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('¿Eliminar "${data['nombre']}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('app-recetas-completas')
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFE8F7F1),
    child: const Center(
      child: Icon(Icons.restaurant_rounded, color: Color(0xFF2D9E73), size: 32),
    ),
  );
}

class _MiniBtn extends StatelessWidget {
  final IconData icono;
  final Color color, bg;
  final VoidCallback onTap;

  const _MiniBtn({
    required this.icono,
    required this.color,
    required this.bg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Icon(icono, color: color, size: 14),
    ),
  );
}