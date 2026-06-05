import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// ── helpers fecha sin intl ────────────────────────────────────────────────────
String _fmtFecha(DateTime d) {
  const meses = ['','enero','febrero','marzo','abril','mayo','junio',
      'julio','agosto','septiembre','octubre','noviembre','diciembre'];
  return '${d.day.toString().padLeft(2,'0')} de ${meses[d.month]} de ${d.year}';
}
String _fmtHora(DateTime d) =>
    '${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')}';
String _fmtCorto(DateTime d) =>
    '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}  ${_fmtHora(d)}';
String _fmtSolo(DateTime d) =>
    '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

// ── colores PDF (sin withOpacity) ─────────────────────────────────────────────
const PdfColor _verde      = PdfColor.fromInt(0xFF2D9E73);
const PdfColor _verdeClaro = PdfColor.fromInt(0xFFE8F5EE);
const PdfColor _gris       = PdfColor.fromInt(0xFF6B7280);
const PdfColor _grisClaro  = PdfColor.fromInt(0xFFF3F4F6);
const PdfColor _blanco     = PdfColors.white;
const PdfColor _negro      = PdfColor.fromInt(0xFF1F2937);
const PdfColor _tabla1     = PdfColor.fromInt(0xFFF9FAFB);
const PdfColor _loginBg    = PdfColor.fromInt(0xFFDCFCE7);
const PdfColor _logoutBg   = PdfColor.fromInt(0xFFFFE4E6);
const PdfColor _favBg      = PdfColor.fromInt(0xFFFFE4EF);
const PdfColor _planBg     = PdfColor.fromInt(0xFFDBEAFE);
const PdfColor _recetasBg  = PdfColor.fromInt(0xFFFFEDD5);
const PdfColor _rolesBg    = PdfColor.fromInt(0xFFF3E8FF);

// ═════════════════════════════════════════════════════════════════════════════
// CLASE PRINCIPAL — usa el mismo nombre en AMBAS versiones para compatibilidad
// ═════════════════════════════════════════════════════════════════════════════
// Alias para compatibilidad: PdfService = PdfServicios
typedef PdfService = PdfServicios;

class PdfServicios {

