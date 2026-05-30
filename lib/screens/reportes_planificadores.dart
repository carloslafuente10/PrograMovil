import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../servicios/pdf_servicios.dart'; // Importación de los servicios

class ReportesPlanificadoresScreen extends StatefulWidget {
  const ReportesPlanificadoresScreen({super.key});
  @override
  State<ReportesPlanificadoresScreen> createState() =>
      _ReportesPlanificadoresScreenState();
}

class _ReportesPlanificadoresScreenState
    extends State<ReportesPlanificadoresScreen> {
  DateTime _fechaSeleccionada = DateTime.now();
  String _formatoReporte = 'PDF'; // <-- Variable para controlar el dropdown

  String _getFechaFormateada() {
    final meses = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return "${_fechaSeleccionada.day} de ${meses[_fechaSeleccionada.month - 1]} ${_fechaSeleccionada.year}";
  }

  String _getDocId(String uid, DateTime date) {
    final mes = date.month.toString().padLeft(2, '0');
    final dia = date.day.toString().padLeft(2, '0');
    return '${uid}_${date.year}-$mes-$dia';
  }

  void _cambiarFecha(int dias) {
    // Bloqueo para evitar avanzar a días futuros mediante las flechas
    DateTime nuevaFecha = _fechaSeleccionada.add(Duration(days: dias));
    DateTime hoy = DateTime.now();
    DateTime hoyLimpio = DateTime(hoy.year, hoy.month, hoy.day);
    DateTime nuevaLimpia = DateTime(
      nuevaFecha.year,
      nuevaFecha.month,
      nuevaFecha.day,
    );

    if (nuevaLimpia.isAfter(hoyLimpio)) {
      return; // No hace nada si intenta ir al futuro
    }

    setState(() {
      _fechaSeleccionada = nuevaFecha;
    });
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2025),
      // ─────────────────────────────────────────────
      // REGLA ESTRICTA: BLOQUEO DE FECHAS FUTURAS
      // ─────────────────────────────────────────────
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF2FA36B)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _fechaSeleccionada = picked);
    }
  }

  // ─────────────────────────────────────────────
  // NUEVO: DIÁLOGO DE REPORTE INDIVIDUAL (CONECTADO)
  // ─────────────────────────────────────────────
  void _mostrarDialogoReporteUsuario(
    BuildContext context,
    String uid,
    String nombreUsuario,
    Map<String, dynamic> userData,
    Map<String, dynamic> plan,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            SizedBox(width: 10),
            Text("Reporte de Usuario", style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Text(
          "¿Quieres sacar el reporte de planificación de $nombreUsuario para la fecha seleccionada?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2FA36B),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Generando reporte para $nombreUsuario...'),
                ),
              );

              // ─────────────────────────────────────────────
              // ENLACE EN VIVO: Invocación directa al servicio
              // ─────────────────────────────────────────────
              await PdfService.generarReporteIndividual(
                uid,
                nombreUsuario,
                plan,
                _fechaSeleccionada,
              );
            },
            child: const Text(
              "Sí, generar",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        title: const Text('Planes por Fecha'),
        backgroundColor: const Color(0xFF2FA36B),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Selector de Fecha
          Container(
            margin: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new,
                    color: Color(0xFF2FA36B),
                  ),
                  onPressed: () => _cambiarFecha(-1),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _seleccionarFecha(context),
                    child: Column(
                      children: [
                        const Text(
                          "Fecha seleccionada",
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                        Text(
                          _getFechaFormateada(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Color(0xFF2FA36B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: Color(0xFF2FA36B),
                  ),
                  onPressed: () => _cambiarFecha(1),
                ),
              ],
            ),
          ),

          // Controles de Exportación Generales
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: DropdownButton<String>(
                    value: _formatoReporte,
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(value: 'PDF', child: Text('PDF')),
                      DropdownMenuItem(value: 'Excel', child: Text('Excel')),
                      DropdownMenuItem(value: 'CSV', child: Text('CSV')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _formatoReporte = value!;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1A1A1A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Generando reporte...')),
                    );

                    if (_formatoReporte == 'PDF') {
                      await PdfService.generarReportePlanificadoresPdf(
                        _fechaSeleccionada,
                      );
                    } else if (_formatoReporte == 'Excel') {
                      await PdfService.generarExcelPlanificadores(
                        _fechaSeleccionada,
                      );
                    } else if (_formatoReporte == 'CSV') {
                      await PdfService.generarCsvPlanificadores(
                        _fechaSeleccionada,
                      );
                    }
                  },
                  child: const Text(
                    'Reporte',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Lista de Usuarios y sus Planes
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('app-usuarios')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final usuarios = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: usuarios.length,
                  itemBuilder: (context, i) {
                    final userData = usuarios[i].data() as Map<String, dynamic>;
                    final uid = usuarios[i].id;
                    final docId = _getDocId(uid, _fechaSeleccionada);

                    final nombreUsuario = userData['nombre']?.toString() ?? 'U';
                    final inicial = nombreUsuario.isNotEmpty
                        ? nombreUsuario[0].toUpperCase()
                        : 'U';

                    return FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('app-planes')
                          .doc(docId)
                          .get(),
                      builder: (context, planSnapshot) {
                        Map<String, dynamic> plan = {};
                        if (planSnapshot.hasData && planSnapshot.data!.exists) {
                          final data = planSnapshot.data!.data();
                          if (data != null) {
                            plan = Map<String, dynamic>.from(data as Map);
                          }
                        }

                        return Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ExpansionTile(
                            tilePadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFFE8F7F1),
                              child: Text(
                                inicial,
                                style: const TextStyle(
                                  color: Color(0xFF2FA36B),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // ─────────────────────────────────────────────
                            // INYECCIÓN DEL BOTÓN DE PDF INDIVIDUAL
                            // ─────────────────────────────────────────────
                            title: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    nombreUsuario,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.picture_as_pdf,
                                    color: Colors.redAccent,
                                    size: 22,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  tooltip: "Reporte de usuario",
                                  onPressed: () =>
                                      _mostrarDialogoReporteUsuario(
                                        context,
                                        uid,
                                        nombreUsuario,
                                        userData,
                                        plan,
                                      ),
                                ),
                              ],
                            ),
                            subtitle: Text(
                              plan.isEmpty
                                  ? "Sin plan registrado"
                                  : "Plan activo",
                              style: TextStyle(
                                fontSize: 12,
                                color: plan.isEmpty
                                    ? Colors.grey
                                    : Colors.green,
                              ),
                            ),
                            children: [
                              _buildComidaSlot(
                                plan,
                                'desayuno',
                                'Desayuno',
                                Icons.wb_sunny_rounded,
                              ),
                              _buildComidaSlot(
                                plan,
                                'almuerzo',
                                'Almuerzo',
                                Icons.restaurant_rounded,
                              ),
                              _buildComidaSlot(
                                plan,
                                'cena',
                                'Cena',
                                Icons.nights_stay_rounded,
                              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icono, size: 20, color: Colors.grey[400]),
          const SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.grey)),
          const SizedBox(width: 10),
          Expanded(
            child: recetaId.isEmpty
                ? const Text(
                    '...',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  )
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
          return const Text('No disponible');
        }

        final data = snap.data!.data() as Map<String, dynamic>?;
        if (data == null) return const Text('Error datos');

        final nombre = data['nombre']?.toString() ?? 'Sin nombre';
        final img = data['imagen']?.toString() ?? '';

        return Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: img.isNotEmpty
                    ? Image.network(
                        img,
                        width: 35,
                        height: 35,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image, size: 20),
                      )
                    : const Icon(Icons.restaurant, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
