import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'crear_receta_usuario_screen.dart';
import 'detalle_receta_screen.dart';

class MisRecetasScreen extends StatelessWidget {
  const MisRecetasScreen({super.key});

  static const Color _verde = Color(0xFF2D9E73);
  static const Color _fondo = Color(0xFFF5F6FA);

  static const _estados = {
    'borrador':    (Color(0xFFFFF3CD), Color(0xFF856404), Icons.edit_note_rounded,        'Borrador'),
    'en_revision': (Color(0xFFE8F4FD), Color(0xFF0D6EFD), Icons.hourglass_top_rounded,   'En revisión'),
    'publicada':   (Color(0xFFD1FAE5), Color(0xFF065F46), Icons.check_circle_rounded,     'Publicada'),
    'rechazada':   (Color(0xFFFFE4E6), Color(0xFF9F1239), Icons.cancel_rounded,           'Rechazada'),
  };

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

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
          'Mis Recetas Personales',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          // Botón copiar desde la BD
          IconButton(
            icon: const Icon(Icons.copy_all_rounded, color: Colors.white),
            tooltip: 'Copiar receta',
            onPressed: () => _abrirBuscadorRecetasDB(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Subheader
          Container(
            color: _verde,
            child: Container(
              decoration: const BoxDecoration(
                color: _fondo,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('recetas_personales')
                    .where('usuarioId', isEqualTo: uid)
                    .snapshots(),
                builder: (context, snap) {
                  final docs = snap.data?.docs ?? [];
                  final total      = docs.length;
                  final borradores = docs.where((d) => (d.data() as Map)['estado'] == 'borrador').length;
                  final publicadas = docs.where((d) => (d.data() as Map)['estado'] == 'publicada').length;
                  final rechazadas = docs.where((d) => (d.data() as Map)['estado'] == 'rechazada').length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.menu_book_rounded, size: 16, color: _verde),
                          const SizedBox(width: 6),
                          Text(
                            '$total receta${total != 1 ? 's' : ''} personal${total != 1 ? 'es' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF1A1A2E)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (borradores > 0)
                            _ContadorChip('$borradores', 'Borrador${borradores != 1 ? 'es' : ''}', const Color(0xFFF59E0B)),
                          if (publicadas > 0)
                            _ContadorChip('$publicadas', 'Publicada${publicadas != 1 ? 's' : ''}', _verde),
                          if (rechazadas > 0)
                            _ContadorChip('$rechazadas', 'Rechazada${rechazadas != 1 ? 's' : ''}', const Color(0xFFE53935)),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // Lista
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('recetas_personales')
                  .where('usuarioId', isEqualTo: uid)
                  .orderBy('fechaCreacion', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: _verde));
                }
                if (snap.hasError) {
                  // Fallback sin orderBy si el índice no existe
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('recetas_personales')
                        .where('usuarioId', isEqualTo: uid)
                        .snapshots(),
                    builder: (ctx2, snap2) {
                      final docs = snap2.data?.docs ?? [];
                      if (docs.isEmpty) return _EmptyState();
                      return _ListaRecetas(docs: docs, estados: _estados);
                    },
                  );
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return _EmptyState();
                return _ListaRecetas(docs: docs, estados: _estados);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _verde,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CrearRecetaUsuarioScreen()),
        ),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nueva receta',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Buscador de recetas de la BD para copiar ──────────────────────────────
  void _abrirBuscadorRecetasDB(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BuscadorRecetasDBSheet(),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.menu_book_rounded, size: 60, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Aún no tienes recetas',
                style: TextStyle(color: Colors.grey[500], fontSize: 15)),
            const SizedBox(height: 6),
            Text('Toca + para crear tu primera receta',
                style: TextStyle(color: Colors.grey[400], fontSize: 12)),
          ],
        ),
      );
}

// ─── Lista de recetas ─────────────────────────────────────────────────────────
class _ListaRecetas extends StatelessWidget {
  final List<QueryDocumentSnapshot> docs;
  final Map<String, dynamic> estados;

  const _ListaRecetas({required this.docs, required this.estados});

  @override
  Widget build(BuildContext context) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.82,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: docs.length,
        itemBuilder: (ctx, i) {
          final data = docs[i].data() as Map<String, dynamic>;
          return _RecetaPersonalCard(
            docId: docs[i].id,
            data: data,
            estados: estados,
          );
        },
      );
}