  // ══════════════════════════════════════════════════════════════════════════
  // HISTORIAL — exportar historial general
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> exportarHistorialGeneral({
    required BuildContext context,
    required List<Map<String, dynamic>> actividades,
    required String filtroRol,
    required String filtroAccion,
    DateTime? fecha,
  }) async {
    final pdf    = pw.Document();
    final ahora  = DateTime.now();
    final fechaG = '${_fmtFecha(ahora)}  ${_fmtHora(ahora)}';
    final labelFecha = fecha != null ? _fmtFecha(fecha) : 'Todas las fechas';

    actividades.sort((a, b) {
      final ta = a['fecha']; final tb = b['fecha'];
      if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
      return 0;
    });

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (ctx) => [
        _header(
          titulo: 'Historial de actividad',
          subtitulo: 'Filtro: $filtroRol  |  Acción: $filtroAccion  |  Fecha: $labelFecha\nTotal: ${actividades.length} registro(s)',
          fechaGen: fechaG,
        ),
        pw.SizedBox(height: 20),
        actividades.isEmpty
            ? pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 24),
                child: pw.Text('Sin actividades.', style: pw.TextStyle(color: _gris)))
            : _tablaActividades(actividades),
        pw.SizedBox(height: 24),
        _footer(),
      ],
    ));

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'historial_${ahora.millisecondsSinceEpoch}.pdf',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // HISTORIAL — exportar usuario individual
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> exportarUsuario({
    required BuildContext context,
    required String uid,
    required String usuario,
    required String correo,
    required String rol,
    required List<Map<String, dynamic>> actividades,
    DateTime? fechaFiltro,
  }) async {
    final pdf    = pw.Document();
    final ahora  = DateTime.now();
    final fechaG = '${_fmtFecha(ahora)}  ${_fmtHora(ahora)}';

    int logins=0, logouts=0, favoritos=0, planes=0;
    for (final a in actividades) {
      switch ((a['tipo'] ?? '').toString()) {
        case 'login':     logins++;    break;
        case 'logout':    logouts++;   break;
        case 'favoritos': favoritos++; break;
        case 'plan':      planes++;    break;
      }
    }

    actividades.sort((a, b) {
      final ta = a['fecha']; final tb = b['fecha'];
      if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
      return 0;
    });

    final iniciales = usuario.trim().split(' ').take(2)
        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (ctx) => [
        _header(titulo: usuario,
            subtitulo: '$correo\nRol: ${rol == "admin" ? "Admin" : "Usuario"}',
            fechaGen: fechaG, iniciales: iniciales),
        pw.SizedBox(height: 20),
        _resumenCards(logins, logouts, favoritos, planes),
        pw.SizedBox(height: 20),
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 24),
          child: pw.Text('Actividad reciente',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _negro))),
        pw.SizedBox(height: 10),
        actividades.isEmpty
            ? pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 24),
                child: pw.Text('Sin actividades.', style: pw.TextStyle(color: _gris)))
            : _listaDetalle(actividades),
        pw.SizedBox(height: 20),
        _notaFinal(_fmtFecha(ahora)),
        pw.SizedBox(height: 20),
        _footer(),
      ],
    ));

    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'historial_${usuario.replaceAll(' ','_')}_${ahora.millisecondsSinceEpoch}.pdf',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REPORTES — Usuarios
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> generarReporteUsuarios(String filtro) async {
    final snap = await FirebaseFirestore.instance.collection('app-usuarios').get();
    final docs = snap.docs.where((doc) {
      if (filtro == 'Todos') return true;
      final data = doc.data();
      final ultimoAcceso = data['ultimoAcceso'];
      if (ultimoAcceso == null) return filtro == 'Inactivo';
      final dias = DateTime.now().difference((ultimoAcceso as Timestamp).toDate()).inDays;
      if (filtro == 'Activo') return dias <= 30;
      if (filtro == 'Inactivo') return dias > 30 && dias <= 60;
      if (filtro == 'Inhabilitado') return dias > 60;
      return true;
    }).toList();

    final pdf = pw.Document();
    final ahora = DateTime.now();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (ctx) => [
        _header(
          titulo: 'Reporte de usuarios',
          subtitulo: 'Filtro: $filtro  |  Total: ${docs.length} usuario(s)',
          fechaGen: '${_fmtFecha(ahora)}  ${_fmtHora(ahora)}',
        ),
        pw.SizedBox(height: 20),
        _tablaUsuarios(docs),
        pw.SizedBox(height: 20),
        _footer(),
      ],
    ));
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'reporte_usuarios_${ahora.millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> generarExcelUsuarios(String filtro) async {
    // Excel no disponible sin dependencia externa — genera CSV
    await generarCsvUsuarios(filtro);
  }

  static Future<void> generarCsvUsuarios(String filtro) async {
    final snap = await FirebaseFirestore.instance.collection('app-usuarios').get();
    final buffer = StringBuffer('Nombre,Correo,Rol,Estado\n');
    for (final doc in snap.docs) {
      final d = doc.data();
      final nombre  = (d['nombre']  ?? '').toString().replaceAll(',', ';');
      final correo  = (d['correo']  ?? d['email'] ?? '').toString().replaceAll(',', ';');
      final rol     = (d['rol']     ?? 'user').toString();
      final estado  = 'Activo';
      buffer.writeln('$nombre,$correo,$rol,$estado');
    }
    // Imprime como PDF con el CSV dentro por simplicidad
    final pdf = pw.Document();
    final ahora = DateTime.now();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('CSV — Usuarios (${_fmtFecha(ahora)})',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text(buffer.toString(), style: const pw.TextStyle(fontSize: 9)),
      ]),
    ));
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'usuarios_${ahora.millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> generarReporteUsuario(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final ahora = DateTime.now();
    final nombre = (data['nombre'] ?? 'Usuario').toString();
    final correo = (data['correo'] ?? data['email'] ?? '').toString();
    final rol    = (data['rol']    ?? 'user').toString();
    final iniciales = nombre.trim().split(' ').take(2)
        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (ctx) => [
        _header(
          titulo: nombre,
          subtitulo: '$correo\nRol: ${rol == "admin" ? "Admin" : "Usuario"}',
          fechaGen: '${_fmtFecha(ahora)}  ${_fmtHora(ahora)}',
          iniciales: iniciales,
        ),
        pw.SizedBox(height: 20),
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 24),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Información del usuario',
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _negro)),
            pw.SizedBox(height: 10),
            _filaInfo('Correo', correo),
            _filaInfo('Rol', rol == 'admin' ? 'Administrador' : 'Usuario'),
            if (data['creadoEn'] != null)
              _filaInfo('Registro', _fmtCorto((data['creadoEn'] as Timestamp).toDate())),
            if (data['ultimoAcceso'] != null)
              _filaInfo('Último acceso', _fmtCorto((data['ultimoAcceso'] as Timestamp).toDate())),
          ]),
        ),
        pw.SizedBox(height: 20),
        _notaFinal(_fmtFecha(ahora)),
        pw.SizedBox(height: 20),
        _footer(),
      ],
    ));
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'usuario_${nombre.replaceAll(' ','_')}_${ahora.millisecondsSinceEpoch}.pdf',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REPORTES — Recetas
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> generarReporteRecetas({
    required String categoria,
    required String buscar,
  }) async {
    final snap = await FirebaseFirestore.instance.collection('app-recetas-completas').get();
    final docs = snap.docs.where((doc) {
      final d = doc.data();
      final nombre = (d['nombre'] ?? '').toString().toLowerCase();
      final cat    = (d['categoria'] ?? '').toString().toLowerCase();
      return nombre.contains(buscar.toLowerCase()) &&
          (categoria == 'Todas' || cat == categoria.toLowerCase());
    }).toList();

    final pdf = pw.Document();
    final ahora = DateTime.now();
    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (ctx) => [
        _header(
          titulo: 'Reporte de Recetas',
          subtitulo: 'Categoría: $categoria  |  Total: ${docs.length} receta(s)',
          fechaGen: '${_fmtFecha(ahora)}  ${_fmtHora(ahora)}',
        ),
        pw.SizedBox(height: 20),
        _tablaRecetas(docs),
        pw.SizedBox(height: 20),
        _footer(),
      ],
    ));
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'recetas_${ahora.millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> generarExcelRecetas({required String categoria, required String buscar}) async {
    await generarCsvRecetas(categoria: categoria, buscar: buscar);
  }

  static Future<void> generarCsvRecetas({required String categoria, required String buscar}) async {
    final snap = await FirebaseFirestore.instance.collection('app-recetas-completas').get();
    final buffer = StringBuffer('Nombre,Categoría,Calorías\n');
    for (final doc in snap.docs) {
      final d = doc.data();
      final nombre = (d['nombre'] ?? '').toString().replaceAll(',', ';');
      final cat    = (d['categoria'] ?? '').toString().replaceAll(',', ';');
      final cal    = (d['calorias'] ?? d['calorías'] ?? '').toString();
      if (nombre.toLowerCase().contains(buscar.toLowerCase()) &&
          (categoria == 'Todas' || cat.toLowerCase() == categoria.toLowerCase())) {
        buffer.writeln('$nombre,$cat,$cal');
      }
    }
    final pdf = pw.Document();
    final ahora = DateTime.now();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('CSV — Recetas (${_fmtFecha(ahora)})',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text(buffer.toString(), style: const pw.TextStyle(fontSize: 9)),
      ]),
    ));
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'recetas_${ahora.millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> generarReporteRecetaIndividual(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> ingredientes,
    List<String> pasos,
  ) async {
    final pdf = pw.Document();
    final ahora = DateTime.now();
    final nombre = (data['nombre'] ?? 'Receta').toString();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (ctx) => [
        _header(
          titulo: nombre,
          subtitulo: 'Categoría: ${data['categoria'] ?? '—'}  |  Calorías: ${data['calorias'] ?? data['calorías'] ?? '—'}',
          fechaGen: '${_fmtFecha(ahora)}  ${_fmtHora(ahora)}',
        ),
        pw.SizedBox(height: 20),
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 24),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            if (ingredientes.isNotEmpty) ...[
              pw.Text('Ingredientes',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _negro)),
              pw.SizedBox(height: 8),
              ...ingredientes.map((ing) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  '• ${ing['cantidad'] ?? ''} ${ing['unidad'] ?? ''} ${ing['nombre'] ?? ''}'.trim(),
                  style: const pw.TextStyle(fontSize: 10),
                ),
              )),
              pw.SizedBox(height: 16),
            ],
            if (pasos.isNotEmpty) ...[
              pw.Text('Preparación',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _negro)),
              pw.SizedBox(height: 8),
              ...pasos.asMap().entries.map((e) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
                  pw.Container(
                    width: 20, height: 20,
                    decoration: const pw.BoxDecoration(color: _verde, shape: pw.BoxShape.circle),
                    child: pw.Center(child: pw.Text('${e.key + 1}',
                        style: pw.TextStyle(color: _blanco, fontSize: 9, fontWeight: pw.FontWeight.bold))),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Expanded(child: pw.Text(e.value, style: const pw.TextStyle(fontSize: 10))),
                ]),
              )),
            ],
          ]),
        ),
        pw.SizedBox(height: 20),
        _footer(),
      ],
    ));
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'receta_${nombre.replaceAll(' ','_')}_${ahora.millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> generarExcelRecetaIndividual(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> ingredientes,
    List<String> pasos,
  ) async {
    await generarCsvRecetaIndividual(data, ingredientes, pasos);
  }

  static Future<void> generarCsvRecetaIndividual(
    Map<String, dynamic> data,
    List<Map<String, dynamic>> ingredientes,
    List<String> pasos,
  ) async {
    final nombre = (data['nombre'] ?? 'Receta').toString();
    final buffer = StringBuffer('Campo,Valor\n');
    buffer.writeln('Nombre,$nombre');
    buffer.writeln('Categoría,${data['categoria'] ?? ''}');
    buffer.writeln('Calorías,${data['calorias'] ?? data['calorías'] ?? ''}');
    buffer.writeln('\nIngredientes:,');
    for (final ing in ingredientes) {
      buffer.writeln('${ing['nombre'] ?? ''},${ing['cantidad'] ?? ''} ${ing['unidad'] ?? ''}');
    }
    buffer.writeln('\nPasos:,');
    for (int i = 0; i < pasos.length; i++) {
      buffer.writeln('Paso ${i+1},${pasos[i].replaceAll(',', ';')}');
    }
    final pdf = pw.Document();
    final ahora = DateTime.now();
    pdf.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('CSV — $nombre (${_fmtFecha(ahora)})',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 12),
        pw.Text(buffer.toString(), style: const pw.TextStyle(fontSize: 9)),
      ]),
    ));
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'receta_${nombre.replaceAll(' ','_')}_${ahora.millisecondsSinceEpoch}.pdf',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REPORTES — Favoritos
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> generarReporteFavoritos() async {
    final usuariosSnap = await FirebaseFirestore.instance.collection('app-usuarios').get();
    final pdf = pw.Document();
    final ahora = DateTime.now();

    final List<Map<String, dynamic>> filas = [];
    for (final userDoc in usuariosSnap.docs) {
      final userData = userDoc.data();
      final favSnap = await FirebaseFirestore.instance
          .collection('app-usuarios').doc(userDoc.id)
          .collection('favoritos').get();
      for (final fav in favSnap.docs) {
        filas.add({
          'usuario': userData['nombre'] ?? '',
          'receta':  (fav.data()['nombre'] ?? '').toString(),
        });
      }
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (ctx) => [
        _header(
          titulo: 'Reporte de Favoritos',
          subtitulo: 'Total registros: ${filas.length}',
          fechaGen: '${_fmtFecha(ahora)}  ${_fmtHora(ahora)}',
        ),
        pw.SizedBox(height: 20),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 24),
          child: pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey200, width: .5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _verde),
                children: ['Usuario', 'Receta favorita'].map((e) =>
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    child: pw.Text(e, style: pw.TextStyle(color: _blanco,
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  )
                ).toList(),
              ),
              ...filas.asMap().entries.map((entry) {
                final bg = entry.key.isEven ? _tabla1 : _blanco;
                final f  = entry.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _celda(f['usuario'] as String),
                    _celda(f['receta']  as String),
                  ],
                );
              }),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        _footer(),
      ],
    ));
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'favoritos_${ahora.millisecondsSinceEpoch}.pdf',
    );
  }

  static Future<void> generarExcelFavoritos() async => generarReporteFavoritos();
  static Future<void> generarCsvFavoritos()   async => generarReporteFavoritos();

  static Future<void> generarReporteFavoritosUsuario(
    String nombre,
    String correo,
    List<QueryDocumentSnapshot> favoritos,
  ) async {
    final pdf = pw.Document();
    final ahora = DateTime.now();
    final iniciales = nombre.trim().split(' ').take(2)
        .map((p) => p.isNotEmpty ? p[0].toUpperCase() : '').join();

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (ctx) => [
        _header(
          titulo: nombre,
          subtitulo: '$correo\nFavoritos: ${favoritos.length}',
          fechaGen: '${_fmtFecha(ahora)}  ${_fmtHora(ahora)}',
          iniciales: iniciales,
        ),
        pw.SizedBox(height: 20),
        pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 24),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Recetas favoritas',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _negro)),
              pw.SizedBox(height: 10),
              ...favoritos.map((fav) {
                final data = fav.data() as Map<String, dynamic>;
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Row(children: [
                    pw.Container(width: 8, height: 8,
                        decoration: const pw.BoxDecoration(color: PdfColors.pink700, shape: pw.BoxShape.circle)),
                    pw.SizedBox(width: 8),
                    pw.Text((data['nombre'] ?? '').toString(),
                        style: pw.TextStyle(fontSize: 11, color: _negro)),
                  ]),
                );
              }),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        _notaFinal(_fmtFecha(ahora)),
        pw.SizedBox(height: 20),
        _footer(),
      ],
    ));
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'favoritos_${nombre.replaceAll(' ','_')}_${ahora.millisecondsSinceEpoch}.pdf',
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // REPORTES — Planificadores
  // ══════════════════════════════════════════════════════════════════════════
  static Future<void> generarReportePlanificadoresPdf(DateTime fecha) async {
    final pdf = pw.Document();
    final ahora = DateTime.now();
    final labelFecha = _fmtSolo(fecha);

    final mes = fecha.month.toString().padLeft(2,'0');
    final dia = fecha.day.toString().padLeft(2,'0');
    final usuariosSnap = await FirebaseFirestore.instance.collection('app-usuarios').get();

    final List<Map<String, dynamic>> filas = [];
    for (final userDoc in usuariosSnap.docs) {
      final userData = userDoc.data();
      final docId = '${userDoc.id}_${fecha.year}-$mes-$dia';
      final planDoc = await FirebaseFirestore.instance
          .collection('app-planes').doc(docId).get();
      final plan = planDoc.exists ? (planDoc.data() ?? {}) : <String, dynamic>{};
      filas.add({
        'nombre':    userData['nombre']  ?? 'Sin nombre',
        'desayuno':  plan['desayuno']    ?? '—',
        'almuerzo':  plan['almuerzo']    ?? '—',
        'cena':      plan['cena']        ?? '—',
      });
    }

    pdf.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(0),
      build: (ctx) => [
        _header(
          titulo: 'Planes del $labelFecha',
          subtitulo: 'Total usuarios: ${filas.length}',
          fechaGen: '${_fmtFecha(ahora)}  ${_fmtHora(ahora)}',
        ),
        pw.SizedBox(height: 20),
        pw.Padding(
          padding: const pw.EdgeInsets.symmetric(horizontal: 24),
          child: pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey200, width: .5),
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(2),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _verde),
                children: ['Usuario','Desayuno','Almuerzo','Cena'].map((e) =>
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                    child: pw.Text(e, style: pw.TextStyle(color: _blanco,
                        fontWeight: pw.FontWeight.bold, fontSize: 9)),
                  )
                ).toList(),
              ),
              ...filas.asMap().entries.map((entry) {
                final bg = entry.key.isEven ? _tabla1 : _blanco;
                final f  = entry.value;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: bg),
                  children: [
                    _celda(f['nombre']   as String),
                    _celda(f['desayuno'] as String),
                    _celda(f['almuerzo'] as String),
                    _celda(f['cena']     as String),
                  ],
                );
              }),
            ],
          ),
        ),
        pw.SizedBox(height: 20),
        _footer(),
      ],
    ));
    await Printing.layoutPdf(
      onLayout: (_) async => pdf.save(),
      name: 'planes_$labelFecha.pdf',
    );
  }

  static Future<void> generarExcelPlanificadores(DateTime fecha) async =>
      generarReportePlanificadoresPdf(fecha);
  static Future<void> generarCsvPlanificadores(DateTime fecha) async =>
      generarReportePlanificadoresPdf(fecha);

  // ══════════════════════════════════════════════════════════════════════════
  // WIDGETS INTERNOS COMPARTIDOS
  // ══════════════════════════════════════════════════════════════════════════

  static pw.Widget _header({
    required String titulo,
    required String subtitulo,
    required String fechaGen,
    String? iniciales,
  }) {
    return pw.Container(
      color: _verde,
      padding: const pw.EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(children: [
          pw.Container(
            width: 40, height: 40,
            decoration: const pw.BoxDecoration(color: _blanco, shape: pw.BoxShape.circle),
            child: pw.Center(child: pw.Text(
              iniciales != null && iniciales.isNotEmpty ? iniciales : 'Y',
              style: pw.TextStyle(color: _verde, fontWeight: pw.FontWeight.bold, fontSize: 14),
            )),
          ),
          pw.SizedBox(width: 10),
          pw.Text('Yagu!',
              style: pw.TextStyle(color: _blanco, fontSize: 13, fontWeight: pw.FontWeight.bold)),
        ]),
        pw.SizedBox(height: 14),
        pw.Text(titulo,
            style: pw.TextStyle(color: _blanco, fontSize: 22, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 6),
        pw.Text(subtitulo,
            style: const pw.TextStyle(color: PdfColor.fromInt(0xFFD6F5E8), fontSize: 11)),
        pw.SizedBox(height: 6),
        pw.Text('Generado: $fechaGen',
            style: const pw.TextStyle(color: PdfColor.fromInt(0xFFB2E8D0), fontSize: 10)),
      ]),
    );
  }

  static pw.Widget _resumenCards(int logins, int logouts, int favoritos, int planes) {
    final items = [
      {'sym':'→','color':PdfColors.green700,'bg':_loginBg,  'v':logins,    'l':'Logins'},
      {'sym':'←','color':PdfColors.red700,  'bg':_logoutBg, 'v':logouts,   'l':'Logouts'},
      {'sym':'♥','color':PdfColors.pink700, 'bg':_favBg,    'v':favoritos, 'l':'Favoritos'},
      {'sym':'▦','color':PdfColors.blue700, 'bg':_planBg,   'v':planes,    'l':'Planes'},
    ];
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 24),
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('Resumen de actividades',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: _negro)),
        pw.SizedBox(height: 10),
        pw.Row(children: items.map((item) {
          final color = item['color'] as PdfColor;
          final bg    = item['bg']    as PdfColor;
          return pw.Expanded(child: pw.Container(
            margin: const pw.EdgeInsets.only(right: 8),
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: pw.BorderRadius.circular(10),
            ),
            child: pw.Column(children: [
              pw.Container(width: 28, height: 28,
                decoration: pw.BoxDecoration(color: bg, shape: pw.BoxShape.circle),
                child: pw.Center(child: pw.Text(item['sym'] as String,
                    style: pw.TextStyle(color: color, fontSize: 13, fontWeight: pw.FontWeight.bold))),
              ),
              pw.SizedBox(height: 6),
              pw.Text('${item['v']}',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: color)),
              pw.Text(item['l'] as String,
                  style: pw.TextStyle(fontSize: 9, color: _gris)),
            ]),
          ));
        }).toList()),
      ]),
    );
  }

  static pw.Widget _tablaActividades(List<Map<String, dynamic>> actividades) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 24),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey200, width: .5),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(2.5),
          2: const pw.FlexColumnWidth(1.5),
          3: const pw.FlexColumnWidth(2),
          4: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _verde),
            children: ['Usuario','Correo','Acción','Fecha/Hora','Rol'].map((e) =>
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: pw.Text(e, style: pw.TextStyle(color: _blanco,
                    fontWeight: pw.FontWeight.bold, fontSize: 9)))
            ).toList(),
          ),
          ...actividades.asMap().entries.map((entry) {
            final i = entry.key; final data = entry.value;
            final ts = data['fecha'];
            final fechaStr = ts is Timestamp ? _fmtCorto(ts.toDate()) : '—';
            final bg   = i.isEven ? _tabla1 : _blanco;
            final tipo = (data['tipo'] ?? '—').toString();
            return pw.TableRow(
              decoration: pw.BoxDecoration(color: bg),
              children: [
                _celda((data['usuario'] ?? '—').toString()),
                _celda((data['correo']  ?? '—').toString()),
                _celdaTipo(tipo),
                _celda(fechaStr),
                _celda((data['rol'] ?? '—').toString()),
              ],
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _tablaUsuarios(List<QueryDocumentSnapshot> docs) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 24),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey200, width: .5),
        columnWidths: {
          0: const pw.FlexColumnWidth(2),
          1: const pw.FlexColumnWidth(2.5),
          2: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _verde),
            children: ['Nombre','Correo','Rol'].map((e) =>
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: pw.Text(e, style: pw.TextStyle(color: _blanco,
                    fontWeight: pw.FontWeight.bold, fontSize: 9)))
            ).toList(),
          ),
          ...docs.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value.data() as Map<String, dynamic>;
            final bg = i.isEven ? _tabla1 : _blanco;
            return pw.TableRow(
              decoration: pw.BoxDecoration(color: bg),
              children: [
                _celda((d['nombre']  ?? 'Sin nombre').toString()),
                _celda((d['correo']  ?? d['email'] ?? '').toString()),
                _celda((d['rol']     ?? 'user').toString()),
              ],
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _tablaRecetas(List<QueryDocumentSnapshot> docs) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 24),
      child: pw.Table(
        border: pw.TableBorder.all(color: PdfColors.grey200, width: .5),
        columnWidths: {
          0: const pw.FlexColumnWidth(3),
          1: const pw.FlexColumnWidth(2),
          2: const pw.FlexColumnWidth(1),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: _verde),
            children: ['Nombre','Categoría','Calorías'].map((e) =>
              pw.Padding(padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: pw.Text(e, style: pw.TextStyle(color: _blanco,
                    fontWeight: pw.FontWeight.bold, fontSize: 9)))
            ).toList(),
          ),
          ...docs.asMap().entries.map((entry) {
            final i = entry.key;
            final d = entry.value.data() as Map<String, dynamic>;
            final bg = i.isEven ? _tabla1 : _blanco;
            return pw.TableRow(
              decoration: pw.BoxDecoration(color: bg),
              children: [
                _celda((d['nombre']    ?? '').toString()),
                _celda((d['categoria'] ?? '').toString()),
                _celda((d['calorias']  ?? d['calorías'] ?? '—').toString()),
              ],
            );
          }),
        ],
      ),
    );
  }

  static pw.Widget _listaDetalle(List<Map<String, dynamic>> actividades) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 24),
      child: pw.Column(children: actividades.take(25).map((data) {
        final ts = data['fecha'];
        String hora = '—'; String hace = '';
        if (ts is Timestamp) {
          final dt = ts.toDate();
          hora = _fmtHora(dt);
          final diff = DateTime.now().difference(dt);
          if      (diff.inMinutes < 60) hace = 'Hace ${diff.inMinutes} min';
          else if (diff.inHours   < 24) hace = 'Hace ${diff.inHours} h';
          else                          hace = 'Hace ${diff.inDays} día(s)';
        }
        final tipo    = (data['tipo']    ?? '').toString();
        final accion  = (data['accion']  ?? _labelAccion(tipo)).toString();
        final detalle = (data['detalle'] ?? '').toString();
        final tColor  = _solidColor(tipo);
        final tBg     = _bgColor(tipo);

        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 1),
          padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 9),
          decoration: pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: .5))),
          child: pw.Row(children: [
            pw.Container(width: 30, height: 30,
              decoration: pw.BoxDecoration(color: tBg, shape: pw.BoxShape.circle),
              child: pw.Center(child: pw.Text(_symTipo(tipo),
                  style: pw.TextStyle(color: tColor, fontSize: 11, fontWeight: pw.FontWeight.bold))),
            ),
            pw.SizedBox(width: 8),
            pw.SizedBox(width: 34, child: pw.Text(hora,
                style: pw.TextStyle(color: tColor, fontWeight: pw.FontWeight.bold, fontSize: 10))),
            pw.SizedBox(width: 6),
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.RichText(text: pw.TextSpan(children: [
                pw.TextSpan(text: accion,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: _negro)),
                if (detalle.isNotEmpty)
                  pw.TextSpan(text: '  $detalle',
                      style: pw.TextStyle(fontSize: 10, color: tColor, fontWeight: pw.FontWeight.bold)),
              ])),
              pw.Text(tipo.isNotEmpty ? tipo[0].toUpperCase() + tipo.substring(1) : '',
                  style: pw.TextStyle(fontSize: 9, color: _gris)),
            ])),
            pw.Text(hace, style: pw.TextStyle(fontSize: 9, color: _gris)),
          ]),
        );
      }).toList()),
    );
  }

  static pw.Widget _notaFinal(String fecha) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 24),
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(color: _verdeClaro, borderRadius: pw.BorderRadius.circular(8)),
        child: pw.Row(children: [
          pw.Container(width: 20, height: 20,
            decoration: const pw.BoxDecoration(color: _verde, shape: pw.BoxShape.circle),
            child: pw.Center(child: pw.Text('✓',
                style: pw.TextStyle(color: _blanco, fontSize: 10, fontWeight: pw.FontWeight.bold))),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('Este reporte incluye todas las actividades del usuario.',
                style: pw.TextStyle(fontSize: 10, color: _negro)),
            pw.Text('Fecha: $fecha', style: pw.TextStyle(fontSize: 9, color: _gris)),
          ])),
        ]),
      ),
    );
  }

  static pw.Widget _footer() {
    return pw.Container(
      padding: const pw.EdgeInsets.fromLTRB(24, 10, 24, 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300, width: .5))),
      child: pw.Row(children: [
        pw.Text('Yagu! ', style: pw.TextStyle(color: _verde, fontWeight: pw.FontWeight.bold, fontSize: 9)),
        pw.Text('Documento generado automáticamente', style: pw.TextStyle(color: _gris, fontSize: 9)),
      ]),
    );
  }

  static pw.Widget _celda(String texto) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    child: pw.Text(texto, style: pw.TextStyle(fontSize: 8.5, color: _negro)),
  );

  static pw.Widget _celdaTipo(String tipo) {
    final color = _solidColor(tipo); final bg = _bgColor(tipo);
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: pw.BoxDecoration(color: bg, borderRadius: pw.BorderRadius.circular(4)),
        child: pw.Text(tipo,
            style: pw.TextStyle(fontSize: 8.5, color: color, fontWeight: pw.FontWeight.bold)),
      ),
    );
  }

  static pw.Widget _filaInfo(String label, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(children: [
        pw.Text('$label: ', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: _gris)),
        pw.Text(valor, style: pw.TextStyle(fontSize: 10, color: _negro)),
      ]),
    );
  }

  static PdfColor _solidColor(String tipo) {
    switch (tipo) {
      case 'login':     return PdfColors.green700;
      case 'logout':    return PdfColors.red700;
      case 'favoritos': return PdfColors.pink700;
      case 'plan':      return PdfColors.blue700;
      case 'recetas':   return PdfColors.orange700;
      case 'roles':     return PdfColors.purple700;
      default:          return _gris;
    }
  }

  static PdfColor _bgColor(String tipo) {
    switch (tipo) {
      case 'login':     return _loginBg;
      case 'logout':    return _logoutBg;
      case 'favoritos': return _favBg;
      case 'plan':      return _planBg;
      case 'recetas':   return _recetasBg;
      case 'roles':     return _rolesBg;
      default:          return _grisClaro;
    }
  }

  static String _symTipo(String tipo) {
    switch (tipo) {
      case 'login':     return '→';
      case 'logout':    return '←';
      case 'favoritos': return '♥';
      case 'plan':      return '▦';
      case 'recetas':   return '⚑';
      default:          return '•';
    }
  }

  static String _labelAccion(String tipo) {
    switch (tipo) {
      case 'login':     return 'Inició sesión';
      case 'logout':    return 'Cerró sesión';
      case 'favoritos': return 'Agregó receta a favoritos';
      case 'plan':      return 'Creó plan semanal';
      case 'recetas':   return 'Consultó la categoría';
      default:          return tipo;
    }
  }
}
