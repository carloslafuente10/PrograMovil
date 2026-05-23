import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AdminRecetasPendientesScreen extends StatelessWidget {
  const AdminRecetasPendientesScreen({super.key});

  static const Color _verde = Color(0xFF2D9E73);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _verde,
        elevation: 0,
        title: const Text('Recetas por aprobar',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('recetas-pendientes')
            .where('estado', isEqualTo: 'pendiente')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _verde));
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox_rounded, size: 60, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('No hay recetas pendientes',
                      style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              final nombre = data['nombre'] ?? 'Sin título';
              final usuario = data['usuarioEmail'] ?? data['usuarioId'] ?? 'Usuario';
              final fecha = data['fechaEnvio'] != null
                  ? (data['fechaEnvio'] as Timestamp).toDate()
                  : DateTime.now();
              final ingsCount = (data['ingredientes'] as List?)?.length ?? 0;
              final pasosCount = (data['pasos'] as List?)?.length ?? 0;

              return Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _mostrarDetalle(context, docs[i].id, data),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(nombre,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(20)),
                              child: Text('Pendiente',
                                  style: TextStyle(
                                      color: Colors.orange[800], fontSize: 11)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(usuario,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text('${fecha.day}/${fecha.month}/${fecha.year}',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            const SizedBox(width: 12),
                            Icon(Icons.egg_alt_outlined, size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text('$ingsCount ing.',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                            const SizedBox(width: 12),
                            Icon(Icons.format_list_numbered_rounded,
                                size: 12, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text('$pasosCount pasos',
                                style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                          ],
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
    );
  }

  void _mostrarDetalle(
      BuildContext context, String docId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetallePendienteSheet(
        docId: docId,
        receta: data,
        onAprobar: () => _aprobarReceta(context, docId, data),
        onRechazar: () => _rechazarReceta(context, docId, data),
      ),
    );
  }

  Future<void> _aprobarReceta(BuildContext context, String docId,
      Map<String, dynamic> data) async {
    try {
      // 1. Publicar en app-recetas-completas
      final recetaParaPublicar = Map<String, dynamic>.from(data);
      recetaParaPublicar.remove('estado');
      recetaParaPublicar.remove('fechaEnvio');
      recetaParaPublicar.remove('usuarioId');
      recetaParaPublicar.remove('usuarioEmail');
      recetaParaPublicar.remove('origenPersonalDocId');
      recetaParaPublicar['fechaCreacion'] = DateTime.now().toIso8601String();
      recetaParaPublicar['aprobadaPor'] =
          FirebaseAuth.instance.currentUser?.email ?? 'admin';

      await FirebaseFirestore.instance
          .collection('app-recetas-completas')
          .add(recetaParaPublicar);

      // 2. Marcar pendiente como aprobada
      await FirebaseFirestore.instance
          .collection('recetas-pendientes')
          .doc(docId)
          .update({
        'estado': 'aprobada',
        'fechaAprobacion': FieldValue.serverTimestamp(),
      });

      // 3. ✅ Actualizar recetas_personales del usuario con estado publicada
      final origenId = data['origenPersonalDocId'] as String?;
      if (origenId != null && origenId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('recetas_personales')
            .doc(origenId)
            .update({'estado': 'publicada'});
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Receta aprobada y publicada'),
          backgroundColor: _verde,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al aprobar: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _rechazarReceta(BuildContext context, String docId,
      Map<String, dynamic> data) async {
    try {
      await FirebaseFirestore.instance
          .collection('recetas-pendientes')
          .doc(docId)
          .update({'estado': 'rechazada'});

      // ✅ Devolver a recetas_personales con estado rechazada para que pueda editar
      final origenId = data['origenPersonalDocId'] as String?;
      if (origenId != null && origenId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('recetas_personales')
            .doc(origenId)
            .update({'estado': 'rechazada'});
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Receta rechazada'),
          backgroundColor: Colors.red,
        ));
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al rechazar: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

// ═══════════════════════════════════════════════════
//  BOTTOM SHEET DE DETALLE
// ═══════════════════════════════════════════════════
class _DetallePendienteSheet extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> receta;
  final VoidCallback onAprobar;
  final VoidCallback onRechazar;

  const _DetallePendienteSheet({
    required this.docId,
    required this.receta,
    required this.onAprobar,
    required this.onRechazar,
  });

  static const Color _verde = Color(0xFF2D9E73);

  @override
  Widget build(BuildContext context) {
    final nombre = receta['nombre'] ?? 'Sin título';
    final ingredientes = receta['ingredientes'] as List? ?? [];
    final pasos = receta['pasos'] as List? ?? [];
    final calorias = receta['calorias']?.toString() ?? '0';
    final tiempo = receta['tiempo']?.toString() ?? '0';
    final categoria = receta['categoria'] ?? '';
    final imgUrl = receta['imagen'] ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),

            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen header
                    if (imgUrl.startsWith('http'))
                      SizedBox(
                        height: 180,
                        width: double.infinity,
                        child: Image.network(imgUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Nombre y categoria
                          if (categoria.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F7F1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(categoria,
                                  style: const TextStyle(
                                      color: _verde,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            ),
                          Text(nombre,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),

                          // Stats rápidos
                          Row(
                            children: [
                              _Stat(Icons.local_fire_department_rounded,
                                  '$calorias cal', const Color(0xFFFF6B35)),
                              const SizedBox(width: 16),
                              _Stat(Icons.timer_outlined, '${tiempo} min', _verde),
                              const SizedBox(width: 16),
                              _Stat(Icons.egg_alt_outlined,
                                  '${ingredientes.length} ing.', Colors.blue),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Ingredientes
                          const Text('Ingredientes',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          ...ingredientes.map((i) {
                            final imgIng = i['imagen']?.toString() ?? '';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: SizedBox(
                                      width: 36,
                                      height: 36,
                                      child: imgIng.startsWith('http')
                                          ? Image.network(imgIng,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  _IngPlaceholder())
                                          : _IngPlaceholder(),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                        i['nombre'] ?? i['ingrediente_id'] ?? '',
                                        style: const TextStyle(fontSize: 13)),
                                  ),
                                  Text(
                                      '${i['cantidad']} ${i['unidad']}',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            );
                          }),

                          const SizedBox(height: 20),
                          const Text('Preparación',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          ...pasos.asMap().entries.map((e) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 26,
                                      height: 26,
                                      decoration: const BoxDecoration(
                                          color: _verde, shape: BoxShape.circle),
                                      child: Center(
                                        child: Text('${e.key + 1}',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(e.value['instruccion'] ?? '',
                                          style: const TextStyle(
                                              fontSize: 13, height: 1.5)),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Botones acción
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onRechazar,
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      label: const Text('Rechazar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onAprobar,
                      icon: const Icon(Icons.check_rounded, color: Colors.white),
                      label: const Text('Aprobar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _verde,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Stat(this.icon, this.label, this.color);

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
        ],
      );
}

class _IngPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFE8F7F1),
        child: const Icon(Icons.egg_alt_rounded,
            color: Color(0xFF2D9E73), size: 18),
      );
}
