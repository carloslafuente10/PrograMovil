import 'package:flutter/material.dart';// Librería de Flutter para la construcción de interfaces gráficas.
import 'package:cloud_firestore/cloud_firestore.dart';// Permite interactuar con la base de datos Firestore de Firebase para obtener los datos de las recetas e ingredientes.

// ─── Modelo interno ───────────────────────────────────────────────────────────
class _IngAdmin {
  final String nombre;
  final String foto;
  final double cantidad;
  final String unidad;
  final bool esPrimordial;

  const _IngAdmin({
    required this.nombre,
    required this.foto,
    required this.cantidad,
    required this.unidad,
    this.esPrimordial = false,
  });
}

// ─── Pantalla principal ───────────────────────────────────────────────────────
class VerRecetaAdminScreen extends StatefulWidget {
  final String recetaId;
  final String nombreReceta;

  const VerRecetaAdminScreen({
    super.key,
    required this.recetaId,
    required this.nombreReceta,
  });

  @override
  State<VerRecetaAdminScreen> createState() => _VerRecetaAdminScreenState();
}
// Pantalla que muestra los detalles de una receta en modo solo lectura para administradores, incluyendo ingredientes y pasos de preparación.
class _VerRecetaAdminScreenState extends State<VerRecetaAdminScreen> {
  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  static const Color _fondo = Color(0xFFF7F7F5);

  late Future<Map<String, dynamic>> _future;

  @override
  void initState() {
    super.initState();
    _future = _cargarReceta();
  }

  // ── Helpers numéricos ──────────────────────────────────────────────────────
  String _calcularNumero(double cantidad) {
    final int parteEntera = cantidad.floor();
    final double decimal = cantidad - parteEntera;
    final Map<double, String> fracciones = {
      0.25: '¼', 0.33: '⅓', 0.5: '½', 0.67: '⅔', 0.75: '¾',
    };
    for (final e in fracciones.entries) {
      if ((decimal - e.key).abs() < 0.05) {
        return parteEntera == 0 ? e.value : '$parteEntera${e.value}';
      }
    }
    if (decimal < 0.05) return '$parteEntera';
    return cantidad.toStringAsFixed(1);
  }

  // Unidades que nunca se pluralizan (abreviaciones y símbolos)
  static const _unidadesInvariables = {'ml', 'g', 'kg', 'oz', 'lb', 'gr', 'l'};

