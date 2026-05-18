import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'crear_receta_usuario_screen.dart';

class MisRecetasScreen extends StatelessWidget {
  const MisRecetasScreen({super.key});

  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  static const Color _fondo = Color(0xFFF5F6FA);

  @override
  Widget build(BuildContext context) {
    final String userId =
        FirebaseAuth.instance.currentUser?.uid ?? 'usuario_desconocido';

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
          'Mis Recetas Personales',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: Colors.white,
            ),
            tooltip: 'Copiar receta de la app',
            onPressed: () => _mostrarDialogoCopiar(context, userId),
          ),
        ],
      ),
      body: Column(
        children: [
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
                    .collection('recetas_personales')
                    .where('creador_id', isEqualTo: userId)
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
                        '$count recetas personales',
                        style: const TextStyle(
                          color: _verde,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => _mostrarDialogoCopiar(context, userId),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _verdeClaro,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.content_copy_rounded,
                                color: _verde,
                                size: 12,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'Copiar receta',
                                style: TextStyle(
                                  color: _verde,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('recetas_personales')
                  .where('creador_id', isEqualTo: userId)
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
                          'Aún no tienes recetas personales',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Crea una nueva o copia una de la app',
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
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    mainAxisExtent: 220,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    return MiRecetaCard(
                      datosCompletos: data,
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
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CrearRecetaUsuarioScreen(),
            ),
          );
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

  static void _mostrarDialogoCopiar(BuildContext context, String userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CopiarRecetaSheet(userId: userId),
    );
  }
}

// ── Bottom sheet para buscar y copiar recetas de la BD ───────────────────────

class _CopiarRecetaSheet extends StatefulWidget {
  final String userId;
  const _CopiarRecetaSheet({required this.userId});

  @override
  State<_CopiarRecetaSheet> createState() => _CopiarRecetaSheetState();
}

class _CopiarRecetaSheetState extends State<_CopiarRecetaSheet> {
  static const Color _verde = Color(0xFF2D9E73);
  final TextEditingController _buscarCtrl = TextEditingController();
  String _filtro = '';

  @override
  void dispose() {
    _buscarCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (ctx, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F6FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Copiar receta de la app',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: Color(0xFF1A1A2E),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Elige una receta para guardar una copia editable en tu perfil',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _buscarCtrl,
                    onChanged: (v) => setState(() => _filtro = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Buscar receta...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _verde,
                        size: 20,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                  var docs = snapshot.data?.docs ?? [];
                  if (_filtro.isNotEmpty) {
                    docs = docs.where((d) {
                      final nombre =
                          (d.data() as Map<String, dynamic>)['nombre']
                              ?.toString()
                              .toLowerCase() ??
                          '';
                      return nombre.contains(_filtro);
                    }).toList();
                  }
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No se encontraron recetas',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    );
                  }
                  return ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      final nombre = data['nombre']?.toString() ?? 'Sin nombre';
                      final img = data['imagen']?.toString() ?? '';
                      final categoria = data['categoria']?.toString() ?? '';
                      final calorias =
                          (data['calorias'] ?? data['calorías'])?.toString() ??
                          '0';
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        elevation: 1,
                        shadowColor: Colors.black12,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            Navigator.pop(context);
                            await _copiarReceta(context, docs[i].id, data);
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 60,
                                    height: 60,
                                    child: img.isNotEmpty
                                        ? Image.network(
                                            img,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                _PlaceholderImg(),
                                          )
                                        : _PlaceholderImg(),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        nombre,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13.5,
                                          color: Color(0xFF1A1A2E),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (categoria.isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE8F7F1),
                                                borderRadius:
                                                    BorderRadius.circular(5),
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
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.local_fire_department_rounded,
                                            size: 12,
                                            color: Colors.orange[400],
                                          ),
                                          const SizedBox(width: 2),
                                          Text(
                                            '$calorias Cal',
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
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F7F1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.content_copy_rounded,
                                    color: _verde,
                                    size: 16,
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }

  Future<void> _copiarReceta(
    BuildContext context,
    String recetaOriginalId,
    Map<String, dynamic> data,
  ) async {
    try {
      // Obtener pasos de forma robusta
      List<dynamic> pasos = [];
      try {
        final docSteps = await FirebaseFirestore.instance
            .collection('steps-recetas')
            .doc(recetaOriginalId)
            .get();
        if (docSteps.exists) {
          pasos = docSteps.data()?['pasos_ordenados'] ?? [];
        } else {
          final q = await FirebaseFirestore.instance
              .collection('steps-recetas')
              .where('receta_id', isEqualTo: recetaOriginalId)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            pasos = q.docs.first.data()['pasos_ordenados'] ?? [];
          } else {
            final q2 = await FirebaseFirestore.instance
                .collection('steps-recetas')
                .where('recetas_id', isEqualTo: recetaOriginalId)
                .limit(1)
                .get();
            if (q2.docs.isNotEmpty) {
              pasos = q2.docs.first.data()['pasos_ordenados'] ?? [];
            }
          }
        }
      } catch (e) {
        debugPrint('Error copiando pasos: $e');
      }

      // Normalizar ingredientes (cantidad como double)
      final ingredientesRaw = data['ingredientes'];
      List<dynamic> ingredientesNorm = [];
      if (ingredientesRaw is List) {
        ingredientesNorm = ingredientesRaw.map((item) {
          if (item is Map) {
            final map = Map<String, dynamic>.from(item);
            map['cantidad'] =
                double.tryParse(map['cantidad']?.toString() ?? '0') ?? 0.0;
            return map;
          }
          return item;
        }).toList();
      }

      final copia = {
        'nombre': data['nombre']?.toString() ?? '',
        'calorias':
            double.tryParse(
              (data['calorias'] ?? data['calorías'])?.toString() ?? '0',
            ) ??
            0.0,
        'tiempo': double.tryParse(data['tiempo']?.toString() ?? '0') ?? 0.0,
        'imagen': data['imagen']?.toString() ?? '',
        'categoria': data['categoria']?.toString() ?? '',
        'subcategoria': data['subcategoria']?.toString() ?? '',
        'porcion_base': data['porcion_base']?.toString() ?? '1',
        'ingredientes': ingredientesNorm,
        'pasos': pasos,
        'creador_id': widget.userId,
        'origenRecetaId': recetaOriginalId, // referencia al original
        'fechaCreacion': DateTime.now().toIso8601String(),
      };
      await FirebaseFirestore.instance
          .collection('recetas_personales')
          .add(copia);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '¡Receta "${data['nombre']}" copiada! Ya puedes editarla.',
            ),
            backgroundColor: _verde,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al copiar receta: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ── Tarjeta de receta personal ────────────────────────────────────────────────

class MiRecetaCard extends StatelessWidget {
  final Map<String, dynamic> datosCompletos;
  final String docId;

  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  const MiRecetaCard({
    super.key,
    required this.datosCompletos,
    required this.docId,
  });
  @override
  Widget build(BuildContext context) {
    final img = datosCompletos['imagen']?.toString() ?? '';
    final nombre = datosCompletos['nombre']?.toString() ?? 'Sin nombre';
    final calorias =
        (datosCompletos['calorias'] ?? datosCompletos['calorías'])
            ?.toString() ??
        '0';
    final category = datosCompletos['categoria']?.toString() ?? '';
    final esCopia = datosCompletos['origenRecetaId'] != null;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (_) => _RecetaOptionsSheet(
            nombre: nombre,
            categoria: category,
            calorias: calorias,
            docId: docId,
            datosCompletos: datosCompletos,
          ),
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
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: img.isNotEmpty
                        ? Image.network(
                            img,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _PlaceholderImg(),
                          )
                        : _PlaceholderImg(),
                  ),
                ),
                if (esCopia)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Text(
                        'Copia',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (category.isNotEmpty)
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
                          category,
                          style: const TextStyle(
                            color: _verde,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    Text(
                      nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                        color: Color(0xFF1A1A2E),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                        GestureDetector(
                          onTap: () => _confirmarEliminar(context, nombre),
                          child: Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: const Icon(
                              Icons.delete_rounded,
                              color: Color(0xFFE53935),
                              size: 13,
                            ),
                          ),
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

  void _confirmarEliminar(BuildContext context, String nombreReceta) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Eliminar receta',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text('¿Eliminar "$nombreReceta"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('recetas_personales')
                  .doc(docId)
                  .delete();
              if (context.mounted) Navigator.pop(context);
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
}

class _PlaceholderImg extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFE8F7F1),
    child: const Center(
      child: Icon(Icons.restaurant_rounded, color: Color(0xFF2D9E73), size: 28),
    ),
  );
}

// ── Bottom sheet de opciones ──────────────────────────────────────────────────

class _RecetaOptionsSheet extends StatelessWidget {
  final String nombre;
  final String categoria;
  final String calorias;
  final String docId;
  final Map<String, dynamic> datosCompletos;

  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);

  const _RecetaOptionsSheet({
    required this.nombre,
    required this.categoria,
    required this.calorias,
    required this.docId,
    required this.datosCompletos,
  });
  @override
  Widget build(BuildContext context) {
    final String img = datosCompletos['imagen']?.toString() ?? '';
    final String tiempo = datosCompletos['tiempo']?.toString() ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.45,
      maxChildSize: 0.75,
      expand: false,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: SingleChildScrollView(
          controller: scrollCtrl,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 60,
                      height: 60,
                      child: img.isNotEmpty
                          ? Image.network(
                              img,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _PlaceholderImg(),
                            )
                          : _PlaceholderImg(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          nombre,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1A1A2E),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            if (categoria.isNotEmpty) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _verdeClaro,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  categoria,
                                  style: const TextStyle(
                                    color: _verde,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            const Icon(
                              Icons.local_fire_department_rounded,
                              size: 13,
                              color: Color(0xFFFF6B35),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$calorias Cal',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[500],
                              ),
                            ),
                            if (tiempo.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.access_time_rounded,
                                size: 13,
                                color: Colors.grey,
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
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => _VistaRecetaPersonal(
                              datosCompletos: datosCompletos,
                              docId: docId,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: _verde,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 26,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Ver receta',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Ingredientes y pasos',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.75),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CrearRecetaUsuarioScreen(
                              docId: docId,
                              datosIniciales: datosCompletos,
                              soloLectura: false,
                              coleccion: 'recetas_personales',
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE8E8E8)),
                        ),
                        child: Column(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFFE8E8E8),
                                ),
                              ),
                              child: const Icon(
                                Icons.edit_rounded,
                                color: Color(0xFF1A1A2E),
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Editar',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1A1A2E),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Modificar campos',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Vista de receta personal (detalle + pasos embebidos) ──────────────────────
// AHORA ES STATEFUL Y CARGA NOMBRES DE INGREDIENTES Y PASOS FALTANTES

// ── Helper: formatea cantidades numéricas a fracciones legibles ──────────────
String _formatCantidad(dynamic valor) {
  if (valor == null) return '';
  final d = double.tryParse(valor.toString());
  if (d == null) return valor.toString();
  // Parte entera
  final entero = d.truncate();
  final decimal = d - entero;
  const eps = 0.01;
  String fraccion = '';
  if ((decimal - 0.25).abs() < eps)
    fraccion = '¼';
  else if ((decimal - 0.5).abs() < eps)
    fraccion = '½';
  else if ((decimal - 0.75).abs() < eps)
    fraccion = '¾';
  else if ((decimal - 0.333).abs() < eps)
    fraccion = '⅓';
  else if ((decimal - 0.667).abs() < eps)
    fraccion = '⅔';
  else if (decimal > eps)
    fraccion = d
        .toStringAsFixed(2)
        .replaceAll(RegExp(r'0+$'), '')
        .replaceAll(RegExp(r'\.$'), '');
  if (entero == 0 && fraccion.isNotEmpty) return fraccion;
  if (fraccion.isEmpty) return entero.toString();
  return '$entero $fraccion';
}

class _VistaRecetaPersonal extends StatefulWidget {
  final Map<String, dynamic> datosCompletos;
  final String docId;
  const _VistaRecetaPersonal({
    required this.datosCompletos,
    required this.docId,
  });

  @override
  State<_VistaRecetaPersonal> createState() => _VistaRecetaPersonalState();
}

class _VistaRecetaPersonalState extends State<_VistaRecetaPersonal> {
  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  static const Color _fondo = Color(0xFFF5F6FA);

  List<Map<String, dynamic>> _ingredientesResueltos = [];
  List<dynamic> _pasos = [];
  bool _cargando = true;
  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    // 1. Resolver nombres de ingredientes
    final ingredientesRaw =
        (widget.datosCompletos['ingredientes'] as List<dynamic>?) ?? [];
    List<Map<String, dynamic>> resolviendo = [];

    for (var item in ingredientesRaw) {
      final map = item is Map
          ? Map<String, dynamic>.from(item)
          : <String, dynamic>{};
      final id = map['ingrediente_id']?.toString() ?? '';
      final nombreOriginal = map['nombre']?.toString() ?? '';
      if (nombreOriginal.isNotEmpty) {
        resolviendo.add(map);
      } else if (id.isNotEmpty) {
        String nombreResuelto = '';
        try {
          final doc = await FirebaseFirestore.instance
              .collection('ingredientes_maestros')
              .doc(id)
              .get();
          if (doc.exists) {
            nombreResuelto = doc.data()?['nombre']?.toString() ?? '';
          }
        } catch (_) {}
        if (nombreResuelto.isEmpty) {
          // Fallback: transformar ID en texto legible (ej: "lomo-res" -> "Lomo Res")
          nombreResuelto = id
              .split('-')
              .map(
                (w) => w.isNotEmpty ? w[0].toUpperCase() + w.substring(1) : '',
              )
              .join(' ');
        }
        map['nombre'] = nombreResuelto;
        resolviendo.add(map);
      } else {
        resolviendo.add(map);
      }
    }

    // 2. Cargar pasos si no vienen en el documento
    List<dynamic> pasosTemp =
        (widget.datosCompletos['pasos'] as List<dynamic>?) ?? [];

    if (pasosTemp.isEmpty) {
      // Intentar obtener pasos desde steps-recetas
      try {
        // Buscar por docId actual (puede que los pasos estén asociados al ID de la receta personal)
        final docSteps = await FirebaseFirestore.instance
            .collection('steps-recetas')
            .doc(widget.docId)
            .get();
        if (docSteps.exists) {
          pasosTemp = docSteps.data()?['pasos_ordenados'] ?? [];
        } else {
          // Si no, buscar por el campo receta_id usando origenRecetaId
          final origenId = widget.datosCompletos['origenRecetaId']?.toString();
          if (origenId != null && origenId.isNotEmpty) {
            final q = await FirebaseFirestore.instance
                .collection('steps-recetas')
                .where('receta_id', isEqualTo: origenId)
                .limit(1)
                .get();
            if (q.docs.isNotEmpty) {
              pasosTemp = q.docs.first.data()['pasos_ordenados'] ?? [];
            } else {
              final q2 = await FirebaseFirestore.instance
                  .collection('steps-recetas')
                  .where('recetas_id', isEqualTo: origenId)
                  .limit(1)
                  .get();
              if (q2.docs.isNotEmpty) {
                pasosTemp = q2.docs.first.data()['pasos_ordenados'] ?? [];
              }
            }
          }
        }
      } catch (_) {}
    }

    setState(() {
      _ingredientesResueltos = resolviendo;
      _pasos = pasosTemp;
      _cargando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.datosCompletos['nombre']?.toString() ?? 'Sin nombre';
    final img = widget.datosCompletos['imagen']?.toString() ?? '';
    final calorias =
        (widget.datosCompletos['calorias'] ?? widget.datosCompletos['calorías'])
            ?.toString() ??
        '0';
    final tiempo = widget.datosCompletos['tiempo']?.toString() ?? '0';
    final categoria = widget.datosCompletos['categoria']?.toString() ?? '';

    return Scaffold(
      backgroundColor: _fondo,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            backgroundColor: _verde,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                nombre,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: img.isNotEmpty
                  ? Image.network(
                      img,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: _verde,
                        child: const Icon(
                          Icons.restaurant_rounded,
                          color: Colors.white54,
                          size: 60,
                        ),
                      ),
                    )
                  : Container(
                      color: _verde,
                      child: const Icon(
                        Icons.restaurant_rounded,
                        color: Colors.white54,
                        size: 60,
                      ),
                    ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _cargando
                  ? const Center(
                      child: CircularProgressIndicator(color: _verde),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (categoria.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _verdeClaro,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  categoria,
                                  style: const TextStyle(
                                    color: _verde,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.local_fire_department_rounded,
                              color: Color(0xFFFF6B35),
                              size: 15,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$calorias Cal',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Icon(
                              Icons.access_time_rounded,
                              color: Colors.grey,
                              size: 15,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$tiempo min',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 22),
                        if (_ingredientesResueltos.isNotEmpty) ...[
                          const Text(
                            'Ingredientes',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._ingredientesResueltos.map((map) {
                            final ingNombre =
                                map['nombre']?.toString() ??
                                map['ingrediente_id']?.toString() ??
                                'Ingrediente';
                            final cantidad = _formatCantidad(map['cantidad']);
                            final unidad = map['unidad']?.toString() ?? '';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: _verde,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  if (cantidad.isNotEmpty ||
                                      unidad.isNotEmpty) ...[
                                    Text(
                                      '$cantidad $unidad'.trim(),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[500],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Expanded(
                                    child: Text(
                                      ingNombre,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF1A1A2E),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const SizedBox(height: 22),
                        ],
                        if (_pasos.isNotEmpty) ...[
                          const Text(
                            'Preparación',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          const SizedBox(height: 10),
                          ..._pasos.asMap().entries.map((entry) {
                            final i = entry.key;
                            final paso = entry.value;
                            final instruccion =
                                (paso is Map ? paso['instruccion'] : paso)
                                    ?.toString() ??
                                '';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: const BoxDecoration(
                                      color: _verde,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${i + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        instruccion,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF1A1A2E),
                                          height: 1.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ] else
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Text(
                                'Esta receta no tiene pasos aún.',
                                style: TextStyle(
                                  color: Colors.grey[400],
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 32),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
