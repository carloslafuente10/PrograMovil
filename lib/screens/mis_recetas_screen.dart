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
        // Botón para copiar desde la BD de administrador
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
                    .collection('recetas_personales')
                    .where('usuarioId', isEqualTo: userId)
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
                      // Botón de copiar visible también aquí
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

          // Grid de recetas personales del usuario
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('recetas_personales')
                  .where('usuarioId', isEqualTo: userId)
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
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    mainAxisExtent: 185,
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

  /// Muestra un diálogo con todas las recetas del admin para copiar una
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
            // Handle
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
                            Navigator.pop(context); // cierra el sheet
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

  /// Copia la receta de app-recetas-completas a recetas_personales del usuario
  Future<void> _copiarReceta(
    BuildContext context,
    String recetaOriginalId,
    Map<String, dynamic> data,
  ) async {
    try {
      // También intentamos copiar los pasos
      List<dynamic> pasos = [];
      try {
        final stepsDoc = await FirebaseFirestore.instance
            .collection('steps-recetas')
            .doc(recetaOriginalId)
            .get();
        if (stepsDoc.exists) {
          pasos = stepsDoc.data()?['pasos_ordenados'] ?? [];
        } else {
          final q = await FirebaseFirestore.instance
              .collection('steps-recetas')
              .where('receta_id', isEqualTo: recetaOriginalId)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            pasos = q.docs.first.data()['pasos_ordenados'] ?? [];
          }
        }
      } catch (_) {}

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
        'usuarioId': widget.userId,
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
            backgroundColor: const Color(0xFF2D9E73),
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
    final categoria = datosCompletos['categoria']?.toString() ?? '';
    final esCopia = datosCompletos['origenRecetaId'] != null;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          // Abre en modo EDICIÓN (no solo lectura)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CrearRecetaUsuarioScreen(
                docId: docId,
                datosIniciales: datosCompletos,
                soloLectura: false, // siempre editable
                coleccion: 'recetas_personales', // colección propia
              ),
            ),
          );
        },
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
                  child: SizedBox(
                    height: 90,
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
                // Badge "copia"
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