// ─── Contador chip ────────────────────────────────────────────────────────────
class _ContadorChip extends StatelessWidget {
  final String count;
  final String label;
  final Color color;

  const _ContadorChip(this.count, this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(count,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      );
}

// ─── Card de receta personal (grid) ──────────────────────────────────────────
class _RecetaPersonalCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Map<String, dynamic> estados;

  static const Color _verde = Color(0xFF2D9E73);

  const _RecetaPersonalCard({
    required this.docId,
    required this.data,
    required this.estados,
  });

  @override
  Widget build(BuildContext context) {
    final nombre    = data['nombre'] ?? 'Sin título';
    final estado    = data['estado'] ?? 'borrador';
    final img       = data['imagen'] ?? '';
    final calorias  = data['calorias']?.toString() ?? '0';
    final categoria = data['categoria'] ?? '';

    final estadoConfig = estados[estado] as (Color, Color, IconData, String)?;
    final bgColor = estadoConfig?.$1 ?? const Color(0xFFF3F4F6);
    final txtColor = estadoConfig?.$2 ?? Colors.grey;
    final icon    = estadoConfig?.$3 ?? Icons.circle;
    final label   = estadoConfig?.$4 ?? estado;

    // Mostrar badge "Copia" si viene copiada
    final esCopia = data['copiadaDe'] != null;

    return GestureDetector(
      onTap: () => _mostrarOpciones(context),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: img.startsWith('http')
                        ? Image.network(img,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _ImgPlaceholder())
                        : _ImgPlaceholder(),
                  ),
                  if (esCopia)
                    Positioned(
                      top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('Copia', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  // Badge estado arriba derecha
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                      child: Icon(icon, color: txtColor, size: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (categoria.isNotEmpty)
                    Text(categoria,
                        style: const TextStyle(color: _verde, fontSize: 9, fontWeight: FontWeight.w700)),
                  Text(nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF6B35), size: 11),
                      const SizedBox(width: 2),
                      Text('$calorias cal', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarOpciones(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _OpcionesRecetaSheet(
        docId: docId,
        data: data,
        estados: estados,
      ),
    );
  }
}

class _ImgPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFE8F7F1),
        child: const Center(
          child: Icon(Icons.restaurant_rounded, color: Color(0xFF2D9E73), size: 28),
        ),
      );
}

// ═══════════════════════════════════════════════════
//  BOTTOM SHEET DE OPCIONES
// ═══════════════════════════════════════════════════
class _OpcionesRecetaSheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Map<String, dynamic> estados;

  const _OpcionesRecetaSheet({
    required this.docId,
    required this.data,
    required this.estados,
  });

  @override
  State<_OpcionesRecetaSheet> createState() => _OpcionesRecetaSheetState();
}

class _OpcionesRecetaSheetState extends State<_OpcionesRecetaSheet> {
  static const Color _verde = Color(0xFF2D9E73);

  bool _eliminando = false;

  String get _estado => widget.data['estado'] ?? 'borrador';
  bool get _puedeEditar  => _estado == 'borrador' || _estado == 'rechazada';
  bool get _puedeReenviar => _estado == 'rechazada';

  @override
  Widget build(BuildContext context) {
    final nombre    = widget.data['nombre'] ?? 'Sin título';
    final img       = widget.data['imagen'] ?? '';
    final calorias  = widget.data['calorias']?.toString() ?? '0';
    final categoria = widget.data['categoria'] ?? '';
    final tiempo    = widget.data['tiempo']?.toString() ?? '0';

    final estadoConfig = widget.estados[_estado] as (Color, Color, IconData, String)?;
    final bgColor = estadoConfig?.$1 ?? const Color(0xFFF3F4F6);
    final txtColor = estadoConfig?.$2 ?? Colors.grey;
    final iconEstado = estadoConfig?.$3 ?? Icons.circle;
    final label   = estadoConfig?.$4 ?? _estado;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),

