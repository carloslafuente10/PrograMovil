import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class _IngReceta {
  String ingredienteId;
  String nombre;
  String cantidad;
  String unidad;
  bool esPrimordial;
  bool esMaestro;

  _IngReceta({
    required this.ingredienteId,
    required this.nombre,
    required this.cantidad,
    required this.unidad,
    this.esPrimordial = false,
    this.esMaestro = false,
  });

  Map<String, dynamic> toMap() => {
    'ingrediente_id': ingredienteId,
    'nombre': nombre,
    'cantidad': double.tryParse(cantidad) ?? 0,
    'unidad': unidad,
    'es_primordial': esPrimordial,
  };
}

class _Paso {
  String instruccion;
  int orden;
  _Paso({required this.instruccion, required this.orden});
  Map<String, dynamic> toMap() => {'instruccion': instruccion, 'orden': orden};
}

//  SCREEN PRINCIPAL

class EditarRecetaScreen extends StatefulWidget {
  final String? docId;
  final Map<String, dynamic>? datosIniciales;
  final bool soloLectura;

  const EditarRecetaScreen({
    super.key,
    this.docId,
    this.datosIniciales,
    this.soloLectura = false,
  });

  @override
  State<EditarRecetaScreen> createState() => _EditarRecetaScreenState();
}

