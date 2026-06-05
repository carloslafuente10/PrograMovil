import 'package:flutter/material.dart';// Librería de Flutter para la construcción de interfaces gráficas
import 'package:cloud_firestore/cloud_firestore.dart';// Permite interactuar con la base de datos Firestore de Firebase para leer y escribir datos relacionados con el plan de comidas del usuario.
import 'package:firebase_auth/firebase_auth.dart';// Permite obtener el usuario autenticado mediante Firebase Authentication, necesario para cargar y guardar el plan de comidas específico de cada usuario.
import 'detalle_receta_screen.dart';// Pantalla de detalle de una receta, a la que se accede al seleccionar una receta planificada en el plan de comidas. Permite al usuario ver la información completa de la receta y realizar acciones como eliminarla del plan o cambiarla por otra receta.
import '../servicios/historial_servicio.dart';// Servicio personalizado encargado de registrar las acciones del usuario relacionadas con el plan de comidas, como agregar o eliminar recetas del plan. Permite llevar un historial de las modificaciones realizadas en el plan para futuras referencias o análisis.
// Pantalla principal del plan de comidas, donde el usuario puede planificar sus comidas diarias seleccionando recetas para desayuno, almuerzo, cena, snacks y bebidas. Permite navegar entre diferentes días para planificar con anticipación o revisar planes pasados. El usuario puede agregar, cambiar o eliminar recetas en cada sección del plan, y se muestra un resumen calórico total del día basado en las recetas seleccionadas.
class PlanScreen extends StatefulWidget {
  const PlanScreen({super.key});

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}
// Estado de la pantalla de plan de comidas, que maneja la lógica para cargar y guardar el plan del usuario, seleccionar recetas para cada sección del plan, calcular el total calórico del día y mantener el estado al navegar entre días. Utiliza un ScrollController para el carrusel de días y mantiene un caché local del plan cargado para mejorar la experiencia del usuario.
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
// Inicializa el estado de la pantalla cargando el plan de comidas para la fecha seleccionada. Se llama al método _cargarPlan para obtener los datos del plan desde Firestore y actualizar la interfaz. También se configura el ScrollController para posicionar el carrusel de días en la fecha actual.
  @override
  void initState() {
    super.initState();
    _cargarPlan();
  }
// Limpia los recursos utilizados por el ScrollController al destruir la pantalla para evitar fugas de memoria. Es importante llamar a _scrollDias.dispose() para liberar los recursos asociados al controlador de desplazamiento cuando la pantalla ya no esté en uso.
  @override
  void dispose() {
    _scrollDias.dispose();
    super.dispose();
  }
// Método para cargar el plan de comidas del usuario para la fecha seleccionada desde Firestore. Se utiliza el _docId generado a partir del userId y la fecha para obtener el documento correspondiente en la colección 'app-planes'. Si el documento existe, se almacena su data en _planCache; si no existe o hay un error, se establece _planCache como un mapa vacío. Durante la carga, se muestra un indicador de progreso y se actualiza la interfaz al finalizar.
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
// Método para guardar una receta seleccionada en el plan de comidas del usuario para la fecha actual. Recibe el tipo de comida (desayuno, almuerzo, cena, snack1, etc.) y el ID de la receta seleccionada. Actualiza el _planCache localmente para reflejar el cambio en la interfaz de forma inmediata, y luego guarda la información en Firestore utilizando el _docId correspondiente. Si el usuario no está autenticado, no realiza ninguna acción. También registra la acción en el historial del usuario mediante HistorialService.
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
        await HistorialService.registrar(
  accion:
      'Agregó una receta a $tipoComida para $_fechaStr',
  tipo: 'plan',
);
  }
// Método para eliminar una receta del plan de comidas del usuario para la fecha actual. Recibe el tipo de comida del que se desea eliminar la receta. Actualiza el _planCache localmente para reflejar el cambio en la interfaz de forma inmediata, y luego elimina la información correspondiente en Firestore utilizando el _docId y el tipo de comida como clave. Si el usuario no está autenticado, no realiza ninguna acción. También registra la acción en el historial del usuario mediante HistorialService.
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
          await HistorialService.registrar(
  accion:
      'Eliminó una receta de $tipoComida para $_fechaStr',
  tipo: 'plan',
);
    } catch (_) {}
  }
