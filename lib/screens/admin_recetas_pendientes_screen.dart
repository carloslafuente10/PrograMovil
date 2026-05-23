import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../servicios/notificaciones_servicio.dart';
import 'components/notificacion_campana.dart';

class AdminRecetasPendientesScreen extends StatefulWidget {
  const AdminRecetasPendientesScreen({super.key});

  @override
  State<AdminRecetasPendientesScreen> createState() =>
      _AdminRecetasPendientesScreenState();
}

class _AdminRecetasPendientesScreenState
    extends State<AdminRecetasPendientesScreen>
    with SingleTickerProviderStateMixin {
  static const Color _verde = Color(0xFF2D9E73);
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: _verde,
        elevation: 0,
        title: const Text('Recetas por revisar',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: const [
          NotificacionCampana(esAdmin: true),
          SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Pendientes'),
            Tab(text: 'Aprobadas'),
            Tab(text: 'Rechazadas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ListaRecetas(estado: 'pendiente', color: Colors.orange),
          _ListaRecetas(estado: 'aprobada', color: _verde),
          _ListaRecetas(estado: 'rechazada', color: Colors.red),
        ],
      ),
    );
  }
}

class _ListaRecetas extends StatelessWidget {
  final String estado;
  final Color color;
  static const Color _verde = Color(0xFF2D9E73);

