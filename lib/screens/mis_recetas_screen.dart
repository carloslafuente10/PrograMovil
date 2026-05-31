import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'crear_receta_usuario_screen.dart';
import 'detalle_receta_screen.dart';
import '../servicios/notificaciones_servicio.dart';

class MisRecetasScreen extends StatefulWidget {
  const MisRecetasScreen({super.key});

  @override
  State<MisRecetasScreen> createState() => _MisRecetasScreenState();
}

class _MisRecetasScreenState extends State<MisRecetasScreen>
    with SingleTickerProviderStateMixin {
  static const Color _verde = Color(0xFF2D9E73);
  static const Color _fondo = Color(0xFFF5F6FA);
  late TabController _tabController;

  static const _estadosConfig = {
    'guardada': (
      Color(0xFFE8F7F1),
      Color(0xFF065F46),
      Icons.bookmark_rounded,
      'Guardada',
    ),
    'borrador': (
      Color(0xFFFFF3CD),
      Color(0xFF856404),
      Icons.edit_note_rounded,
      'Borrador',
    ),
    'copia': (
      Color(0xFFE8F4FD),
      Color(0xFF0D6EFD),
      Icons.copy_rounded,
      'Copia',
    ),
    'en_revision': (
      Color(0xFFE8F4FD),
      Color(0xFF0D6EFD),
      Icons.hourglass_top_rounded,
      'En revisión',
    ),
    'publicada': (
      Color(0xFFD1FAE5),
      Color(0xFF065F46),
      Icons.check_circle_rounded,
      'Publicada',
    ),
    'rechazada': (
      Color(0xFFFFE4E6),
      Color(0xFF9F1239),
      Icons.cancel_rounded,
      'Rechazada',
    ),
    'rechazada_editada': (
      Color(0xFFFFF3CD),
      Color(0xFF856404),
      Icons.edit_note_rounded,
      'Lista p/ reenviar',
    ),
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
          'Mis Recetas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy_all_rounded, color: Colors.white),
            tooltip: 'Copiar receta del catálogo',
            onPressed: () => _abrirBuscadorRecetasDB(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Guardadas'),
            Tab(text: 'Borradores'),
            Tab(text: 'Copias'),
            Tab(text: 'Publicadas'),
            Tab(text: 'Revisión'),
            Tab(text: 'Rechazadas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _TabRecetas(
            uid: uid, estadosConfig: _estadosConfig,
            filtro: (e, esCopia) => !esCopia && e != 'borrador',
            emptyMsg: 'No tienes recetas guardadas',
            emptySubMsg: 'Crea y guarda tus propias recetas',
          ),
          _TabRecetas(
            uid: uid, estadosConfig: _estadosConfig,
            filtro: (e, esCopia) => !esCopia && e == 'borrador',
            emptyMsg: 'No tienes borradores',
            emptySubMsg: 'Los borradores son recetas en proceso',
          ),
          _TabRecetas(
            uid: uid, estadosConfig: _estadosConfig,
            filtro: (e, esCopia) => esCopia,
            emptyMsg: 'No tienes copias',
            emptySubMsg: 'Copia recetas del catálogo para editarlas',
          ),
          _TabRecetas(
            uid: uid, estadosConfig: _estadosConfig,
            filtro: (e, esCopia) => !esCopia && e == 'publicada',
            emptyMsg: 'No tienes recetas publicadas',
            emptySubMsg: 'Envía tus recetas para que el admin las apruebe',
          ),
          _TabRecetas(
            uid: uid, estadosConfig: _estadosConfig,
            filtro: (e, esCopia) => !esCopia && e == 'en_revision',
            emptyMsg: 'Ninguna receta en revisión',
            emptySubMsg: 'Aquí aparecen las que enviaste al admin',
          ),
          _TabRecetas(
            uid: uid, estadosConfig: _estadosConfig,
            filtro: (e, esCopia) => !esCopia && e == 'rechazada',
            emptyMsg: 'No tienes recetas rechazadas',
            emptySubMsg: '',
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

  void _abrirBuscadorRecetasDB(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _BuscadorRecetasDBSheet(),
    );
  }
}

class _TabRecetas extends StatelessWidget {
  final String uid;
  final Map<String, dynamic> estadosConfig;
  final bool Function(String estado, bool esCopia) filtro;
  final String emptyMsg;
  final String emptySubMsg;

  static const Color _verde = Color(0xFF2D9E73);

  const _TabRecetas({
    required this.uid, required this.estadosConfig,
    required this.filtro, required this.emptyMsg, required this.emptySubMsg,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('recetas_personales')
          .where('usuarioId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: _verde));
        }
        final allDocs = snap.data?.docs ?? [];
        final docs = allDocs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final estado = data['estado'] ?? 'borrador';
          final esCopia = data['copiadaDe'] != null;
          return filtro(estado, esCopia);
        }).toList();

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.menu_book_rounded, size: 60, color: Colors.grey[300]),
                const SizedBox(height: 12),
                Text(emptyMsg,
                    style: TextStyle(color: Colors.grey[600], fontSize: 15, fontWeight: FontWeight.w600)),
                if (emptySubMsg.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(emptySubMsg, style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                ],
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2, childAspectRatio: 0.82,
            crossAxisSpacing: 12, mainAxisSpacing: 12,
          ),
          itemCount: docs.length,
          itemBuilder: (ctx, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _RecetaPersonalCard(
                docId: docs[i].id, data: data, estadosConfig: estadosConfig);
          },
        );
      },
    );
  }
}