// Método para seleccionar una receta para una sección del plan de comidas. Recibe el tipo de comida y las categorías permitidas para filtrar las recetas disponibles. Navega a la pantalla _SelectorRecetaScreen, donde el usuario puede elegir una receta del catálogo que cumpla con las categorías especificadas. Al regresar de la selección, si se obtuvo un resultado válido, se llama a _guardarEnPlan para guardar la receta seleccionada en el plan del usuario.
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
// Método para calcular el total de calorías del plan de comidas del día actual. Recorre cada sección del plan (desayuno, almuerzo, cena, snacks, bebidas) y obtiene el ID de la receta seleccionada para cada sección. Luego, consulta Firestore para obtener los detalles de cada receta y sumar las calorías totales. Si no hay recetas seleccionadas o ocurre un error al obtener los datos, se considera que esa sección aporta 0 calorías. El resultado final es el total calórico del día basado en las recetas seleccionadas en el plan.
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
// Método auxiliar para obtener las categorías permitidas según el tipo de comida. Recibe el tipo de comida (desayuno, almuerzo, cena, snack1, etc.) y devuelve una lista de categorías que se deben usar para filtrar las recetas disponibles al seleccionar una receta para esa sección del plan. Esto permite que, por ejemplo, al seleccionar una receta para el desayuno solo se muestren recetas categorizadas como "Desayuno", mientras que para los snacks se muestren recetas categorizadas como "Snacks".
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
// Construye la interfaz de la pantalla de plan de comidas, que incluye un encabezado con el título y la fecha seleccionada, un carrusel horizontal para navegar entre días, un resumen calórico total del día y secciones para cada tipo de comida (desayuno, almuerzo, cena, snacks y bebidas). Cada sección muestra la receta seleccionada o un placeholder si no hay receta, y permite agregar o cambiar la receta. Si el plan está cargando, se muestra un indicador de progreso en lugar del contenido.
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
// Construye el encabezado de la pantalla de plan de comidas, que muestra el título "Plan de Comidas" y la fecha seleccionada en un formato amigable. Si la fecha seleccionada es el día actual, se muestra "Hoy" seguido del mes y día. Si no es hoy, se muestra la fecha completa con día, mes y año. Además, si la fecha seleccionada no es hoy, se muestra un botón "Hoy" que permite al usuario volver rápidamente a la fecha actual. El encabezado tiene un diseño limpio con tipografía destacada para el título y un estilo más sutil para la fecha.
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
// Construye el carrusel horizontal de días que permite al usuario navegar entre diferentes fechas para planificar o revisar su plan de comidas. Muestra los días de la semana y el número del día en un formato compacto. El día seleccionado se resalta con un fondo naranja, mientras que el día actual se resalta con un color verde. Al tocar un día, se actualiza la fecha seleccionada y se carga el plan correspondiente a esa fecha.
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
// Construye el resumen calórico total del día basado en las recetas seleccionadas en el plan de comidas. Utiliza un FutureBuilder para calcular las calorías totales de forma asíncrona llamando al método _calcularCaloriasTotales. Si no hay datos o el total es 0, no muestra nada. Si hay un total calórico, muestra un contenedor con un ícono de fuego y el texto "Total del día: X cal", donde X es el total calculado. El contenedor tiene un diseño destacado con fondo verde claro y borde verde.
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
// Construye la sección de comida para un tipo específico (desayuno, almuerzo, cena). Recibe el tipo de comida, el título a mostrar, el ícono, los colores para el diseño y el subtítulo descriptivo. Muestra la receta seleccionada para esa sección o un placeholder si no hay receta. Permite agregar o cambiar la receta mediante un botón que abre el selector de recetas. Si hay una receta seleccionada, muestra una tarjeta con la información de la receta y un botón para eliminarla del plan.
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
// Construye la sección de snacks y bebidas, que incluye un encabezado con el título "Snacks y Bebidas" y un botón para expandir o contraer la sección. Al expandir, muestra subsecciones para snacks y bebidas, cada una con su propio conjunto de slots para agregar recetas. Permite agregar o eliminar recetas para cada slot, y muestra la información de las recetas seleccionadas en tarjetas dentro de cada subsección.
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
// Método auxiliar para construir la cuadrícula de slots para snacks o bebidas. Recibe una lista de claves que representan cada slot (snack1, snack2, bebida1, etc.), los colores para el diseño y una etiqueta para mostrar en el placeholder. Para cada slot, verifica si hay una receta seleccionada en el _planCache; si hay una receta, muestra una tarjeta con la información de la receta y un botón para eliminarla del plan. Si no hay receta, muestra un placeholder que invita al usuario a agregar una receta para ese slot.
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
// Widget que representa una tarjeta de receta dentro del plan de comidas. Muestra la información de la receta obtenida desde Firestore, incluyendo el nombre, imagen, calorías y tiempo de preparación. Permite al usuario tocar la tarjeta para ver los detalles de la receta en una nueva pantalla, y también incluye un botón para eliminar la receta del plan. Si la receta no se encuentra o hay un error al cargarla, muestra un placeholder indicando que la receta no fue encontrada.
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
// Método auxiliar para mostrar un placeholder de imagen cuando no se puede cargar la imagen de la receta. Muestra un contenedor con un fondo de color claro y un ícono de restaurante en el centro, utilizando el color de acento proporcionado.
  Widget _imgPlaceholder(Color color) => Container(
        width: 80,
        height: 80,
        color: color.withValues(alpha: 0.1),
        child: Icon(Icons.restaurant, size: 28, color: color),
      );
}
// Widget que representa un placeholder vacío para las secciones de comida que aún no tienen una receta seleccionada. Muestra un contenedor con un fondo de color claro, un borde del mismo color y un ícono de agregar junto con un texto que invita al usuario a planificar esa sección del plan de comidas. Al tocar el placeholder, se ejecuta la función onTap para abrir el selector de recetas correspondiente.
class _PlaceholderVacio extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color color;

  const _PlaceholderVacio({
    required this.label,
    required this.onTap,
    this.color = const Color(0xFF2D9E73),
  });
