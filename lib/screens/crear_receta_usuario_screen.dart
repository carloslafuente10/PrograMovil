import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// ─────────────────────────────────────────────
//  MODELO LIGERO PARA INGREDIENTE SELECCIONADO
// ─────────────────────────────────────────────
class _IngredienteSeleccionado {
  final String id;
  final String nombre;
  final String? imagen;
  String cantidad;
  String unidad;

  _IngredienteSeleccionado({
    required this.id,
    required this.nombre,
    this.imagen,
    this.cantidad = '1',
    this.unidad = 'g',
  });

  Map<String, dynamic> toMap() => {
        'ingrediente_id': id,
        'nombre': nombre,
        'imagen': imagen ?? '',
        'cantidad': double.tryParse(cantidad) ?? 1,
        'unidad': unidad,
      };
}

// ─────────────────────────────────────────────
//  PANTALLA PRINCIPAL
// ─────────────────────────────────────────────
class CrearRecetaUsuarioScreen extends StatefulWidget {
  /// Si se pasa [recetaExistente] y [recetaPersonalId] se edita un borrador
  final Map<String, dynamic>? recetaExistente;
  final String? recetaPersonalId;

  const CrearRecetaUsuarioScreen({
    super.key,
    this.recetaExistente,
    this.recetaPersonalId,
  });

  @override
  State<CrearRecetaUsuarioScreen> createState() =>
      _CrearRecetaUsuarioScreenState();
}