class _RecetaPersonalCard extends StatelessWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Map<String, dynamic> estadosConfig;
  static const Color _verde = Color(0xFF2D9E73);

  const _RecetaPersonalCard({
    required this.docId, required this.data, required this.estadosConfig,
  });

  @override
  Widget build(BuildContext context) {
    final nombre = data['nombre'] ?? 'Sin título';
    final estado = data['estado'] ?? 'borrador';
    final img = data['imagen'] ?? '';
    // Normaliza calorías: puede venir como double, int o String desde Firestore
    final caloriasRaw = data['calorias'] ?? data['calorías'] ?? 0;
    final calorias = caloriasRaw is double
        ? caloriasRaw.toInt().toString()
        : caloriasRaw.toString();
    final categoria = data['categoria'] ?? '';
    final esCopia = data['copiadaDe'] != null;

    final configKey = esCopia ? 'copia' : estado;
    final cfg = estadosConfig[configKey] as (Color, Color, IconData, String)?;
    final bgColor = cfg?.$1 ?? const Color(0xFFF3F4F6);
    final txtColor = cfg?.$2 ?? Colors.grey;
    final icon = cfg?.$3 ?? Icons.circle;

    final enRevision = data['estadoRevision'] == 'pendiente';

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
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: img.startsWith('http')
                        ? Image.network(img, width: double.infinity, height: double.infinity, fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _ImgPlaceholder())
                        : _ImgPlaceholder(),
                  ),
                  Positioned(top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                      child: Icon(icon, color: txtColor, size: 12),
                    ),
                  ),
                  if (enRevision)
                    Positioned(top: 8, left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(color: const Color(0xFF0D6EFD), borderRadius: BorderRadius.circular(8)),
                        child: const Text('En revisión',
                            style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (categoria.isNotEmpty)
                  Text(categoria, style: const TextStyle(color: _verde, fontSize: 9, fontWeight: FontWeight.w700)),
                Text(nombre, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF1A1A2E))),
                const SizedBox(height: 3),
                Row(children: [
                  const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF6B35), size: 11),
                  const SizedBox(width: 2),
                  Text('$calorias cal', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                ]),
              ]),
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
      builder: (_) => _OpcionesRecetaSheet(docId: docId, data: data, estadosConfig: estadosConfig),
    );
  }
}

class _ImgPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFE8F7F1),
    child: const Center(child: Icon(Icons.restaurant_rounded, color: Color(0xFF2D9E73), size: 28)),
  );
}

class _OpcionesRecetaSheet extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final Map<String, dynamic> estadosConfig;

  const _OpcionesRecetaSheet({
    required this.docId, required this.data, required this.estadosConfig,
  });

  @override
  State<_OpcionesRecetaSheet> createState() => _OpcionesRecetaSheetState();
}

class _OpcionesRecetaSheetState extends State<_OpcionesRecetaSheet> {
  static const Color _verde = Color(0xFF2D9E73);
  bool _eliminando = false;
  bool _enviando = false;

  String get _estado => widget.data['estado'] ?? 'borrador';
  bool get _esCopia => widget.data['copiadaDe'] != null;
  String get _estadoRevision => widget.data['estadoRevision'] ?? '';

  bool get _puedeEnviar =>
      !_esCopia && _estado == 'guardada' && _estadoRevision != 'pendiente';
  bool get _puedeReenviar => !_esCopia && _estado == 'rechazada_editada';
  bool get _estaRechazadaSinEditar => !_esCopia && _estado == 'rechazada';
  bool get _puedeEditar =>
      _estado == 'borrador' || _estado == 'guardada' || _estado == 'rechazada' ||
      _estado == 'rechazada_editada' || _esCopia;
  bool get _enRevisionActiva => _estadoRevision == 'pendiente';