// Construye la interfaz del placeholder vacío, que incluye un ícono de agregar y un texto descriptivo. El contenedor tiene un diseño limpio con un fondo de color claro y un borde del mismo color, utilizando el color proporcionado para mantener la coherencia visual con el resto de la sección.
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
// Widget que representa la pantalla de selección de recetas para un tipo específico de comida. Permite al usuario buscar entre las recetas disponibles en Firestore, filtrando por categorías permitidas según el tipo de comida. Muestra una lista de recetas que coinciden con la búsqueda y las categorías, y permite al usuario seleccionar una receta para agregarla al plan de comidas.
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
// Estado de la pantalla de selección de recetas. Maneja la lógica de búsqueda, filtrado por categorías y selección de recetas. Utiliza un StreamBuilder para mostrar las recetas disponibles en tiempo real desde Firestore, y permite al usuario buscar por nombre de receta. Al seleccionar una receta, se devuelve la información de la receta seleccionada a la pantalla anterior para agregarla al plan de comidas.
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
// Limpia el controlador de texto al desechar el widget para evitar fugas de memoria.
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
// Construye la interfaz de la pantalla de selección de recetas, que incluye un campo de búsqueda y una lista de recetas filtradas por la búsqueda y las categorías permitidas. Permite al usuario seleccionar una receta para agregarla al plan de comidas, o limpiar la búsqueda para mostrar todas las recetas disponibles.
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
// Método auxiliar para mostrar un placeholder de imagen cuando no se puede cargar la imagen de la receta. Muestra un contenedor con un fondo de color claro y un ícono de restaurante en el centro, utilizando el color de acento proporcionado.
  Widget _placeholder() => Container(
        width: 80,
        height: 80,
        color: const Color(0xFFE8F7F1),
        child: const Icon(Icons.restaurant, size: 28, color: _verde),
      );
}