class _CrearRecetaUsuarioScreenState extends State<CrearRecetaUsuarioScreen>
    with TickerProviderStateMixin {
  // ── Colores ──────────────────────────────────
  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  static const Color _fondo = Color(0xFFF5F6FA);

  // ── PageView / pestañas ──────────────────────
  late PageController _pageCtrl;
  int _paginaActual = 0;

  // ── Campos Info ──────────────────────────────
  final _nombreCtrl = TextEditingController();
  final _caloriasCtrl = TextEditingController();
  final _tiempoCtrl = TextEditingController();
  final _imagenCtrl = TextEditingController();
  final _subcategoriaCtrl = TextEditingController();
  int _porciones = 1;
  String _categoria = '';

  // ── Ingredientes ─────────────────────────────
  final List<_IngredienteSeleccionado> _ingredientes = [];

  // ── Pasos ────────────────────────────────────
  final List<TextEditingController> _pasosCtrl = [];

  // ── Estado guardado ──────────────────────────
  bool _guardando = false;
  String? _recetaPersonalId; // doc en recetas_personales

  // ── Validación en tiempo real ─────────────────
  bool _intentoAvanzar = false;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _recetaPersonalId = widget.recetaPersonalId;

    if (widget.recetaExistente != null) {
      _cargarDatosExistentes(widget.recetaExistente!);
    } else {
      _pasosCtrl.add(TextEditingController());
    }
  }

  void _cargarDatosExistentes(Map<String, dynamic> data) {
    _nombreCtrl.text = data['nombre'] ?? '';
    _caloriasCtrl.text = data['calorias']?.toString() ?? '';
    _tiempoCtrl.text = data['tiempo']?.toString() ?? '';
    _imagenCtrl.text = data['imagen'] ?? '';
    _subcategoriaCtrl.text = data['subcategoria'] ?? '';
    _porciones = data['porciones'] ?? 1;
    _categoria = data['categoria'] ?? '';

    final ings = data['ingredientes'] as List? ?? [];
    for (final i in ings) {
      _ingredientes.add(_IngredienteSeleccionado(
        id: i['ingrediente_id'] ?? '',
        nombre: i['nombre'] ?? '',
        imagen: i['imagen'],
        cantidad: i['cantidad']?.toString() ?? '1',
        unidad: i['unidad'] ?? 'g',
      ));
    }

    final pasos = data['pasos'] as List? ?? [];
    for (final p in pasos) {
      _pasosCtrl.add(TextEditingController(text: p['instruccion'] ?? ''));
    }
    if (_pasosCtrl.isEmpty) _pasosCtrl.add(TextEditingController());
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _nombreCtrl.dispose();
    _caloriasCtrl.dispose();
    _tiempoCtrl.dispose();
    _imagenCtrl.dispose();
    _subcategoriaCtrl.dispose();
    for (final c in _pasosCtrl) {
      c.dispose();
    }
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  LÓGICA DE NAVEGACIÓN
  // ─────────────────────────────────────────────
  // En modo edición (receta copiada), la categoría ya viene prellenada, no se valida
  bool get _esModoEdicion => widget.recetaExistente != null;

  bool get _infoValida =>
      _nombreCtrl.text.trim().isNotEmpty &&
      _caloriasCtrl.text.trim().isNotEmpty &&
      (_esModoEdicion || _categoria.isNotEmpty);

  bool get _ingredientesValidos => _ingredientes.isNotEmpty;

  bool get _pasosValidos =>
      _pasosCtrl.any((c) => c.text.trim().isNotEmpty);

  bool get _todoValido =>
      _infoValida && _ingredientesValidos && _pasosValidos;

  void _irAPagina(int pagina) {
    if (pagina > _paginaActual) {
      setState(() => _intentoAvanzar = true);
      if (_paginaActual == 0 && !_infoValida) {
        _mostrarSnack('Completa nombre, calorías y categoría');
        return;
      }
      if (_paginaActual == 1 && !_ingredientesValidos) {
        _mostrarSnack('Agrega al menos un ingrediente');
        return;
      }
    }
    setState(() {
      _paginaActual = pagina;
      _intentoAvanzar = false;
    });
    _pageCtrl.animateToPage(
      pagina,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _mostrarSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color(0xFFE53935),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  GUARDAR BORRADOR (recetas_personales)
  // ─────────────────────────────────────────────
  Map<String, dynamic> _buildPayload(String estado) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final email = FirebaseAuth.instance.currentUser?.email ?? '';
    return {
      'nombre': _nombreCtrl.text.trim(),
      'calorias': double.tryParse(_caloriasCtrl.text) ?? 0,
      'tiempo': int.tryParse(_tiempoCtrl.text) ?? 0,
      'imagen': _imagenCtrl.text.trim(),
      'porciones': _porciones,
      'categoria': _categoria,
      'subcategoria': _subcategoriaCtrl.text.trim(),
      'ingredientes': _ingredientes.map((i) => i.toMap()).toList(),
      'pasos': _pasosCtrl
          .asMap()
          .entries
          .where((e) => e.value.text.trim().isNotEmpty)
          .map((e) => {'orden': e.key + 1, 'instruccion': e.value.text.trim()})
          .toList(),
      'estado': estado,
      'usuarioId': uid,
      'usuarioEmail': email,
      'fechaCreacion': DateTime.now().toIso8601String(),
    };
  }

  Future<void> _guardarBorrador() async {
    if (_guardando) return;
    setState(() => _guardando = true);
    try {
      final payload = _buildPayload('borrador');
      if (_recetaPersonalId != null) {
        await FirebaseFirestore.instance
            .collection('recetas_personales')
            .doc(_recetaPersonalId)
            .update(payload);
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('recetas_personales')
            .add(payload);
        _recetaPersonalId = doc.id;
      }
      if (mounted) _mostrarSnackVerde('Borrador guardado');
    } catch (e) {
      if (mounted) _mostrarSnack('Error al guardar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ─────────────────────────────────────────────
  //  ENVIAR A REVISIÓN
  // ─────────────────────────────────────────────
  Future<void> _enviarARevision() async {
    if (!_todoValido) {
      if (!_infoValida) {
        _irAPagina(0);
        _mostrarSnack('Completa la información básica');
      } else if (!_ingredientesValidos) {
        _irAPagina(1);
        _mostrarSnack('Agrega al menos un ingrediente');
      } else {
        _irAPagina(2);
        _mostrarSnack('Agrega al menos un paso');
      }
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogConfirmar(nombre: _nombreCtrl.text.trim()),
    );
    if (confirmar != true) return;

    setState(() => _guardando = true);
    try {
      // 1. Guardar/actualizar en recetas_personales con estado en_revision
      final payloadPersonal = _buildPayload('en_revision');
      if (_recetaPersonalId != null) {
        await FirebaseFirestore.instance
            .collection('recetas_personales')
            .doc(_recetaPersonalId)
            .update(payloadPersonal);
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('recetas_personales')
            .add(payloadPersonal);
        _recetaPersonalId = doc.id;
      }

      // 2. Crear documento en recetas-pendientes
      final payloadPendiente = _buildPayload('pendiente');
      payloadPendiente['origenPersonalDocId'] = _recetaPersonalId;
      payloadPendiente['fechaEnvio'] = FieldValue.serverTimestamp();
      await FirebaseFirestore.instance
          .collection('recetas-pendientes')
          .add(payloadPendiente);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text('Receta enviada a revisión'),
              ],
            ),
            backgroundColor: _verde,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      if (mounted) _mostrarSnack('Error al enviar: $e');
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _mostrarSnackVerde(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _verde,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _StepIndicator(
            paso: _paginaActual,
            infoValida: _infoValida,
            ingredientesValidos: _ingredientesValidos,
            pasosValidos: _pasosValidos,
            onTap: _irAPagina,
          ),
          Expanded(
            child: PageView(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _PaginaInfo(
                  nombreCtrl: _nombreCtrl,
                  caloriasCtrl: _caloriasCtrl,
                  tiempoCtrl: _tiempoCtrl,
                  imagenCtrl: _imagenCtrl,
                  subcategoriaCtrl: _subcategoriaCtrl,
                  porciones: _porciones,
                  categoria: _categoria,
                  mostrarError: _intentoAvanzar && !_infoValida,
                  onPorcionesChanged: (v) => setState(() => _porciones = v),
                  onCategoriaChanged: (v) => setState(() => _categoria = v),
                  onSiguiente: () => _irAPagina(1),
                ),
                _PaginaIngredientes(
                  ingredientes: _ingredientes,
                  onChanged: () => setState(() {}),
                  onSiguiente: () => _irAPagina(2),
                ),
                _PaginaPasos(
                  pasosCtrl: _pasosCtrl,
                  onChanged: () => setState(() {}),
                ),
              ],
            ),
          ),
          _BottomBar(
            pagina: _paginaActual,
            todoValido: _todoValido,
            guardando: _guardando,
            onGuardarBorrador: _guardarBorrador,
            onEnviarRevision: _enviarARevision,
            onAnterior: _paginaActual > 0
                ? () => _irAPagina(_paginaActual - 1)
                : null,
            onSiguiente:
                _paginaActual < 2 ? () => _irAPagina(_paginaActual + 1) : null,
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    final titles = ['Información', 'Ingredientes', 'Pasos'];
    return AppBar(
      backgroundColor: _verde,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        titles[_paginaActual],
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18),
      ),
      actions: [
        if (_guardando)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            ),
          )
        else
          TextButton(
            onPressed: _guardarBorrador,
            child: const Text('Guardar',
                style: TextStyle(color: Colors.white70, fontSize: 13)),
          ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════
//  STEP INDICATOR
// ═══════════════════════════════════════════════
class _StepIndicator extends StatelessWidget {
  final int paso;
  final bool infoValida, ingredientesValidos, pasosValidos;
  final void Function(int) onTap;

  const _StepIndicator({
    required this.paso,
    required this.infoValida,
    required this.ingredientesValidos,
    required this.pasosValidos,
    required this.onTap,
  });

  static const Color _verde = Color(0xFF2D9E73);

  @override
  Widget build(BuildContext context) {
    final steps = [
      (Icons.info_outline_rounded, 'Info', infoValida),
      (Icons.egg_alt_outlined, 'Ingredientes', ingredientesValidos),
      (Icons.format_list_numbered_rounded, 'Pasos', pasosValidos),
    ];
    return Container(
      color: _verde,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F6FA),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(
          children: steps.asMap().entries.map((entry) {
            final idx = entry.key;
            final (icon, label, valid) = entry.value;
            final isActive = paso == idx;
            final isDone = valid && paso > idx;
            return Expanded(
              child: GestureDetector(
                onTap: () => onTap(idx),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? _verde
                            : isDone
                                ? const Color(0xFFE8F7F1)
                                : Colors.grey[200],
                        border: isActive
                            ? null
                            : Border.all(
                                color: isDone ? _verde : Colors.grey[300]!,
                                width: 1.5),
                      ),
                      child: Icon(
                        isDone ? Icons.check_rounded : icon,
                        color: isActive
                            ? Colors.white
                            : isDone
                                ? _verde
                                : Colors.grey[400],
                        size: 18,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w400,
                        color: isActive ? _verde : Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      height: 3,
                      decoration: BoxDecoration(
                        color: isActive ? _verde : Colors.transparent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  PÁGINA 1: INFO
// ═══════════════════════════════════════════════
class _PaginaInfo extends StatefulWidget {
  final TextEditingController nombreCtrl, caloriasCtrl, tiempoCtrl, imagenCtrl, subcategoriaCtrl;
  final int porciones;
  final String categoria;
  final bool mostrarError;
  final void Function(int) onPorcionesChanged;
  final void Function(String) onCategoriaChanged;
  final VoidCallback onSiguiente;

  const _PaginaInfo({
    required this.nombreCtrl,
    required this.caloriasCtrl,
    required this.tiempoCtrl,
    required this.imagenCtrl,
    required this.subcategoriaCtrl,
    required this.porciones,
    required this.categoria,
    required this.mostrarError,
    required this.onPorcionesChanged,
    required this.onCategoriaChanged,
    required this.onSiguiente,
  });

  @override
  State<_PaginaInfo> createState() => _PaginaInfoState();
}

class _PaginaInfoState extends State<_PaginaInfo> {
  static const Color _verde = Color(0xFF2D9E73);
  static const List<String> _categorias = [
    'Desayuno', 'Almuerzo', 'Cena', 'Snacks', 'Refrescos',
    'Postres', 'Sopas', 'Ensaladas', 'Bebidas', 'Panadería',
    'Vegano', 'Vegetariano', 'Otras',
  ];

  bool _imagenValida = false;

  @override
  void initState() {
    super.initState();
    widget.imagenCtrl.addListener(_checkImagen);
  }

  void _checkImagen() {
    final url = widget.imagenCtrl.text.trim();
    setState(() => _imagenValida = url.startsWith('http'));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Preview imagen
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            height: _imagenValida ? 160 : 0,
            child: _imagenValida
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      widget.imagenCtrl.text.trim(),
                      width: double.infinity,
                      height: 160,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (_imagenValida) const SizedBox(height: 12),

          _Label('Imagen (URL)'),
          _Campo(
            ctrl: widget.imagenCtrl,
            hint: 'https://...',
            icono: Icons.image_outlined,
          ),
          const SizedBox(height: 16),

          _Label('Nombre de la receta', obligatorio: true, error: widget.mostrarError && widget.nombreCtrl.text.isEmpty),
          _Campo(
            ctrl: widget.nombreCtrl,
            hint: 'Ej: Ensalada mediterránea',
            icono: Icons.restaurant_rounded,
            error: widget.mostrarError && widget.nombreCtrl.text.isEmpty,
          ),
          const SizedBox(height: 12),

          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label('Calorías', obligatorio: true, error: widget.mostrarError && widget.caloriasCtrl.text.isEmpty),
                  _Campo(
                    ctrl: widget.caloriasCtrl,
                    hint: '350',
                    icono: Icons.local_fire_department_rounded,
                    teclado: TextInputType.number,
                    error: widget.mostrarError && widget.caloriasCtrl.text.isEmpty,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Label('Tiempo (min)'),
                  _Campo(
                    ctrl: widget.tiempoCtrl,
                    hint: '30',
                    icono: Icons.timer_outlined,
                    teclado: TextInputType.number,
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),

          _Label('Porciones'),
          _SelectorPorciones(
            valor: widget.porciones,
            onChanged: widget.onPorcionesChanged,
          ),
          const SizedBox(height: 16),

          _Label('Categoría', obligatorio: true, error: widget.mostrarError && widget.categoria.isEmpty),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categorias.map((cat) {
              final sel = widget.categoria == cat;
              return GestureDetector(
                onTap: () => widget.onCategoriaChanged(cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? _verde : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? _verde : (widget.mostrarError && widget.categoria.isEmpty ? Colors.red[300]! : Colors.grey[300]!),
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      color: sel ? Colors.white : Colors.grey[700],
                      fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          _Label('Subcategoría (opcional)'),
          _Campo(
            ctrl: widget.subcategoriaCtrl,
            hint: 'Ej: saludable, rápida, especial...',
            icono: Icons.label_outline_rounded,
          ),
          const SizedBox(height: 20),

          // Botón siguiente
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: widget.onSiguiente,
              icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
              label: const Text('Siguiente: Ingredientes',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _verde,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  PÁGINA 2: INGREDIENTES
// ═══════════════════════════════════════════════
class _PaginaIngredientes extends StatefulWidget {
  final List<_IngredienteSeleccionado> ingredientes;
  final VoidCallback onChanged;
  final VoidCallback onSiguiente;

  const _PaginaIngredientes({
    required this.ingredientes,
    required this.onChanged,
    required this.onSiguiente,
  });

  @override
  State<_PaginaIngredientes> createState() => _PaginaIngredientesState();
}

class _PaginaIngredientesState extends State<_PaginaIngredientes> {
  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);

  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _resultados = [];
  bool _buscando = false;

  static const List<String> _unidades = [
    'g', 'kg', 'ml', 'l', 'taza', 'cdta', 'cda', 'unidad', 'pizca'
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_buscar);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _buscar() async {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _resultados = []);
      return;
    }
    setState(() => _buscando = true);
    try {
      // Intenta buscar por nombreLower primero; si no hay resultados, intenta por nombre
      QuerySnapshot snap = await FirebaseFirestore.instance
          .collection('ingredientes_maestros')
          .where('nombreLower', isGreaterThanOrEqualTo: q)
          .where('nombreLower', isLessThan: '${q}z')
          .limit(20)
          .get();

      // Fallback: buscar por campo 'nombre' si la colección no usa nombreLower
      if (snap.docs.isEmpty) {
        snap = await FirebaseFirestore.instance
            .collection('ingredientes_maestros')
            .where('nombre', isGreaterThanOrEqualTo: q)
            .where('nombre', isLessThan: '${q}z')
            .limit(20)
            .get();
      }

      if (mounted) {
        setState(() {
          _resultados = snap.docs
              .map((d) => {'id': d.id, ...d.data() as Map<String, dynamic>})
              .toList();
          _buscando = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _buscando = false);
    }
  }

  void _agregarIngredientePersonalizado() {
    final nombreCtrl = TextEditingController(text: _searchCtrl.text.trim());
    final unidades = _unidades;
    String unidadSel = unidades.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlg) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Agregar ingrediente',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: TextField(
                  controller: nombreCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Nombre del ingrediente',
                    prefixIcon: Icon(Icons.egg_alt_outlined, color: Color(0xFF2D9E73), size: 18),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                const Text('Unidad:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: unidadSel,
                  items: unidades
                      .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                      .toList(),
                  onChanged: (v) => setDlg(() => unidadSel = v ?? unidadSel),
                ),
              ]),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                final nombre = nombreCtrl.text.trim();
                if (nombre.isEmpty) return;
                final id = 'custom-${nombre.toLowerCase().replaceAll(' ', '-')}';
                widget.ingredientes.add(_IngredienteSeleccionado(
                  id: id,
                  nombre: nombre,
                  unidad: unidadSel,
                ));
                _searchCtrl.clear();
                setState(() => _resultados = []);
                widget.onChanged();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2D9E73),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Agregar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  void _agregarIngrediente(Map<String, dynamic> ing) {
    final yaExiste = widget.ingredientes.any((i) => i.id == ing['id']);
    if (yaExiste) return;
    widget.ingredientes.add(_IngredienteSeleccionado(
      id: ing['id'] ?? '',
      nombre: ing['nombre'] ?? '',
      imagen: ing['imagen'],
    ));
    _searchCtrl.clear();
    setState(() => _resultados = []);
    widget.onChanged();
  }

  void _eliminar(int idx) {
    widget.ingredientes.removeAt(idx);
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Barra de búsqueda
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8)],
            ),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Buscar ingrediente...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon: _buscando
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2D9E73))),
                      )
                    : const Icon(Icons.search_rounded, color: Color(0xFF2D9E73)),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),

        // Resultados de búsqueda
        if (_resultados.isNotEmpty)
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 12)],
            ),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: _resultados.length,
              itemBuilder: (ctx, i) {
                final ing = _resultados[i];
                final imgUrl = ing['imagen']?.toString() ?? '';
                return ListTile(
                  dense: true,
                  leading: _MiniImagen(url: imgUrl, size: 36),
                  title: Text(ing['nombre'] ?? '', style: const TextStyle(fontSize: 14)),
                  trailing: const Icon(Icons.add_circle_rounded, color: Color(0xFF2D9E73), size: 20),
                  onTap: () => _agregarIngrediente(ing),
                );
              },
            ),
          ),

        // Opción de agregar ingrediente personalizado
        if (_searchCtrl.text.trim().isNotEmpty && !_buscando)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: GestureDetector(
              onTap: _agregarIngredientePersonalizado,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F7F1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2D9E73).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.add_rounded, color: Color(0xFF2D9E73), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '¿No está? Agregar "${_searchCtrl.text.trim()}" como ingrediente libre',
                        style: const TextStyle(
                          color: Color(0xFF2D9E73),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        const SizedBox(height: 8),

        // Lista de ingredientes seleccionados
        Expanded(
          child: widget.ingredientes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.egg_alt_outlined, size: 56, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('Busca y agrega ingredientes', style: TextStyle(color: Colors.grey[500])),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: widget.ingredientes.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    return _IngredienteCard(
                      ing: widget.ingredientes[i],
                      unidades: _unidades,
                      onEliminar: () => _eliminar(i),
                      onChanged: widget.onChanged,
                    );
                  },
                ),
        ),

        // Botón siguiente
        if (widget.ingredientes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onSiguiente,
                icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                label: Text(
                  '${widget.ingredientes.length} ingrediente${widget.ingredientes.length != 1 ? 's' : ''} · Siguiente: Pasos',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _verde,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Card de ingrediente seleccionado ───────────
// Diseño: foto | [cantidad unidad / nombre] | lapicito | basurero
class _IngredienteCard extends StatefulWidget {
  final _IngredienteSeleccionado ing;
  final List<String> unidades;
  final VoidCallback onEliminar;
  final VoidCallback onChanged;

  const _IngredienteCard({
    required this.ing,
    required this.unidades,
    required this.onEliminar,
    required this.onChanged,
  });

  @override
  State<_IngredienteCard> createState() => _IngredienteCardState();
}

class _IngredienteCardState extends State<_IngredienteCard> {
  static const Color _verde = Color(0xFF2D9E73);

  void _abrirEditor() {
    final cantCtrl = TextEditingController(text: widget.ing.cantidad);
    String unidadSel = widget.unidades.contains(widget.ing.unidad)
        ? widget.ing.unidad
        : widget.unidades.first;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setDlg) => AlertDialog(
          contentPadding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(widget.ing.nombre,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Foto del ingrediente en el diálogo
              if ((widget.ing.imagen ?? '').isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    widget.ing.imagen!,
                    width: double.infinity,
                    height: 120,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                )
              else
                Container(
                  height: 80,
                  color: const Color(0xFFE8F7F1),
                  child: const Center(
                    child: Icon(Icons.restaurant_rounded, size: 40, color: _verde),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cantidad', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: TextField(
                        controller: cantCtrl,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Unidad', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: unidadSel,
                          isExpanded: true,
                          items: widget.unidades
                              .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                              .toList(),
                          onChanged: (v) => setDlg(() => unidadSel = v ?? unidadSel),
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
              onPressed: () => Navigator.pop(ctx),
              child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  widget.ing.cantidad = cantCtrl.text.trim().isEmpty ? '1' : cantCtrl.text.trim();
                  widget.ing.unidad = unidadSel;
                });
                widget.onChanged();
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _verde,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Guardar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  /// Convierte decimal a fracción legible: 0.5 → 1/2, 0.25 → 1/4, etc.
  String _formatCantidad(String raw) {
    final d = double.tryParse(raw);
    if (d == null) return raw;
    final entero = d.floor();
    final decimal = d - entero;
    final fracs = {0.25: '1/4', 0.33: '1/3', 0.5: '1/2', 0.67: '2/3', 0.75: '3/4'};
    String? frac;
    for (final e in fracs.entries) {
      if ((decimal - e.key).abs() < 0.05) { frac = e.value; break; }
    }
    if (decimal < 0.05) return '$entero';
    if (frac != null && entero == 0) return frac;
    if (frac != null) return '$entero $frac';
    return d.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final cantidadTexto = _formatCantidad(widget.ing.cantidad);
    final unidadTexto = widget.ing.unidad.trim();

    return GestureDetector(
      onTap: _abrirEditor,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
        ),
        child: Row(
          children: [
            // Ícono verde tap → abre editor (sin foto inline)
            Container(
              width: 52,
              height: 52,
              margin: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F7F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.restaurant_rounded, size: 24, color: _verde),
            ),
            const SizedBox(width: 12),

          // Cantidad + unidad arriba / nombre abajo
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fila superior: cantidad · unidad
                Row(
                  children: [
                    Text(
                      cantidadTexto,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    if (unidadTexto.isNotEmpty) ...[
                      const SizedBox(width: 4),
                      Text(
                        unidadTexto,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                // Fila inferior: nombre
                Text(
                  widget.ing.nombre,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF444455),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Botón eliminar
          GestureDetector(
            onTap: widget.onEliminar,
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE53935), size: 16),
            ),
          ),
        ],
        ), // Row
      ), // Container
    ); // GestureDetector
  }
}

class _DropUnidad extends StatefulWidget {
  final String valor;
  final List<String> opciones;
  final void Function(String) onChanged;

  const _DropUnidad({required this.valor, required this.opciones, required this.onChanged});

  @override
  State<_DropUnidad> createState() => _DropUnidadState();
}

class _DropUnidadState extends State<_DropUnidad> {
  late String _val;

  @override
  void initState() {
    super.initState();
    _val = widget.opciones.contains(widget.valor) ? widget.valor : widget.opciones.first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _val,
          isDense: true,
          style: const TextStyle(fontSize: 12, color: Color(0xFF1A1A2E)),
          items: widget.opciones.map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
          onChanged: (v) {
            if (v == null) return;
            setState(() => _val = v);
            widget.onChanged(v);
          },
        ),
      ),
    );
  }
}

// ─── Mini imagen redonda ─────────────────────────
class _MiniImagen extends StatelessWidget {
  final String url;
  final double size;

  const _MiniImagen({required this.url, required this.size});

  @override
  Widget build(BuildContext context) {
    if (url.startsWith('http')) {
      return SizedBox(
        width: size,
        height: size,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        color: const Color(0xFFE8F7F1),
        child: const Center(
          child: Icon(Icons.egg_alt_rounded, color: Color(0xFF2D9E73), size: 20),
        ),
      );
}

// ═══════════════════════════════════════════════
//  PÁGINA 3: PASOS
// ═══════════════════════════════════════════════
class _PaginaPasos extends StatefulWidget {
  final List<TextEditingController> pasosCtrl;
  final VoidCallback onChanged;

  const _PaginaPasos({required this.pasosCtrl, required this.onChanged});

  @override
  State<_PaginaPasos> createState() => _PaginaPasosState();
}

class _PaginaPasosState extends State<_PaginaPasos> {
  static const Color _verde = Color(0xFF2D9E73);

  void _agregarPaso() {
    widget.pasosCtrl.add(TextEditingController());
    widget.onChanged();
    setState(() {});
  }

  void _eliminarPaso(int idx) {
    if (widget.pasosCtrl.length <= 1) return;
    widget.pasosCtrl[idx].dispose();
    widget.pasosCtrl.removeAt(idx);
    widget.onChanged();
    setState(() {});
  }

  void _moverPaso(int idx, int delta) {
    final destino = idx + delta;
    if (destino < 0 || destino >= widget.pasosCtrl.length) return;
    final temp = widget.pasosCtrl[idx];
    widget.pasosCtrl[idx] = widget.pasosCtrl[destino];
    widget.pasosCtrl[destino] = temp;
    widget.onChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
            onReorder: (oldIdx, newIdx) {
              if (newIdx > oldIdx) newIdx--;
              final temp = widget.pasosCtrl.removeAt(oldIdx);
              widget.pasosCtrl.insert(newIdx, temp);
              widget.onChanged();
              setState(() {});
            },
            itemCount: widget.pasosCtrl.length,
            itemBuilder: (ctx, i) {
              return _PasoCard(
                key: ValueKey(widget.pasosCtrl[i]),
                numero: i + 1,
                ctrl: widget.pasosCtrl[i],
                puedeSubir: i > 0,
                puedeBajar: i < widget.pasosCtrl.length - 1,
                puedeEliminar: widget.pasosCtrl.length > 1,
                onSubir: () => _moverPaso(i, -1),
                onBajar: () => _moverPaso(i, 1),
                onEliminar: () => _eliminarPaso(i),
                onChanged: widget.onChanged,
              );
            },
          ),
        ),

        // Botón agregar paso
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: OutlinedButton.icon(
            onPressed: _agregarPaso,
            icon: const Icon(Icons.add_rounded, color: Color(0xFF2D9E73)),
            label: const Text('Agregar paso',
                style: TextStyle(color: Color(0xFF2D9E73), fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF2D9E73)),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              minimumSize: const Size(double.infinity, 0),
            ),
          ),
        ),
      ],
    );
  }
}

class _PasoCard extends StatelessWidget {
  final int numero;
  final TextEditingController ctrl;
  final bool puedeSubir, puedeBajar, puedeEliminar;
  final VoidCallback onSubir, onBajar, onEliminar, onChanged;

  const _PasoCard({
    super.key,
    required this.numero,
    required this.ctrl,
    required this.puedeSubir,
    required this.puedeBajar,
    required this.puedeEliminar,
    required this.onSubir,
    required this.onBajar,
    required this.onEliminar,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Número + drag handle
          Container(
            width: 44,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF2D9E73),
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
            ),
            child: Column(
              children: [
                Text(
                  '$numero',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 6),
                const Icon(Icons.drag_handle_rounded, color: Colors.white60, size: 16),
              ],
            ),
          ),

          // Campo de texto
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: TextField(
                controller: ctrl,
                minLines: 2,
                maxLines: 6,
                style: const TextStyle(fontSize: 13.5, height: 1.45),
                decoration: InputDecoration(
                  hintText: 'Describe este paso...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
          ),

          // Acciones
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 6),
              if (puedeSubir)
                _MicroBtn(Icons.keyboard_arrow_up_rounded, Colors.grey[600]!, onSubir),
              if (puedeBajar)
                _MicroBtn(Icons.keyboard_arrow_down_rounded, Colors.grey[600]!, onBajar),
              if (puedeEliminar)
                _MicroBtn(Icons.delete_outline_rounded, const Color(0xFFE53935), onEliminar),
              const SizedBox(height: 6),
            ],
          ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }
}

