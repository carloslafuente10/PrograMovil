import 'package:flutter/material.dart';// Librería principal de Flutter para la construcción de interfaces gráficas.
import 'package:cloud_firestore/cloud_firestore.dart';// Librería para interactuar con Firestore, la base de datos en la nube de Firebase.
import 'detalle_historial_usuario_screen.dart';// Pantalla que muestra el detalle del historial de actividades de un usuario específico, con la capacidad de filtrar por fecha y exportar el reporte en formato PDF. Utiliza Firestore para obtener los datos del historial y la librería pdf para generar el documento a partir de los registros filtrados.
import '../servicios/pdf_servicios.dart';// Servicio personalizado para generar documentos PDF a partir de los datos del historial de actividades de los usuarios, utilizado en la pantalla DetalleHistorialUsuarioScreen para crear el reporte de actividades del usuario en formato PDF.
// Pantalla que muestra el historial de actividades de los usuarios, con la capacidad de filtrar por fecha, rol y tipo de acción. Utiliza Firestore para obtener los datos del historial en tiempo real, y permite exportar el reporte de actividades filtrado en formato PDF a través de la pantalla DetalleHistorialUsuarioScreen.
class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}
// Estado de la pantalla HistorialScreen, que maneja la lógica para filtrar el historial de actividades por fecha, rol y tipo de acción, y para exportar el reporte de actividades filtrado en formato PDF. Incluye un StreamBuilder para escuchar los cambios en Firestore y actualizar la lista de actividades en tiempo real, y métodos para mostrar diálogos de selección de fecha y para navegar a la pantalla DetalleHistorialUsuarioScreen con los datos filtrados.
class _HistorialScreenState extends State<HistorialScreen> {
  static const Color _verde = Color(0xFF2D9E73);

  String filtroRol = 'Todos';
  String filtroAccion = 'Todas';
  String buscar = '';
  DateTime? fechaFiltro; // null = sin filtro de fecha

  final buscarCtrl = TextEditingController();

  final List<Map<String, dynamic>> acciones = [
    {'valor': 'Todas', 'icono': Icons.check_circle_outline, 'color': Color(0xFF2D9E73)},
    {'valor': 'login',    'icono': Icons.login,              'color': Colors.green},
    {'valor': 'logout',   'icono': Icons.logout,             'color': Colors.red},
    {'valor': 'favoritos','icono': Icons.favorite_border,    'color': Colors.pink},
    {'valor': 'plan',     'icono': Icons.calendar_month,     'color': Colors.blue},
    {'valor': 'recetas',  'icono': Icons.restaurant,         'color': Colors.orange},
  ];

  // ── helpers de fecha ──────────────────────────────────────────────────────
  DateTime get _hoy {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  String _labelFecha(DateTime d) {
    final hoy = _hoy;
    if (d == hoy) return 'Hoy';
    if (d == hoy.subtract(const Duration(days: 1))) return 'Ayer';
    return '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  }

  Future<void> _seleccionarFecha() async {
    final seleccionada = await showDatePicker(
      context: context,
      initialDate: fechaFiltro ?? _hoy,
      firstDate: DateTime(2020),
      lastDate: _hoy,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF2D9E73),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (seleccionada != null) {
      setState(() => fechaFiltro = seleccionada);
    }
  }

  // ── icono / color por tipo ────────────────────────────────────────────────
  IconData _iconoTipo(String tipo) {
    switch (tipo) {
      case 'login':     return Icons.login;
      case 'logout':    return Icons.logout;
      case 'favoritos': return Icons.favorite;
      case 'plan':      return Icons.calendar_month;
      case 'recetas':   return Icons.restaurant;
      case 'roles':     return Icons.admin_panel_settings;
      default:          return Icons.circle;
    }
  }

  Color _colorTipo(String tipo) {
    switch (tipo) {
      case 'login':     return Colors.green;
      case 'logout':    return Colors.red;
      case 'favoritos': return Colors.pink;
      case 'plan':      return Colors.blue;
      case 'recetas':   return Colors.orange;
      case 'roles':     return Colors.purple;
      default:          return Colors.black54;
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        backgroundColor: _verde,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Historial', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('Actividad de usuarios', style: TextStyle(fontSize: 12, color: Colors.white70)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt_outlined),
            onPressed: _seleccionarFecha,
            tooltip: 'Filtrar por fecha',
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('app-historial').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF2D9E73)));
          }

          final todosLosDocs = snapshot.data!.docs;

