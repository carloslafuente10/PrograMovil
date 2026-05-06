import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detalle_receta_screen.dart';
class AdminRecetasScreen extends StatelessWidget {
  const AdminRecetasScreen({super.key});

  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  static const Color _fondo = Color(0xFFF5F6FA);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _verde,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Gestionar Recetas',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded, color: Colors.white),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // Subheader con contador
          Container(
            width: double.infinity,
            color: _verde,
            child: Container(
              decoration: const BoxDecoration(
                color: _fondo,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('app-recetas-completas')
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.docs.length ?? 0;
                  return Row(
                    children: [
                      const Icon(
                        Icons.restaurant_menu_rounded,
                        color: _verde,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$count recetas en total',
                        style: const TextStyle(
                          color: _verde,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Grid de recetas — 3 columnas
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('app-recetas-completas')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _verde),
                  );
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.restaurant_menu_rounded,
                          size: 56,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No hay recetas aún',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Toca + para agregar tu primera receta',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, // 3 columnas
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 215, // altura fija por tarjeta
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final recetaMap = {
                      'nombre': data['nombre']?.toString() ?? '',
                      'img': data['imagen']?.toString() ?? '',
                      'calorias':
                          (data['calorias'] ?? data['calorías'])?.toString() ??
                          '0',
                      'tiempo': data['tiempo']?.toString() ?? '',
                      'categoria': data['categoria']?.toString() ?? '',
                    };
                    return AdminRecetaCard(
                      receta: recetaMap,
                      docId: docs[i].id,
                    );
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
        onPressed: () {
          FirebaseFirestore.instance.collection('app-recetas-completas').add({
            'nombre': 'Nueva receta',
            'calorias': '0',
            'imagen': '',
            'tiempo': '0',
            'categoria': 'General',
          });
        },
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: const Text(
          'Nueva receta',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

// ── Tarjeta de receta ─────────────────────────────────────────
class AdminRecetaCard extends StatelessWidget {
  final Map<String, String> receta;
  final String docId;

  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);

  const AdminRecetaCard({super.key, required this.receta, required this.docId});

  @override
  Widget build(BuildContext context) {
    final img = receta['img'] ?? '';
    final nombre = receta['nombre'] ?? '';
    final calorias = receta['calorias'] ?? '0';
    final categoria = receta['categoria'] ?? '';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        //onTap: () => _editarReceta(context),
        onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DetalleRecetaScreen(
        recetaId: docId,
        nombreReceta: receta['nombre'] ?? '',
        isAdmin: true,
      ),
    ),
  );
},
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
              child: SizedBox(
                height: 90,
                width: double.infinity,
                child: img.isNotEmpty
                    ? Image.network(
                        img,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _Placeholder(),
                      )
                    : _Placeholder(),
              ),
            ),

            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (categoria.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 1,
                        ),
                        margin: const EdgeInsets.only(bottom: 3),
                        decoration: BoxDecoration(
                          color: _verdeClaro,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          categoria,
                          style: const TextStyle(
                            color: _verde,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Text(
                      nombre,
                      maxLines: 2,
overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: Color(0xFF1A1A2E),
                      ),
                      
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          color: Color(0xFFFF6B35),
                          size: 11,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '$calorias Cal',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Spacer(),
                        // Editar
                        _MiniBtn(
                          icono: Icons.edit_rounded,
                          color: _verde,
                          bg: _verdeClaro,
                          onTap: () => _editarReceta(context),
                        ),
                        const SizedBox(width: 4),
                        // Eliminar
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
        title: const Text(
          'Eliminar receta',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text('¿Eliminar "${receta['nombre']}"?'),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _editarReceta(BuildContext context) {
    final nombreCtrl = TextEditingController(text: receta['nombre']);
    final caloriasCtrl = TextEditingController(text: receta['calorias']);
    final imagenCtrl = TextEditingController(text: receta['img']);
    final tiempoCtrl = TextEditingController(text: receta['tiempo']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Editar receta',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 16),
              _Campo(
                ctrl: nombreCtrl,
                label: 'Nombre',
                icono: Icons.restaurant_menu_rounded,
              ),
              const SizedBox(height: 10),
              _Campo(
                ctrl: caloriasCtrl,
                label: 'Calorías',
                icono: Icons.local_fire_department_rounded,
                tipo: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _Campo(
                ctrl: tiempoCtrl,
                label: 'Tiempo (min)',
                icono: Icons.timer_rounded,
                tipo: TextInputType.number,
              ),
              const SizedBox(height: 10),
              _Campo(
                ctrl: imagenCtrl,
                label: 'URL de imagen',
                icono: Icons.image_rounded,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    FirebaseFirestore.instance
                        .collection('app-recetas-completas')
                        .doc(docId)
                        .update({
                          'nombre': nombreCtrl.text,
                          'calorias': caloriasCtrl.text,
                          'tiempo': tiempoCtrl.text,
                          'imagen': imagenCtrl.text,
                        });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D9E73),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Guardar cambios',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────
class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFE8F7F1),
    child: const Center(
      child: Icon(Icons.restaurant_rounded, color: Color(0xFF2D9E73), size: 28),
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
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Icon(icono, color: color, size: 13),
    ),
  );
}

class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icono;
  final TextInputType tipo;
  const _Campo({
    required this.ctrl,
    required this.label,
    required this.icono,
    this.tipo = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: tipo,
    decoration: InputDecoration(
      labelText: label,
      prefixIcon: Icon(icono, color: const Color(0xFF2D9E73), size: 18),
      filled: true,
      fillColor: const Color(0xFFF5F6FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2D9E73), width: 1.5),
      ),
      labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
  );
}