  // Unidades que son medidas (se muestra "de" antes del nombre)
  static const _unidadesMedida = {
    'cucharada', 'cucharadas', 'cucharadita', 'cucharaditas',
    'cucharita', 'cucharitas',
    'taza', 'tazas', 'vaso', 'vasos', 'copa', 'copas',
    'litro', 'litros', 'l',
    'mililitro', 'mililitros', 'ml',
    'gramo', 'gramos', 'g', 'gr',
    'kilogramo', 'kilogramos', 'kg',
    'onza', 'onzas', 'oz',
    'libra', 'libras', 'lb',
    'pizca', 'pizcas',
    'puñado', 'puñados',
    'trozo', 'trozos',
    'rodaja', 'rodajas',
    'rebanada', 'rebanadas',
    'porción', 'porciones',
    'unidad', 'unidades',
  };

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
    final List<String> partes = limpio.split(' ');
    final int deIdx = partes.indexWhere((p) => p.toLowerCase() == 'de');
    if (deIdx > 0) {
      partes[0] = _pluralizarPalabra(partes[0], cantidad);
      return partes.join(' ');
    }
    partes[0] = _pluralizarPalabra(partes[0], cantidad);
    return partes.join(' ');
  }

  String _pluralizarNombre(double cantidad, String nombre) {
    if (cantidad <= 1 || nombre.trim().isEmpty) return nombre.trim();
    final String limpio = nombre.trim();
    if (limpio.toLowerCase().contains(' de ')) return limpio;
    final List<String> partes = limpio.split(' ');
    partes[0] = _pluralizarPalabra(partes[0], cantidad);
    return partes.join(' ');
  }

  String _abreviarUnidad(String unidad, double cantidad) {
    final String lower = unidad.toLowerCase();
    // Abreviaciones fijas (invariables)
    const Map<String, String> abrevFijas = {
      'gramo': 'g', 'gramos': 'g',
      'kilogramo': 'kg', 'kilogramos': 'kg',
      'mililitro': 'ml', 'mililitros': 'ml',
      'litro': 'litro', 'litros': 'litro',
      'libra': 'libra', 'libras': 'libra',
      'onza': 'oz', 'onzas': 'oz',
    };
    if (abrevFijas.containsKey(lower)) {
      final String base = abrevFijas[lower]!;
      return _pluralizarSeguro(cantidad, base);
    }
    // Abreviaciones con plural especial
    if (lower == 'cucharada' || lower == 'cucharadas') {
      return cantidad <= 1 ? 'cda.' : 'cdas.';
    }
    if (lower == 'cucharadita' || lower == 'cucharaditas' ||
        lower == 'cucharita' || lower == 'cucharitas') {
      return cantidad <= 1 ? 'cdta.' : 'cdtas.';
    }
    if (lower == 'taza' || lower == 'tazas') {
      return cantidad <= 1 ? 'taza' : 'tazas';
    }
    // Para el resto, pluralizar de forma segura
    return _pluralizarSeguro(cantidad, unidad);
  }

  // ── Carga de datos ─────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> _cargarReceta() async {
    // 1. Documento de la receta
    var snap = await FirebaseFirestore.instance
        .collection('app-recetas-completas')
        .doc(widget.recetaId)
        .get();
    if (!snap.exists) throw Exception('Receta no encontrada');
    final receta = snap.data()!;

    // 2. Ingredientes → resolver nombres y fotos desde ingredientes_maestros
    final List<dynamic> rawIngs = receta['ingredientes'] ?? [];
    final List<_IngAdmin> ings = [];
    for (final item in rawIngs) {
      if (item is! Map) continue;
      final String id = item['ingrediente_id']?.toString() ?? '';
      final double cantidad =
          (item['cantidad'] is num) ? (item['cantidad'] as num).toDouble() : 0;
      final String unidad = item['unidad']?.toString() ?? '';
      final bool primordial = item['es_primordial'] ?? false;
      String nombre = id.replaceAll('-', ' ');
      String foto = '';
      if (id.isNotEmpty) {
        try {
          final m = await FirebaseFirestore.instance
              .collection('ingredientes_maestros')
              .doc(id)
              .get();
          if (m.exists) {
            nombre = m.data()!['nombre']?.toString().trim() ?? nombre;
            foto = m.data()!['foto']?.toString() ?? '';
          }
        } catch (_) {}
      }
      ings.add(_IngAdmin(
        nombre: nombre,
        foto: foto,
        cantidad: cantidad,
        unidad: unidad,
        esPrimordial: primordial,
      ));
    }

    // 3. Pasos
    List<dynamic> pasos = [];
    if (receta.containsKey('pasos_ordenados')) {
      pasos = List.from(receta['pasos_ordenados'] ?? []);
    } else if (receta.containsKey('pasos')) {
      pasos = List.from(receta['pasos'] ?? []);
    }
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

    return {'receta': receta, 'ingredientes': ings, 'pasos': pasos};
  }

  // ── Eliminar ───────────────────────────────────────────────────────────────
  void _confirmarEliminar(BuildContext context, String nombre) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar receta',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: Text(
            '¿Eliminar "$nombre"? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await FirebaseFirestore.instance
                  .collection('app-recetas-completas')
                  .doc(widget.recetaId)
                  .delete();
              if (mounted) Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Eliminar',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: _fondo,
            appBar: AppBar(
              backgroundColor: _verde,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(widget.nombreReceta,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            ),
            body: const Center(child: CircularProgressIndicator(color: _verde)),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            appBar: AppBar(
              backgroundColor: _verde,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(widget.nombreReceta,
                  style: const TextStyle(color: Colors.white)),
            ),
            body: Center(child: Text('Error: ${snap.error}')),
          );
        }

        final receta = snap.data!['receta'] as Map<String, dynamic>;
        final ings = snap.data!['ingredientes'] as List<_IngAdmin>;
        final pasos = snap.data!['pasos'] as List;

        final String imagen = receta['imagen']?.toString() ?? '';
        final String nombre = receta['nombre']?.toString() ?? widget.nombreReceta;
        final String categoria = receta['categoria']?.toString() ?? '';
        final String subcategoria = receta['subcategoria']?.toString() ?? '';
        final String caloriasStr =
            (receta['calorías'] ?? receta['calorias'])?.toString() ?? '0';
        final int tiempo =
            int.tryParse(receta['tiempo']?.toString() ?? '0') ?? 0;

        return Scaffold(
          backgroundColor: _fondo,
          body: CustomScrollView(
            slivers: [
              // ── AppBar con imagen ────────────────────────────────────────
              SliverAppBar(
                expandedHeight: 260,
                pinned: true,
                backgroundColor: _verde,
                foregroundColor: Colors.white,
                leading: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Colors.white),
                  ),
                ),
                actions: [
                  // Badge Solo lectura
                  Container(
                    margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_rounded, color: Colors.white, size: 12),
                        SizedBox(width: 4),
                        Text('Sólo lectura',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: imagen.isNotEmpty
                      ? Image.network(imagen, fit: BoxFit.cover)
                      : Container(
                          color: _verde.withOpacity(0.2),
                          child: const Icon(Icons.restaurant,
                              size: 80, color: Colors.white54),
                        ),
                ),
              ),

              // ── Contenido ────────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre + categorías + info
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Chips categoría / subcategoría
                          if (categoria.isNotEmpty || subcategoria.isNotEmpty)
                            Wrap(
                              spacing: 6,
                              children: [
                                if (categoria.isNotEmpty)
                                  _Chip(label: categoria),
                                if (subcategoria.isNotEmpty)
                                  _Chip(
                                      label: subcategoria,
                                      color: Colors.grey[700]!,
                                      bg: Colors.grey[100]!),
                              ],
                            ),
                          const SizedBox(height: 10),
                          Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 16,
                            runSpacing: 6,
                            children: [
                              _InfoChip(
                                icon: Icons.local_fire_department,
                                color: Colors.orange[400]!,
                                label: '$caloriasStr cal',
                              ),
                              if (tiempo > 0)
                                _InfoChip(
                                  icon: Icons.access_time,
                                  color: Colors.grey[500]!,
                                  label: '$tiempo min',
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Ingredientes ─────────────────────────────────────
                    Container(
                      color: Colors.white,
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Ingredientes',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (ings.isEmpty)
                            Text('No hay ingredientes.',
                                style: TextStyle(color: Colors.grey[500]))
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: ings.length,
                              separatorBuilder: (_, __) =>
                                  Divider(height: 1, color: Colors.grey[100]),
                              itemBuilder: (_, i) =>
                                  _IngRow(
                                    ing: ings[i],
                                    calcNum: _calcularNumero,
                                    abrevU: _abreviarUnidad,
                                    esMedida: (u) => _unidadesMedida.contains(u),
                                    pluralizarNombre: _pluralizarNombre,
                                  ),
                            ),
                        ],
                      ),
                    ),

                    // ── Preparación ──────────────────────────────────────
                    if (pasos.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        color: Colors.white,
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
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
                            ...pasos.asMap().entries.map((e) {
                              final instruccion =
                                  (e.value as Map<String, dynamic>)['instruccion']
                                          ?.toString() ??
                                      '';
                              if (instruccion.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      width: 30,
                                      height: 30,
                                      decoration: const BoxDecoration(
                                        color: _verde,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${e.key + 1}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(top: 5),
                                        child: Text(
                                          instruccion,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF3A3A3A),
                                            height: 1.55,
                                          ),
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
                    ],

                    SizedBox(
                      height: MediaQuery.of(context).padding.bottom + 80,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // ── Bottom bar: solo Eliminar ─────────────────────────────────────
          bottomNavigationBar: Container(
            padding: EdgeInsets.fromLTRB(
                20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _confirmarEliminar(context, nombre),
                icon: const Icon(Icons.delete_rounded, size: 20),
                label: const Text(
                  'Eliminar receta',
                  style:
                      TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE53935),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── Fila de ingrediente ──────────────────────────────────────────────────────
class _IngRow extends StatelessWidget {
  final _IngAdmin ing;
  final String Function(double) calcNum;
  final String Function(String, double) abrevU;
  final bool Function(String) esMedida;
  final String Function(double, String) pluralizarNombre;

  const _IngRow({
    required this.ing,
    required this.calcNum,
    required this.abrevU,
    required this.esMedida,
    required this.pluralizarNombre,
  });

  static const Color _verde = Color(0xFF2D9E73);

  @override
  Widget build(BuildContext context) {
    final String numero = calcNum(ing.cantidad);
    final String unidadTrim = ing.unidad.trim();
    final String unidadLower = unidadTrim.toLowerCase();

    // "unidad" / "unidades" → ocultar, solo mostrar nombre pluralizado
    final bool esUnidad = unidadLower == 'unidad' || unidadLower == 'unidades';

    String cantidadTexto;
    String nombreTexto;

    if (esUnidad || unidadTrim.isEmpty) {
      // Sin unidad: [número] [nombre pluralizado]
      cantidadTexto = numero;
      nombreTexto = pluralizarNombre(ing.cantidad, ing.nombre);
    } else {
      final String unidadAbrev = abrevU(unidadTrim, ing.cantidad);
      cantidadTexto = '$numero $unidadAbrev';
      // Si es medida → "de nombre"; si la unidad ya incluye "de" → nombre solo
      if (unidadLower.contains(' de ')) {
        nombreTexto = ing.nombre;
      } else if (esMedida(unidadLower)) {
        nombreTexto = 'de ${ing.nombre}';
      } else {
        nombreTexto = pluralizarNombre(ing.cantidad, ing.nombre);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Foto
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F7F1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ing.foto.isNotEmpty
                  ? Image.network(
                      ing.foto,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.restaurant_rounded,
                          size: 22,
                          color: _verde),
                    )
                  : const Icon(Icons.restaurant_rounded,
                      size: 22, color: _verde),
            ),
          ),
          const SizedBox(width: 10),

          // 2. Cantidad + unidad abreviada
          Text(
            cantidadTexto,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _verde,
            ),
          ),
          const SizedBox(width: 8),

          // 3. Nombre del ingrediente
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    nombreTexto,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                if (ing.esPrimordial) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Widgets pequeños ─────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;

  const _Chip({
    required this.label,
    this.color = const Color(0xFF2D9E73),
    this.bg = const Color(0xFFE8F7F1),
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;

  const _InfoChip(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        ],
      );
}