  @override
  Widget build(BuildContext context) {
    final nombre = widget.data['nombre'] ?? 'Sin título';
    final img = widget.data['imagen'] ?? '';
    // Normaliza calorías: puede venir como double, int o String
    final caloriasRaw = widget.data['calorias'] ?? widget.data['calorías'] ?? 0;
    final calorias = caloriasRaw is double
        ? caloriasRaw.toInt().toString()
        : caloriasRaw.toString();
    final categoria = widget.data['categoria'] ?? '';
    final tiempoRaw = widget.data['tiempo'] ?? 0;
    final tiempo = tiempoRaw is double
        ? tiempoRaw.toInt().toString()
        : tiempoRaw.toString();

    final configKey = _esCopia ? 'copia' : _estado;
    final cfg = widget.estadosConfig[configKey] as (Color, Color, IconData, String)?;
    final bgColor = cfg?.$1 ?? const Color(0xFFF3F4F6);
    final txtColor = cfg?.$2 ?? Colors.grey;
    final iconEstado = cfg?.$3 ?? Icons.circle;
    final label = cfg?.$4 ?? _estado;

    // ✅ FIX: SafeArea + padding bottom dinámico para no taparse con botones del celular
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
            ),

            Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(width: 64, height: 64,
                  child: img.startsWith('http')
                      ? Image.network(img, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _ImgPlaceholder())
                      : _ImgPlaceholder()),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (categoria.isNotEmpty)
                    Text(categoria, style: const TextStyle(color: _verde, fontSize: 10, fontWeight: FontWeight.w700)),
                  Text(nombre,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.local_fire_department_rounded, color: Color(0xFFFF6B35), size: 12),
                    const SizedBox(width: 2),
                    Text('$calorias Cal', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                    const SizedBox(width: 10),
                    Icon(Icons.timer_outlined, color: Colors.grey[500], size: 12),
                    const SizedBox(width: 2),
                    Text('$tiempo min', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                  ]),
                ]),
              ),
              Column(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(iconEstado, color: txtColor, size: 11),
                    const SizedBox(width: 4),
                    Text(label, style: TextStyle(color: txtColor, fontSize: 10, fontWeight: FontWeight.w600)),
                  ]),
                ),
                if (_enRevisionActiva) ...[
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(color: const Color(0xFF0D6EFD), borderRadius: BorderRadius.circular(8)),
                    child: const Text('En revisión',
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
                  ),
                ],
              ]),
            ]),

            const SizedBox(height: 20),
            const Divider(height: 1),
            const SizedBox(height: 16),

            if (_esCopia)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFE8F4FD), borderRadius: BorderRadius.circular(10)),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded, color: Color(0xFF0D6EFD), size: 14),
                  SizedBox(width: 8),
                  Expanded(child: Text('Las copias son solo para uso personal y no se pueden publicar.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF0D6EFD)))),
                ]),
              ),

            if (_enRevisionActiva)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFFE8F4FD), borderRadius: BorderRadius.circular(10)),
                child: const Row(children: [
                  Icon(Icons.hourglass_top_rounded, color: Color(0xFF0D6EFD), size: 14),
                  SizedBox(width: 8),
                  Expanded(child: Text('Esta receta está en revisión. Espera la respuesta del administrador.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF0D6EFD)))),
                ]),
              ),

            if (_estaRechazadaSinEditar)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE53935).withOpacity(0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.edit_notifications_rounded, color: Color(0xFFE53935), size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'Esta receta ha sido rechazada. Por favor, revísala y edítala antes de volver a enviarla.',
                    style: TextStyle(fontSize: 11, color: Color(0xFFE53935), height: 1.4))),
                ]),
              ),

            Row(children: [
              Expanded(
                child: _OpcionBtn(
                  icon: Icons.play_circle_fill_rounded,
                  label: 'Ver receta',
                  sublabel: 'Ingredientes y pasos',
                  color: _verde,
                  bgColor: const Color(0xFFE8F7F1),
                  onTap: () { Navigator.pop(context); _verReceta(context); },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _OpcionBtn(
                  icon: Icons.edit_rounded,
                  label: 'Editar',
                  sublabel: 'Modificar campos',
                  color: _puedeEditar ? const Color(0xFF1A1A2E) : Colors.grey[400]!,
                  bgColor: _puedeEditar ? const Color(0xFFF5F6FA) : Colors.grey[100]!,
                  onTap: _puedeEditar ? () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => CrearRecetaUsuarioScreen(
                        recetaExistente: widget.data,
                        recetaPersonalId: widget.docId,
                      ),
                    ));
                  } : null,
                ),
              ),
            ]),

            const SizedBox(height: 12),

            Row(children: [
              if (_puedeEnviar) ...[
                Expanded(
                  child: _OpcionBtn(
                    icon: _enviando ? Icons.hourglass_top_rounded : Icons.send_rounded,
                    label: _enviando ? 'Enviando...' : 'Publicar',
                    sublabel: 'Enviar al admin',
                    color: _verde,
                    bgColor: const Color(0xFFE8F7F1),
                    onTap: _enviando ? null : () => _confirmarEnvio(context),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              if (_puedeReenviar) ...[
                Expanded(
                  child: _OpcionBtn(
                    icon: Icons.send_rounded,
                    label: 'Reenviar',
                    sublabel: 'A revisión',
                    color: const Color(0xFF3B82F6),
                    bgColor: const Color(0xFFE8F4FD),
                    onTap: () => _confirmarReenvio(context),
                  ),
                ),
                const SizedBox(width: 12),
              ],
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
            ]),
          ],
        ),
      ),
    );
  }

  void _verReceta(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetalleRecetaPersonalSheet(
        data: widget.data, docId: widget.docId,
        copiadaDe: widget.data['copiadaDe']?.toString(),
      ),
    );
  }

  Future<void> _confirmarEnvio(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enviar para publicación', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('¿Quieres enviar "${widget.data['nombre']}" al administrador para revisión?'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFE8F7F1), borderRadius: BorderRadius.circular(10)),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFF2D9E73), size: 14),
              SizedBox(width: 8),
              Expanded(child: Text('Tu receta permanecerá en tus recetas guardadas.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF2D9E73)))),
            ]),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[600]))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2D9E73),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Enviar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    setState(() => _enviando = true);

    try {
      final payload = Map<String, dynamic>.from(widget.data);
      payload['estadoRevision'] = 'pendiente';
      payload['origenPersonalDocId'] = widget.docId;
      payload['fechaEnvio'] = FieldValue.serverTimestamp();
      payload['estado'] = 'pendiente';

      final pendienteRef = await FirebaseFirestore.instance
          .collection('recetas-pendientes').add(payload);

      await FirebaseFirestore.instance
          .collection('recetas_personales').doc(widget.docId)
          .update({'estadoRevision': 'pendiente', 'estado': 'en_revision'});

      await NotificacionesServicio.notificarAdmins(
        recipeId: pendienteRef.id,
        recipeName: widget.data['nombre'] ?? '',
        usuarioEmail: FirebaseAuth.instance.currentUser?.email ?? '',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_rounded, color: Colors.white),
            SizedBox(width: 10),
            Text('Receta enviada para revisión'),
          ]),
          backgroundColor: const Color(0xFF2D9E73),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      setState(() => _enviando = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
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
            style: ElevatedButton.styleFrom(backgroundColor: _verde,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Reenviar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true || !context.mounted) return;

    try {
      final payload = Map<String, dynamic>.from(widget.data);
      payload['estadoRevision'] = 'pendiente';
      payload['origenPersonalDocId'] = widget.docId;
      payload['fechaEnvio'] = FieldValue.serverTimestamp();
      payload['estado'] = 'pendiente';
      payload.remove('motivoRechazo');

      final pendienteRef = await FirebaseFirestore.instance
          .collection('recetas-pendientes').add(payload);

      await FirebaseFirestore.instance
          .collection('recetas_personales').doc(widget.docId)
          .update({
            'estado': 'en_revision',
            'estadoRevision': 'pendiente',
            'motivoRechazo': FieldValue.delete(),
          });

      await NotificacionesServicio.notificarAdmins(
        recipeId: pendienteRef.id,
        recipeName: widget.data['nombre'] ?? '',
        usuarioEmail: FirebaseAuth.instance.currentUser?.email ?? '',
      );

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Receta reenviada a revisión'),
          backgroundColor: _verde,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ));
      }
    } catch (e) {
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  Future<void> _confirmarEliminar(BuildContext context) async {
    final enRevision = _estado == 'en_revision';

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar receta', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('¿Seguro que quieres eliminar "${widget.data['nombre']}"?'),
          const SizedBox(height: 10),
          if (enRevision)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: const Color(0xFFFFEBEE), borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.warning_rounded, color: Color(0xFFE53935), size: 14),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Esta receta está en revisión. Al eliminarla se cancelará la solicitud al administrador.',
                  style: TextStyle(fontSize: 11, color: Color(0xFFE53935), height: 1.4))),
              ]),
            )
          else
            Text('Esto solo borra tu copia personal.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[600]))),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE53935),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    setState(() => _eliminando = true);
    try {
      if (enRevision) {
        final batch = FirebaseFirestore.instance.batch();
        final pendientesSnap = await FirebaseFirestore.instance
            .collection('recetas-pendientes')
            .where('origenPersonalDocId', isEqualTo: widget.docId)
            .where('estado', isEqualTo: 'pendiente')
            .get();
        for (final doc in pendientesSnap.docs) { batch.delete(doc.reference); }

        final notifsSnap = await FirebaseFirestore.instance
            .collection('notifications')
            .where('type', isEqualTo: 'recipe_pending')
            .get();
        for (final doc in notifsSnap.docs) {
          final recipeId = doc.data()['recipeId'] as String? ?? '';
          final esDePendiente = pendientesSnap.docs.any((p) => p.id == recipeId);
          if (esDePendiente) batch.delete(doc.reference);
        }
        await batch.commit();
      }

      await FirebaseFirestore.instance
          .collection('recetas_personales').doc(widget.docId).delete();

      if (context.mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _eliminando = false);
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }
}

