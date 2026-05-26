import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../servicios/historial_servicio.dart';

String _pluralizarUnidad(String cantidad, String unidad) {
  if (unidad.isEmpty) return unidad;
  // Invariables: nunca se pluralizan
  const invariables = {'g', 'kg', 'ml', 'l', 'oz', 'lb', 'al gusto', 'c/n'};
  if (invariables.contains(unidad.toLowerCase())) return unidad;
  final double? valor = double.tryParse(cantidad.replaceAll(',', '.'));
  final bool plural = valor == null || valor > 1;
  const plurales = {
    'taza': 'tazas',
    'cucharada': 'cucharadas',
    'cucharadita': 'cucharaditas',
    'cucharita': 'cucharitas',
    'unidad': 'unidades',
    'pizca': 'pizcas',
    'rebanada': 'rebanadas',
    'trozo': 'trozos',
    'diente': 'dientes',
    'hoja': 'hojas',
    'lata': 'latas',
    'sobre': 'sobres',
    'paquete': 'paquetes',
    'rodaja': 'rodajas',
    'litro': 'litros',
    'libra': 'libras',
  };
  const singulares = {
    'tazas': 'taza',
    'cucharadas': 'cucharada',
    'cucharaditas': 'cucharadita',
    'cucharitas': 'cucharita',
    'unidades': 'unidad',
    'pizcas': 'pizca',
    'rebanadas': 'rebanada',
    'trozos': 'trozo',
    'dientes': 'diente',
    'hojas': 'hoja',
    'latas': 'lata',
    'sobres': 'sobre',
    'paquetes': 'paquete',
    'rodajas': 'rodaja',
    'litros': 'litro',
    'libras': 'libra',
  };
  final base = singulares[unidad.toLowerCase()] ?? unidad;
  return plural ? (plurales[base.toLowerCase()] ?? base) : base;
}

// ── Modelos ───────────────────────────────────────────────────────────────────

class _IngReceta {
  String ingredienteId; // ID en ingredientes_maestros (o generado si es nuevo)
  String nombre;
  String cantidad;
  String unidad;
  bool esPrimordial;
  bool esMaestro; // true = existe en BD, false = recién creado
  // Campos extra para cuando se crea un ingrediente nuevo
  String foto;
  String categoria;
  List<String> sustitutos;

  _IngReceta({
    required this.ingredienteId,
    required this.nombre,
    required this.cantidad,
    required this.unidad,
    this.esPrimordial = false,
    this.esMaestro = true,
    this.foto = '',
    this.categoria = '',
    this.sustitutos = const [],
  });

  Map<String, dynamic> toMap() => {
    'ingrediente_id': ingredienteId,
    'nombre': nombre,
    'cantidad': double.tryParse(cantidad.replaceAll(',', '.')) ?? 0,
    'unidad': unidad,
    'es_primordial': esPrimordial,
  };
}

class _Paso {
  String instruccion;
  _Paso({required this.instruccion});
  Map<String, dynamic> toMap(int orden) => {
    'instruccion': instruccion,
    'orden': orden,
  };
}

// ── Pantalla principal ────────────────────────────────────────────────────────

class CrearRecetaAdminScreen extends StatefulWidget {
  const CrearRecetaAdminScreen({super.key});

  @override
  State<CrearRecetaAdminScreen> createState() => _CrearRecetaAdminScreenState();
}