class _EditarRecetaScreenState extends State<EditarRecetaScreen>
    with SingleTickerProviderStateMixin {
  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  static const Color _fondo = Color(0xFFF5F6FA);

  late TabController _tabCtrl;

  late final TextEditingController _nombreCtrl;
  late final TextEditingController _caloriasCtrl;
  late final TextEditingController _tiempoCtrl;
  late final TextEditingController _imagenCtrl;
  late final TextEditingController _porcionCtrl;
  String _categoriaSeleccionada = '';
  // Subcategoría como campo de texto libre
  late final TextEditingController _subcategoriaCtrl;

  List<_IngReceta> _ingredientes = [];
  List<_Paso> _pasos = [];
  List<Map<String, dynamic>> _maestros = [];
  bool _cargandoMaestros = true;
  bool _guardando = false;

  static const List<String> _unidadesSugeridas = [
    'g',
    'kg',
    'ml',
    'L',
    'taza',
    'tazas',
    'cucharada',
    'cucharadita',
    'unidad',
    'unidades',
    'pizca',
    'al gusto',
    'rebanada',
    'rebanadas',
    'trozo',
    'trozos',
    'diente',
    'dientes',
    'hoja',
    'hojas',
    'lata',
    'sobre',
    'paquete',
    'rodaja',
    'rodajas',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    final d = widget.datosIniciales ?? {};
    _nombreCtrl = TextEditingController(text: d['nombre']?.toString() ?? '');
    _caloriasCtrl = TextEditingController(
      text: (d['calorias'] ?? d['calorías'])?.toString() ?? '',
    );
    _tiempoCtrl = TextEditingController(text: d['tiempo']?.toString() ?? '');
    _imagenCtrl = TextEditingController(text: d['imagen']?.toString() ?? '');
    _porcionCtrl = TextEditingController(
      text: d['porcion_base']?.toString() ?? '1',
    );
    _categoriaSeleccionada = d['categoria']?.toString() ?? '';
    // Subcategoría: campo de texto libre, inicializado desde datosIniciales
    _subcategoriaCtrl = TextEditingController(
      text: d['subcategoria']?.toString() ?? '',
    );

    if (d['ingredientes'] != null) {
      for (final item in d['ingredientes'] as List) {
        if (item is Map) {
          _ingredientes.add(
            _IngReceta(
              ingredienteId: item['ingrediente_id']?.toString() ?? '',
              nombre:
                  item['nombre']?.toString() ??
                  item['ingrediente_id']?.toString() ??
                  '',
              cantidad: item['cantidad']?.toString() ?? '',
              unidad: item['unidad']?.toString() ?? '',
              esPrimordial: item['es_primordial'] == true,
              esMaestro:
                  item['ingrediente_id'] != null &&
                  item['ingrediente_id'].toString().isNotEmpty,
            ),
          );
        }
      }
    }
    _cargarMaestros();
    _cargarPasos();
  }

  Future<void> _cargarMaestros() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('ingredientes_maestros')
          .orderBy('nombre')
          .get();
      if (mounted)
        setState(() {
          _maestros = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          _cargandoMaestros = false;
        });
    } catch (_) {
      if (mounted) setState(() => _cargandoMaestros = false);
    }
  }

  // Llave maestra: cubre los 3 formatos que puede tener la BD
  //  - Intento 1: doc cuyo ID == docId de la receta  (guardado nuevo)
  //  - Intento 2: campo 'receta_id'  (sin 's', formato original en BD)
  //  - Intento 3: campo 'recetas_id' (con 's', formato de la corrección anterior)
  Future<void> _cargarPasos() async {
    if (widget.docId == null) {
      debugPrint('[PASOS] docId es null, abortando carga');
      return;
    }
    debugPrint('[PASOS] Buscando pasos para docId: ${widget.docId}');
    try {
      // Intento 1 — doc con el mismo ID que la receta
      final doc = await FirebaseFirestore.instance
          .collection('steps-recetas')
          .doc(widget.docId)
          .get();

      if (doc.exists) {
        debugPrint('[PASOS] Intento 1 OK — doc encontrado por ID');
        _procesarDatosPasos(doc.data());
        return;
      }
      debugPrint(
        '[PASOS] Intento 1 fallido — no existe doc con ID ${widget.docId}',
      );

      // Intento 2 — campo 'receta_id' (sin 's') — formato original de la BD
      final q2 = await FirebaseFirestore.instance
          .collection('steps-recetas')
          .where('receta_id', isEqualTo: widget.docId)
          .limit(1)
          .get();

      if (q2.docs.isNotEmpty) {
        debugPrint('[PASOS] Intento 2 OK — encontrado por campo receta_id');
        _procesarDatosPasos(q2.docs.first.data());
        return;
      }
      debugPrint('[PASOS] Intento 2 fallido — sin resultados para receta_id');

      // Intento 3 — campo 'recetas_id' (con 's') — documentos migrados
      final q3 = await FirebaseFirestore.instance
          .collection('steps-recetas')
          .where('recetas_id', isEqualTo: widget.docId)
          .limit(1)
          .get();

      if (q3.docs.isNotEmpty) {
        debugPrint('[PASOS] Intento 3 OK — encontrado por campo recetas_id');
        _procesarDatosPasos(q3.docs.first.data());
        return;
      }
      debugPrint(
        '[PASOS] ❌ Ningún intento encontró pasos para ${widget.docId}',
      );
    } catch (e) {
      debugPrint('[PASOS] Error al cargar pasos: $e');
    }
  }

  // Auxiliar: convierte el mapa de Firestore en la lista _pasos ordenada
  void _procesarDatosPasos(Map<String, dynamic>? data) {
    if (data == null || data['pasos_ordenados'] == null) return;
    final lista = data['pasos_ordenados'] as List;
    if (mounted) {
      setState(() {
        _pasos =
            lista
                .map(
                  (p) => _Paso(
                    instruccion: p['instruccion']?.toString() ?? '',
                    orden: (p['orden'] as num?)?.toInt() ?? 0,
                  ),
                )
                .toList()
              ..sort((a, b) => a.orden.compareTo(b.orden));
      });
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _nombreCtrl.dispose();
    _caloriasCtrl.dispose();
    _tiempoCtrl.dispose();
    _imagenCtrl.dispose();
    _porcionCtrl.dispose();
    _subcategoriaCtrl.dispose();
    super.dispose();
  }

  // Confirmación antes de guardar
  Future<void> _mostrarConfirmacion() async {
    final ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.lock_outline_rounded,
                color: Color(0xFFFF8F00),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Guardar receta',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Deseas guardar esta receta?',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFFFCC02).withOpacity(0.5),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFFF8F00),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Una vez guardada, la receta no podrá editarse. Solo podrás eliminarla.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.grey[700],
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _verde,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Guardar',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok == true) await _guardar();
  }

  // _guardar: incluye subcategoria y guarda pasos con campo receta_id (consistente con BD)
  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      // Convertir calorias y tiempo a double para consistencia con el modelo de BD
      final double caloriasDouble =
          double.tryParse(_caloriasCtrl.text.trim()) ?? 0.0;
      final double tiempoDouble =
          double.tryParse(_tiempoCtrl.text.trim()) ?? 0.0;

      final datos = {
        'nombre': _nombreCtrl.text.trim(),
        'calorias': caloriasDouble, // ← siempre double
        'tiempo': tiempoDouble, // ← siempre double
        'imagen': _imagenCtrl.text.trim(),
        'categoria': _categoriaSeleccionada,
        'subcategoria': _subcategoriaCtrl.text.trim(),
        'porcion_base': _porcionCtrl.text.trim(),
        'ingredientes': _ingredientes.map((i) => i.toMap()).toList(),
      };

      String docId;
      if (widget.docId != null) {
        await FirebaseFirestore.instance
            .collection('app-recetas-completas')
            .doc(widget.docId)
            .update(datos);
        docId = widget.docId!;
      } else {
        final ref = await FirebaseFirestore.instance
            .collection('app-recetas-completas')
            .add(datos);
        docId = ref.id;
      }

      if (_pasos.isNotEmpty) {
        debugPrint(
          '[GUARDAR] Guardando ${_pasos.length} pasos en steps-recetas/$docId',
        );
        await FirebaseFirestore.instance
            .collection('steps-recetas')
            .doc(docId)
            .set({
              'pasos_ordenados': _pasos.map((p) => p.toMap()).toList(),
              'receta_id': docId, // mismo nombre que usa el resto de la BD
            });
        debugPrint(
          '[GUARDAR] ✅ Pasos guardados correctamente para docId: $docId',
        );
      } else {
        debugPrint('[GUARDAR] ⚠️ Sin pasos para guardar (_pasos está vacío)');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esNueva = widget.docId == null;
    final titulo = widget.soloLectura
        ? 'Detalle de receta'
        : (esNueva ? 'Nueva receta' : 'Editar receta');

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
        title: Text(
          titulo,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        bottom: widget.soloLectura
            ? null
            : TabBar(
                controller: _tabCtrl,
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.info_outline_rounded, size: 18),
                    text: 'Info',
                  ),
                  Tab(
                    icon: Icon(Icons.egg_alt_rounded, size: 18),
                    text: 'Ingredientes',
                  ),
                  Tab(
                    icon: Icon(Icons.format_list_numbered_rounded, size: 18),
                    text: 'Pasos',
                  ),
                ],
              ),
      ),
      body: widget.soloLectura ? _buildSoloLectura() : _buildEditor(),
      bottomNavigationBar: widget.soloLectura
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: ElevatedButton(
                  onPressed: _guardando ? null : _mostrarConfirmacion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _verde,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _guardando
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'Guardar receta',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                ),
              ),
            ),
    );
  }

  //  SOLO LECTURA
  Widget _buildSoloLectura() {
    final d = widget.datosIniciales ?? {};
    final img = _imagenCtrl.text;
    final List ingredientesRaw = d['ingredientes'] ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (img.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
                img,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            _PlaceholderImagen(),
          const SizedBox(height: 20),
          _SeccionTitulo('Información básica'),
          const SizedBox(height: 10),
          _InfoCard(
            children: [
              _InfoFila('Nombre', _nombreCtrl.text),
              _InfoFila('Calorías', '${_caloriasCtrl.text} Cal'),
              _InfoFila('Tiempo', '${_tiempoCtrl.text} min'),
              _InfoFila('Porción base', _porcionCtrl.text),
              _InfoFila('Categoría', _categoriaSeleccionada),
              if (_subcategoriaCtrl.text.isNotEmpty)
                _InfoFila('Subcategoría', _subcategoriaCtrl.text),
            ],
          ),
          const SizedBox(height: 20),
          _SeccionTitulo('Ingredientes (${ingredientesRaw.length})'),
          const SizedBox(height: 10),
          if (ingredientesRaw.isEmpty)
            _VacioMsg('Sin ingredientes')
          else
            ...ingredientesRaw.map((item) {
              if (item is! Map) return const SizedBox();
              final nombre =
                  item['nombre']?.toString() ??
                  item['ingrediente_id']?.toString() ??
                  '—';
              final cantidad = item['cantidad']?.toString() ?? '';
              final unidad = item['unidad']?.toString() ?? '';
              final primordial = item['es_primordial'] == true;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F7F1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.egg_alt_rounded,
                        color: Color(0xFF2D9E73),
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nombre,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                          if (cantidad.isNotEmpty || unidad.isNotEmpty)
                            Text(
                              '$cantidad $unidad'.trim(),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey[500],
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (primordial)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F7F1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Primordial',
                          style: TextStyle(
                            color: Color(0xFF2D9E73),
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            }),
          const SizedBox(height: 20),
          _SeccionTitulo('Pasos de preparación (${_pasos.length})'),
          const SizedBox(height: 10),
          if (_pasos.isEmpty)
            _VacioMsg('Sin pasos registrados')
          else
            ..._pasos.map(
              (p) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D9E73),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${p.orden}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        p.instruccion,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1A1A2E),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEditor() => TabBarView(
    controller: _tabCtrl,
    children: [_tabInfo(), _tabIngredientes(), _tabPasos()],
  );

  // ── TAB INFO ──────────────────────────────────────────────────────────────
  Widget _tabInfo() => SingleChildScrollView(
    padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SeccionTitulo('Imagen'),
        const SizedBox(height: 8),
        _CampoTexto(
          ctrl: _imagenCtrl,
          label: 'URL de imagen',
          icono: Icons.image_rounded,
        ),
        if (_imagenCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              _imagenCtrl.text,
              height: 140,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox(),
            ),
          ),
        ],
        const SizedBox(height: 20),
        _SeccionTitulo('Información básica'),
        const SizedBox(height: 10),
        _CampoTexto(
          ctrl: _nombreCtrl,
          label: 'Nombre de la receta',
          icono: Icons.restaurant_menu_rounded,
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _CampoTexto(
                ctrl: _caloriasCtrl,
                label: 'Calorías',
                icono: Icons.local_fire_department_rounded,
                tipo: TextInputType.number,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _CampoTexto(
                ctrl: _tiempoCtrl,
                label: 'Tiempo (min)',
                icono: Icons.timer_rounded,
                tipo: TextInputType.number,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _CampoTexto(
          ctrl: _porcionCtrl,
          label: 'Porción base (ej: 4 porciones)',
          icono: Icons.people_outline_rounded,
          tipo: TextInputType.number,
        ),
        const SizedBox(height: 20),
        _SeccionTitulo('Categoría'),
        const SizedBox(height: 10),
        _SelectorCategoria(
          seleccionada: _categoriaSeleccionada,
          onSeleccionar: (cat) => setState(() => _categoriaSeleccionada = cat),
        ),
        // Subcategoría: campo de texto libre, siempre visible
        const SizedBox(height: 16),
        _SeccionTitulo('Subcategoría'),
        const SizedBox(height: 4),
        Text(
          'Ej: Sopas, Postres, Jugos... (opcional)',
          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
        ),
        const SizedBox(height: 8),
        _CampoTexto(
          ctrl: _subcategoriaCtrl,
          label: 'Subcategoría',
          icono: Icons.label_outline_rounded,
        ),
      ],
    ),
  );

  // TABLA INGREDIENTES
  Widget _tabIngredientes() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(
          children: [
            Text(
              '${_ingredientes.length} ingredientes',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const Spacer(),
            _BotonAgregar(
              label: 'Agregar',
              onTap: () => _mostrarDialogoIngrediente(),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: _ingredientes.isEmpty
            ? _VacioMsg('Toca "Agregar" para añadir ingredientes')
            : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: _ingredientes.length,
                onReorder: (o, n) => setState(() {
                  if (n > o) n--;
                  _ingredientes.insert(n, _ingredientes.removeAt(o));
                }),
                itemBuilder: (context, i) => _IngredienteItemEditor(
                  key: ValueKey('ing_$i'),
                  ing: _ingredientes[i],
                  onEditar: () => _mostrarDialogoIngrediente(index: i),
                  onEliminar: () => setState(() => _ingredientes.removeAt(i)),
                  onTogglePrimordial: () => setState(
                    () => _ingredientes[i].esPrimordial =
                        !_ingredientes[i].esPrimordial,
                  ),
                ),
              ),
      ),
    ],
  );

  void _mostrarDialogoIngrediente({int? index}) {
    final ing = index != null ? _ingredientes[index] : null;
    Map<String, dynamic>? maestroInicial;
    if (ing != null && ing.esMaestro && ing.ingredienteId.isNotEmpty) {
      maestroInicial = _maestros.firstWhere(
        (m) => m['id'] == ing.ingredienteId,
        orElse: () => <String, dynamic>{},
      );
      if (maestroInicial.isEmpty) maestroInicial = null;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DialogoIngrediente(
        maestros: _maestros,
        cargandoMaestros: _cargandoMaestros,
        unidadesSugeridas: _unidadesSugeridas,
        ingInicial: ing,
        maestroInicial: maestroInicial,
        onGuardar: (nuevo) => setState(() {
          if (index != null)
            _ingredientes[index] = nuevo;
          else
            _ingredientes.add(nuevo);
        }),
        onNuevoMaestroCreado: (nuevo) => setState(() => _maestros.add(nuevo)),
      ),
    );
  }

  // TAB PASOS
  Widget _tabPasos() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
        child: Row(
          children: [
            Text(
              '${_pasos.length} pasos',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const Spacer(),
            _BotonAgregar(label: 'Agregar paso', onTap: _mostrarDialogoPaso),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Expanded(
        child: _pasos.isEmpty
            ? _VacioMsg('Toca "Agregar paso" para añadir instrucciones')
            : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                itemCount: _pasos.length,
                onReorder: (o, n) => setState(() {
                  if (n > o) n--;
                  _pasos.insert(n, _pasos.removeAt(o));
                  for (int i = 0; i < _pasos.length; i++)
                    _pasos[i] = _Paso(
                      instruccion: _pasos[i].instruccion,
                      orden: i + 1,
                    );
                }),
                itemBuilder: (context, i) => _PasoItemEditor(
                  key: ValueKey('paso_$i'),
                  paso: _pasos[i],
                  numero: i + 1,
                  onEditar: () => _mostrarDialogoPaso(index: i),
                  onEliminar: () => setState(() {
                    _pasos.removeAt(i);
                    for (int j = 0; j < _pasos.length; j++)
                      _pasos[j] = _Paso(
                        instruccion: _pasos[j].instruccion,
                        orden: j + 1,
                      );
                  }),
                ),
              ),
      ),
    ],
  );

  void _mostrarDialogoPaso({int? index}) {
    final paso = index != null ? _pasos[index] : null;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DialogoPaso(
        pasoInicial: paso,
        ingredientes: _ingredientes,
        numeroPaso: index != null ? index + 1 : _pasos.length + 1,
        onGuardar: (instruccion) => setState(() {
          if (index != null)
            _pasos[index] = _Paso(instruccion: instruccion, orden: index + 1);
          else
            _pasos.add(
              _Paso(instruccion: instruccion, orden: _pasos.length + 1),
            );
        }),
      ),
    );
  }
}