class _MicroBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MicroBtn(this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: color, size: 18),
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints(),
      );
}

// ═══════════════════════════════════════════════
//  BOTTOM BAR
// ═══════════════════════════════════════════════
class _BottomBar extends StatelessWidget {
  final int pagina;
  final bool todoValido, guardando;
  final VoidCallback onGuardarBorrador, onEnviarRevision;
  final VoidCallback? onAnterior, onSiguiente;

  const _BottomBar({
    required this.pagina,
    required this.todoValido,
    required this.guardando,
    required this.onGuardarBorrador,
    required this.onEnviarRevision,
    required this.onAnterior,
    required this.onSiguiente,
  });

  static const Color _verde = Color(0xFF2D9E73);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, -2))],
      ),
      child: Row(
        children: [
          // Borrador siempre visible
          OutlinedButton(
            onPressed: guardando ? null : onGuardarBorrador,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.grey[300]!),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            child: Text('Borrador', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ),
          const SizedBox(width: 8),

          // Solo en la última página: Enviar a revisión
          if (pagina == 2)
            Expanded(
              child: ElevatedButton.icon(
                onPressed: guardando ? null : onEnviarRevision,
                icon: guardando
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                label: const Text('Enviar a revisión',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: todoValido ? _verde : Colors.grey[400],
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            )
          else
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onSiguiente,
                icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                label: const Text('Siguiente',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _verde,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  WIDGETS AUXILIARES
// ═══════════════════════════════════════════════
class _Label extends StatelessWidget {
  final String texto;
  final bool obligatorio;
  final bool error;

  const _Label(this.texto, {this.obligatorio = false, this.error = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            texto,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: error ? Colors.red[700] : const Color(0xFF444466),
            ),
          ),
          if (obligatorio)
            Text(' *', style: TextStyle(color: error ? Colors.red[700] : Colors.red[400], fontSize: 12)),
        ],
      ),
    );
  }
}

class _Campo extends StatelessWidget {
  final TextEditingController ctrl;
  final String hint;
  final IconData icono;
  final TextInputType teclado;
  final bool error;

  const _Campo({
    required this.ctrl,
    required this.hint,
    required this.icono,
    this.teclado = TextInputType.text,
    this.error = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: error
            ? Border.all(color: Colors.red[300]!)
            : Border.all(color: Colors.grey[200]!),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6)],
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: teclado,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
          prefixIcon: Icon(icono, color: const Color(0xFF2D9E73), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _SelectorPorciones extends StatelessWidget {
  final int valor;
  final void Function(int) onChanged;

  const _SelectorPorciones({required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BtnPorcion(Icons.remove_rounded, () => onChanged((valor - 1).clamp(1, 99))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              '$valor',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
          _BtnPorcion(Icons.add_rounded, () => onChanged((valor + 1).clamp(1, 99))),
        ],
      ),
    );
  }
}

class _BtnPorcion extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _BtnPorcion(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: const Color(0xFF2D9E73), size: 20),
        padding: const EdgeInsets.all(10),
        constraints: const BoxConstraints(),
      );
}

// ─────────────────────────────────────────────
//  DIÁLOGO DE CONFIRMACIÓN
// ─────────────────────────────────────────────
class _DialogConfirmar extends StatelessWidget {
  final String nombre;

  const _DialogConfirmar({required this.nombre});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Enviar a revisión', style: TextStyle(fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Tu receta "$nombre" será enviada al administrador para revisión.'),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F7F1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Color(0xFF2D9E73), size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Puedes seguir editando tu borrador mientras está en revisión.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF2D9E73)),
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
            backgroundColor: const Color(0xFF2D9E73),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Enviar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