class _CrearRecetaAdminScreenState extends State<CrearRecetaAdminScreen>
    with SingleTickerProviderStateMixin {
  // ── Paleta ──────────────────────────────────────────────────────────────────
  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  static const Color _fondo = Color(0xFFF5F6FA);
  static const Color _rojo = Color(0xFFE53935);

  // ── Controladores ───────────────────────────────────────────────────────────
  late TabController _tabCtrl;
  final _nombreCtrl = TextEditingController();
  final _caloriasCtrl = TextEditingController();
  final _tiempoCtrl = TextEditingController();
  final _imagenCtrl = TextEditingController();
  final _porcionCtrl = TextEditingController(text: '1');
  final _subcategoriaCtrl = TextEditingController();

  String _categoriaSeleccionada = '';
  List<_IngReceta> _ingredientes = [];
  List<_Paso> _pasos = [];

  // ── Maestros ─────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _maestros = [];
  bool _cargandoMaestros = true;

  bool _guardando = false;

  static const List<String> _unidades = [
    'g',
    'kg',
    'ml',
    'L',
    'litro',
    'libra',
    'taza',
    'cucharada',
    'cucharadita',
    'unidad',
    'pizca',
    'al gusto',
    'rebanada',
    'trozo',
    'diente',
    'hoja',
    'lata',
    'sobre',
    'paquete',
    'rodaja',
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _cargarMaestros();
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

  Future<void> _cargarMaestros() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('ingredientes_maestros')
          .orderBy('nombre')
          .get();
      if (mounted) {
        setState(() {
          _maestros = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
          _cargandoMaestros = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _cargandoMaestros = false);
    }
  }

  // ── Guardar ──────────────────────────────────────────────────────────────────

  Future<void> _confirmarYGuardar() async {
    // Validaciones básicas
    if (_nombreCtrl.text.trim().isEmpty) {
      _snack('El nombre de la receta es obligatorio', isError: true);
      _tabCtrl.animateTo(0);
      return;
    }
    if (_ingredientes.isEmpty) {
      _snack('Agrega al menos un ingrediente', isError: true);
      _tabCtrl.animateTo(1);
      return;
    }
    if (_pasos.isEmpty) {
      _snack('Agrega al menos un paso de preparación', isError: true);
      _tabCtrl.animateTo(2);
      return;
    }

    // Advertencia de no-edición
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(
              Icons.lock_outline_rounded,
              color: Color(0xFFE53935),
              size: 22,
            ),
            SizedBox(width: 8),
            Text(
              'Atención',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
            ),
          ],
        ),
        content: const Text(
          'Una vez guardada, esta receta NO podrá ser editada desde el panel de administración.\n\n'
          '¿Deseas continuar y publicarla?',
          style: TextStyle(fontSize: 14, height: 1.5),
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
            ),
            child: const Text(
              'Publicar receta',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    await _guardar();
  }

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      // 1. Crear ingredientes nuevos (no maestros) en ingredientes_maestros
      for (final ing in _ingredientes) {
        if (!ing.esMaestro) {
          final id = ing.ingredienteId.isNotEmpty
              ? ing.ingredienteId
              : ing.nombre.toLowerCase().replaceAll(' ', '-');
          ing.ingredienteId = id;
          await FirebaseFirestore.instance
              .collection('ingredientes_maestros')
              .doc(id)
              .set({
                'nombre': ing.nombre,
                'categoria': 'otros',
                'foto': '',
                'sustitutos': [],
              }, SetOptions(merge: true));
        }
      }

      // 2. Crear doc en app-recetas-completas
      final docRef = await FirebaseFirestore.instance
          .collection('app-recetas-completas')
          .add({
            'nombre': _nombreCtrl.text.trim(),
            'calorias': _caloriasCtrl.text.trim(),
            'tiempo': _tiempoCtrl.text.trim(),
            'imagen': _imagenCtrl.text.trim(),
            'categoria': _categoriaSeleccionada,
            'subcategoria': _subcategoriaCtrl.text.trim(),
            'porcion_base': int.tryParse(_porcionCtrl.text.trim()) ?? 1,
            'ingredientes': _ingredientes.map((i) => i.toMap()).toList(),
            'creado_por': 'admin',
            'fecha_creacion': FieldValue.serverTimestamp(),
          });

      // 3. Guardar pasos en steps-recetas (doc con el mismo ID)
      final pasosOrdenados = _pasos
          .asMap()
          .entries
          .map((e) => e.value.toMap(e.key + 1))
          .toList();
      await FirebaseFirestore.instance
          .collection('steps-recetas')
          .doc(docRef.id)
          .set({'pasos_ordenados': pasosOrdenados});
          await HistorialService
    .registrar(

  accion:
      'Creó receta ${_nombreCtrl.text.trim()}',

  tipo:
      'recetas',
);

      if (mounted) {
        _snack('¡Receta publicada exitosamente!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _snack('Error al guardar: $e', isError: true);
        setState(() => _guardando = false);
      }
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? _rojo : _verde,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

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
          'Nueva receta',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          if (_guardando)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _confirmarYGuardar,
                icon: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Publicar',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
          ),
          tabs: const [
            Tab(text: 'Info general'),
            Tab(text: 'Ingredientes'),
            Tab(text: 'Pasos'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [_TabInfo(), _TabIngredientes(), _TabPasos()],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 1: Información general
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _TabInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Aviso de solo-creación
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFB74D), width: 1),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFFE65100),
                  size: 16,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recuerda: una vez publicada, esta receta no podrá ser editada.',
                    style: TextStyle(
                      color: Color(0xFFE65100),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Imagen preview
          if (_imagenCtrl.text.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.network(
                _imagenCtrl.text.trim(),
                height: 160,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _PlaceholderImg(),
              ),
            ),
            const SizedBox(height: 12),
          ] else
            _PlaceholderImg(),

          const SizedBox(height: 12),
          _Campo(
            ctrl: _imagenCtrl,
            hint: 'URL de la imagen',
            icono: Icons.image_rounded,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          _Campo(
            ctrl: _nombreCtrl,
            hint: 'Nombre de la receta *',
            icono: Icons.restaurant_menu_rounded,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Campo(
                  ctrl: _caloriasCtrl,
                  hint: 'Calorías',
                  icono: Icons.local_fire_department_rounded,
                  tipo: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _Campo(
                  ctrl: _tiempoCtrl,
                  hint: 'Tiempo (min)',
                  icono: Icons.timer_outlined,
                  tipo: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _Campo(
            ctrl: _porcionCtrl,
            hint: 'Porciones base',
            icono: Icons.people_outline_rounded,
            tipo: TextInputType.number,
          ),
          const SizedBox(height: 16),

          // Categoría
          const _Label('Categoría'),
          const SizedBox(height: 8),
          _SelectorCategorias(
            seleccionada: _categoriaSeleccionada,
            onSeleccionar: (c) => setState(() => _categoriaSeleccionada = c),
          ),
          const SizedBox(height: 12),
          _Campo(
            ctrl: _subcategoriaCtrl,
            hint: 'Subcategoría (ej: comida asiática)',
            icono: Icons.label_outline_rounded,
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 2: Ingredientes
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _TabIngredientes() {
    return Column(
      children: [
        // Encabezado con botón agregar
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Text(
                '${_ingredientes.length} ingrediente${_ingredientes.length != 1 ? 's' : ''}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _BotonAgregar(
                label: 'Agregar',
                onTap: () => _mostrarSelectorIngrediente(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Lista
        Expanded(
          child: _ingredientes.isEmpty
              ? const _VacioMsg(
                  'Toca "Agregar" para añadir\ningredientes a la receta',
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                  itemCount: _ingredientes.length,
                  onReorder: (old, nuevo) {
                    setState(() {
                      if (nuevo > old) nuevo--;
                      final item = _ingredientes.removeAt(old);
                      _ingredientes.insert(nuevo, item);
                    });
                  },
                  itemBuilder: (context, i) {
                    final ing = _ingredientes[i];
                    return _TarjetaIngrediente(
                      key: ValueKey('ing_$i'),
                      ing: ing,
                      unidades: _unidades,
                      onCambioCantidad: (v) => setState(() => ing.cantidad = v),
                      onCambioUnidad: (v) => setState(() => ing.unidad = v),
                      onTogglePrimordial: () =>
                          setState(() => ing.esPrimordial = !ing.esPrimordial),
                      onEliminar: () =>
                          setState(() => _ingredientes.removeAt(i)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Selector de ingrediente maestro / nuevo ───────────────────────────────────

  void _mostrarSelectorIngrediente(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _ModalIngrediente(
        maestros: _maestros,
        cargando: _cargandoMaestros,
        onSeleccionado: (ing) {
          setState(() => _ingredientes.add(ing));
        },
        onNuevoCreado: (ing) async {
          // Guardar en ingredientes_maestros con todos los campos
          final id = ing.ingredienteId;
          await FirebaseFirestore.instance
              .collection('ingredientes_maestros')
              .doc(id)
              .set({
                'nombre': ing.nombre,
                'categoria': ing.categoria.isNotEmpty ? ing.categoria : 'otros',
                'foto': ing.foto,
                'sustitutos': ing.sustitutos,
              }, SetOptions(merge: true));
          // Actualizar la lista local de maestros para búsquedas futuras
          setState(() {
            _maestros.add({'id': id, 'nombre': ing.nombre, 'foto': ing.foto});
            _ingredientes.add(ing..esMaestro = true);
          });
          _snack('Ingrediente "${ing.nombre}" creado en la base de datos');
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════════
  // TAB 3: Pasos
  // ══════════════════════════════════════════════════════════════════════════════

  Widget _TabPasos() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            children: [
              Text(
                '${_pasos.length} paso${_pasos.length != 1 ? 's' : ''}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              _BotonAgregar(
                label: 'Agregar paso',
                onTap: () => _agregarPaso(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _pasos.isEmpty
              ? const _VacioMsg(
                  'Toca "Agregar paso" para añadir\nlas instrucciones de preparación',
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
                  itemCount: _pasos.length,
                  onReorder: (old, nuevo) {
                    setState(() {
                      if (nuevo > old) nuevo--;
                      final item = _pasos.removeAt(old);
                      _pasos.insert(nuevo, item);
                    });
                  },
                  itemBuilder: (context, i) {
                    return _TarjetaPaso(
                      key: ValueKey('paso_$i'),
                      numero: i + 1,
                      paso: _pasos[i],
                      onEditar: () => _editarPaso(context, i),
                      onEliminar: () => setState(() => _pasos.removeAt(i)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _agregarPaso(BuildContext context) => _mostrarEditorPaso(context, null);

  void _editarPaso(BuildContext context, int index) =>
      _mostrarEditorPaso(context, index);

  void _mostrarEditorPaso(BuildContext context, int? index) {
    final ctrl = TextEditingController(
      text: index != null ? _pasos[index].instruccion : '',
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              index == null ? 'Nuevo paso' : 'Editar paso ${index + 1}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              maxLines: 4,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Describe este paso de la preparación…',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                filled: true,
                fillColor: _fondo,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 10),
            // Sugerencias rápidas de pasos
            if (index == null) ...[
              Text(
                'Sugerencias rápidas:',
                style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  'Precalentar el horno a 180°C',
                  'Mezclar todos los ingredientes secos',
                  'Saltear a fuego medio por 5 min',
                  'Dejar reposar 10 minutos',
                  'Hervir agua con sal',
                  'Licuar hasta obtener consistencia suave',
                  'Marinar por 30 minutos',
                  'Condimentar al gusto con sal y pimienta',
                ].map((sugerencia) => GestureDetector(
                  onTap: () {
                    if (ctrl.text.trim().isEmpty) {
                      ctrl.text = sugerencia;
                    } else {
                      ctrl.text = ctrl.text.trim() + ' ' + sugerencia;
                    }
                    ctrl.selection = TextSelection.fromPosition(
                      TextPosition(offset: ctrl.text.length),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7F1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF2D9E73).withOpacity(0.3)),
                    ),
                    child: Text(
                      sugerencia,
                      style: const TextStyle(fontSize: 11, color: Color(0xFF2D9E73)),
                    ),
                  ),
                )).toList(),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final texto = ctrl.text.trim();
                  if (texto.isEmpty) return;
                  setState(() {
                    if (index == null) {
                      _pasos.add(_Paso(instruccion: texto));
                    } else {
                      _pasos[index].instruccion = texto;
                    }
                  });
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _verde,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  index == null ? 'Agregar' : 'Guardar cambios',
                  style: const TextStyle(
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
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Modal selector de ingrediente
// ══════════════════════════════════════════════════════════════════════════════

class _ModalIngrediente extends StatefulWidget {
  final List<Map<String, dynamic>> maestros;
  final bool cargando;
  final ValueChanged<_IngReceta> onSeleccionado;
  final ValueChanged<_IngReceta> onNuevoCreado;

  const _ModalIngrediente({
    required this.maestros,
    required this.cargando,
    required this.onSeleccionado,
    required this.onNuevoCreado,
  });

  @override
  State<_ModalIngrediente> createState() => _ModalIngredienteState();
}

class _ModalIngredienteState extends State<_ModalIngrediente> {
  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  static const Color _fondo = Color(0xFFF5F6FA);

  final _buscadorCtrl = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _buscadorCtrl.addListener(
      () => setState(() => _query = _buscadorCtrl.text),
    );
  }

  @override
  void dispose() {
    _buscadorCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filtrados {
    if (_query.trim().isEmpty) return widget.maestros;
    final q = _query.toLowerCase();
    return widget.maestros
        .where((m) => (m['nombre'] ?? '').toString().toLowerCase().contains(q))
        .toList();
  }

  // Genera un ID limpio desde el nombre
  String _idDesdeNombre(String nombre) =>
      nombre.trim().toLowerCase().replaceAll(' ', '-');

  // Abre sheet para crear ingrediente nuevo (con todos los campos maestros)
  void _crearNuevo() {
    final nombreCtrl = TextEditingController(text: _query.trim());
    final fotoCtrl = TextEditingController();
    final categoriaCtrl = TextEditingController();
    final sustitutoCtrl = TextEditingController();
    bool esPrimordialLocal = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheet) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const Text(
                  'Crear nuevo ingrediente maestro',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Se guardará en ingredientes_maestros y quedará disponible para todas las recetas.',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
                const SizedBox(height: 16),
                // Nombre
                _SheetField(ctrl: nombreCtrl, label: 'Nombre *', hint: 'ej: salsa soya', autofocus: true),
                const SizedBox(height: 12),
                // Categoría
                _SheetField(ctrl: categoriaCtrl, label: 'Categoría *', hint: 'ej: aderezos, carnes, lácteos…'),
                const SizedBox(height: 12),
                // Foto
                _SheetField(ctrl: fotoCtrl, label: 'URL de foto', hint: 'https://…'),
                const SizedBox(height: 12),
                // Sustituto
                _SheetField(ctrl: sustitutoCtrl, label: 'Sustituto (opcional)', hint: 'ej: salsa de tamarindo'),
                const SizedBox(height: 14),
                // Es primordial
                GestureDetector(
                  onTap: () => setSheet(() => esPrimordialLocal = !esPrimordialLocal),
                  child: Row(
                    children: [
                      Container(
                        width: 22, height: 22,
                        decoration: BoxDecoration(
                          color: esPrimordialLocal ? _verde : Colors.transparent,
                          border: Border.all(color: _verde, width: 2),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: esPrimordialLocal
                            ? const Icon(Icons.check, color: Colors.white, size: 14)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Marcar como ingrediente primordial ★',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                    label: const Text(
                      'Crear y agregar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    onPressed: () {
                      final nombre = nombreCtrl.text.trim();
                      final categoria = categoriaCtrl.text.trim();
                      if (nombre.isEmpty || categoria.isEmpty) return;
                      final sustitutos = sustitutoCtrl.text.trim().isNotEmpty
                          ? [sustitutoCtrl.text.trim()]
                          : <String>[];
                      final ing = _IngReceta(
                        ingredienteId: _idDesdeNombre(nombre),
                        nombre: nombre,
                        cantidad: '1',
                        unidad: '',
                        esPrimordial: esPrimordialLocal,
                        esMaestro: false,
                        // pass extra metadata for saving
                        foto: fotoCtrl.text.trim(),
                        categoria: categoria,
                        sustitutos: sustitutos,
                      );
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                      widget.onNuevoCreado(ing);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _verde,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(
              children: [
                const Text(
                  'Seleccionar ingrediente',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                ),
                const Spacer(),
                // Botón crear nuevo siempre visible
                GestureDetector(
                  onTap: _crearNuevo,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _verdeClaro,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.add_rounded, color: _verde, size: 14),
                        SizedBox(width: 4),
                        Text(
                          'Nuevo',
                          style: TextStyle(
                            color: _verde,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _buscadorCtrl,
              autofocus: true,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Buscar ingrediente…',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _verde,
                  size: 18,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear_rounded,
                          color: Colors.grey[400],
                          size: 18,
                        ),
                        onPressed: () => _buscadorCtrl.clear(),
                      )
                    : null,
                filled: true,
                fillColor: _fondo,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          if (widget.cargando)
            const Expanded(
              child: Center(child: CircularProgressIndicator(color: _verde)),
            )
          else if (_filtrados.isEmpty)
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.search_off_rounded,
                    size: 40,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'No se encontró "$_query"',
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _crearNuevo,
                    icon: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: Text(
                      'Crear "$_query"',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _verde,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: scrollCtrl,
                itemCount: _filtrados.length,
                itemBuilder: (_, i) {
                  final m = _filtrados[i];
                  final nombre = m['nombre']?.toString() ?? m['id'] ?? '';
                  final foto = m['foto']?.toString() ?? '';
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: foto.isNotEmpty
                          ? Image.network(
                              foto,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _MiniPlaceholder(),
                            )
                          : _MiniPlaceholder(),
                    ),
                    title: Text(
                      nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.add_circle_rounded,
                      color: _verde,
                      size: 22,
                    ),
                    onTap: () {
                      final ing = _IngReceta(
                        ingredienteId: m['id']?.toString() ?? '',
                        nombre: nombre,
                        cantidad: '1',
                        unidad: '',
                        esMaestro: true,
                      );
                      Navigator.pop(context);
                      widget.onSeleccionado(ing);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MiniPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: const Color(0xFFE8F7F1),
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Icon(
      Icons.restaurant_rounded,
      color: Color(0xFF2D9E73),
      size: 20,
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════════════
// Tarjeta de ingrediente en la lista
// ══════════════════════════════════════════════════════════════════════════════

class _TarjetaIngrediente extends StatelessWidget {
  final _IngReceta ing;
  final List<String> unidades;
  final ValueChanged<String> onCambioCantidad;
  final ValueChanged<String> onCambioUnidad;
  final VoidCallback onTogglePrimordial;
  final VoidCallback onEliminar;

  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);

  const _TarjetaIngrediente({
    super.key,
    required this.ing,
    required this.unidades,
    required this.onCambioCantidad,
    required this.onCambioUnidad,
    required this.onTogglePrimordial,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Ícono arrastrar
                Icon(
                  Icons.drag_handle_rounded,
                  color: Colors.grey[300],
                  size: 18,
                ),
                const SizedBox(width: 8),

                // Nombre
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          ing.nombre,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13.5,
                            color: Color(0xFF1A1A2E),
                          ),
                        ),
                      ),
                      // Badge nuevo
                      if (!ing.esMaestro) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'Nuevo',
                            style: TextStyle(
                              color: Color(0xFFE65100),
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Eliminar
                IconButton(
                  icon: const Icon(
                    Icons.delete_rounded,
                    color: Color(0xFFE53935),
                    size: 18,
                  ),
                  onPressed: onEliminar,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                // Cantidad
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: TextEditingController(text: ing.cantidad)
                      ..selection = TextSelection.fromPosition(
                        TextPosition(offset: ing.cantidad.length),
                      ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: const TextStyle(fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Cant.',
                      filled: true,
                      fillColor: const Color(0xFFF5F6FA),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: onCambioCantidad,
                  ),
                ),
                const SizedBox(width: 8),

                // Unidad (dropdown)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: unidades.contains(ing.unidad) ? ing.unidad : null,
                    hint: Text(
                      'Unidad',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF5F6FA),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF1A1A2E),
                    ),
                    items: unidades
                        .map(
                          (u) => DropdownMenuItem(
                            value: u,
                            child: Text(
                              _pluralizarUnidad(ing.cantidad, u),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => onCambioUnidad(v ?? ''),
                  ),
                ),
                const SizedBox(width: 8),

                // Toggle primordial
                GestureDetector(
                  onTap: onTogglePrimordial,
                  child: Tooltip(
                    message: ing.esPrimordial
                        ? 'Ingrediente obligatorio'
                        : 'Marcar como obligatorio',
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: ing.esPrimordial
                            ? _verdeClaro
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        ing.esPrimordial
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        color: ing.esPrimordial ? _verde : Colors.grey[400],
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Tarjeta de paso
// ══════════════════════════════════════════════════════════════════════════════

class _TarjetaPaso extends StatelessWidget {
  final int numero;
  final _Paso paso;
  final VoidCallback onEditar;
  final VoidCallback onEliminar;

  static const Color _verde = Color(0xFF2D9E73);

  const _TarjetaPaso({
    super.key,
    required this.numero,
    required this.paso,
    required this.onEditar,
    required this.onEliminar,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Número
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
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Instrucción
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    paso.instruccion,
                    style: const TextStyle(
                      fontSize: 13.5,
                      height: 1.5,
                      color: Color(0xFF444455),
                    ),
                  ),
                ],
              ),
            ),
            // Acciones
            Column(
              children: [
                Icon(
                  Icons.drag_handle_rounded,
                  color: Colors.grey[300],
                  size: 18,
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onEditar,
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Color(0xFF2D9E73),
                    size: 16,
                  ),
                ),
                const SizedBox(height: 4),
                GestureDetector(
                  onTap: onEliminar,
                  child: const Icon(
                    Icons.delete_rounded,
                    color: Color(0xFFE53935),
                    size: 16,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Widgets reutilizables
// ══════════════════════════════════════════════════════════════════════════════

class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icono;
  final TextInputType tipo;
  final ValueChanged<String>? onChanged;

  const _Campo({
    required this.ctrl,
    required this.hint,
    required this.icono,
    this.tipo = TextInputType.text,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: tipo,
    style: const TextStyle(fontSize: 13),
    onChanged: onChanged,
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: Color(0xFFBBBBCC)),
      prefixIcon: Icon(icono, color: const Color(0xFF2D9E73), size: 16),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2D9E73), width: 1.5),
      ),
    ),
  );
}

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

class _PlaceholderImg extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 160,
    decoration: BoxDecoration(
      color: const Color(0xFFE8F7F1),
      borderRadius: BorderRadius.circular(14),
    ),
    child: const Center(
      child: Icon(Icons.image_rounded, color: Color(0xFF2D9E73), size: 48),
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

// ══════════════════════════════════════════════════════════════════════════════
// Selector de categorías (StreamBuilder desde Firestore)
// ══════════════════════════════════════════════════════════════════════════════

class _SelectorCategorias extends StatelessWidget {
  final String seleccionada;
  final ValueChanged<String> onSeleccionar;

  static const Color _verde = Color(0xFF2D9E73);

  const _SelectorCategorias({
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
      if (!snapshot.hasData) {
        return const SizedBox(
          height: 40,
          child: Center(
            child: CircularProgressIndicator(color: _verde, strokeWidth: 2),
          ),
        );
      }
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

// ── Helper campo de texto para sheets ────────────────────────────────────────
class _SheetField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String hint;
  final bool autofocus;
  const _SheetField({
    required this.ctrl,
    required this.label,
    required this.hint,
    this.autofocus = false,
  });

  static const Color _fondo = Color(0xFFF5F6FA);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF555555)),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: ctrl,
          autofocus: autofocus,
          style: const TextStyle(fontSize: 13),
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 12),
            filled: true,
            fillColor: _fondo,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