          // Info de la receta
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64, height: 64,
                  child: img.startsWith('http')
                      ? Image.network(img, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _ImgPlaceholder())
                      : _ImgPlaceholder(),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (categoria.isNotEmpty)
                      Text(categoria, style: const TextStyle(color: _verde, fontSize: 10, fontWeight: FontWeight.w700)),
                    Text(nombre,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1A1A2E)),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF6B35), size: 12),
                        const SizedBox(width: 2),
                        Text('$calorias Cal', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                        const SizedBox(width: 10),
                        Icon(Icons.timer_outlined, color: Colors.grey[500], size: 12),
                        const SizedBox(width: 2),
                        Text('$tiempo min', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ],
                    ),
                  ],
                ),
              ),
              // Badge estado
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(iconEstado, color: txtColor, size: 11),
                    const SizedBox(width: 4),
                    Text(label, style: TextStyle(color: txtColor, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(height: 1),
          const SizedBox(height: 16),

          // Botones de acción en fila 2x2
          Row(
            children: [
              // Ver receta (solo lectura)
              Expanded(
                child: _OpcionBtn(
                  icon: Icons.play_circle_fill_rounded,
                  label: 'Ver receta',
                  sublabel: 'Ingredientes y pasos',
                  color: _verde,
                  bgColor: const Color(0xFFE8F7F1),
                  onTap: () {
                    Navigator.pop(context);
                    _verRecetaPersonal(context);
                  },
                ),
              ),
              const SizedBox(width: 12),
              // Editar
              Expanded(
                child: _OpcionBtn(
                  icon: Icons.edit_rounded,
                  label: 'Editar',
                  sublabel: 'Modificar campos',
                  color: _puedeEditar ? const Color(0xFF1A1A2E) : Colors.grey[400]!,
                  bgColor: _puedeEditar ? const Color(0xFFF5F6FA) : Colors.grey[100]!,
                  onTap: _puedeEditar
                      ? () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CrearRecetaUsuarioScreen(
                                recetaExistente: widget.data,
                                recetaPersonalId: widget.docId,
                              ),
                            ),
                          );
                        }
                      : null,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              // Reenviar (si rechazada)
              if (_puedeReenviar) ...[
                Expanded(
                  child: _OpcionBtn(
                    icon: Icons.send_rounded,
                    label: 'Reenviar',
                    sublabel: 'A revisión',
                    color: const Color(0xFF3B82F6),
                    bgColor: const Color(0xFFE8F4FD),
                    onTap: () {
                      Navigator.pop(context);
                      _confirmarReenvio(context);
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
              // Eliminar
              Expanded(
                child: _OpcionBtn(
                  icon: Icons.delete_outline_rounded,
                  label: _eliminando ? 'Eliminando...' : 'Eliminar',
                  sublabel: 'Borrar esta receta',
                  color: const Color(0xFFE53935),
                  bgColor: const Color(0xFFFFEBEE),
                  onTap: _eliminando ? null : () => _confirmarEliminar(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Ver receta personal como solo lectura usando DetalleRecetaPersonalSheet
  void _verRecetaPersonal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleRecetaPersonalSheet(data: widget.data),
    );
  }

  Future<void> _confirmarReenvio(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Reenviar a revisión', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('¿Quieres reenviar "${widget.data['nombre']}" al administrador?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[600]))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _verde,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Reenviar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      final payload = Map<String, dynamic>.from(widget.data);
      payload['estado'] = 'pendiente';
      payload['fechaEnvio'] = FieldValue.serverTimestamp();
      payload['origenPersonalDocId'] = widget.docId;
      await FirebaseFirestore.instance.collection('recetas-pendientes').add(payload);
      await FirebaseFirestore.instance
          .collection('recetas_personales')
          .doc(widget.docId)
          .update({'estado': 'en_revision'});
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: const Text('Receta reenviada a revisión'),
              backgroundColor: _verde, behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              margin: const EdgeInsets.all(16)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16)),
        );
      }
    }
  }

  Future<void> _confirmarEliminar(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar receta', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text('¿Seguro que quieres eliminar "${widget.data['nombre']}"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[600]))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _eliminando = true);
    try {
      await FirebaseFirestore.instance
          .collection('recetas_personales')
          .doc(widget.docId)
          .delete();
      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _eliminando = false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e'), backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16)),
        );
      }
    }
  }
}

// ─── Botón de opción ──────────────────────────────────────────────────────────
class _OpcionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _OpcionBtn({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.bgColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
              const SizedBox(height: 2),
              Text(sublabel, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
            ],
          ),
        ),
      );
}

