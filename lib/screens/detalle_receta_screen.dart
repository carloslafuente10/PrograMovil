import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'favoritos_provider.dart';
import 'cocina_pasos_screen.dart';

class _IngredienteCompleto {
  final String id;
  final double cantidad;
  final String unidad;
  final String nombre;
  final String foto;
  final String sustituto;
  final bool es_primordial; // <-- 1. Añadimos la variable

  const _IngredienteCompleto({
    required this.id,
    required this.cantidad,
    required this.unidad,
    required this.nombre,
    required this.foto,
    required this.sustituto,
    this.es_primordial = false, // <-- 2. La incluimos en el constructor
  });
}

class DetalleRecetaScreen extends StatefulWidget {
  // 1. Declaramos ambas variables como campos de la clase
  final String recetaId;
  final String nombreReceta;
  final bool isAdmin;

  // 2. Las inicializamos correctamente en el constructor
  const DetalleRecetaScreen({
    super.key,
    required this.recetaId,
    required this.nombreReceta,
    this.isAdmin = false,
  });

  @override
  State<DetalleRecetaScreen> createState() => _DetalleRecetaScreenState();
}

class _DetalleRecetaScreenState extends State<DetalleRecetaScreen> {
  late Future<Map<String, dynamic>> _futureDatos;
  int _porciones = 1;
  int _porcionesBase = 1;
  List<bool> _checks = [];
  List<_IngredienteCompleto> _ingredientesEditables = [];

  bool _isFirstLoad = true;
  final Color _verde = const Color(0xFF2E7D32);

  @override
  void initState() {
    super.initState();
    _futureDatos = _cargarTodo();
  }

  String _calcularNumero(double cantidadBase) {
    final double resultado = cantidadBase * _porciones / _porcionesBase;
    final int parteEntera = resultado.floor();
    final double decimal = resultado - parteEntera;
    final Map<double, String> fracciones = {
      0.25: '1/4',
      0.33: '1/3',
      0.5: '1/2',
      0.67: '2/3',
      0.75: '3/4',
    };
    String? fraccion;
    for (final entry in fracciones.entries) {
      if ((decimal - entry.key).abs() < 0.05) {
        fraccion = entry.value;
        break;
      }
    }

    if (decimal < 0.05) return '$parteEntera';
    if (fraccion != null && parteEntera == 0) return fraccion;
    if (fraccion != null && parteEntera > 0) return '$parteEntera $fraccion';
    return resultado.toStringAsFixed(1);
  }

  String _pluralizarSeguro(double cantidad, String texto) {
    String limpio = texto.trim();
    if (cantidad <= 1 || limpio.isEmpty) return limpio;
    List<String> partes = limpio.split(' ');
    String primera = partes[0];
    String lower = primera.toLowerCase();
    if (lower.endsWith('s') || lower.endsWith('x')) {
    } else if (lower.endsWith('z')) {
      partes[0] = '${primera.substring(0, primera.length - 1)}ces';
    } else if (RegExp(r'[aeiouáéóíú]$').hasMatch(lower)) {
      partes[0] = '${primera}s';
    } else {
      partes[0] = '${primera}es';
    }

    return partes.join(' ');
  }

  String _textoIngrediente(
    double cantidadBase,
    String unidadOriginal,
    String nombre,
  ) {
    double cantidadActual = cantidadBase * _porciones / _porcionesBase;
    String unidadNorm = unidadOriginal.trim().toLowerCase();

    if (['gramo', 'gramos', 'g', 'gr'].contains(unidadNorm) &&
        cantidadActual >= 1000) {
      return '${(cantidadActual / 1000).toStringAsFixed(1).replaceAll('.0', '')} kg de $nombre';
    }
    if (['mililitro', 'mililitros', 'ml'].contains(unidadNorm) &&
        cantidadActual >= 1000) {
      return '${(cantidadActual / 1000).toStringAsFixed(1).replaceAll('.0', '')} L de $nombre';
    }

    final String numero = _calcularNumero(cantidadBase);
    final String unidad = unidadOriginal.trim();
    if (unidad.isNotEmpty) {
      return '$numero ${_pluralizarSeguro(cantidadActual, unidad)} de $nombre';
    }
    return '$numero ${_pluralizarSeguro(cantidadActual, nombre)}';
  }