class _OpcionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final Color bgColor;
  final VoidCallback? onTap;

  const _OpcionBtn({
    required this.icon, required this.label, required this.sublabel,
    required this.color, required this.bgColor, this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
        const SizedBox(height: 2),
        Text(sublabel, style: TextStyle(fontSize: 10, color: color.withOpacity(0.7))),
      ]),
    ),
  );
}

class _DetalleRecetaPersonalSheet extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;
  final String? copiadaDe;
  const _DetalleRecetaPersonalSheet({
    required this.data, required this.docId, this.copiadaDe,
  });
  @override
  State<_DetalleRecetaPersonalSheet> createState() =>
      _DetalleRecetaPersonalSheetState();
}

class _DetalleRecetaPersonalSheetState extends State<_DetalleRecetaPersonalSheet> {
  static const Color _verde = Color(0xFF2D9E73);
  List<Map<String, dynamic>> _ings = [];
  List<Map<String, dynamic>> _pasos = [];
  bool _cargando = true;

  static const _unidadesInvariables = {'ml', 'g', 'kg', 'oz', 'lb', 'gr', 'l'};
  static const _unidadesMedida = {
    'cucharada','cucharadas','cucharadita','cucharaditas','cucharita','cucharitas',
    'taza','tazas','vaso','vasos','copa','copas','litro','litros','l','mililitro',
    'mililitros','ml','gramo','gramos','g','gr','kilogramo','kilogramos','kg',
    'onza','onzas','oz','libra','libras','lb','pizca','pizcas','puñado','puñados',
    'trozo','trozos','rodaja','rodajas','rebanada','rebanadas','porción','porciones',
  };