//  INGREDIENTE

class _DialogoIngrediente extends StatefulWidget {
  final List<Map<String, dynamic>> maestros;
  final bool cargandoMaestros;
  final List<String> unidadesSugeridas;
  final _IngReceta? ingInicial;
  final Map<String, dynamic>? maestroInicial;
  final ValueChanged<_IngReceta> onGuardar;
  final ValueChanged<Map<String, dynamic>> onNuevoMaestroCreado;

  const _DialogoIngrediente({
    required this.maestros,
    required this.cargandoMaestros,
    required this.unidadesSugeridas,
    required this.onGuardar,
    required this.onNuevoMaestroCreado,
    this.ingInicial,
    this.maestroInicial,
  });

  @override
  State<_DialogoIngrediente> createState() => _DialogoIngredienteState();
}

class _DialogoIngredienteState extends State<_DialogoIngrediente> {
  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);

  final _busquedaCtrl = TextEditingController();
  final _cantidadCtrl = TextEditingController();
  final _unidadCtrl = TextEditingController();
  final _nombreLibreCtrl = TextEditingController();

  List<Map<String, dynamic>> _filtrados = [];
  Map<String, dynamic>? _maestroSeleccionado;
  bool _esLibre = false;
  bool _esPrimordial = false;
  bool _mostrarSugerenciasUnidad = false;
  List<String> _sugerenciasUnidadFiltradas = [];

  @override
  void initState() {
    super.initState();
    _filtrados = widget.maestros;
    _sugerenciasUnidadFiltradas = widget.unidadesSugeridas;

    if (widget.ingInicial != null) {
      final ing = widget.ingInicial!;
      _cantidadCtrl.text = ing.cantidad;
      _unidadCtrl.text = ing.unidad;
      _esPrimordial = ing.esPrimordial;
      if (ing.esMaestro && widget.maestroInicial != null) {
        _maestroSeleccionado = widget.maestroInicial;
        _busquedaCtrl.text = widget.maestroInicial!['nombre']?.toString() ?? '';
      } else if (!ing.esMaestro) {
        _esLibre = true;
        _nombreLibreCtrl.text = ing.nombre;
      }
    }

    _unidadCtrl.addListener(() {
      final q = _unidadCtrl.text.toLowerCase();
      setState(() {
        _mostrarSugerenciasUnidad = _unidadCtrl.text.isNotEmpty;
        _sugerenciasUnidadFiltradas = q.isEmpty
            ? widget.unidadesSugeridas
            : widget.unidadesSugeridas
                  .where((u) => u.toLowerCase().contains(q))
                  .toList();
      });
    });
  }

  @override
  void dispose() {
    _busquedaCtrl.dispose();
    _cantidadCtrl.dispose();
    _unidadCtrl.dispose();
    _nombreLibreCtrl.dispose();
    super.dispose();
  }

  void _filtrar(String q) => setState(() {
    _filtrados = q.isEmpty
        ? widget.maestros
        : widget.maestros
              .where(
                (m) =>
                    m['nombre']?.toString().toLowerCase().contains(
                      q.toLowerCase(),
                    ) ??
                    false,
              )
              .toList();
  });

  Future<void> _crearNuevoMaestro() async {
    final nombre = _nombreLibreCtrl.text.trim();
    if (nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Escribe primero el nombre del ingrediente'),
        ),
      );
      return;
    }
    await showDialog(
      context: context,
      builder: (_) => _DialogoCrearMaestro(
        nombreInicial: nombre,
        onCrear: (datos) async {
          try {
            final ref = await FirebaseFirestore.instance
                .collection('ingredientes_maestros')
                .add(datos);
            final nuevoMaestro = {'id': ref.id, ...datos};
            widget.onNuevoMaestroCreado(nuevoMaestro);
            setState(() {
              _maestroSeleccionado = nuevoMaestro;
              _esLibre = false;
              _busquedaCtrl.text = datos['nombre']?.toString() ?? '';
            });
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '"${datos['nombre']}" agregado a ingredientes maestros',
                  ),
                  backgroundColor: _verde,
                ),
              );
          } catch (e) {
            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: Colors.red,
                ),
              );
          }
        },
      ),
    );
  }

  void _guardar() {
    if (!_esLibre && _maestroSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un ingrediente o usa uno libre'),
        ),
      );
      return;
    }
    if (_esLibre && _nombreLibreCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe el nombre del ingrediente')),
      );
      return;
    }
    final ingrediente = _esLibre
        ? _IngReceta(
            ingredienteId: _nombreLibreCtrl.text
                .trim()
                .toLowerCase()
                .replaceAll(' ', '-'),
            nombre: _nombreLibreCtrl.text.trim(),
            cantidad: _cantidadCtrl.text.trim(),
            unidad: _unidadCtrl.text.trim(),
            esPrimordial: _esPrimordial,
            esMaestro: false,
          )
        : _IngReceta(
            ingredienteId: _maestroSeleccionado!['id']?.toString() ?? '',
            nombre: _maestroSeleccionado!['nombre']?.toString() ?? '',
            cantidad: _cantidadCtrl.text.trim(),
            unidad: _unidadCtrl.text.trim(),
            esPrimordial: _esPrimordial,
            esMaestro: true,
          );

    widget.onGuardar(ingrediente);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const Text(
                    'Ingrediente',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() {
                      _esLibre = !_esLibre;
                      _maestroSeleccionado = null;
                      _busquedaCtrl.clear();
                      _nombreLibreCtrl.clear();
                    }),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _esLibre ? Colors.orange[50] : _verdeClaro,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _esLibre
                              ? Colors.orange[300]!
                              : _verde.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        _esLibre ? '✎ Libre' : '🔍 Maestro',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _esLibre ? Colors.orange[800] : _verde,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ingrediente libre
                    if (_esLibre) ...[
                      const _Label('Nombre libre'),
                      const SizedBox(height: 8),
                      _Campo(
                        ctrl: _nombreLibreCtrl,
                        hint: 'Ej: Pan tostado integral',
                        icono: Icons.edit_rounded,
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _crearNuevoMaestro,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0FFF8),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _verde.withOpacity(0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                color: _verde,
                                size: 18,
                              ),
                              SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Guardar en ingredientes maestros',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12.5,
                                        color: _verde,
                                      ),
                                    ),
                                    Text(
                                      'Estará disponible para otras recetas',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                color: _verde,
                                size: 12,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Ingrediente maestro
                      const _Label('Buscar en ingredientes maestros'),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _busquedaCtrl,
                        onChanged: _filtrar,
                        decoration: InputDecoration(
                          hintText: 'Buscar ingrediente...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: _verde,
                            size: 18,
                          ),
                          filled: true,
                          fillColor: const Color(0xFFF5F6FA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: _busquedaCtrl.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _busquedaCtrl.clear();
                                    _filtrar('');
                                  },
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_maestroSeleccionado != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _verdeClaro,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _verde.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle_rounded,
                                color: _verde,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _maestroSeleccionado!['nombre']?.toString() ??
                                    '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _verde,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _maestroSeleccionado = null),
                                child: const Icon(
                                  Icons.close_rounded,
                                  size: 16,
                                  color: _verde,
                                ),
                              ),
                            ],
                          ),
                        )
                      else if (widget.cargandoMaestros)
                        const Center(
                          child: CircularProgressIndicator(color: _verde),
                        )
                      else
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[200]!),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: _filtrados.length,
                              itemBuilder: (context, i) {
                                final m = _filtrados[i];
                                return ListTile(
                                  dense: true,
                                  leading: const Icon(
                                    Icons.egg_alt_rounded,
                                    color: _verde,
                                    size: 20,
                                  ),
                                  title: Text(
                                    m['nombre']?.toString() ?? '',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: m['categoria'] != null
                                      ? Text(
                                          m['categoria'].toString(),
                                          style: const TextStyle(fontSize: 11),
                                        )
                                      : null,
                                  onTap: () => setState(() {
                                    _maestroSeleccionado = m;
                                    _busquedaCtrl.text =
                                        m['nombre']?.toString() ?? '';
                                  }),
                                );
                              },
                            ),
                          ),
                        ),
                    ],

                    const SizedBox(height: 20),
                    const _Label('Cantidad'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _cantidadCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Ej: 200  /  1  /  al gusto',
                        prefixIcon: const Icon(
                          Icons.scale_rounded,
                          color: _verde,
                          size: 18,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF5F6FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                    const _Label('Unidad de medida'),
                    const SizedBox(height: 4),
                    Text(
                      'Ej: "g", "taza", "pan tostado", "hoja"',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _unidadCtrl,
                      onTap: () =>
                          setState(() => _mostrarSugerenciasUnidad = true),
                      onTapOutside: (_) =>
                          setState(() => _mostrarSugerenciasUnidad = false),
                      decoration: InputDecoration(
                        hintText: 'Ej: g, taza, hoja...',
                        prefixIcon: const Icon(
                          Icons.straighten_rounded,
                          color: _verde,
                          size: 18,
                        ),
                        suffixIcon: _unidadCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _unidadCtrl.clear();
                                  setState(() {});
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: const Color(0xFFF5F6FA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: _verde,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    if (_mostrarSugerenciasUnidad &&
                        _sugerenciasUnidadFiltradas.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: _sugerenciasUnidadFiltradas
                            .take(12)
                            .map(
                              (u) => GestureDetector(
                                onTap: () => setState(() {
                                  _unidadCtrl.text = u;
                                  _mostrarSugerenciasUnidad = false;
                                }),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 11,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: _verdeClaro,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _verde.withOpacity(0.25),
                                    ),
                                  ),
                                  child: Text(
                                    u,
                                    style: const TextStyle(
                                      color: _verde,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],

                    const SizedBox(height: 20),
                    GestureDetector(
                      onTap: () =>
                          setState(() => _esPrimordial = !_esPrimordial),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: _esPrimordial
                              ? _verdeClaro
                              : const Color(0xFFF5F6FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _esPrimordial
                                ? _verde.withOpacity(0.4)
                                : Colors.grey.shade200,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _esPrimordial
                                  ? Icons.star_rounded
                                  : Icons.star_outline_rounded,
                              color: _esPrimordial ? _verde : Colors.grey[400],
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ingrediente primordial',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    'El usuario necesita tenerlo sí o sí para cocinar',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _esPrimordial,
                              onChanged: (v) =>
                                  setState(() => _esPrimordial = v),
                              activeColor: _verde,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _guardar,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _verde,
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Agregar ingrediente',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
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

//  DIÁLOGO CREAR MAESTRO

class _DialogoCrearMaestro extends StatefulWidget {
  final String nombreInicial;
  final ValueChanged<Map<String, dynamic>> onCrear;
  const _DialogoCrearMaestro({
    required this.nombreInicial,
    required this.onCrear,
  });
  @override
  State<_DialogoCrearMaestro> createState() => _DialogoCrearMaestroState();
}

class _DialogoCrearMaestroState extends State<_DialogoCrearMaestro> {
  static const Color _verde = Color(0xFF2D9E73);
  late final TextEditingController _nombreCtrl;
  final _fotoCtrl = TextEditingController();
  final _sustCtrl = TextEditingController();
  String _cat = '';
  final List<String> _sustitutos = [];

  static const List<String> _cats = [
    'Proteínas',
    'Grasas',
    'Carbohidratos',
    'Lácteos',
    'Frutas',
    'Verduras',
    'Especias',
    'Legumbres',
    'Otros',
  ];

  @override
  void initState() {
    super.initState();
    _nombreCtrl = TextEditingController(text: widget.nombreInicial);
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _fotoCtrl.dispose();
    _sustCtrl.dispose();
    super.dispose();
  }

  void _addSust() {
    final s = _sustCtrl.text.trim();
    if (s.isNotEmpty && !_sustitutos.contains(s))
      setState(() {
        _sustitutos.add(s);
        _sustCtrl.clear();
      });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    title: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F7F1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.add_circle_rounded, color: _verde, size: 20),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Nuevo ingrediente maestro',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
        ),
      ],
    ),
    content: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const _Label('Nombre *'),
          const SizedBox(height: 6),
          _Campo(
            ctrl: _nombreCtrl,
            hint: 'Ej: Aceite de girasol',
            icono: Icons.label_rounded,
          ),
          const SizedBox(height: 14),
          const _Label('URL de foto (opcional)'),
          const SizedBox(height: 6),
          _Campo(
            ctrl: _fotoCtrl,
            hint: 'https://...',
            icono: Icons.image_rounded,
          ),
          const SizedBox(height: 14),
          const _Label('Categoría'),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _cats.map((c) {
              final sel = c == _cat;
              return GestureDetector(
                onTap: () => setState(() => _cat = sel ? '' : c),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: sel ? _verde : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    c,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : Colors.grey[700],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          const _Label('Sustitutos (opcional)'),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _Campo(
                  ctrl: _sustCtrl,
                  hint: 'Ej: manteca',
                  icono: Icons.swap_horiz_rounded,
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _addSust,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F7F1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.add_rounded, color: _verde, size: 20),
                ),
              ),
            ],
          ),
          if (_sustitutos.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: _sustitutos
                  .map(
                    (s) => Chip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      deleteIcon: const Icon(Icons.close, size: 14),
                      onDeleted: () => setState(() => _sustitutos.remove(s)),
                      backgroundColor: const Color(0xFFE8F7F1),
                      side: BorderSide.none,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
      ),
      ElevatedButton(
        onPressed: () {
          if (_nombreCtrl.text.trim().isEmpty) return;
          widget.onCrear({
            'nombre': _nombreCtrl.text.trim(),
            'foto': _fotoCtrl.text.trim(),
            'categoria': _cat,
            'sustitutos': _sustitutos,
          });
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: _verde,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Text(
          'Crear ingrediente',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

//  DIÁLOGO PASO

class _DialogoPaso extends StatefulWidget {
  final _Paso? pasoInicial;
  final List<_IngReceta> ingredientes;
  final int numeroPaso;
  final ValueChanged<String> onGuardar;
  const _DialogoPaso({
    required this.onGuardar,
    required this.ingredientes,
    required this.numeroPaso,
    this.pasoInicial,
  });
  @override
  State<_DialogoPaso> createState() => _DialogoPasoState();
}

class _DialogoPasoState extends State<_DialogoPaso> {
  static const Color _verde = Color(0xFF2D9E73);
  late final TextEditingController _ctrl;

  List<String> get _sugerencias {
    final ings = widget.ingredientes.map((i) => i.nombre).toList();
    final n = widget.numeroPaso;
    final p = ings.isNotEmpty ? ings[0] : 'los ingredientes';
    final s = ings.length > 1 ? ings[1] : 'el resto';
    if (n == 1)
      return [
        'Lava y prepara $p correctamente antes de usar.',
        'Pesa y mide todos los ingredientes: $p${ings.length > 1 ? ', $s' : ''} y el resto.',
        'Precalienta el horno y organiza los utensilios sobre la mesa.',
      ];
    if (n == 2)
      return [
        'Corta $p en trozos del tamaño indicado en la receta.',
        'Mezcla $p con $s hasta obtener una mezcla uniforme.',
        'Calienta una sartén a fuego medio y añade $p.',
      ];
    if (n == 3)
      return [
        'Agrega $s a la preparación y mezcla bien.',
        'Cocina a fuego bajo, removiendo ocasionalmente.',
        'Sazona con sal y pimienta al gusto.',
      ];
    return [
      'Verifica la cocción y ajusta el calor si es necesario.',
      'Agrega los ingredientes restantes y mezcla suavemente.',
      'Retira del fuego y deja reposar 2 minutos antes de servir.',
      'Sirve inmediatamente acompañado de tu preferencia.',
    ];
  }

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.pasoInicial?.instruccion ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
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
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _verde,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.numeroPaso}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Instrucción del paso',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Describe este paso con detalle...',
                filled: true,
                fillColor: const Color(0xFFF5F6FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _verde, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(14),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: const [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  color: Color(0xFFFF8F00),
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'Sugerencias para este paso',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._sugerencias.map(
              (s) => GestureDetector(
                onTap: () => setState(() {
                  final actual = _ctrl.text.trim();
                  _ctrl.text = actual.isEmpty ? s : '$actual $s';
                  _ctrl.selection = TextSelection.fromPosition(
                    TextPosition(offset: _ctrl.text.length),
                  );
                }),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFFFCC02).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          s,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey[700],
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Color(0xFFFF8F00),
                        size: 18,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_ctrl.text.trim().isEmpty) return;
                  widget.onGuardar(_ctrl.text.trim());
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _verde,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Guardar paso',
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

//  ITEMS DE LISTA

class _IngredienteItemEditor extends StatelessWidget {
  final _IngReceta ing;
  final VoidCallback onEditar, onEliminar, onTogglePrimordial;
  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  const _IngredienteItemEditor({
    super.key,
    required this.ing,
    required this.onEditar,
    required this.onEliminar,
    required this.onTogglePrimordial,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        const Icon(Icons.drag_handle_rounded, color: Colors.grey, size: 18),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _verdeClaro,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            ing.esMaestro ? Icons.verified_rounded : Icons.egg_alt_rounded,
            color: _verde,
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ing.nombre,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                  color: Color(0xFF1A1A2E),
                ),
              ),
              Text(
                '${ing.cantidad} ${ing.unidad}'.trim().isEmpty
                    ? 'Sin cantidad'
                    : '${ing.cantidad} ${ing.unidad}'.trim(),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
        if (ing.esPrimordial)
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
            decoration: BoxDecoration(
              color: _verdeClaro,
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Text(
              '★',
              style: TextStyle(color: _verde, fontSize: 10),
            ),
          ),
        GestureDetector(
          onTap: onEditar,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: _verdeClaro,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.edit_rounded, color: _verde, size: 14),
          ),
        ),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onEliminar,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.delete_rounded,
              color: Color(0xFFE53935),
              size: 14,
            ),
          ),
        ),
      ],
    ),
  );
}

class _PasoItemEditor extends StatelessWidget {
  final _Paso paso;
  final int numero;
  final VoidCallback onEditar, onEliminar;
  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  const _PasoItemEditor({
    super.key,
    required this.paso,
    required this.numero,
    required this.onEditar,
    required this.onEliminar,
  });
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.drag_handle_rounded, color: Colors.grey, size: 18),
        const SizedBox(width: 8),
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: _verde,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Text(
              '$numero',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            paso.instruccion,
            style: const TextStyle(
              fontSize: 12.5,
              color: Color(0xFF1A1A2E),
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 6),
        Column(
          children: [
            GestureDetector(
              onTap: onEditar,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: _verdeClaro,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.edit_rounded, color: _verde, size: 14),
              ),
            ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onEliminar,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_rounded,
                  color: Color(0xFFE53935),
                  size: 14,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

//  SELECTOR CATEGORÍA

class _SelectorCategoria extends StatelessWidget {
  final String seleccionada;
  final ValueChanged<String> onSeleccionar;
  static const Color _verde = Color(0xFF2D9E73);
  const _SelectorCategoria({
    required this.seleccionada,
    required this.onSeleccionar,
  });
  @override
  Widget build(BuildContext context) => StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('app-Categorías')
        .orderBy('nombre')
        .snapshots(),
    builder: (context, snapshot) {
      if (!snapshot.hasData)
        return const SizedBox(
          height: 40,
          child: Center(
            child: CircularProgressIndicator(color: _verde, strokeWidth: 2),
          ),
        );
      final cats = snapshot.data!.docs
          .map((d) => d['nombre']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      return SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: cats.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (context, i) {
            final cat = cats[i];
            final activa = cat == seleccionada;
            return GestureDetector(
              onTap: () => onSeleccionar(cat),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: activa ? _verde : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: activa ? _verde : Colors.grey.shade300,
                  ),
                ),
                child: Text(
                  cat,
                  style: TextStyle(
                    color: activa ? Colors.white : Colors.grey[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}

//  WIDGETS AUXILIARES

class _Label extends StatelessWidget {
  final String texto;
  const _Label(this.texto);
  @override
  Widget build(BuildContext context) => Text(
    texto,
    style: const TextStyle(
      fontWeight: FontWeight.w600,
      fontSize: 12.5,
      color: Color(0xFF1A1A2E),
    ),
  );
}

class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icono;
  const _Campo({required this.ctrl, required this.hint, required this.icono});
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    style: const TextStyle(fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12),
      prefixIcon: Icon(icono, color: const Color(0xFF2D9E73), size: 16),
      filled: true,
      fillColor: const Color(0xFFF5F6FA),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
  );
}

class _SeccionTitulo extends StatelessWidget {
  final String titulo;
  const _SeccionTitulo(this.titulo);
  @override
  Widget build(BuildContext context) => Text(
    titulo,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 14,
      color: Color(0xFF1A1A2E),
    ),
  );
}

class _InfoFila extends StatelessWidget {
  final String label, valor;
  const _InfoFila(this.label, this.valor);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(
              color: Color(0xFF1A1A2E),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    ),
  );
}

class _PlaceholderImagen extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 120,
    decoration: BoxDecoration(
      color: const Color(0xFFE8F7F1),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Center(
      child: Icon(Icons.image_rounded, color: Color(0xFF2D9E73), size: 40),
    ),
  );
}

class _VacioMsg extends StatelessWidget {
  final String msg;
  const _VacioMsg(this.msg);
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 48, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text(
            msg,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _BotonAgregar extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  const _BotonAgregar({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: _verdeClaro,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const Icon(Icons.add_rounded, color: _verde, size: 16),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: _verde,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CampoTexto extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final IconData icono;
  final TextInputType tipo;
  const _CampoTexto({
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
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2D9E73), width: 1.5),
      ),
      labelStyle: TextStyle(color: Colors.grey[500], fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
    ),
  );
}
