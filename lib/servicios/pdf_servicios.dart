import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart' as html;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';

final _colorVerde = PdfColor.fromHex('2D9E73');
final _colorVerdeOsc = PdfColor.fromHex('1B5E20');
final _colorVerdeClaro = PdfColor.fromHex('E8F7F1');
final _colorCafe = PdfColor.fromHex('8B5E3C');
final _colorFondo = PdfColor.fromHex('F4F6F8');

class PdfService {
  static Future<void> _guardarYAbrir(
    Uint8List bytes,
    String nombre, {
    String ext = 'pdf',
  }) async {
    if (kIsWeb) {
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', '$nombre.$ext')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$nombre.$ext');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    }
  }

  static pw.Widget _encabezado(String titulo, {String? subtitulo}) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _colorVerde,
        borderRadius: pw.BorderRadius.circular(8),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Yagu!',
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 10,
              fontWeight: pw.FontWeight.normal,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            titulo,
            style: pw.TextStyle(
              color: PdfColors.white,
              fontSize: 20,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          if (subtitulo != null) ...[
            pw.SizedBox(height: 4),
            pw.Text(
              subtitulo,
              style: const pw.TextStyle(color: PdfColors.white, fontSize: 11),
            ),
          ],
          pw.SizedBox(height: 4),
          pw.Text(
            'Generado: ${_fechaHoy()}',
            style: const pw.TextStyle(color: PdfColors.white, fontSize: 9),
          ),
        ],
      ),
    );
  }

  static pw.Widget _tabla({
    required List<String> headers,
    required List<List<String>> rows,
    List<double>? widths,
  }) {
    final colWidths =
        widths ?? List.filled(headers.length, 1.0 / headers.length);

    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: rows,
      headerStyle: pw.TextStyle(
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
        fontSize: 10,
      ),
      headerDecoration: pw.BoxDecoration(color: _colorVerde),
      cellStyle: const pw.TextStyle(fontSize: 9),
      cellAlignments: {
        for (int i = 0; i < headers.length; i++) i: pw.Alignment.centerLeft,
      },
      columnWidths: {
        for (int i = 0; i < colWidths.length; i++)
          i: pw.FlexColumnWidth(colWidths[i]),
      },
      cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      oddRowDecoration: pw.BoxDecoration(color: _colorFondo),
    );
  }

  static pw.Widget _footer() {
    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 20),
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: PdfColors.grey300, width: 0.5),
        ),
      ),
      child: pw.Text(
        'Yagu! — Documento generado automáticamente',
        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey),
      ),
    );
  }

  static String _fechaHoy() {
    final now = DateTime.now();
    const meses = [
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
    return '${now.day.toString().padLeft(2, '0')} ${meses[now.month - 1]} ${now.year}';
  }

  static String _formatTS(dynamic ts) {
    if (ts == null) return 'Sin registro';
    try {
      final dt = ts.toDate() as DateTime;
      const meses = [
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
      return '${dt.day.toString().padLeft(2, '0')} ${meses[dt.month - 1]} ${dt.year}';
    } catch (_) {
      return 'Sin registro';
    }
  }

  static Future<void> generarReporteUsuarios(String filtroEstado) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('app-usuarios')
        .get();
    final pdf = pw.Document();

    var docs = List.from(snapshot.docs);
    docs.sort((a, b) {
      final na = (a.data()['nombre'] ?? '').toString().toLowerCase();
      final nb = (b.data()['nombre'] ?? '').toString().toLowerCase();
      if (na.isEmpty) return 1;
      if (nb.isEmpty) return -1;
      return na.compareTo(nb);
    });

    final rows = <List<String>>[];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      String estado = 'Inactivo';
      if (data['ultimoAcceso'] != null) {
        final dias = DateTime.now()
            .difference(data['ultimoAcceso'].toDate())
            .inDays;
        if (dias <= 30)
          estado = 'Activo';
        else if (dias <= 60)
          estado = 'Inactivo';
        else
          estado = 'Inhabilitado';
      }
      if (filtroEstado != 'Todos' && estado != filtroEstado) continue;
      rows.add([
        (data['nombre'] ?? '').toString().isEmpty
            ? 'Sin nombre'
            : data['nombre'].toString(),
        data['correo']?.toString() ?? data['email']?.toString() ?? '',
        data['rol']?.toString() ?? 'user',
        _formatTS(data['creadoEn']),
        _formatTS(data['ultimoAcceso']),
        estado,
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          _encabezado(
            'Reporte de usuarios',
            subtitulo:
                'Filtro: $filtroEstado  |  Total: ${rows.length} usuario(s)',
          ),
          pw.SizedBox(height: 16),
          _tabla(
            headers: [
              'Nombre',
              'Correo',
              'Rol',
              'Registro',
              'Último acceso',
              'Estado',
            ],
            rows: rows,
            widths: [1.4, 2.2, 0.7, 1.2, 1.2, 0.8],
          ),
          _footer(),
        ],
      ),
    );

    await _guardarYAbrir(await pdf.save(), 'reporte_usuarios');
  }

  static Future<void> generarExcelUsuarios(String filtroEstado) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('app-usuarios')
        .get();
    final excel = Excel.createExcel();
    final sheet = excel['Usuarios'];

    sheet.appendRow([
      'Nombre',
      'Correo',
      'Rol',
      'Fecha Registro',
      'Último Acceso',
      'Estado',
    ]);

    var docs = List.from(snapshot.docs);
    docs.sort((a, b) {
      final na = (a.data()['nombre'] ?? '').toString().toLowerCase();
      final nb = (b.data()['nombre'] ?? '').toString().toLowerCase();
      if (na.isEmpty) return 1;
      if (nb.isEmpty) return -1;
      return na.compareTo(nb);
    });

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      String estado = 'Inactivo';
      if (data['ultimoAcceso'] != null) {
        final dias = DateTime.now()
            .difference(data['ultimoAcceso'].toDate())
            .inDays;
        if (dias <= 30)
          estado = 'Activo';
        else if (dias <= 60)
          estado = 'Inactivo';
        else
          estado = 'Inhabilitado';
      }
      if (filtroEstado != 'Todos' && estado != filtroEstado) continue;
      sheet.appendRow([
        (data['nombre'] ?? '').toString().isEmpty
            ? 'Sin nombre'
            : data['nombre'].toString(),
        data['correo']?.toString() ?? data['email']?.toString() ?? '',
        data['rol']?.toString() ?? 'user',
        _formatTS(data['creadoEn']),
        _formatTS(data['ultimoAcceso']),
        estado,
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;
    await _guardarYAbrir(Uint8List.fromList(bytes), 'usuarios', ext: 'xlsx');
  }

  static Future<void> generarCsvUsuarios(String filtroEstado) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('app-usuarios')
        .get();
    final rows = <List<dynamic>>[
      ['Nombre', 'Correo', 'Rol', 'Fecha Registro', 'Último Acceso', 'Estado'],
    ];

    var docs = List.from(snapshot.docs);
    docs.sort((a, b) {
      final na = (a.data()['nombre'] ?? '').toString().toLowerCase();
      final nb = (b.data()['nombre'] ?? '').toString().toLowerCase();
      if (na.isEmpty) return 1;
      if (nb.isEmpty) return -1;
      return na.compareTo(nb);
    });

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      String estado = 'Inactivo';
      if (data['ultimoAcceso'] != null) {
        final dias = DateTime.now()
            .difference(data['ultimoAcceso'].toDate())
            .inDays;
        if (dias <= 30)
          estado = 'Activo';
        else if (dias <= 60)
          estado = 'Inactivo';
        else
          estado = 'Inhabilitado';
      }
      if (filtroEstado != 'Todos' && estado != filtroEstado) continue;
      rows.add([
        (data['nombre'] ?? '').toString().isEmpty
            ? 'Sin nombre'
            : data['nombre'].toString(),
        data['correo']?.toString() ?? data['email']?.toString() ?? '',
        data['rol']?.toString() ?? 'user',
        _formatTS(data['creadoEn']),
        _formatTS(data['ultimoAcceso']),
        estado,
      ]);
    }

    await _guardarYAbrir(
      Uint8List.fromList(const ListToCsvConverter().convert(rows).codeUnits),
      'usuarios',
      ext: 'csv',
    );
  }

  static Future<void> generarReporteUsuario(Map<String, dynamic> data) async {
    final pdf = pw.Document();
    final nombre = data['nombre']?.toString() ?? 'Sin nombre';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _encabezado('Perfil de usuario', subtitulo: nombre),
            pw.SizedBox(height: 20),
            _tabla(
              headers: ['Campo', 'Información'],
              widths: [1.0, 2.5],
              rows: [
                ['Nombre', nombre],
                [
                  'Correo',
                  data['correo']?.toString() ??
                      data['email']?.toString() ??
                      'Sin correo',
                ],
                ['Rol', data['rol']?.toString() ?? 'user'],
                ['Estado', 'Activo'],
                ['Fecha registro', _formatTS(data['creadoEn'])],
                ['Último acceso', _formatTS(data['ultimoAcceso'])],
              ],
            ),
            _footer(),
          ],
        ),
      ),
    );

    await _guardarYAbrir(await pdf.save(), 'usuario_$nombre');
  }

  static Future<void> generarReporteFavoritos() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('app-usuarios')
        .get();
    final pdf = pw.Document();
    final rows = <List<String>>[];

    for (final userDoc in snapshot.docs) {
      final userData = userDoc.data();
      final favs = await FirebaseFirestore.instance
          .collection('app-usuarios')
          .doc(userDoc.id)
          .collection('favoritos')
          .get();
      rows.add([
        userData['nombre']?.toString().isEmpty == true
            ? 'Sin nombre'
            : userData['nombre']?.toString() ?? 'Sin nombre',
        userData['correo']?.toString() ?? userData['email']?.toString() ?? '',
        favs.docs.length.toString(),
      ]);
    }

    // Ordenar por nombre
    rows.sort((a, b) => a[0].toLowerCase().compareTo(b[0].toLowerCase()));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          _encabezado(
            'Reporte de favoritos',
            subtitulo: 'Total usuarios analizados: ${rows.length}',
          ),
          pw.SizedBox(height: 16),
          _tabla(
            headers: ['Usuario', 'Correo', 'Total favoritos'],
            widths: [1.5, 2.5, 1.0],
            rows: rows,
          ),
          _footer(),
        ],
      ),
    );

    await _guardarYAbrir(await pdf.save(), 'favoritos');
  }

  static Future<void> generarReporteFavoritosUsuario(
    String nombreUsuario,
    String correo,
    List<QueryDocumentSnapshot> favoritos,
  ) async {
    final pdf = pw.Document();
    final rows = favoritos.map((favDoc) {
      final fav = favDoc.data() as Map<String, dynamic>;
      return [fav['nombre']?.toString() ?? 'Sin nombre'];
    }).toList();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          _encabezado(
            'Favoritos de $nombreUsuario',
            subtitulo: 'Correo: $correo',
          ),
          pw.SizedBox(height: 16),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: _colorVerdeClaro,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              'Total de recetas favoritas: ${favoritos.length}',
              style: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                fontSize: 11,
                color: _colorVerdeOsc,
              ),
            ),
          ),
          pw.SizedBox(height: 12),
          _tabla(
            headers: ['#', 'Nombre de la receta'],
            widths: [0.3, 3.0],
            rows: rows
                .asMap()
                .entries
                .map((e) => ['${e.key + 1}', e.value[0]])
                .toList(),
          ),
          _footer(),
        ],
      ),
    );

    await _guardarYAbrir(await pdf.save(), 'favoritos_$nombreUsuario');
  }

  static Future<void> generarExcelFavoritos() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('app-usuarios')
        .get();
    final excel = Excel.createExcel();
    final sheet = excel['Favoritos'];
    sheet.appendRow(['Usuario', 'Correo', 'Total favoritos']);

    for (final userDoc in snapshot.docs) {
      final userData = userDoc.data();
      final favs = await FirebaseFirestore.instance
          .collection('app-usuarios')
          .doc(userDoc.id)
          .collection('favoritos')
          .get();
      sheet.appendRow([
        userData['nombre']?.toString() ?? 'Sin nombre',
        userData['correo']?.toString() ?? userData['email']?.toString() ?? '',
        favs.docs.length.toString(),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;
    await _guardarYAbrir(Uint8List.fromList(bytes), 'favoritos', ext: 'xlsx');
  }

  static Future<void> generarCsvFavoritos() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('app-usuarios')
        .get();
    final rows = <List<dynamic>>[
      ['Usuario', 'Correo', 'Total favoritos'],
    ];

    for (final userDoc in snapshot.docs) {
      final userData = userDoc.data();
      final favs = await FirebaseFirestore.instance
          .collection('app-usuarios')
          .doc(userDoc.id)
          .collection('favoritos')
          .get();
      rows.add([
        userData['nombre']?.toString() ?? 'Sin nombre',
        userData['correo']?.toString() ?? userData['email']?.toString() ?? '',
        favs.docs.length.toString(),
      ]);
    }

    await _guardarYAbrir(
      Uint8List.fromList(const ListToCsvConverter().convert(rows).codeUnits),
      'favoritos',
      ext: 'csv',
    );
  }

  static Future<void> generarReporteRecetas({
    String categoria = 'Todas',
    String buscar = '',
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('app-recetas-completas')
        .get();
    final pdf = pw.Document();

    var docs = List.from(snapshot.docs);
    docs.sort((a, b) {
      final na = (a.data()['nombre'] ?? '').toString().toLowerCase();
      final nb = (b.data()['nombre'] ?? '').toString().toLowerCase();
      if (na.isEmpty) return 1;
      if (nb.isEmpty) return -1;
      return na.compareTo(nb);
    });

    // Aplicar filtros de búsqueda y categoría
    if (buscar.isNotEmpty) {
      docs = docs.where((doc) {
        final nombre = (doc.data()['nombre'] ?? '').toString().toLowerCase();
        return nombre.contains(buscar.toLowerCase());
      }).toList();
    }
    if (categoria != 'Todas') {
      docs = docs.where((doc) {
        final cat = (doc.data()['categoria'] ?? '').toString().toLowerCase();
        return cat == categoria.toLowerCase();
      }).toList();
    }

    final rows = docs.map((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return [
        data['nombre']?.toString() ?? '',
        data['categoria']?.toString() ?? '',
        '${data['calorias'] ?? data['calorías'] ?? 0} cal',
        '${data['tiempo'] ?? 0} min',
      ];
    }).toList();

    final subtituloFiltros = [
      if (categoria != 'Todas') 'Categoría: $categoria',
      if (buscar.isNotEmpty) 'Búsqueda: $buscar',
      'Total: \${rows.length} receta(s)',
    ].join('  |  ');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          _encabezado('Catálogo de Recetas', subtitulo: subtituloFiltros),
          pw.SizedBox(height: 16),
          _tabla(
            headers: ['Nombre', 'Categoría', 'Calorías', 'Tiempo'],
            widths: [2.5, 1.5, 1.0, 0.8],
            rows: rows,
          ),
          _footer(),
        ],
      ),
    );

    await _guardarYAbrir(await pdf.save(), 'recetas');
  }

  static Future<void> generarExcelRecetas({
    String categoria = 'Todas',
    String buscar = '',
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('app-recetas-completas')
        .get();
    final excel = Excel.createExcel();
    final sheet = excel['Recetas'];
    sheet.appendRow(['Nombre', 'Categoría', 'Calorías', 'Tiempo (min)']);

    var docs = List.from(snapshot.docs);
    docs.sort((a, b) {
      final na = (a.data()['nombre'] ?? '').toString().toLowerCase();
      final nb = (b.data()['nombre'] ?? '').toString().toLowerCase();
      if (na.isEmpty) return 1;
      if (nb.isEmpty) return -1;
      return na.compareTo(nb);
    });

    if (buscar.isNotEmpty) {
      docs = docs.where((doc) {
        final nombre = (doc.data()['nombre'] ?? '').toString().toLowerCase();
        return nombre.contains(buscar.toLowerCase());
      }).toList();
    }
    if (categoria != 'Todas') {
      docs = docs.where((doc) {
        final cat = (doc.data()['categoria'] ?? '').toString().toLowerCase();
        return cat == categoria.toLowerCase();
      }).toList();
    }

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      sheet.appendRow([
        data['nombre']?.toString() ?? '',
        data['categoria']?.toString() ?? '',
        '${data["calorias"] ?? data["calorías"] ?? 0}',
        '${data["tiempo"] ?? 0}',
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;
    await _guardarYAbrir(Uint8List.fromList(bytes), 'recetas', ext: 'xlsx');
  }

  static Future<void> generarCsvRecetas({
    String categoria = 'Todas',
    String buscar = '',
  }) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('app-recetas-completas')
        .get();
    final rows = <List<dynamic>>[
      ['Nombre', 'Categoría', 'Calorías', 'Tiempo (min)'],
    ];

    var docs = List.from(snapshot.docs);
    docs.sort((a, b) {
      final na = (a.data()['nombre'] ?? '').toString().toLowerCase();
      final nb = (b.data()['nombre'] ?? '').toString().toLowerCase();
      if (na.isEmpty) return 1;
      if (nb.isEmpty) return -1;
      return na.compareTo(nb);
    });

    if (buscar.isNotEmpty) {
      docs = docs.where((doc) {
        final nombre = (doc.data()['nombre'] ?? '').toString().toLowerCase();
        return nombre.contains(buscar.toLowerCase());
      }).toList();
    }
    if (categoria != 'Todas') {
      docs = docs.where((doc) {
        final cat = (doc.data()['categoria'] ?? '').toString().toLowerCase();
        return cat == categoria.toLowerCase();
      }).toList();
    }

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      rows.add([
        data['nombre']?.toString() ?? '',
        data['categoria']?.toString() ?? '',
        '${data["calorias"] ?? data["calorías"] ?? 0}',
        '${data["tiempo"] ?? 0}',
      ]);
    }

    await _guardarYAbrir(
      Uint8List.fromList(const ListToCsvConverter().convert(rows).codeUnits),
      'recetas',
      ext: 'csv',
    );
  }

  static Future<void> generarReporteRecetaIndividual(
    Map<String, dynamic> receta,
    List<Map<String, dynamic>> ingredientes,
    List<String> pasos,
  ) async {
    final pdf = pw.Document();
    final nombre = receta['nombre']?.toString() ?? 'Receta';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (ctx) => [
          _encabezado(
            nombre,
            subtitulo: [
              if ((receta['categoria'] ?? '').toString().isNotEmpty)
                'Categoría: ${receta['categoria']}',
              'Calorías: ${receta['calorias'] ?? receta['calorías'] ?? 0} cal',
              if ((receta['tiempo'] ?? 0).toString() != '0')
                'Tiempo: ${receta['tiempo']} min',
            ].join('  |  '),
          ),
          pw.SizedBox(height: 20),

          // Ingredientes
          pw.Text(
            'Ingredientes',
            style: pw.TextStyle(
              fontSize: 13,
              fontWeight: pw.FontWeight.bold,
              color: _colorVerdeOsc,
            ),
          ),
          pw.SizedBox(height: 8),
          if (ingredientes.isEmpty)
            pw.Text(
              'Sin ingredientes registrados.',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey),
            )
          else
            _tabla(
              headers: ['Ingrediente', 'Cantidad', 'Unidad'],
              widths: [2.5, 1.0, 1.0],
              rows: ingredientes
                  .map(
                    (ing) => [
                      ing['nombre']?.toString() ?? '',
                      ing['cantidad']?.toString() ?? '',
                      ing['unidad']?.toString() ?? '',
                    ],
                  )
                  .toList(),
            ),
          pw.SizedBox(height: 20),

          // Preparación
          if (pasos.isNotEmpty) ...[
            pw.Text(
              'Preparación',
              style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _colorVerdeOsc,
              ),
            ),
            pw.SizedBox(height: 8),
            ...pasos.asMap().entries.map(
              (e) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 10),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 22,
                      height: 22,
                      decoration: pw.BoxDecoration(
                        color: _colorVerde,
                        shape: pw.BoxShape.circle,
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '${e.key + 1}',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    pw.SizedBox(width: 10),
                    pw.Expanded(
                      child: pw.Text(
                        e.value,
                        style: const pw.TextStyle(fontSize: 10),
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          _footer(),
        ],
      ),
    );

    final nombreArchivo = 'receta_${nombre.replaceAll(' ', '_').toLowerCase()}';
    await _guardarYAbrir(await pdf.save(), nombreArchivo);
  }

  static Future<void> generarExcelRecetaIndividual(
    Map<String, dynamic> receta,
    List<Map<String, dynamic>> ingredientes,
    List<String> pasos,
  ) async {
    final nombre = receta['nombre']?.toString() ?? 'Receta';
    final excel = Excel.createExcel();

    final sheetInfo = excel['Información'];
    sheetInfo.appendRow(['Campo', 'Valor']);
    sheetInfo.appendRow(['Nombre', nombre]);
    sheetInfo.appendRow(['Categoría', receta['categoria']?.toString() ?? '']);
    sheetInfo.appendRow([
      'Calorías',
      '${receta['calorias'] ?? receta['calorías'] ?? 0}',
    ]);
    sheetInfo.appendRow(['Tiempo (min)', '${receta['tiempo'] ?? 0}']);

    final sheetIngs = excel['Ingredientes'];
    sheetIngs.appendRow(['Ingrediente', 'Cantidad', 'Unidad']);
    for (final ing in ingredientes) {
      sheetIngs.appendRow([
        ing['nombre'] ?? '',
        ing['cantidad'] ?? '',
        ing['unidad'] ?? '',
      ]);
    }

    final sheetPasos = excel['Preparación'];
    sheetPasos.appendRow(['Paso', 'Instrucción']);
    for (int i = 0; i < pasos.length; i++) {
      sheetPasos.appendRow(['${i + 1}', pasos[i]]);
    }

    try {
      excel.delete('Sheet1');
    } catch (_) {}

    final bytes = excel.encode();
    if (bytes == null) return;
    final nombreArchivo = 'receta_${nombre.replaceAll(' ', '_').toLowerCase()}';
    await _guardarYAbrir(Uint8List.fromList(bytes), nombreArchivo, ext: 'xlsx');
  }

  static Future<void> generarCsvRecetaIndividual(
    Map<String, dynamic> receta,
    List<Map<String, dynamic>> ingredientes,
    List<String> pasos,
  ) async {
    final nombre = receta['nombre']?.toString() ?? 'Receta';
    final rows = <List<dynamic>>[];

    rows.add(['=== INFORMACIÓN ===']);
    rows.add(['Nombre', nombre]);
    rows.add(['Categoría', receta['categoria']?.toString() ?? '']);
    rows.add(['Calorías', '${receta['calorias'] ?? receta['calorías'] ?? 0}']);
    rows.add(['Tiempo (min)', '${receta['tiempo'] ?? 0}']);
    rows.add([]);
    rows.add(['=== INGREDIENTES ===']);
    rows.add(['Ingrediente', 'Cantidad', 'Unidad']);
    for (final ing in ingredientes) {
      rows.add([
        ing['nombre'] ?? '',
        ing['cantidad'] ?? '',
        ing['unidad'] ?? '',
      ]);
    }
    rows.add([]);
    rows.add(['=== PREPARACIÓN ===']);
    rows.add(['Paso', 'Instrucción']);
    for (int i = 0; i < pasos.length; i++) {
      rows.add(['${i + 1}', pasos[i]]);
    }

    final nombreArchivo = 'receta_${nombre.replaceAll(' ', '_').toLowerCase()}';
    await _guardarYAbrir(
      Uint8List.fromList(const ListToCsvConverter().convert(rows).codeUnits),
      nombreArchivo,
      ext: 'csv',
    );
  }

  static Future<String> _nombreReceta(String? id) async {
    if (id == null || id.isEmpty) return 'No planificado';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('app-recetas-completas')
          .doc(id)
          .get();
      if (doc.exists) return doc.data()?['nombre']?.toString() ?? 'Sin nombre';
    } catch (_) {}
    return 'Receta eliminada';
  }

  static Future<List<List<dynamic>>> _datosPlanificadores(
    DateTime fecha,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('app-usuarios')
        .get();
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    final fechaStr = '${fecha.year}-$mes-$dia';
    final rows = <List<dynamic>>[
      ['Usuario', 'Correo', 'Desayuno', 'Almuerzo', 'Cena'],
    ];

    final docs = List.from(snapshot.docs);
    docs.sort((a, b) {
      final na = (a.data()['nombre'] ?? '').toString().trim().toLowerCase();
      final nb = (b.data()['nombre'] ?? '').toString().trim().toLowerCase();
      if (na.isEmpty && nb.isEmpty) return 0;
      if (na.isEmpty) return 1;
      if (nb.isEmpty) return -1;
      return na.compareTo(nb);
    });

    for (final userDoc in docs) {
      final userData = userDoc.data();
      final docId = '${userDoc.id}_$fechaStr';
      final planSnap = await FirebaseFirestore.instance
          .collection('app-planes')
          .doc(docId)
          .get();

      String desayuno = 'No planificado',
          almuerzo = 'No planificado',
          cena = 'No planificado';
      if (planSnap.exists && planSnap.data() != null) {
        final planData = planSnap.data()!;
        desayuno = await _nombreReceta(planData['desayuno']?.toString());
        almuerzo = await _nombreReceta(planData['almuerzo']?.toString());
        cena = await _nombreReceta(planData['cena']?.toString());
      }

      rows.add([
        userData['nombre']?.toString().isEmpty == true
            ? 'Sin nombre'
            : userData['nombre']?.toString() ?? 'Sin nombre',
        userData['correo']?.toString() ?? userData['email']?.toString() ?? '',
        desayuno,
        almuerzo,
        cena,
      ]);
    }
    return rows;
  }

  static Future<void> generarReportePlanificadoresPdf(DateTime fecha) async {
    final rows = await _datosPlanificadores(fecha);
    final pdf = pw.Document();
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (ctx) => [
          _encabezado(
            'Plan alimenticio por fecha',
            subtitulo:
                'Fecha: $dia/$mes/${fecha.year}  |  ${rows.length - 1} usuario(s)',
          ),
          pw.SizedBox(height: 16),
          _tabla(
            headers: rows.first.cast<String>(),
            widths: [1.4, 1.8, 1.6, 1.6, 1.6],
            rows: rows.sublist(1).map((r) => r.cast<String>()).toList(),
          ),
          _footer(),
        ],
      ),
    );

    await _guardarYAbrir(
      await pdf.save(),
      'planificadores_${fecha.year}-$mes-$dia',
    );
  }

  static Future<void> generarExcelPlanificadores(DateTime fecha) async {
    final rows = await _datosPlanificadores(fecha);
    final excel = Excel.createExcel();
    final sheet = excel['Planificadores'];
    for (final row in rows) {
      sheet.appendRow(row);
    }
    final bytes = excel.encode();
    if (bytes == null) return;
    final fechaStr =
        '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
    await _guardarYAbrir(
      Uint8List.fromList(bytes),
      'planificadores_$fechaStr',
      ext: 'xlsx',
    );
  }

  static Future<void> generarCsvPlanificadores(DateTime fecha) async {
    final rows = await _datosPlanificadores(fecha);
    final fechaStr =
        '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';
    await _guardarYAbrir(
      Uint8List.fromList(const ListToCsvConverter().convert(rows).codeUnits),
      'planificadores_$fechaStr',
      ext: 'csv',
    );
  }

  static Future<void> generarReporteGeneral() async =>
      generarReporteUsuarios('Todos');
}