  String _calcularNumero(double cantidad) {
    final int parteEntera = cantidad.floor();
    final double decimal = cantidad - parteEntera;
    final Map<double, String> fracciones = {0.25: '¼', 0.33: '⅓', 0.5: '½', 0.67: '⅔', 0.75: '¾'};
    for (final e in fracciones.entries) {
      if ((decimal - e.key).abs() < 0.05) {
        return parteEntera == 0 ? e.value : '$parteEntera${e.value}';
      }
    }
    if (decimal < 0.05) return '$parteEntera';
    return cantidad.toStringAsFixed(1);
  }

  String _pluralizarPalabra(String palabra, double cantidad) {
    if (cantidad <= 1 || palabra.isEmpty) return palabra;
    final String lower = palabra.toLowerCase();
    if (_unidadesInvariables.contains(lower)) return palabra;
    if (lower.endsWith('s') || lower.endsWith('x')) return palabra;
    if (lower.endsWith('z')) return '${palabra.substring(0, palabra.length - 1)}ces';
    if (RegExp(r'[aeiouáéíóú]$').hasMatch(lower)) return '${palabra}s';
    return '${palabra}es';
  }

  String _pluralizarSeguro(double cantidad, String texto) {
    if (cantidad <= 1 || texto.trim().isEmpty) return texto.trim();
    final String limpio = texto.trim();
    if (_unidadesInvariables.contains(limpio.toLowerCase())) return limpio;
    final parts = limpio.split(' ');
    final int deIdx = parts.indexWhere((p) => p.toLowerCase() == 'de');
    if (deIdx > 0) { parts[0] = _pluralizarPalabra(parts[0], cantidad); return parts.join(' '); }
    parts[0] = _pluralizarPalabra(parts[0], cantidad);
    return parts.join(' ');
  }

  String _pluralizarNombre(double cantidad, String nombre) {
    if (cantidad <= 1 || nombre.trim().isEmpty) return nombre.trim();
    final String limpio = nombre.trim();
    if (limpio.toLowerCase().contains(' de ')) return limpio;
    final parts = limpio.split(' ');
    parts[0] = _pluralizarPalabra(parts[0], cantidad);
    return parts.join(' ');
  }

  String _abreviarUnidad(String unidad, double cantidad) {
    final String lower = unidad.toLowerCase();
    const Map<String, String> abrevFijas = {
      'gramo': 'g', 'gramos': 'g', 'kilogramo': 'kg', 'kilogramos': 'kg',
      'mililitro': 'ml', 'mililitros': 'ml', 'litro': 'litro', 'litros': 'litro',
      'libra': 'libra', 'libras': 'libra', 'onza': 'oz', 'onzas': 'oz',
    };
    if (abrevFijas.containsKey(lower)) return _pluralizarSeguro(cantidad, abrevFijas[lower]!);
    if (lower == 'cucharada' || lower == 'cucharadas') return cantidad <= 1 ? 'cda.' : 'cdas.';
    if (lower == 'cucharadita' || lower == 'cucharaditas' || lower == 'cucharita' || lower == 'cucharitas')
      return cantidad <= 1 ? 'cdta.' : 'cdtas.';
    if (lower == 'taza' || lower == 'tazas') return cantidad <= 1 ? 'taza' : 'tazas';
    return _pluralizarSeguro(cantidad, unidad);
  }

