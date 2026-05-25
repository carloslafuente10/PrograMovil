import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'detalle_receta_screen.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  static const Color _fondo = Color(0xFFF7F7F5);
  static const Color _naranja = Color(0xFFFF6B35);

  static const Color _amarillo = Color(0xFFF59E0B);
  static const Color _amarilloClaro = Color(0xFFFEF3C7);
  static const Color _indigo = Color(0xFF6366F1);
  static const Color _indigoClaro = Color(0xFFEEF2FF);
  static const Color _snackColor = Color(0xFFF97316);
  static const Color _snackClaro = Color(0xFFFFF7ED);
  static const Color _azul = Color(0xFF0EA5E9);
  static const Color _azulClaro = Color(0xFFE0F2FE);

  static const int _offsetBase = 50000;

  DateTime _fechaSeleccionada = DateTime.now();
  Map<String, dynamic>? _planCache;
  bool _cargandoPlan = false;
  bool _snacksExpandido = false;

  late final ScrollController _scrollDias = ScrollController(
    initialScrollOffset: _offsetBase * 56.0 - 150,
  );

  String? get _userId => FirebaseAuth.instance.currentUser?.uid;

  String get _docId {
    final f = _fechaSeleccionada;
    final mes = f.month.toString().padLeft(2, '0');
    final dia = f.day.toString().padLeft(2, '0');
    return '${_userId}_${f.year}-$mes-$dia';
  }

  String get _fechaStr {
    final f = _fechaSeleccionada;
    final mes = f.month.toString().padLeft(2, '0');
    final dia = f.day.toString().padLeft(2, '0');
    return '${f.year}-$mes-$dia';
  }

  DateTime _indexAFecha(int index) {
    final hoy = DateTime.now();
    final hoyNorm = DateTime(hoy.year, hoy.month, hoy.day);
    return hoyNorm.add(Duration(days: index - _offsetBase));
  }

  @override
  void initState() {
    super.initState();
    _cargarPlan();
  }

  @override
  void dispose() {
    _scrollDias.dispose();
    super.dispose();
  }

  Future<void> _cargarPlan() async {
    if (_userId == null) return;
    setState(() => _cargandoPlan = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app-planes')
          .doc(_docId)
          .get();
      if (mounted) {
        setState(() {
          _planCache = doc.exists ? doc.data() : {};
          _cargandoPlan = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _planCache = {};
          _cargandoPlan = false;
        });
      }
    }
  }

  Future<void> _guardarEnPlan(String tipoComida, String recetaId) async {
    if (_userId == null) return;
    setState(() {
      _planCache ??= {};
      _planCache![tipoComida] = recetaId;
    });
    await FirebaseFirestore.instance
        .collection('app-planes')
        .doc(_docId)
        .set(
          {
            'userId': _userId,
            'fecha': _fechaStr,
            tipoComida: recetaId,
          },
          SetOptions(merge: true),
        );
  }

  Future<void> _eliminarDelPlan(String tipoComida) async {
    if (_userId == null) return;
    setState(() {
      _planCache?.remove(tipoComida);
    });
    try {
      await FirebaseFirestore.instance
          .collection('app-planes')
          .doc(_docId)
          .update({tipoComida: FieldValue.delete()});
    } catch (_) {}
  }

  Future<void> _seleccionarReceta(
    String tipoComida,
    List<String> categoriasPermitidas,
  ) async {
    final resultado = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => _SelectorRecetaScreen(
          tipoComida: tipoComida,
          categoriasPermitidas: categoriasPermitidas,
        ),
      ),
    );
    if (resultado != null) {
      await _guardarEnPlan(tipoComida, resultado['id']!);
    }
  }

  Future<int> _calcularCaloriasTotales() async {
    if (_planCache == null) return 0;
    int total = 0;
    final tipos = [
      'desayuno',
      'almuerzo',
      'cena',
      'snack1',
      'snack2',
      'snack3',
      'bebida1',
      'bebida2',
      'bebida3',
    ];
    for (final tipo in tipos) {
      final id = _planCache![tipo]?.toString() ?? '';
      if (id.isEmpty) continue;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('app-recetas-completas')
            .doc(id)
            .get();
        if (doc.exists) {
          final cal = int.tryParse(
                (doc.data()?['calorias'] ??
                        doc.data()?['calorías'] ??
                        '0')
                    .toString(),
              ) ??
              0;
          total += cal;
        }
      } catch (_) {}
    }
    return total;
  }

  List<String> _categoriasParaTipo(String tipo) {
    switch (tipo) {
      case 'desayuno':
        return ['Desayuno'];
      case 'almuerzo':
        return ['Almuerzo'];
      case 'cena':
        return ['Cena'];
      case 'snack1':
      case 'snack2':
      case 'snack3':
        return ['Snacks'];
      case 'bebida1':
      case 'bebida2':
      case 'bebida3':
        return ['Refrescos'];
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: _fondo,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildCarruselDias(),
            const SizedBox(height: 8),
            if (!_cargandoPlan && _planCache != null) _buildResumenCalorico(),
            Expanded(
              child: _cargandoPlan
                  ? const Center(
                      child: CircularProgressIndicator(color: _verde),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        _buildSeccionComida(
                          'desayuno',
                          'Desayuno',
                          Icons.wb_sunny_rounded,
                          _amarillo,
                          _amarilloClaro,
                          'Empieza tu día con energía',
                        ),
                        const SizedBox(height: 12),
                        _buildSeccionComida(
                          'almuerzo',
                          'Almuerzo',
                          Icons.restaurant_rounded,
                          _verde,
                          _verdeClaro,
                          'Tu comida principal del día',
                        ),
                        const SizedBox(height: 12),
                        _buildSeccionComida(
                          'cena',
                          'Cena',
                          Icons.nights_stay_rounded,
                          _indigo,
                          _indigoClaro,
                          'Una cena ligera y nutritiva',
                        ),
                        const SizedBox(height: 12),
                        _buildSeccionSnacksBebidas(),
                        const SizedBox(height: 24),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final hoy = DateTime.now();
    final esHoy = _fechaSeleccionada.year == hoy.year &&
        _fechaSeleccionada.month == hoy.month &&
        _fechaSeleccionada.day == hoy.day;

    const meses = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Plan de Comidas',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              Text(
                esHoy
                    ? 'Hoy — ${meses[_fechaSeleccionada.month]} ${_fechaSeleccionada.day}'
                    : '${meses[_fechaSeleccionada.month]} ${_fechaSeleccionada.day}, ${_fechaSeleccionada.year}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ],
          ),
          if (!esHoy)
            GestureDetector(
              onTap: () {
                final hoyNorm = DateTime(hoy.year, hoy.month, hoy.day);
                setState(() => _fechaSeleccionada = hoyNorm);
                _cargarPlan();
                _scrollDias.animateTo(
                  _offsetBase * 56.0 - 150,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _verde,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: _naranja.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Text(
                  'Hoy',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCarruselDias() {
    const dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    final hoy = DateTime.now();
    final hoyNorm = DateTime(hoy.year, hoy.month, hoy.day);

    return SizedBox(
      height: 72,
      child: ListView.builder(
        controller: _scrollDias,
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _offsetBase * 2,
        itemExtent: 56,
        itemBuilder: (context, index) {
          final dia = _indexAFecha(index);
          final esSeleccionado = dia.year == _fechaSeleccionada.year &&
              dia.month == _fechaSeleccionada.month &&
              dia.day == _fechaSeleccionada.day;
          final esHoy = dia.year == hoyNorm.year &&
              dia.month == hoyNorm.month &&
              dia.day == hoyNorm.day;

          return GestureDetector(
            onTap: () {
              setState(() => _fechaSeleccionada = dia);
              _cargarPlan();
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 8),
              width: 48,
              decoration: BoxDecoration(
                color: esSeleccionado ? _naranja : Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: esSeleccionado
                    ? [
                        BoxShadow(
                          color: _naranja.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                        ),
                      ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    dias[(dia.weekday - 1) % 7],
                    style: TextStyle(
                      fontSize: 10,
                      color: esSeleccionado
                          ? Colors.white70
                          : Colors.grey[500],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dia.day}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: esSeleccionado
                          ? Colors.white
                          : esHoy
                              ? _verde
                              : const Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResumenCalorico() {
    return FutureBuilder<int>(
      future: _calcularCaloriasTotales(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == 0) {
          return const SizedBox.shrink();
        }
        final total = snapshot.data!;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: _verde.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _verde.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.local_fire_department_rounded,
                  color: _naranja, size: 18),
              const SizedBox(width: 8),
              Text(
                'Total del día: $total cal',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeccionComida(
    String tipo,
    String titulo,
    IconData icono,
    Color color,
    Color colorClaro,
    String subtitulo,
  ) {
    final recetaId = _planCache?[tipo]?.toString() ?? '';
    final tieneReceta = recetaId.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: colorClaro,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icono, color: color, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          subtitulo,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => _seleccionarReceta(
                    tipo,
                    _categoriasParaTipo(tipo),
                  ),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            tieneReceta
                ? _TarjetaRecetaPlan(
                    recetaId: recetaId,
                    onEliminar: () => _eliminarDelPlan(tipo),
                    accentColor: color,
                  )
                : _PlaceholderVacio(
                    label: 'Planifica tu $titulo',
                    onTap: () => _seleccionarReceta(
                      tipo,
                      _categoriasParaTipo(tipo),
                    ),
                    color: color,
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildSeccionSnacksBebidas() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: _snackClaro,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.local_cafe_rounded,
                          color: _snackColor, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Snacks y Bebidas',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        Text(
                          'Añade snacks y bebidas durante el día',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () =>
                      setState(() => _snacksExpandido = !_snacksExpandido),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: _snackColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      _snacksExpandido ? Icons.remove : Icons.add,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _snacksExpandido
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(Icons.cookie_outlined,
                                color: _snackColor, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Snacks',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildSlotsGrid(
                          claves: ['snack1', 'snack2', 'snack3'],
                          color: _snackColor,
                          colorClaro: _snackClaro,
                          label: 'snack',
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Icon(Icons.water_drop_outlined,
                                color: _azul, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Bebidas',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildSlotsGrid(
                          claves: ['bebida1', 'bebida2', 'bebida3'],
                          color: _azul,
                          colorClaro: _azulClaro,
                          label: 'bebida',
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlotsGrid({
    required List<String> claves,
    required Color color,
    required Color colorClaro,
    required String label,
  }) {
    return Column(
      children: claves.map((clave) {
        final recetaId = _planCache?[clave]?.toString() ?? '';
        final tieneReceta = recetaId.isNotEmpty;
        final numero = clave.replaceAll(RegExp(r'[^0-9]'), '');

        final etiquetas = {
          'snack1': 'Media mañana',
          'snack2': 'Media tarde',
          'snack3': 'Post cena',
          'bebida1': 'Con el almuerzo',
          'bebida2': 'Con la cena',
          'bebida3': 'Durante el día',
        };

        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: tieneReceta
              ? _TarjetaRecetaPlan(
                  recetaId: recetaId,
                  onEliminar: () => _eliminarDelPlan(clave),
                  accentColor: color,
                  etiqueta: etiquetas[clave],
                )
              : _PlaceholderVacio(
                  label:
                      'Añadir ${label == 'snack' ? 'snack' : 'bebida'} (${etiquetas[clave] ?? numero})',
                  onTap: () => _seleccionarReceta(
                    clave,
                    _categoriasParaTipo(clave),
                  ),
                  color: color,
                ),
        );
      }).toList(),
    );
  }
}

class _TarjetaRecetaPlan extends StatelessWidget {
  final String recetaId;
  final VoidCallback onEliminar;
  final Color accentColor;
  final String? etiqueta;

  const _TarjetaRecetaPlan({
    required this.recetaId,
    required this.onEliminar,
    this.accentColor = const Color(0xFF2D9E73),
    this.etiqueta,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('app-recetas-completas')
          .doc(recetaId)
          .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: accentColor,
                ),
              ),
            ),
          );
        }

        if (!snapshot.data!.exists) {
          return _PlaceholderVacio(
            label: 'Receta no encontrada',
            onTap: onEliminar,
            color: accentColor,
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final nombre = data['nombre']?.toString() ?? 'Sin nombre';
        final imagen = data['imagen']?.toString() ?? '';
        final calorias =
            (data['calorias'] ?? data['calorías'])?.toString() ?? '0';
        final tiempo = data['tiempo']?.toString() ?? '0';

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DetalleRecetaScreen(
                  recetaId: recetaId,
                  nombreReceta: nombre,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(14),
                  ),
                  child: imagen.isNotEmpty
                      ? Image.network(
                          imagen,
                          width: 80,
                          height: 80,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              _imgPlaceholder(accentColor),
                        )
                      : _imgPlaceholder(accentColor),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (etiqueta != null)
                          Text(
                            etiqueta!,
                            style: TextStyle(
                              fontSize: 10,
                              color: accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        if (etiqueta != null) const SizedBox(height: 2),
                        Text(
                          nombre,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.local_fire_department,
                                size: 13, color: Colors.orange[400]),
                            const SizedBox(width: 3),
                            Text(
                              '$calorias Cal',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                            ),
                            const SizedBox(width: 10),
                            Icon(Icons.access_time,
                                size: 13, color: Colors.grey[400]),
                            const SizedBox(width: 3),
                            Text(
                              '$tiempo Min',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[500]),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: GestureDetector(
                    onTap: onEliminar,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _imgPlaceholder(Color color) => Container(
        width: 80,
        height: 80,
        color: color.withValues(alpha: 0.1),
        child: Icon(Icons.restaurant, size: 28, color: color),
      );
}

class _PlaceholderVacio extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _PlaceholderVacio({
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF2D9E73),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            style: BorderStyle.solid,
          ),
        ),
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectorRecetaScreen extends StatefulWidget {
  final String tipoComida;
  final List<String> categoriasPermitidas;

  const _SelectorRecetaScreen({
    required this.tipoComida,
    required this.categoriasPermitidas,
  });

  @override
  State<_SelectorRecetaScreen> createState() => _SelectorRecetaScreenState();
}

class _SelectorRecetaScreenState extends State<_SelectorRecetaScreen> {
  static const Color _verde = Color(0xFF2D9E73);
  String _busqueda = '';
  final TextEditingController _ctrl = TextEditingController();

  bool _documentoPermitido(Map<String, dynamic> data) {
    final categoria =
        (data['categoría'] ?? data['categoria'] ?? '').toString();
    if (widget.categoriasPermitidas.isEmpty) return true;
    return widget.categoriasPermitidas
        .any((c) => c.toLowerCase() == categoria.toLowerCase());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String get _titulo {
    final titulos = {
      'desayuno': 'Elegir Desayuno',
      'almuerzo': 'Elegir Almuerzo',
      'cena': 'Elegir Cena',
      'snack1': 'Elegir Snack',
      'snack2': 'Elegir Snack',
      'snack3': 'Elegir Snack',
      'bebida1': 'Elegir Bebida',
      'bebida2': 'Elegir Bebida',
      'bebida3': 'Elegir Bebida',
    };
    return titulos[widget.tipoComida] ?? 'Elegir receta';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: Text(
          _titulo,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _ctrl,
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: InputDecoration(
                hintText: 'Buscar receta...',
                hintStyle:
                    TextStyle(color: Colors.grey[400], fontSize: 14),
                prefixIcon:
                    Icon(Icons.search, color: Colors.grey[400], size: 20),
                suffixIcon: _busqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear,
                            color: Colors.grey, size: 20),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() => _busqueda = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[200]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _verde, width: 1.5),
                ),
              ),
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

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('No hay recetas disponibles'),
                  );
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final nombre =
                      (data['nombre'] ?? '').toString().toLowerCase();
                  return _documentoPermitido(data) &&
                      nombre.contains(_busqueda.toLowerCase());
                }).toList();

                if (docs.isEmpty) {
                  return Center(
                    child: Text(
                      _busqueda.isNotEmpty
                          ? 'Sin resultados para "$_busqueda"'
                          : 'No hay recetas en esta categoría',
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final nombre =
                        data['nombre']?.toString() ?? 'Sin nombre';
                    final imagen = data['imagen']?.toString() ?? '';
                    final calorias =
                        (data['calorias'] ?? data['calorías'])
                            ?.toString() ??
                        '0';
                    final tiempo = data['tiempo']?.toString() ?? '0';

                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context, {
                          'id': docs[i].id,
                          'nombre': nombre,
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(14),
                              ),
                              child: imagen.isNotEmpty
                                  ? Image.network(
                                      imagen,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          _placeholder(),
                                    )
                                  : _placeholder(),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    nombre,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.local_fire_department,
                                          size: 13,
                                          color: Colors.orange[400]),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$calorias Cal',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500]),
                                      ),
                                      const SizedBox(width: 10),
                                      Icon(Icons.access_time,
                                          size: 13,
                                          color: Colors.grey[400]),
                                      const SizedBox(width: 3),
                                      Text(
                                        '$tiempo min',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey[500]),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Icon(
                                Icons.add_circle_outline_rounded,
                                color: _verde,
                                size: 24,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _placeholder() => Container(
        width: 80,
        height: 80,
        color: const Color(0xFFE8F7F1),
        child: const Icon(Icons.restaurant, size: 28, color: _verde),
      );
}