          // ── calcular estadísticas globales ───────────────────────────────
          int totalRegistros = todosLosDocs.length;
          final Set<String> uidsAdmin = {};
          final Set<String> uidsUser  = {};
          final Set<String> uidsHoy   = {}; // usuarios únicos con actividad hoy

          final hoy = _hoy;

          for (final doc in todosLosDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final uid = (data['uid'] ?? '').toString();
            final rol = (data['rol'] ?? '').toString();
            final ts  = data['fecha'];
            if (ts is Timestamp) {
              final d = ts.toDate();
              final dNorm = DateTime(d.year, d.month, d.day);
              if (dNorm == hoy && uid.isNotEmpty) uidsHoy.add(uid);
            }
            if (uid.isNotEmpty) {
              if (rol == 'admin') uidsAdmin.add(uid); else uidsUser.add(uid);
            }
          }
          final int hoyCount = uidsHoy.length;

          // ── aplicar filtros ───────────────────────────────────────────────
          // Agrupar por usuario (para la lista de tarjetas)
          final Map<String, Map<String, dynamic>> usuarios = {};

          for (final doc in todosLosDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final uid     = (data['uid']     ?? '').toString();
            final usuario = (data['usuario'] ?? '').toString();
            final rol     = (data['rol']     ?? '').toString();
            final correo  = (data['correo']  ?? '').toString();
            final tipo    = (data['tipo']    ?? '').toString();
            final ts      = data['fecha'];

            if (uid.isEmpty) continue;

            // filtro búsqueda
            if (!usuario.toLowerCase().contains(buscar)) continue;
            // filtro rol
            if (filtroRol != 'Todos' && rol != filtroRol) continue;
            // filtro acción
            if (filtroAccion != 'Todas' && tipo != filtroAccion) continue;
            // filtro fecha
            if (fechaFiltro != null && ts is Timestamp) {
              final d = ts.toDate();
              final dNorm = DateTime(d.year, d.month, d.day);
              if (dNorm != fechaFiltro) continue;
            }

            if (!usuarios.containsKey(uid)) {
              usuarios[uid] = {
                'uid': uid, 'usuario': usuario, 'rol': rol, 'correo': correo,
              };
            }
          }

          // También preparar lista plana de actividades filtradas (para PDF)
          final List<Map<String, dynamic>> actividadesFiltradas = [];
          for (final doc in todosLosDocs) {
            final data = doc.data() as Map<String, dynamic>;
            final uid     = (data['uid']     ?? '').toString();
            final usuario = (data['usuario'] ?? '').toString();
            final rol     = (data['rol']     ?? '').toString();
            final tipo    = (data['tipo']    ?? '').toString();
            final ts      = data['fecha'];

            if (uid.isEmpty) continue;
            if (!usuario.toLowerCase().contains(buscar)) continue;
            if (filtroRol    != 'Todos'  && rol  != filtroRol)    continue;
            if (filtroAccion != 'Todas'  && tipo != filtroAccion) continue;
            if (fechaFiltro != null && ts is Timestamp) {
              final d = ts.toDate();
              final dNorm = DateTime(d.year, d.month, d.day);
              if (dNorm != fechaFiltro) continue;
            }
            actividadesFiltradas.add(data);
          }

          final listaUsuarios = usuarios.values.toList();

