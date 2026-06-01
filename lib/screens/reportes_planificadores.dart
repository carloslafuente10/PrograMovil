import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../servicios/pdf_servicios.dart';

class ReportesPlanificadoresScreen extends StatefulWidget {
  const ReportesPlanificadoresScreen({super.key});

  @override
  State<ReportesPlanificadoresScreen> createState() =>
      _ReportesPlanificadoresScreenState();
}

class _ReportesPlanificadoresScreenState
    extends State<ReportesPlanificadoresScreen> {

  static const Color _verde     = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  static const Color _pizarra   = Color(0xFF455A64);
  static const Color _fondo     = Color(0xFFF4F6F8);

  DateTime _fechaSeleccionada = DateTime.now();
  String _formatoReporte = 'PDF';

  static const List<List<Color>> _paletas = [
    [Color(0xFF1565C0), Color(0xFFE3F2FD)],
    [Color(0xFF6A1B9A), Color(0xFFF3E5F5)],
    [Color(0xFF00838F), Color(0xFFE0F7FA)],
    [Color(0xFFE65100), Color(0xFFFFF3E0)],
    [Color(0xFF558B2F), Color(0xFFF1F8E9)],
    [Color(0xFFC62828), Color(0xFFFFEBEE)],
    [Color(0xFF4527A0), Color(0xFFEDE7F6)],
    [Color(0xFF00695C), Color(0xFFE0F2F1)],
  ];

  static List<Color> _paletaPara(String seed) {
    int hash = 0;
    for (final c in seed.codeUnits) {
      hash = (hash * 31 + c) & 0x7FFFFFFF;
    }
    return _paletas[hash % _paletas.length];
  }

  String _getFechaFormateada() {
    const meses = ['Ene','Feb','Mar','Abr','May','Jun',
                   'Jul','Ago','Sep','Oct','Nov','Dic'];
    return '${_fechaSeleccionada.day} de '
        '${meses[_fechaSeleccionada.month - 1]} '
        '${_fechaSeleccionada.year}';
  }

  String _getDocId(String uid, DateTime date) {
    final mes = date.month.toString().padLeft(2, '0');
    final dia = date.day.toString().padLeft(2, '0');
    return '${uid}_${date.year}-$mes-$dia';
  }

  void _cambiarFecha(int dias) =>
      setState(() => _fechaSeleccionada = _fechaSeleccionada.add(Duration(days: dias)));

  Future<void> _seleccionarFecha(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2025),
      lastDate: DateTime(2027),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: _verde),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _fechaSeleccionada = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        title: const Text('Planes por Fecha',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: _verde,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: _verde),
                  onPressed: () => _cambiarFecha(-1),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _seleccionarFecha(context),
                    child: Column(
                      children: [
                        const Text('Fecha seleccionada',
                            style: TextStyle(fontSize: 10, color: Colors.grey)),
                        Text(
                          _getFechaFormateada(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: _verde,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward_ios_rounded, color: _verde),
                  onPressed: () => _cambiarFecha(1),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButton<String>(
                        value: _formatoReporte,
                        underline: const SizedBox(),
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: 'PDF',   child: Text('PDF')),
                          DropdownMenuItem(value: 'Excel', child: Text('Excel')),
                          DropdownMenuItem(value: 'CSV',   child: Text('CSV')),
                        ],
                        onChanged: (v) => setState(() => _formatoReporte = v!),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Generando reporte...')),
                        );
                        if (_formatoReporte == 'PDF') {
                          await PdfService.generarReportePlanificadoresPdf(_fechaSeleccionada);
                        } else if (_formatoReporte == 'Excel') {
                          await PdfService.generarExcelPlanificadores(_fechaSeleccionada);
                        } else {
                          await PdfService.generarCsvPlanificadores(_fechaSeleccionada);
                        }
                      },
                      icon: const Icon(Icons.download_rounded, size: 15, color: Colors.white),
                      label: const Text('Reporte',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _verde,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('app-usuarios')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator(color: _verde));
                }

                // Ordenar usuarios
                final usuarios = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
                usuarios.sort((a, b) {
                  final da = a.data() as Map<String, dynamic>;
                  final db = b.data() as Map<String, dynamic>;
                  final na = (da['nombre'] ?? '').toString().trim().toLowerCase();
                  final nb = (db['nombre'] ?? '').toString().trim().toLowerCase();
                  if (na.isEmpty && nb.isEmpty) return 0;
                  if (na.isEmpty) return 1;
                  if (nb.isEmpty) return -1;
                  return na.compareTo(nb);
                });

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: usuarios.length,
                  itemBuilder: (context, i) {
                    final userData = usuarios[i].data() as Map<String, dynamic>;
                    final uid = usuarios[i].id;
                    final docId = _getDocId(uid, _fechaSeleccionada);
                    final nombreUsuario = userData['nombre']?.toString() ?? '';
                    final inicial = nombreUsuario.isNotEmpty
                        ? nombreUsuario[0].toUpperCase()
                        : '?';
                    final paleta = _paletaPara(uid);

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('app-planes')
                          .doc(docId)
                          .get(),
                      builder: (context, planSnapshot) {
                        Map<String, dynamic> plan = {};
                        if (planSnapshot.hasData && planSnapshot.data!.exists) {
                          final data = planSnapshot.data!.data();
                          if (data != null) plan = Map<String, dynamic>.from(data as Map);
                        }

                        return Card(
                          elevation: 1,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: paleta[1],
                                  child: nombreUsuario.isNotEmpty
                                      ? Text(inicial,
                                          style: TextStyle(
                                            color: paleta[0],
                                            fontWeight: FontWeight.bold,
                                          ))
                                      : Icon(Icons.person, color: paleta[0]),
                                ),
                              ],
                            ),
                            title: Text(
                              nombreUsuario.isNotEmpty ? nombreUsuario : 'Sin nombre',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              plan.isEmpty ? 'Sin plan registrado' : 'Plan activo',
                              style: TextStyle(
                                fontSize: 12,
                                color: plan.isEmpty ? Colors.grey : _verde,
                                fontWeight: plan.isEmpty
                                    ? FontWeight.normal
                                    : FontWeight.w600,
                              ),
                            ),
                            children: [
                              _buildComidaSlot(plan, 'desayuno', 'Desayuno', Icons.wb_sunny_rounded),
                              _buildComidaSlot(plan, 'almuerzo', 'Almuerzo', Icons.restaurant_rounded),
                              _buildComidaSlot(plan, 'cena',     'Cena',     Icons.nights_stay_rounded),
                              const SizedBox(height: 8),
                            ],
                          ),
                        );
                      },
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


  Widget _buildComidaSlot(
    Map<String, dynamic> plan,
    String key,
    String label,
    IconData icono,
  ) {
    final recetaId = plan[key]?.toString() ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icono, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 10),
          SizedBox(
            width: 70,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
          ),
          Expanded(
            child: recetaId.isEmpty
                ? Text('Sin planificar',
                    style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                        color: Colors.grey[400]))
                : _RecetaMiniCard(recetaId: recetaId),
          ),
        ],
      ),
    );
  }
}

class _RecetaMiniCard extends StatelessWidget {
  final String recetaId;
  const _RecetaMiniCard({required this.recetaId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('app-recetas-completas')
          .doc(recetaId)
          .get(),
      builder: (context, snap) {
        if (!snap.hasData || !snap.data!.exists) {
          return const Text('No disponible',
              style: TextStyle(fontSize: 12, color: Colors.grey));
        }
        final data = snap.data!.data() as Map<String, dynamic>?;
        if (data == null) return const Text('Error');
        final nombre = data['nombre']?.toString() ?? 'Sin nombre';
        final img    = data['imagen']?.toString() ?? '';

        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6F8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: img.isNotEmpty
                    ? Image.network(img, width: 32, height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image, size: 18))
                    : const Icon(Icons.restaurant, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 12),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        );
      },
    );
  }
}