  Map<String, String> _textoIngrediente(Map<String, dynamic> ing) {
    final double cantidad = (ing['cantidad'] is num)
        ? (ing['cantidad'] as num).toDouble()
        : double.tryParse(ing['cantidad']?.toString() ?? '0') ?? 0;
    final String nombre = ing['nombre']?.toString().trim() ?? '';
    final String unidadRaw = ing['unidad']?.toString().trim() ?? '';
    final String unidadLower = unidadRaw.toLowerCase();
    final String numero = _calcularNumero(cantidad);
    final bool esUnidad = unidadLower == 'unidad' || unidadLower == 'unidades';

    if (esUnidad || unidadRaw.isEmpty) {
      return {'cantidad': numero, 'nombre': _pluralizarNombre(cantidad, nombre)};
    }

    final String unidadAbrev = _abreviarUnidad(unidadRaw, cantidad);
    String nombreFinal;
    if (unidadLower.contains(' de ')) {
      nombreFinal = nombre;
    } else if (_unidadesMedida.contains(unidadLower)) {
      nombreFinal = 'de $nombre';
    } else {
      nombreFinal = _pluralizarNombre(cantidad, nombre);
    }
    return {'cantidad': '$numero $unidadAbrev', 'nombre': nombreFinal};
  }

  @override
  void initState() { super.initState(); _cargar(); }

  String _slugANombre(String slug) {
    if (slug.isEmpty) return slug;
    return slug.split('-').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');
  }