          return Column(
            children: [
              // ── tarjetas de estadísticas ──────────────────────────────────
              _estadisticas(totalRegistros, hoyCount, uidsAdmin.length, uidsUser.length),

              // ── barra de búsqueda ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: TextField(
                  controller: buscarCtrl,
                  decoration: InputDecoration(
                    hintText: 'Buscar usuario...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (v) => setState(() => buscar = v.toLowerCase()),
                ),
              ),

              // ── filtro rol (chips) ────────────────────────────────────────
              _filtroRolChips(),

              // ── filtro acción (chips con iconos) ──────────────────────────
              _filtroAccionChips(),


              // ── encabezado lista (tappable para abrir datepicker) ────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _seleccionarFecha,
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month, color: _verde, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            fechaFiltro != null ? _labelFecha(fechaFiltro!) : 'Hoy',
                            style: TextStyle(
                              color: _verde,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              decoration: TextDecoration.underline,
                              decorationColor: _verde,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.arrow_drop_down, color: _verde, size: 18),
                          if (fechaFiltro != null) ...[
                            const SizedBox(width: 6),
                            GestureDetector(
                              onTap: () => setState(() => fechaFiltro = null),
                              child: const Icon(Icons.close, color: Colors.grey, size: 15),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Spacer(),
                    Flexible(
                      child: Text(
                        '${actividadesFiltradas.length} actividades',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              // ── lista usuarios ────────────────────────────────────────────
              Expanded(
                child: listaUsuarios.isEmpty
                    ? const Center(child: Text('Sin usuarios con esos filtros', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 100),
                        itemCount: listaUsuarios.length,
                        itemBuilder: (ctx, i) => _tarjetaUsuario(listaUsuarios[i]),
                      ),
              ),

              // ── barra inferior exportar PDF ───────────────────────────────
              _barraExportar(actividadesFiltradas),
            ],
          );
        },
      ),
    );
  }

  // ── widget estadísticas ───────────────────────────────────────────────────
  Widget _estadisticas(int registros, int hoy, int admins, int users) {
    final items = [
      {'icono': Icons.article_outlined, 'valor': registros, 'label': 'Registros', 'color': const Color(0xFF2D9E73)},
      {'icono': Icons.calendar_today,   'valor': hoy,       'label': 'Hoy',       'color': Colors.orange},
      {'icono': Icons.shield_outlined,  'valor': admins,    'label': 'Admins',    'color': Colors.purple},
      {'icono': Icons.group_outlined,   'valor': users,     'label': 'Usuarios',  'color': Colors.blue},
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: (item['color'] as Color).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item['icono'] as IconData, color: item['color'] as Color, size: 22),
              ),
              const SizedBox(height: 6),
              Text('${item['valor']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              Text(item['label'] as String, style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── chips rol ─────────────────────────────────────────────────────────────
  Widget _filtroRolChips() {
    final opciones = [
      {'valor': 'Todos',  'label': 'Todos'},
      {'valor': 'admin',  'label': 'Admins'},
      {'valor': 'user',   'label': 'Usuarios'},
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(
        children: [
          const Text('Rol ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(width: 8),
          ...opciones.map((o) {
            final seleccionado = filtroRol == o['valor'];
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => setState(() => filtroRol = o['valor']!),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                  decoration: BoxDecoration(
                    color: seleccionado ? const Color(0xFF2D9E73) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: seleccionado ? const Color(0xFF2D9E73) : Colors.grey.shade300),
                  ),
                  child: Text(
                    o['label']!,
                    style: TextStyle(
                      color: seleccionado ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── chips acción ──────────────────────────────────────────────────────────
  Widget _filtroAccionChips() {
    return SizedBox(
      height: 50,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
        children: acciones.map((a) {
          final seleccionado = filtroAccion == a['valor'];
          final color = a['color'] as Color;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => setState(() => filtroAccion = a['valor'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: seleccionado ? color.withOpacity(0.15) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: seleccionado ? color : Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(a['icono'] as IconData, size: 14, color: seleccionado ? color : Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      a['valor'] as String,
                      style: TextStyle(
                        color: seleccionado ? color : Colors.black54,
                        fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── tarjeta de usuario ────────────────────────────────────────────────────
  Widget _tarjetaUsuario(Map<String, dynamic> usuario) {
    final esAdmin = usuario['rol'] == 'admin';
    final iniciales = (usuario['usuario'] as String)
        .trim()
        .split(' ')
        .take(2)
        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '')
        .join();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DetalleHistorialUsuarioScreen(
              uid: usuario['uid'],
              usuario: usuario['usuario'],
            ),
          ),
        ),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: esAdmin ? Colors.purple.shade100 : const Color(0xFF2D9E73).withOpacity(0.2),
          child: Text(
            iniciales.isEmpty ? '?' : iniciales,
            style: TextStyle(
              color: esAdmin ? Colors.purple : const Color(0xFF2D9E73),
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        title: Text(usuario['usuario'], style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(usuario['correo'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: esAdmin ? Colors.purple.shade50 : const Color(0xFF2D9E73).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            esAdmin ? 'Admin' : 'Usuario',
            style: TextStyle(
              color: esAdmin ? Colors.purple : const Color(0xFF2D9E73),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  // ── barra inferior exportar ───────────────────────────────────────────────
  Widget _barraExportar(List<Map<String, dynamic>> actividades) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 10, offset: const Offset(0, -3))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              // botón formato PDF
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: TextButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.picture_as_pdf, color: Color(0xFF2D9E73), size: 18),
                  label: const Text('PDF', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              // botón exportar
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => PdfServicios.exportarHistorialGeneral(
                    context: context,
                    actividades: actividades,
                    filtroRol: filtroRol,
                    filtroAccion: filtroAccion,
                    fecha: fechaFiltro,
                  ),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Exportar a PDF', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D9E73),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'El reporte incluirá los filtros y búsqueda aplicados.',
            style: TextStyle(color: Colors.grey, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