// ═══════════════════════════════════════════════════
//  VISTA DE RECETA PERSONAL (solo lectura)
// ═══════════════════════════════════════════════════
class _DetalleRecetaPersonalSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  const _DetalleRecetaPersonalSheet({required this.data});

  @override
  State<_DetalleRecetaPersonalSheet> createState() => _DetalleRecetaPersonalSheetState();
}

class _DetalleRecetaPersonalSheetState extends State<_DetalleRecetaPersonalSheet> {
  static const Color _verde = Color(0xFF2D9E73);
  List<Map<String, dynamic>> _ingredientesEnriquecidos = [];
  bool _cargandoIngs = true;

  @override
  void initState() {
    super.initState();
    _cargarIngredientes();
  }

  Future<void> _cargarIngredientes() async {
    final rawIngs = widget.data['ingredientes'] as List? ?? [];
    final enriquecidos = <Map<String, dynamic>>[];

    for (final item in rawIngs) {
      final m = item as Map<String, dynamic>;
      final ingId = m['ingrediente_id']?.toString() ?? '';
      String nombre = m['nombre']?.toString() ?? ingId;
      String foto = m['imagen']?.toString() ?? '';

      // Buscar en ingredientes_maestros si no tiene imagen o el nombre viene del id
      if (ingId.isNotEmpty && (foto.isEmpty || nombre == ingId)) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('ingredientes_maestros')
              .doc(ingId)
              .get();
          if (doc.exists) {
            final maestro = doc.data()!;
            nombre = maestro['nombre']?.toString() ?? nombre;
            foto = maestro['foto']?.toString() ?? maestro['imagen']?.toString() ?? foto;
          }
        } catch (_) {}
      }

      enriquecidos.add({
        ...m,
        'nombre': nombre,
        'foto': foto,
      });
    }

    if (mounted) setState(() {
      _ingredientesEnriquecidos = enriquecidos;
      _cargandoIngs = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final nombre    = widget.data['nombre'] ?? 'Sin título';
    final calorias  = widget.data['calorias']?.toString() ?? '0';
    final tiempo    = widget.data['tiempo']?.toString() ?? '0';
    final categoria = widget.data['categoria'] ?? '';
    final subcategoria = widget.data['subcategoria'] ?? '';
    final imgUrl    = widget.data['imagen'] ?? '';
    final pasos     = widget.data['pasos'] as List? ?? [];

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
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),

            // Badge solo lectura
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.visibility_rounded, color: _verde, size: 13),
                  SizedBox(width: 4),
                  Text('Sólo lectura', style: TextStyle(color: _verde, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 4),

            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen
                    if (imgUrl.startsWith('http'))
                      SizedBox(
                        height: 200,
                        width: double.infinity,
                        child: Image.network(imgUrl, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                      ),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Categoria + subcategoria
                          Wrap(
                            spacing: 6,
                            children: [
                              if (categoria.isNotEmpty)
                                _Chip(categoria, _verde, const Color(0xFFE8F7F1)),
                              if (subcategoria.isNotEmpty)
                                _Chip(subcategoria, Colors.grey[700]!, Colors.grey[100]!),
                            ],
                          ),
                          const SizedBox(height: 8),

                          Text(nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),

                          // Stats
                          Row(
                            children: [
                              _Stat(Icons.local_fire_department_rounded, '$calorias cal', const Color(0xFFFF6B35)),
                              const SizedBox(width: 16),
                              if (tiempo != '0') _Stat(Icons.timer_outlined, '${tiempo} min', _verde),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // Ingredientes
                          const Text('Ingredientes',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 8),

                          if (_cargandoIngs)
                            const Center(child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(color: _verde, strokeWidth: 2),
                            ))
                          else
                            ..._ingredientesEnriquecidos.map((ing) {
                              final fotoIng = ing['foto']?.toString() ?? '';
                              final nombreIng = ing['nombre']?.toString() ?? '';
                              final cantidad = ing['cantidad']?.toString() ?? '';
                              final unidad = ing['unidad']?.toString() ?? '';
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 5),
                                child: Row(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: SizedBox(
                                        width: 36, height: 36,
                                        child: fotoIng.startsWith('http')
                                            ? Image.network(fotoIng, fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => _IngPlaceholder())
                                            : _IngPlaceholder(),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(child: Text(nombreIng, style: const TextStyle(fontSize: 13))),
                                    Text('$cantidad $unidad',
                                        style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                                  ],
                                ),
                              );
                            }),

                          if (pasos.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            const Text('Preparación',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            ...pasos.asMap().entries.map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    width: 26, height: 26,
                                    decoration: const BoxDecoration(color: _verde, shape: BoxShape.circle),
                                    child: Center(
                                      child: Text('${e.key + 1}',
                                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      (e.value as Map<String, dynamic>)['instruccion']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 13, height: 1.5),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                          const SizedBox(height: 20),
                        ],
                      ),
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
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  const _Chip(this.label, this.color, this.bg);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
      );
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
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w500)),
        ],
      );
}