  Future<void> _cargar() async {
    final rawIngs = widget.data['ingredientes'] as List? ?? [];
    final result = <Map<String, dynamic>>[];
    for (final item in rawIngs) {
      final m = item as Map<String, dynamic>;
      final ingId = m['ingrediente_id']?.toString() ?? '';
      String nombre = m['nombre']?.toString() ?? '';
      if (nombre.isEmpty || nombre == ingId) nombre = _slugANombre(ingId);
      String foto = m['imagen']?.toString() ?? '';
      if (ingId.isNotEmpty && (foto.isEmpty || nombre == ingId || nombre == _slugANombre(ingId))) {
        try {
          final doc = await FirebaseFirestore.instance
              .collection('ingredientes_maestros').doc(ingId).get();
          if (doc.exists) {
            final n = doc.data()!['nombre']?.toString() ?? '';
            if (n.isNotEmpty) nombre = n;
            foto = doc.data()!['foto']?.toString() ?? doc.data()!['imagen']?.toString() ?? foto;
          }
        } catch (_) {}
      }
      result.add({...m, 'nombre': nombre, 'foto': foto});
    }

    List<Map<String, dynamic>> pasosEncontrados = [];
    final pasosLocal = widget.data['pasos'] as List? ?? [];
    if (pasosLocal.isNotEmpty) {
      pasosEncontrados = pasosLocal.map((p) => Map<String, dynamic>.from(p as Map)).toList();
    }

    if (pasosEncontrados.isEmpty && widget.copiadaDe != null) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('steps-recetas').doc(widget.copiadaDe).get();
        if (snap.exists) {
          pasosEncontrados = List<Map<String, dynamic>>.from(
              (snap.data()!['pasos_ordenados'] as List? ?? [])
                  .map((p) => Map<String, dynamic>.from(p as Map)));
        }
        if (pasosEncontrados.isEmpty) {
          final q = await FirebaseFirestore.instance
              .collection('steps-recetas')
              .where('receta_id', isEqualTo: widget.copiadaDe).limit(1).get();
          if (q.docs.isNotEmpty) {
            pasosEncontrados = List<Map<String, dynamic>>.from(
                (q.docs.first.data()['pasos_ordenados'] as List? ?? [])
                    .map((p) => Map<String, dynamic>.from(p as Map)));
          }
        }
      } catch (_) {}
    }

    if (pasosEncontrados.isEmpty) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('steps-recetas').doc(widget.docId).get();
        if (snap.exists) {
          pasosEncontrados = List<Map<String, dynamic>>.from(
              (snap.data()!['pasos_ordenados'] as List? ?? [])
                  .map((p) => Map<String, dynamic>.from(p as Map)));
        }
        if (pasosEncontrados.isEmpty) {
          final q = await FirebaseFirestore.instance
              .collection('steps-recetas')
              .where('receta_id', isEqualTo: widget.docId).limit(1).get();
          if (q.docs.isNotEmpty) {
            pasosEncontrados = List<Map<String, dynamic>>.from(
                (q.docs.first.data()['pasos_ordenados'] as List? ?? [])
                    .map((p) => Map<String, dynamic>.from(p as Map)));
          }
        }
        if (pasosEncontrados.isEmpty) {
          final q = await FirebaseFirestore.instance
              .collection('steps-recetas')
              .where('receta_id', isEqualTo: widget.docId).limit(1).get();
          if (q.docs.isNotEmpty) {
            pasosEncontrados = List<Map<String, dynamic>>.from(
                (q.docs.first.data()['pasos_ordenados'] as List? ?? [])
                    .map((p) => Map<String, dynamic>.from(p as Map)));
          }
        }
      } catch (_) {}
    }

    pasosEncontrados.sort(
        (a, b) => ((a['orden'] ?? 0) as num).compareTo((b['orden'] ?? 0) as num));

    if (mounted) setState(() { _ings = result; _pasos = pasosEncontrados; _cargando = false; });
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.data['nombre'] ?? 'Sin título';
    // Normaliza calorías
    final caloriasRaw = widget.data['calorias'] ?? widget.data['calorías'] ?? 0;
    final calorias = caloriasRaw is double
        ? caloriasRaw.toInt().toString()
        : caloriasRaw.toString();
    final tiempoRaw = widget.data['tiempo'] ?? 0;
    final tiempo = tiempoRaw is double
        ? tiempoRaw.toInt().toString()
        : tiempoRaw.toString();
    final categoria = widget.data['categoria'] ?? '';
    final imgUrl = widget.data['imagen'] ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.92, minChildSize: 0.5, maxChildSize: 0.96,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: scrollCtrl,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (imgUrl.startsWith('http'))
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.network(imgUrl, width: double.infinity, height: 200, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                    ),
                  const SizedBox(height: 12),
                  if (categoria.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: const Color(0xFFE8F7F1), borderRadius: BorderRadius.circular(6)),
                      child: Text(categoria, style: const TextStyle(color: _verde, fontSize: 10, fontWeight: FontWeight.w600)),
                    ),
                  const SizedBox(height: 6),
                  Text(nombre, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(children: [
                    _Stat(Icons.local_fire_department_rounded, '$calorias cal', const Color(0xFFFF6B35)),
                    const SizedBox(width: 16),
                    if (tiempo != '0') _Stat(Icons.timer_outlined, '$tiempo min', _verde),
                  ]),
                  const SizedBox(height: 20),
                  const Text('Ingredientes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (_cargando)
                    const Center(child: CircularProgressIndicator(color: _verde, strokeWidth: 2))
                  else
                    ..._ings.map((ing) {
                      final partes = _textoIngrediente(ing);
                      final fotoUrl = ing['foto']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(width: 40, height: 40,
                              child: fotoUrl.startsWith('http')
                                  ? Image.network(fotoUrl, fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _IngPlaceholder())
                                  : _IngPlaceholder()),
                          ),
                          const SizedBox(width: 10),
                          Text(partes['cantidad']!,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _verde)),
                          const SizedBox(width: 7),
                          Expanded(child: Text(partes['nombre']!,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400, color: Color(0xFF1A1A1A)),
                              maxLines: 2, overflow: TextOverflow.ellipsis)),
                        ]),
                      );
                    }),
                  const SizedBox(height: 20),
                  const Text('Preparación', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  if (_cargando)
                    const Center(child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: CircularProgressIndicator(color: _verde, strokeWidth: 2)))
                  else if (_pasos.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(children: [
                        Icon(Icons.info_outline_rounded, size: 16, color: Colors.grey[400]),
                        const SizedBox(width: 8),
                        Text('No hay pasos de preparación disponibles.',
                            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                      ]),
                    )
                  else
                    ..._pasos.asMap().entries.map((e) {
                      final paso = e.value;
                      final instruccion = paso['instruccion']?.toString() ?? '';
                      final imgPaso = paso['img']?.toString() ?? '';
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Container(
                            width: 26, height: 26,
                            decoration: const BoxDecoration(color: _verde, shape: BoxShape.circle),
                            child: Center(child: Text('${e.key + 1}',
                                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            if (imgPaso.startsWith('http')) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(imgPaso, height: 120, width: double.infinity, fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                              ),
                              const SizedBox(height: 6),
                            ],
                            Text(instruccion, style: const TextStyle(fontSize: 13, height: 1.5)),
                          ])),
                        ]),
                      );
                    }),
                ]),
              ),
            ),
          ),
        ]),
      ),
    );
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
    child: const Icon(Icons.egg_alt_rounded, color: Color(0xFF2D9E73), size: 18),
  );
}

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
  void initState() { super.initState(); _cargarRecientes(); _searchCtrl.addListener(_onChanged); }
  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _cargarRecientes() async {
    setState(() => _buscando = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('app-recetas-completas').limit(20).get();
      if (mounted) setState(() { _resultados = snap.docs; _buscando = false; });
    } catch (_) { if (mounted) setState(() => _buscando = false); }
  }

  void _onChanged() {
    final q = _searchCtrl.text.trim();
    if (q == _busqueda) return;
    _busqueda = q;
    if (q.isEmpty) { _cargarRecientes(); return; }
    _buscar(q);
  }

  Future<void> _buscar(String q) async {
    setState(() => _buscando = true);
    try {
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection('app-recetas-completas')
          .where('nombre', isGreaterThanOrEqualTo: q)
          .where('nombre', isLessThan: '${q}z').limit(20).get();
      if (snap.docs.isEmpty) {
        final qCap = q[0].toUpperCase() + q.substring(1);
        snap = await FirebaseFirestore.instance.collection('app-recetas-completas')
            .where('nombre', isGreaterThanOrEqualTo: qCap)
            .where('nombre', isLessThan: '${qCap}z').limit(20).get();
      }
      if (mounted) setState(() { _resultados = snap.docs; _buscando = false; });
    } catch (_) { if (mounted) setState(() => _buscando = false); }
  }

  Future<void> _copiarReceta(QueryDocumentSnapshot doc) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() => _copiando = true);
    final receta = doc.data() as Map<String, dynamic>;
    try {
      // Calorías: el catálogo usa 'calorías' (con tilde), las personales 'calorias'
      final caloriasVal = receta['calorias'] ?? receta['calorías'] ?? 0;

      // Ingredientes: el catálogo solo guarda ingrediente_id, sin campo 'nombre'.
      // Hay que resolver el nombre desde ingredientes_maestros para que al editar
      // la copia se muestren correctamente.
      final rawIngs = receta['ingredientes'] as List? ?? [];
      final ingsResueltos = <Map<String, dynamic>>[];
      for (final i in rawIngs) {
        final m = i as Map<String, dynamic>;
        final ingId = m['ingrediente_id']?.toString() ?? '';
        String nombre = m['nombre']?.toString() ?? '';
        String imagen = m['imagen']?.toString() ?? '';
        if (nombre.isEmpty && ingId.isNotEmpty) {
          try {
            final maestroDoc = await FirebaseFirestore.instance
                .collection('ingredientes_maestros')
                .doc(ingId)
                .get();
            if (maestroDoc.exists) {
              nombre = maestroDoc.data()!['nombre']?.toString() ?? '';
              if (imagen.isEmpty) {
                imagen = maestroDoc.data()!['foto']?.toString() ??
                    maestroDoc.data()!['imagen']?.toString() ?? '';
              }
            }
          } catch (_) {}
          if (nombre.isEmpty) nombre = ingId.replaceAll('-', ' ');
        }
        ingsResueltos.add({
          'ingrediente_id': ingId,
          'nombre': nombre,
          'cantidad': m['cantidad'] ?? 1,
          'unidad': m['unidad'] ?? '',
          'imagen': imagen,
          'es_primordial': m['es_primordial'] ?? false,
        });
      }

      // Pasos: el catálogo puede guardarlos en el mismo doc como 'pasos_ordenados'
      final pasosOrdenados = receta['pasos_ordenados'] as List? ?? [];
      final pasosLegacy    = receta['pasos'] as List? ?? [];
      final pasos = pasosOrdenados.isNotEmpty ? pasosOrdenados : pasosLegacy;

      final payload = {
        'nombre': '${receta['nombre'] ?? 'Receta'} (copia)',
        'calorias': caloriasVal,
        'tiempo': receta['tiempo'] ?? 0,
        'imagen': receta['imagen'] ?? '',
        'porciones': int.tryParse(receta['porcion_base']?.toString() ?? '1') ?? 1,
        'categoria': receta['categoria'] ?? '',
        'subcategoria': receta['subcategoria'] ?? '',
        'ingredientes': ingsResueltos,
        'pasos': pasos,
        'estado': 'copia',
        'usuarioId': user.uid,
        'usuarioEmail': user.email ?? '',
        'fechaCreacion': DateTime.now().toIso8601String(),
        'copiadaDe': doc.id,
      };
      await FirebaseFirestore.instance.collection('recetas_personales').add(payload);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Receta copiada. Encuéntrala en la pestaña Copias'),
        backgroundColor: _verde,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ));
    } catch (e) {
      setState(() => _copiando = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9, minChildSize: 0.5, maxChildSize: 0.96,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Copiar receta del catálogo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Las copias son solo para uso personal',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 12),
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
                    prefixIcon: _buscando
                        ? const Padding(padding: EdgeInsets.all(12),
                            child: SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: _verde)))
                        : const Icon(Icons.search_rounded, color: _verde),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ]),
          ),
          const Divider(height: 1),
          Expanded(
            child: _copiando
                ? const Center(child: CircularProgressIndicator(color: _verde))
                : _resultados.isEmpty && !_buscando
                ? Center(child: Text('No se encontraron recetas',
                    style: TextStyle(color: Colors.grey[500])))
                : ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
                    itemCount: _resultados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final doc = _resultados[i];
                      final data = doc.data() as Map<String, dynamic>;
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        elevation: 1, shadowColor: Colors.black12,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _copiarReceta(doc),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: SizedBox(width: 56, height: 56,
                                  child: (data['imagen'] ?? '').startsWith('http')
                                      ? Image.network(data['imagen'], fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _IngPlaceholder())
                                      : _IngPlaceholder()),
                              ),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                if ((data['categoria'] ?? '').isNotEmpty)
                                  Text(data['categoria'],
                                      style: const TextStyle(color: _verde, fontSize: 9, fontWeight: FontWeight.w700)),
                                Text(data['nombre'] ?? '',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                    maxLines: 1, overflow: TextOverflow.ellipsis),
                              ])),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(color: Color(0xFFE8F7F1), shape: BoxShape.circle),
                                child: const Icon(Icons.copy_rounded, color: _verde, size: 16),
                              ),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}