  Future<Map<String, dynamic>> _cargarTodo() async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('app-recetas-completas')
        .doc(widget.recetaId)
        .get();

    if (!docSnapshot.exists) {
      throw Exception("No se encontró la receta");
    }
    final receta = docSnapshot.data()!;
    final List<dynamic> rawIngredientes = receta['ingredientes'] ?? [];
    final List<_IngredienteCompleto> ingredientes = [];

    for (final item in rawIngredientes) {
      if (item is! Map) continue;
      final String id =
          item['ingrediente_id']?.toString() ??
          item['ingrediente']?.toString() ??
          '';
      final double cantidad = (item['cantidad'] is num)
          ? (item['cantidad'] as num).toDouble()
          : 0.0;
      final String unidad = item['unidad']?.toString() ?? '';
      final bool esPrimordial =
          item['es_primordial'] ?? false; // <-- EXTRAEMOS EL DATO

      String nombre = id;
      String foto = '';
      String sustituto = '';

      if (id.isNotEmpty) {
        try {
          final maestroDoc = await FirebaseFirestore.instance
              .collection('ingredientes_maestros')
              .doc(id)
              .get();
          if (maestroDoc.exists) {
            final m = maestroDoc.data()!;
            nombre = m['nombre']?.toString().trim() ?? id;
            foto = m['foto']?.toString() ?? '';
            final raw = m['sustitutos'];
            if (raw is String)
              sustituto = raw;
            else if (raw is List)
              sustituto = raw.join(', ');
          }
        } catch (_) {}
      }

      if (nombre == id && nombre.contains('-')) {
        nombre = nombre.replaceAll('-', ' ');
      }

      ingredientes.add(
        _IngredienteCompleto(
          id: id,
          cantidad: cantidad,
          unidad: unidad,
          nombre: nombre,
          foto: foto,
          sustituto: sustituto,
          es_primordial: esPrimordial, // <-- CONECTAMOS EL CABLE AL MOLDE
        ),
      );
    }
    return {'receta': receta, 'ingredientes': ingredientes};
  }

  bool get _puedecocinar {
    if (_checks.isEmpty || _ingredientesEditables.isEmpty) return false;

    // 1. Condición del 80%
    final marcadosCount = _checks.where((c) => c).length;
    final bool tieneOchentaPorciento = (marcadosCount / _checks.length) >= 0.8;

    // 2. Condición del Ingrediente Primordial
    bool faltaPrimordial = false;
    for (int i = 0; i < _ingredientesEditables.length; i++) {
      // Si el ingrediente es primordial en la BD y NO tiene el check marcado...
      if (_ingredientesEditables[i].es_primordial && !_checks[i]) {
        faltaPrimordial = true;
        break;
      }
    }

    // El botón solo sirve si tiene el 80% Y NO falta ningún primordial
    return tieneOchentaPorciento && !faltaPrimordial;
  }

  void _editarIngrediente(int index, _IngredienteCompleto ing) {
    final cantidadCtrl = TextEditingController(text: ing.cantidad.toString());
    final nombreCtrl = TextEditingController(text: ing.nombre);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Editar ingrediente"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: "Nombre"),
            ),
            TextField(
              controller: cantidadCtrl,
              decoration: const InputDecoration(labelText: "Cantidad"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _ingredientesEditables[index] = _IngredienteCompleto(
                  id: ing.id,
                  cantidad: double.tryParse(cantidadCtrl.text) ?? 0,
                  unidad: ing.unidad,
                  nombre: nombreCtrl.text,
                  foto: ing.foto,
                  sustituto: ing.sustituto,
                );
              });
              Navigator.pop(context);
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }

  void _agregarIngrediente() {
    final nombreCtrl = TextEditingController();
    final cantidadCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Nuevo ingrediente"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nombreCtrl,
              decoration: const InputDecoration(labelText: "Nombre"),
            ),
            TextField(
              controller: cantidadCtrl,
              decoration: const InputDecoration(labelText: "Cantidad"),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _ingredientesEditables.add(
                  _IngredienteCompleto(
                    id: nombreCtrl.text.toLowerCase().replaceAll(" ", "-"),
                    nombre: nombreCtrl.text,
                    cantidad: double.tryParse(cantidadCtrl.text) ?? 0,
                    unidad: "",
                    foto: "",
                    sustituto: "",
                  ),
                );

                _checks.add(false);
              });

              Navigator.pop(context);
            },
            child: const Text("Agregar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final favState = FavoritosProvider.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _futureDatos,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              backgroundColor: Color(0xFFF7F7F5),
              body: Center(child: CircularProgressIndicator(color: _verde)),
            );
          }

          if (snapshot.hasError)
            return Scaffold(appBar: AppBar(title: Text(widget.nombreReceta)));

          final receta = snapshot.data!['receta'] as Map<String, dynamic>;
          final ingredientes =
              snapshot.data!['ingredientes'] as List<_IngredienteCompleto>;

          if (_isFirstLoad) {
            _porcionesBase =
                int.tryParse(receta['porcion_base']?.toString() ?? '1') ?? 1;
            _porciones = _porcionesBase;
            //_checks = List.filled(ingredientes.length, false);
            _ingredientesEditables = List.from(ingredientes);
            _checks = List.filled(_ingredientesEditables.length, false);
            _isFirstLoad = false;
          }

          final String imagenPrincipal = receta['imagen'] ?? '';
          final String nombre = receta['nombre'] ?? widget.nombreReceta;

          final double caloriasBase =
              double.tryParse(
                (receta['calorías'] ?? receta['calorias'])?.toString() ?? '0',
              ) ??
              0;

          final int caloriasTotales =
              (caloriasBase * (_porciones / _porcionesBase)).round();

          final int tiempoBase =
              int.tryParse(receta['tiempo']?.toString() ?? '0') ?? 0;

          int tiempoAjustado = tiempoBase > 0
              ? (tiempoBase *
                        (1 + (0.15 * ((_porciones / _porcionesBase) - 1))))
                    .round()
              : 0;

          String rating = '';
          receta.forEach((k, v) {
            if (k.trim() == 'rating') rating = v.toString();
          });

          final int resenasNum =
              int.tryParse(receta['reseña']?.toString() ?? '0') ?? 0;

          final int totalIng = _checks.length;
          final int marcados = _checks.where((c) => c).length;
          final int porcentaje = totalIng > 0
              ? ((marcados / totalIng) * 100).round()
              : 0;

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: Colors.white,
                foregroundColor: Colors.white,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: imagenPrincipal.isNotEmpty
                      ? Image.network(imagenPrincipal, fit: BoxFit.cover)
                      : Container(
                          color: _verde.withValues(alpha: 0.2),
                          child: const Icon(
                            Icons.restaurant,
                            size: 80,
                            color: Colors.white54,
                          ),
                        ),
                ),
              ),

              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  nombre,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              if (!widget.isAdmin)
                                Builder(
                                  builder: (context) {
                                    final favStateLocal = FavoritosProvider.of(
                                      context,
                                    );
                                    final bool esFavLocal = favStateLocal
                                        .esFavorito(nombre);
                                    return GestureDetector(
                                      onTap: () {
                                        favStateLocal.toggle({
                                          'id': widget.recetaId, // <-- LA LÍNEA VITAL QUE FALTABA
                                          'nombre': nombre,
                                          'img': imagenPrincipal,
                                          'calorias': caloriasBase
                                              .round()
                                              .toString(),
                                          'tiempo': tiempoBase.toString(),
                                          'categoria':
                                              receta['categoria']?.toString() ??
                                              '',
                                        });
                                      },
                                      child: Container(
                                        width: 40,
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: esFavLocal
                                              ? Colors.red.withValues(
                                                  alpha: 0.1,
                                                )
                                              : const Color(0xFFF7F7F5),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: esFavLocal
                                                ? Colors.redAccent
                                                : Colors.grey[300]!,
                                          ),
                                        ),
                                        child: Icon(
                                          esFavLocal
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          color: esFavLocal
                                              ? Colors.redAccent
                                              : Colors.grey[400],
                                          size: 20,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing:
                                14.0, // Espacio horizontal entre los grupos
                            runSpacing:
                                8.0, // Espacio vertical si se llega a saltar de línea
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // Grupo 1: Calorías
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.local_fire_department,
                                    size: 15,
                                    color: Colors.orange[400],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${caloriasBase.round()} Cal. (Total: $caloriasTotales)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              // Grupo 2: Tiempo
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 15,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    tiempoAjustado > 0
                                        ? '~$tiempoAjustado min'
                                        : '—',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              // Grupo 3: Rating (Condicional)
                              if (rating.isNotEmpty &&
                                  rating != '0' &&
                                  rating != '0.0')
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 15,
                                      color: Colors.amber,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      resenasNum > 0
                                          ? '$rating ($resenasNum)'
                                          : '$rating',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Ingredientes',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),

                              Row(
                                children: [
                                  if (widget.isAdmin)
                                    IconButton(
                                      icon: const Icon(
                                        Icons.add,
                                        color: Colors.green,
                                      ),
                                      onPressed: _agregarIngrediente,
                                    ),

                                  if (!widget.isAdmin) ...[
                                    _ContadorBtn(
                                      icon: Icons.remove,
                                      onTap: () {
                                        if (_porciones > 1) {
                                          setState(() {
                                            _porciones--;
                                            _checks = List.filled(
                                              _ingredientesEditables.length,
                                              false,
                                            );
                                          });
                                        }
                                      },
                                    ),

                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),
                                      child: Text('$_porciones'),
                                    ),

                                    _ContadorBtn(
                                      icon: Icons.add,
                                      onTap: () {
                                        setState(() {
                                          _porciones++;
                                          _checks = List.filled(
                                            _ingredientesEditables.length,
                                            false,
                                          );
                                        });
                                      },
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          //if (ingredientes.isEmpty)
                          if (_ingredientesEditables.isEmpty)
                            Text(
                              'No hay ingredientes disponibles',
                              style: TextStyle(color: Colors.grey[500]),
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              //itemCount: ingredientes.length,
                              itemCount: _ingredientesEditables.length,
                              separatorBuilder: (context, index) =>
                                  Divider(height: 1, color: Colors.grey[100]),
                              itemBuilder: (context, i) {
                                //final ing = ingredientes[i];
                                final ing = _ingredientesEditables[i];
                                final marcado = _checks.length > i
                                    ? _checks[i]
                                    : false;
                                final String textoCompleto = _textoIngrediente(
                                  ing.cantidad,
                                  ing.unidad,
                                  ing.nombre,
                                );
                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      GestureDetector(
                                        onTap: widget.isAdmin
                                            ? null
                                            : () => setState(
                                                () => _checks[i] = !_checks[i],
                                              ),
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: ing.foto.isNotEmpty
                                                  ? Image.network(
                                                      ing.foto,
                                                      width: 44,
                                                      height: 44,
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (c, e, s) =>
                                                          _IngPlaceholder(),
                                                    )
                                                  : _IngPlaceholder(),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                textoCompleto,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: marcado
                                                      ? Colors.grey[400]
                                                      : const Color(0xFF1A1A1A),
                                                  decoration: marcado
                                                      ? TextDecoration
                                                            .lineThrough
                                                      : null,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            /*AnimatedContainer(//
                                              duration: const Duration(
                                                milliseconds: 200,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: marcado
                                                    ? _verde
                                                    : Colors.red.withValues(
                                                        alpha: 0.1,
                                                      ),
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: marcado
                                                      ? _verde
                                                      : Colors.red[300]!,
                                                  width: 1,
                                                ),
                                              ),
                                              child: Text(
                                                marcado ? 'Tengo ✓' : 'Falta',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: marcado
                                                      ? Colors.white
                                                      : Colors.red[700],
                                                ),
                                              ),
                                            )*/
                                            widget.isAdmin
                                                ? Row(
                                                    children: [
                                                      //  EDITAR
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.edit,
                                                          color: Colors.blue,
                                                          size: 18,
                                                        ),
                                                        onPressed: () {
                                                          _editarIngrediente(
                                                            i,
                                                            ing,
                                                          );
                                                        },
                                                      ),

                                                      //ELIMINAR
                                                      IconButton(
                                                        icon: const Icon(
                                                          Icons.delete,
                                                          color: Colors.red,
                                                          size: 18,
                                                        ),
                                                        onPressed: () {
                                                          setState(() {
                                                            //ingredientes.removeAt(i);
                                                            //_checks.removeAt(i);
                                                            _ingredientesEditables
                                                                .removeAt(i);
                                                            _checks.removeAt(i);
                                                          });
                                                        },
                                                      ),
                                                    ],
                                                  )
                                                : AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 200,
                                                    ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: marcado
                                                          ? _verde
                                                          : Colors.red
                                                                .withValues(
                                                                  alpha: 0.1,
                                                                ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            20,
                                                          ),
                                                      border: Border.all(
                                                        color: marcado
                                                            ? _verde
                                                            : Colors.red[300]!,
                                                        width: 1,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      marcado
                                                          ? 'Tengo ✓'
                                                          : 'Falta',
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: marcado
                                                            ? Colors.white
                                                            : Colors.red[700],
                                                      ),
                                                    ),
                                                  ),
                                          ],
                                        ),
                                      ),
                                      if (ing.sustituto.isNotEmpty && !marcado)
                                        Container(
                                          margin: const EdgeInsets.only(
                                            top: 12,
                                            left: 56,
                                          ),
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF4F5F7),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.lightbulb_outline,
                                                    color: Colors.orange[400],
                                                    size: 16,
                                                  ),
                                                  const SizedBox(width: 6),
                                                  const Text(
                                                    'Sugerencia',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                      color: Color(0xFF1A1A1A),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 6),
                                              RichText(
                                                text: TextSpan(
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[600],
                                                    height: 1.4,
                                                  ),
                                                  children: [
                                                    const TextSpan(
                                                      text: 'Si no tienes ',
                                                    ),
                                                    TextSpan(
                                                      text: ing.nombre,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Color(
                                                          0xFF1A1A1A,
                                                        ),
                                                      ),
                                                    ),
                                                    const TextSpan(
                                                      text: ', puedes usar ',
                                                    ),
                                                    TextSpan(
                                                      text: ing.sustituto,
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Color(
                                                          0xFF1A1A1A,
                                                        ),
                                                      ),
                                                    ),
                                                    const TextSpan(text: '.'),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: FutureBuilder<Map<String, dynamic>>(
          future: _futureDatos,
          builder: (context, snapshot) {
            final receta = snapshot.data?['receta'] as Map<String, dynamic>?;
            final String nombre = receta?['nombre'] ?? widget.nombreReceta;
            final int totalIng = _checks.length;
            final int marcados = _checks.where((c) => c).length;
            final int porcentaje = totalIng > 0
                ? ((marcados / totalIng) * 100).round()
                : 0;
            final bool activo = _puedecocinar;

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (totalIng > 0) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            // Calculamos el progreso de 0.0 a 1.0
                            value: marcados / totalIng,
                            minHeight: 6,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(
                              activo ? _verde : Colors.orange,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        // Mostramos el porcentaje sin decimales
                        '${porcentaje.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: activo ? _verde : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: activo
                        ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CocinaPasosScreen(recetaId: widget.recetaId),
                            ),
                          )
                        : null,
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: Text(
                      activo
                          ? 'Empezar a cocinar'
                          : (porcentaje < 80
                                ? 'Marca el 80% de ingredientes ($porcentaje%)'
                                : 'Falta ingrediente obligatorio'), // <--- Aviso extra
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _verde,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[500],
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ContadorBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ContadorBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF1A1A1A)),
      ),
    );
  }
}

class _IngPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFE8E8E8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.restaurant, size: 20, color: Colors.white70),
    );
  }
}