  const _ListaRecetas({required this.estado, required this.color});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recetas-pendientes')
          .where('estado', isEqualTo: estado)
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
                Text('No hay recetas $estado',
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
            final nombre     = data['nombre'] ?? 'Sin título';
            final usuario    = data['usuarioEmail'] ?? data['usuarioId'] ?? 'Usuario';
            final fecha      = data['fechaEnvio'] != null
                ? (data['fechaEnvio'] as Timestamp).toDate()
                : DateTime.now();
            final ingsCount  = (data['ingredientes'] as List?)?.length ?? 0;
            final pasosCount = (data['pasos'] as List?)?.length ?? 0;

            return Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: estado == 'pendiente'
                    ? () => _mostrarDetalle(context, docs[i].id, data)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(nombre,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                              color: color.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(20)),
                          child: Text(
                            estado == 'pendiente' ? 'Pendiente'
                                : estado == 'aprobada' ? 'Aprobada' : 'Rechazada',
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        Icon(Icons.person_outline, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(child: Text(usuario,
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            overflow: TextOverflow.ellipsis)),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
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
                        Icon(Icons.format_list_numbered_rounded, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Text('$pasosCount pasos',
                            style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ]),
                      if (estado == 'rechazada' && data['motivoRechazo'] != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                          child: Row(children: [
                            const Icon(Icons.info_outline_rounded, color: Colors.red, size: 13),
                            const SizedBox(width: 6),
                            Expanded(child: Text(data['motivoRechazo'],
                                style: const TextStyle(fontSize: 11, color: Colors.red))),
                          ]),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _mostrarDetalle(BuildContext context, String docId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _DetallePendienteSheet(
        docId: docId,
        receta: data,
        sheetContext: sheetCtx,
      ),
    );
  }
}

class _DetallePendienteSheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> receta;
  final BuildContext sheetContext;

  const _DetallePendienteSheet({
    required this.docId,
    required this.receta,
    required this.sheetContext,
  });

  @override
  State<_DetallePendienteSheet> createState() => _DetallePendienteSheetState();
}

class _DetallePendienteSheetState extends State<_DetallePendienteSheet> {
  static const Color _verde = Color(0xFF2D9E73);
  bool _procesando = false;

  // ✅ FIX Bug 4: marcar como leída la notificación del admin asociada
  // a este recipeId para que el contador baje al atender la receta
  Future<void> _marcarNotifLeidaPorRecipeId(String recipeId) async {
    try {
      final adminEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      if (adminEmail.isEmpty) return;
      final snap = await FirebaseFirestore.instance
          .collection('notifications')
          .where('adminEmail', isEqualTo: adminEmail)
          .where('recipeId', isEqualTo: recipeId)
          .where('read', isEqualTo: false)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final nombre       = widget.receta['nombre'] ?? 'Sin título';
    final ingredientes = widget.receta['ingredientes'] as List? ?? [];
    final pasos        = widget.receta['pasos'] as List? ?? [];
    final calorias     = widget.receta['calorias']?.toString() ?? '0';
    final tiempo       = widget.receta['tiempo']?.toString() ?? '0';
    final categoria    = widget.receta['categoria'] ?? '';
    final imgUrl       = widget.receta['imagen'] ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.92, minChildSize: 0.5, maxChildSize: 0.96,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (imgUrl.startsWith('http'))
                      SizedBox(height: 180, width: double.infinity,
                          child: Image.network(imgUrl, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox.shrink())),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (categoria.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              margin: const EdgeInsets.only(bottom: 6),
                              decoration: BoxDecoration(
                                  color: const Color(0xFFE8F7F1),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Text(categoria,
                                  style: const TextStyle(color: _verde, fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                          Text(nombre,
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          Row(children: [
                            _Stat(Icons.local_fire_department_rounded, '$calorias cal', const Color(0xFFFF6B35)),
                            const SizedBox(width: 16),
                            _Stat(Icons.timer_outlined, '$tiempo min', _verde),
                            const SizedBox(width: 16),
                            _Stat(Icons.egg_alt_outlined, '${ingredientes.length} ing.', Colors.blue),
                          ]),
                          const SizedBox(height: 20),
                          const Text('Ingredientes',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          ...ingredientes.map((i) {
                            final imgIng = i['imagen']?.toString() ?? '';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 5),
                              child: Row(children: [
                                ClipRRect(borderRadius: BorderRadius.circular(8),
                                  child: SizedBox(width: 36, height: 36,
                                    child: imgIng.startsWith('http')
                                        ? Image.network(imgIng, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _IngPlaceholder())
                                        : _IngPlaceholder())),
                                const SizedBox(width: 10),
                                Expanded(child: Text(i['nombre'] ?? i['ingrediente_id'] ?? '',
                                    style: const TextStyle(fontSize: 13))),
                                Text('${i['cantidad']} ${i['unidad']}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600],
                                        fontWeight: FontWeight.w500)),
                              ]),
                            );
                          }),
                          const SizedBox(height: 20),
                          const Text('Preparación',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),
                          ...pasos.asMap().entries.map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Container(width: 26, height: 26,
                                decoration: const BoxDecoration(color: _verde, shape: BoxShape.circle),
                                child: Center(child: Text('${e.key + 1}',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)))),
                              const SizedBox(width: 10),
                              Expanded(child: Text(e.value['instruccion'] ?? '',
                                  style: const TextStyle(fontSize: 13, height: 1.5))),
                            ]),
                          )),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _procesando ? null : () => _mostrarDialogoRechazo(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      label: const Text('Rechazar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _procesando ? Colors.grey : Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _procesando ? null : () => _aprobarReceta(context),
                      icon: _procesando
                          ? const SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check_rounded, color: Colors.white),
                      label: Text(_procesando ? 'Aprobando...' : 'Aprobar'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _procesando ? Colors.grey : _verde,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  Future<void> _aprobarReceta(BuildContext context) async {
    if (_procesando) return;
    setState(() => _procesando = true);
    try {
      final recetaParaPublicar = Map<String, dynamic>.from(widget.receta);
      for (final k in ['estado','fechaEnvio','usuarioId','usuarioEmail','origenPersonalDocId','motivoRechazo']) {
        recetaParaPublicar.remove(k);
      }
      recetaParaPublicar['fechaCreacion'] = DateTime.now().toIso8601String();
      recetaParaPublicar['aprobadaPor'] = FirebaseAuth.instance.currentUser?.email ?? 'admin';

      await FirebaseFirestore.instance.collection('app-recetas-completas').add(recetaParaPublicar);

      await FirebaseFirestore.instance
          .collection('recetas-pendientes').doc(widget.docId)
          .update({'estado': 'aprobada', 'fechaAprobacion': FieldValue.serverTimestamp()});

      final origenId = widget.receta['origenPersonalDocId'] as String?;
      if (origenId != null && origenId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('recetas_personales').doc(origenId)
            .update({
              'estado':         'publicada',
              'estadoRevision': 'aprobada',
            });
      }

      final userId = widget.receta['usuarioId'] as String?;
      if (userId != null && userId.isNotEmpty) {
        await NotificacionesServicio.notificarUsuarioAprobada(
          userId: userId, recipeId: widget.docId, recipeName: widget.receta['nombre'] ?? '');
      }

      // ✅ FIX Bug 4: marcar notif del admin como leída al aprobar
      await _marcarNotifLeidaPorRecipeId(widget.docId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('✅ Receta aprobada y publicada'), backgroundColor: _verde));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  void _mostrarDialogoRechazo(BuildContext context) {
    if (_procesando) return;
    final motivoCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(children: [
          Icon(Icons.cancel_rounded, color: Color(0xFFE53935)),
          SizedBox(width: 8),
          Text('Rechazar receta', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${widget.receta['nombre'] ?? ''}"',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            const SizedBox(height: 12),
            const Text('Motivo del rechazo (obligatorio):',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[300]!)),
              child: TextField(
                controller: motivoCtrl, maxLines: 3,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Ej: Faltan pasos, imagen no válida...',
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                  border: InputBorder.none, contentPadding: EdgeInsets.all(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[600]))),
          ElevatedButton(
            onPressed: () {
              final motivo = motivoCtrl.text.trim();
              if (motivo.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Escribe un motivo'), backgroundColor: Colors.red));
                return;
              }
              Navigator.pop(context);
              _rechazarReceta(context, motivo);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Rechazar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _rechazarReceta(BuildContext context, String motivo) async {
    if (_procesando) return;
    setState(() => _procesando = true);
    try {
      await FirebaseFirestore.instance
          .collection('recetas-pendientes').doc(widget.docId)
          .update({'estado': 'rechazada', 'motivoRechazo': motivo,
              'fechaRechazo': FieldValue.serverTimestamp()});

      final origenId = widget.receta['origenPersonalDocId'] as String?;
      if (origenId != null && origenId.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('recetas_personales').doc(origenId)
            .update({
              'estado':         'rechazada',
              'estadoRevision': 'rechazada',
              'motivoRechazo':  motivo,
            });
      }

      final userId = widget.receta['usuarioId'] as String?;
      if (userId != null && userId.isNotEmpty) {
        await NotificacionesServicio.notificarUsuarioRechazada(
          userId:              userId,
          recipeId:            widget.docId,
          recipeName:          widget.receta['nombre'] ?? '',
          motivo:              motivo,
          origenPersonalDocId: origenId,
        );
      }

      // ✅ FIX Bug 4: marcar notif del admin como leída al rechazar
      await _marcarNotifLeidaPorRecipeId(widget.docId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Receta rechazada'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _procesando = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

class _Stat extends StatelessWidget {
  final IconData icon; final String label; final Color color;
  const _Stat(this.icon, this.label, this.color);
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: color, size: 14), const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
  ]);
}

class _IngPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFE8F7F1),
    child: const Icon(Icons.egg_alt_rounded, color: Color(0xFF2D9E73), size: 18));
}