import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'favoritos_provider.dart';
import 'cocina_pasos_screen.dart';
import 'crear_receta_usuario_screen.dart';

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
    // Buscar primero en app-recetas-completas, luego en recetas_personales
    var docSnapshot = await FirebaseFirestore.instance
        .collection('app-recetas-completas')
        .doc(widget.recetaId)
        .get();

    Map<String, dynamic> receta;
    if (docSnapshot.exists) {
      receta = docSnapshot.data()!;
    } else {
      // Fallback: buscar en recetas_personales (recetas copiadas o personales)
      final personalSnap = await FirebaseFirestore.instance
          .collection('recetas_personales')
          .doc(widget.recetaId)
          .get();
      if (!personalSnap.exists) {
        throw Exception("No se encontró la receta");
      }
      receta = personalSnap.data()!;
    }
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
    // Cargar pasos: primero desde el propio doc, luego desde steps-recetas
    List<dynamic> pasos = [];
    if (receta.containsKey('pasos_ordenados')) {
      pasos = List.from(receta['pasos_ordenados'] ?? []);
    } else if (receta.containsKey('pasos')) {
      pasos = List.from(receta['pasos'] ?? []);
    }
    // Si el doc no tenía pasos embebidos, buscar en steps-recetas
    if (pasos.isEmpty) {
      try {
        final stepsDoc = await FirebaseFirestore.instance
            .collection('steps-recetas')
            .doc(widget.recetaId)
            .get();
        if (stepsDoc.exists) {
          pasos = List.from(stepsDoc.data()!['pasos_ordenados'] ?? []);
        }
        if (pasos.isEmpty) {
          for (final campo in ['receta_id', 'recetas_id']) {
            final q = await FirebaseFirestore.instance
                .collection('steps-recetas')
                .where(campo, isEqualTo: widget.recetaId)
                .limit(1)
                .get();
            if (q.docs.isNotEmpty) {
              pasos = List.from(q.docs.first.data()['pasos_ordenados'] ?? []);
              break;
            }
          }
        }
      } catch (_) {}
    }
    pasos.sort((a, b) => (a['orden'] ?? 0).compareTo(b['orden'] ?? 0));

    return {'receta': receta, 'ingredientes': ingredientes, 'pasos': pasos};
  }

  bool get _puedecocinar {
    if (_checks.isEmpty || _ingredientesEditables.isEmpty) return false;

    // 1. Condición del mayor al 80%
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

    // El botón solo sirve si tiene mas del 80% Y NO falta ningún primordial
    return tieneOchentaPorciento && !faltaPrimordial;
  }

  void _mostrarMiniVentanaIngrediente(_IngredienteCompleto ing) {
    final Color verde = const Color(0xFF2E7D32);
    final double cantidadActual = ing.cantidad * _porciones / _porcionesBase;
    final String numero = _calcularNumero(ing.cantidad);
    final String unidad = ing.unidad.trim();
    final String textoCompleto = unidad.isNotEmpty
        ? '$numero $unidad de ${ing.nombre}'
        : '$numero ${ing.nombre}';

    showDialog(
      context: context,
      barrierColor: Colors.black45,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.hardEdge,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Foto o placeholder
            SizedBox(
              height: 160,
              width: double.infinity,
              child: ing.foto.isNotEmpty
                  ? Image.network(
                      ing.foto,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: const Color(0xFFE8F7F1),
                        child: Icon(Icons.restaurant_rounded, size: 60, color: verde),
                      ),
                    )
                  : Container(
                      color: const Color(0xFFE8F7F1),
                      child: Icon(Icons.restaurant_rounded, size: 60, color: verde),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                children: [
                  Text(
                    ing.nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F7F1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      textoCompleto,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: verde,
                      ),
                    ),
                  ),
                  if (ing.sustituto.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      '💡 Sustituto: ${ing.sustituto}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cerrar'),
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

  // ─── Copiar receta aprobada a recetas personales ───
  Future<void> _copiarAPersonales(Map<String, dynamic> receta) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Copiar receta', style: TextStyle(fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Se guardará una copia de "${receta['nombre']}" en Mis recetas para que puedas editarla.'),
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
                      'La copia se guardará como borrador para que la personalices.',
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
            child: const Text('Copiar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmar != true || !mounted) return;

    try {
      // Construir ingredientes en el formato de recetas_personales
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
        // Intento 1: doc con el mismo ID en steps-recetas
        final stepsDoc = await FirebaseFirestore.instance
            .collection('steps-recetas')
            .doc(widget.recetaId)
            .get();
        if (stepsDoc.exists) {
          pasosOriginales = List.from(stepsDoc.data()!['pasos_ordenados'] ?? []);
        }
        // Intento 2: campo receta_id / recetas_id
        if (pasosOriginales.isEmpty) {
          for (final campo in ['receta_id', 'recetas_id']) {
            final q = await FirebaseFirestore.instance
                .collection('steps-recetas')
                .where(campo, isEqualTo: widget.recetaId)
                .limit(1)
                .get();
            if (q.docs.isNotEmpty) {
              pasosOriginales = List.from(q.docs.first.data()['pasos_ordenados'] ?? []);
              break;
            }
          }
        }
        // Fallback: pasos dentro del mismo doc de la receta
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
        'copiadaDe': widget.recetaId,
      };

      final docRef = await FirebaseFirestore.instance
          .collection('recetas_personales')
          .add(payload);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text('Receta copiada a Mis recetas'),
            ],
          ),
          backgroundColor: const Color(0xFF2D9E73),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
          action: SnackBarAction(
            label: 'Editar',
            textColor: Colors.white,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CrearRecetaUsuarioScreen(
                    recetaExistente: payload,
                    recetaPersonalId: docRef.id,
                  ),
                ),
              );
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al copiar: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // final favState = FavoritosProvider.of(context);
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
          final pasosList = snapshot.data!['pasos'] as List? ?? [];

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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
                                          'id': widget
                                              .recetaId, // <-- LA LÍNEA VITAL QUE FALTABA
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
                              if (!widget.isAdmin) ...[
                                const SizedBox(width: 8),
                                GestureDetector(
                                  onTap: () => _copiarAPersonales(receta),
                                  child: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE8F7F1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFF2D9E73).withOpacity(0.4)),
                                    ),
                                    child: const Icon(
                                      Icons.copy_rounded,
                                      color: Color(0xFF2D9E73),
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ],
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

                              Wrap(
                                spacing: 14,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
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
                                            // Ícono tap → mini ventana con foto
                                            GestureDetector(
                                              onTap: widget.isAdmin
                                                  ? null
                                                  : () => _mostrarMiniVentanaIngrediente(ing),
                                              child: Container(
                                                width: 40,
                                                height: 40,
                                                decoration: BoxDecoration(
                                                  color: marcado
                                                      ? Colors.grey[100]
                                                      : const Color(0xFFE8F7F1),
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Icon(
                                                  Icons.restaurant_rounded,
                                                  size: 20,
                                                  color: marcado
                                                      ? Colors.grey[400]
                                                      : _verde,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      textoCompleto,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: marcado
                                                            ? Colors.grey[400]
                                                            : const Color(
                                                                0xFF1A1A1A,
                                                              ),
                                                        decoration: marcado
                                                            ? TextDecoration
                                                                  .lineThrough
                                                            : null,
                                                      ),
                                                    ),
                                                  ),
                                                  if (ing.es_primordial) ...[
                                                    const SizedBox(width: 6),
                                                    const Icon(
                                                      Icons.star_rounded,
                                                      size: 16,
                                                      color: Colors.amber,
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 10),

                                            widget.isAdmin
                                                ? Row(
                                                    children: [
                                                      IconButton(
                                                        constraints:
                                                            const BoxConstraints(),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        iconSize: 18,
                                                        icon: const Icon(
                                                          Icons.edit,
                                                          color: Colors.blue,
                                                        ),
                                                        onPressed: () {
                                                          _editarIngrediente(
                                                            i,
                                                            ing,
                                                          );
                                                        },
                                                      ),

                                                      IconButton(
                                                        constraints:
                                                            const BoxConstraints(),
                                                        padding:
                                                            EdgeInsets.zero,
                                                        iconSize: 18,
                                                        icon: const Icon(
                                                          Icons.delete,
                                                          color: Colors.red,
                                                        ),
                                                        onPressed: () {
                                                          setState(() {
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
                    // ── Sección Pasos ──────────────────────────────
                    if (pasosList.isNotEmpty)
                    Container(
                          color: Colors.white,
                          margin: const EdgeInsets.only(top: 8),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Preparación',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...pasosList.asMap().entries.map((entry) {
                                final i = entry.key;
                                final paso = entry.value as Map<String, dynamic>;
                                final instruccion = paso['instruccion']?.toString() ?? '';
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF2E7D32),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${i + 1}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          instruccion,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            height: 1.5,
                                            color: Color(0xFF444455),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
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
      //a aca
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
                                ? 'Marca más del 80% de ingredientes ($porcentaje%)'
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