class _IngPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        color: const Color(0xFFE8F7F1),
        child: const Icon(Icons.egg_alt_rounded, color: Color(0xFF2D9E73), size: 18),
      );
}

// ═══════════════════════════════════════════════════
//  BUSCADOR DE RECETAS DE LA BD PARA COPIAR
// ═══════════════════════════════════════════════════
class _BuscadorRecetasDBSheet extends StatefulWidget {
  const _BuscadorRecetasDBSheet();

  @override
  State<_BuscadorRecetasDBSheet> createState() => _BuscadorRecetasDBSheetState();
}

class _BuscadorRecetasDBSheetState extends State<_BuscadorRecetasDBSheet> {
  static const Color _verde = Color(0xFF2D9E73);
  final _searchCtrl = TextEditingController();
  List<QueryDocumentSnapshot> _resultados = [];
  bool _buscando = false;
  bool _copiando = false;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarRecientes();
    _searchCtrl.addListener(_onBusquedaChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarRecientes() async {
    setState(() => _buscando = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('app-recetas-completas')
          .limit(20)
          .get();
      if (mounted) setState(() { _resultados = snap.docs; _buscando = false; });
    } catch (_) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _onBusquedaChanged() {
    final q = _searchCtrl.text.trim();
    if (q == _busqueda) return;
    _busqueda = q;
    if (q.isEmpty) { _cargarRecientes(); return; }
    _buscar(q);
  }

  Future<void> _buscar(String q) async {
    setState(() => _buscando = true);
    final qLower = q.toLowerCase();
    try {
      // Buscar por nombre
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection('app-recetas-completas')
          .where('nombre', isGreaterThanOrEqualTo: q)
          .where('nombre', isLessThan: '${q}z')
          .limit(20)
          .get();

      if (snap.docs.isEmpty) {
        // Fallback: buscar con primera letra mayúscula
        final qCap = q[0].toUpperCase() + q.substring(1);
        snap = await FirebaseFirestore.instance
            .collection('app-recetas-completas')
            .where('nombre', isGreaterThanOrEqualTo: qCap)
            .where('nombre', isLessThan: '${qCap}z')
            .limit(20)
            .get();
      }

      if (mounted) setState(() { _resultados = snap.docs; _buscando = false; });
    } catch (_) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  Future<void> _copiarReceta(QueryDocumentSnapshot doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _copiando = true);
    final receta = doc.data() as Map<String, dynamic>;

    try {
      final ingsOriginales = receta['ingredientes'] as List? ?? [];
      final ingredientesMapeados = ingsOriginales.map((i) {
        final m = i as Map<String, dynamic>;
        return {
          'ingrediente_id': m['ingrediente_id'] ?? '',
          'nombre': m['nombre'] ?? '',
          'cantidad': m['cantidad'] ?? 1,
          'unidad': m['unidad'] ?? '',
          'imagen': m['imagen'] ?? '',
          'es_primordial': m['es_primordial'] ?? false,
        };
      }).toList();

      // Buscar pasos en steps-recetas (campo pasos_ordenados)
      List<dynamic> pasosOriginales = [];
      try {
        final stepsDoc = await FirebaseFirestore.instance
            .collection('steps-recetas')
            .doc(doc.id)
            .get();
        if (stepsDoc.exists) {
          pasosOriginales = List.from(stepsDoc.data()!['pasos_ordenados'] ?? []);
        }
        if (pasosOriginales.isEmpty) {
          for (final campo in ['receta_id', 'recetas_id']) {
            final q = await FirebaseFirestore.instance
                .collection('steps-recetas')
                .where(campo, isEqualTo: doc.id)
                .limit(1)
                .get();
            if (q.docs.isNotEmpty) {
              pasosOriginales = List.from(q.docs.first.data()['pasos_ordenados'] ?? []);
              break;
            }
          }
        }
        // Fallback: pasos embebidos en el doc de la receta
        if (pasosOriginales.isEmpty) {
          pasosOriginales = List.from(
            receta['pasos_ordenados'] ?? receta['pasos'] ?? [],
          );
        }
        pasosOriginales.sort((a, b) => (a['orden'] ?? 0).compareTo(b['orden'] ?? 0));
      } catch (_) {}

      final payload = {
        'nombre': '${receta['nombre'] ?? 'Receta'} (copia)',
        'calorias': receta['calorias'] ?? receta['calorías'] ?? 0,
        'tiempo': receta['tiempo'] ?? 0,
        'imagen': receta['imagen'] ?? '',
        'porciones': int.tryParse(receta['porcion_base']?.toString() ?? '1') ?? 1,
        'categoria': receta['categoria'] ?? '',
        'subcategoria': receta['subcategoria'] ?? '',
        'ingredientes': ingredientesMapeados,
        'pasos': pasosOriginales,
        'estado': 'borrador',
        'usuarioId': user.uid,
        'usuarioEmail': user.email ?? '',
        'fechaCreacion': DateTime.now().toIso8601String(),
        'copiadaDe': doc.id,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('recetas_personales')
          .add(payload);

      if (!mounted) return;
      Navigator.pop(context); // Cerrar buscador

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Receta copiada a Mis recetas'),
            ],
          ),
          backgroundColor: _verde,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: 'Editar',
            textColor: Colors.white,
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => CrearRecetaUsuarioScreen(
                  recetaExistente: payload,
                  recetaPersonalId: docRef.id,
                ),
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      setState(() => _copiando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al copiar: $e'), backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating, margin: const EdgeInsets.all(16)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
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
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Copiar receta',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A2E))),
                  const SizedBox(height: 2),
                  Text('Busca una receta del catálogo y cópiala para editarla',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  const SizedBox(height: 12),
                  // Barra de búsqueda
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F6FA),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Buscar receta...',
                        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                        prefixIcon: _buscando
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(width: 18, height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: _verde)),
                              )
                            : const Icon(Icons.search_rounded, color: _verde),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear_rounded, color: Colors.grey[400]),
                                onPressed: () { _searchCtrl.clear(); _cargarRecientes(); })
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Resultados
            Expanded(
              child: _copiando
                  ? const Center(child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(color: _verde),
                        SizedBox(height: 12),
                        Text('Copiando receta...', style: TextStyle(color: _verde)),
                      ],
                    ))
                  : _resultados.isEmpty && !_buscando
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text('No se encontraron recetas', style: TextStyle(color: Colors.grey[500])),
                            ],
                          ),
                        )
                      : ListView.separated(
                          controller: scrollCtrl,
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                          itemCount: _resultados.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final doc = _resultados[i];
                            final data = doc.data() as Map<String, dynamic>;
                            final nombre = data['nombre'] ?? 'Sin título';
                            final img = data['imagen'] ?? '';
                            final calorias = data['calorias']?.toString() ?? '0';
                            final categoria = data['categoria'] ?? '';
                            final tiempo = data['tiempo']?.toString() ?? '0';

                            return Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              elevation: 1,
                              shadowColor: Colors.black12,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _copiarReceta(doc),
                                child: Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: SizedBox(
                                          width: 56, height: 56,
                                          child: img.startsWith('http')
                                              ? Image.network(img, fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => _IngPlaceholder())
                                              : _IngPlaceholder(),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            if (categoria.isNotEmpty)
                                              Text(categoria,
                                                  style: const TextStyle(color: _verde, fontSize: 9, fontWeight: FontWeight.w700)),
                                            Text(nombre,
                                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                                maxLines: 1, overflow: TextOverflow.ellipsis),
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                const Icon(Icons.local_fire_department_rounded,
                                                    color: Color(0xFFFF6B35), size: 11),
                                                const SizedBox(width: 2),
                                                Text('$calorias cal', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                                if (tiempo != '0') ...[
                                                  const SizedBox(width: 8),
                                                  Icon(Icons.timer_outlined, color: Colors.grey[500], size: 11),
                                                  const SizedBox(width: 2),
                                                  Text('$tiempo min', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                                ],
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE8F7F1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.copy_rounded, color: _verde, size: 16),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
