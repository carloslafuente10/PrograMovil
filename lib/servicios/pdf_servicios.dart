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
import 'package:printing/printing.dart'; // <-- IMPORTACIÓN CLAVE

class PdfService {
  // ==========================================
  // REPORTE USUARIOS
  // ==========================================

  static Future<void> generarReporteUsuarios(String filtroEstado) async {
    final pdf = pw.Document();
    final snapshot = await FirebaseFirestore.instance
        .collection('app-usuarios')
        .get();
    final usuarios = snapshot.docs;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Reporte de Usuarios',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: [
              'Nombre',
              'Correo',
              'Rol',
              'Registro',
              'Último acceso',
              'Estado',
            ],
            data: usuarios
                .map((doc) {
                  final data = doc.data();
                  final creadoEn = data['creadoEn'];
                  final ultimoAcceso = data['ultimoAcceso'];
                  String fechaRegistro = 'Sin registro';
                  String fechaUltimoAcceso = 'Sin acceso';
                  String estado = 'Inactivo';

                  if (creadoEn != null)
                    fechaRegistro = creadoEn
                        .toDate()
                        .toString()
                        .split('.')
                        .first;
                  if (ultimoAcceso != null) {
                    final fecha = ultimoAcceso.toDate();
                    fechaUltimoAcceso = fecha.toString().split('.').first;
                    final diferencia = DateTime.now().difference(fecha).inDays;
                    if (diferencia <= 30)
                      estado = 'Activo';
                    else if (diferencia <= 60)
                      estado = 'Inactivo';
                    else
                      estado = 'Inhabilitado';
                  }
                  if (filtroEstado != 'Todos' && estado != filtroEstado)
                    return null;

                  return <String>[
                    (data['nombre'] ?? '').toString().isEmpty
                        ? 'Sin nombre'
                        : data['nombre'],
                    data['correo'] ?? data['email'] ?? '',
                    data['rol'] ?? 'user',
                    fechaRegistro,
                    fechaUltimoAcceso,
                    estado,
                  ];
                })
                .whereType<List<String>>()
                .toList(),
          ),
        ],
      ),
    );

    // SOLUCIÓN NATIVA PARA PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_Usuarios.pdf',
    );
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
      'Registro',
      'Último acceso',
      'Estado',
    ]);

    for (final doc in snapshot.docs) {
      final data = doc.data();
      String estado = 'Inactivo';
      if (data['ultimoAcceso'] != null) {
        final diferencia = DateTime.now()
            .difference(data['ultimoAcceso'].toDate())
            .inDays;
        estado = diferencia <= 30
            ? 'Activo'
            : (diferencia <= 60 ? 'Inactivo' : 'Inhabilitado');
      }
      if (filtroEstado != 'Todos' && estado != filtroEstado) continue;

      sheet.appendRow([
        (data['nombre'] ?? '').toString().isEmpty
            ? 'Sin nombre'
            : data['nombre'],
        data['correo'] ?? data['email'] ?? '',
        data['rol'] ?? 'user',
        data['creadoEn'] != null
            ? data['creadoEn'].toDate().toString().split('.').first
            : 'Sin registro',
        data['ultimoAcceso'] != null
            ? data['ultimoAcceso'].toDate().toString().split('.').first
            : 'Sin acceso',
        estado,
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;
    if (kIsWeb) {
      final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
      html.AnchorElement(href: url)
        ..setAttribute('download', 'usuarios.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/usuarios.xlsx');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    }
  }

  static Future<void> generarCsvUsuarios(String filtroEstado) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('app-usuarios')
        .get();
    List<List<dynamic>> rows = [
      ['Nombre', 'Correo', 'Rol', 'Registro', 'Último acceso', 'Estado'],
    ];

    for (final doc in snapshot.docs) {
      final data = doc.data();
      String estado = 'Inactivo';
      if (data['ultimoAcceso'] != null) {
        final diferencia = DateTime.now()
            .difference(data['ultimoAcceso'].toDate())
            .inDays;
        estado = diferencia <= 30
            ? 'Activo'
            : (diferencia <= 60 ? 'Inactivo' : 'Inhabilitado');
      }
      if (filtroEstado != 'Todos' && estado != filtroEstado) continue;

      rows.add([
        (data['nombre'] ?? '').toString().isEmpty
            ? 'Sin nombre'
            : data['nombre'],
        data['correo'] ?? data['email'] ?? '',
        data['rol'] ?? 'user',
        data['creadoEn'] != null
            ? data['creadoEn'].toDate().toString().split('.').first
            : 'Sin registro',
        data['ultimoAcceso'] != null
            ? data['ultimoAcceso'].toDate().toString().split('.').first
            : 'Sin acceso',
        estado,
      ]);
    }

    final bytes = Uint8List.fromList(
      const ListToCsvConverter().convert(rows).codeUnits,
    );
    if (kIsWeb) {
      final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
      html.AnchorElement(href: url)
        ..setAttribute('download', 'usuarios.csv')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/usuarios.csv');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    }
  }

  // ==========================================
  // REPORTE FAVORITOS
  // ==========================================

  static Future<void> generarReporteFavoritos() async {
    final usuarios =
        (await FirebaseFirestore.instance.collection('app-usuarios').get())
            .docs;
    final pdf = pw.Document();
    List<List<String>> rows = [
      ['Usuario', 'Cantidad favoritos'],
    ];

    for (final userDoc in usuarios) {
      final favoritos = await FirebaseFirestore.instance
          .collection('app-usuarios')
          .doc(userDoc.id)
          .collection('favoritos')
          .get();
      rows.add([
        userDoc.data()['nombre'] ?? 'Sin nombre',
        favoritos.docs.length.toString(),
      ]);
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Reporte Favoritos',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(headers: rows.first, data: rows.sublist(1)),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_Favoritos.pdf',
    );
  }

  static Future<void> generarReporteFavoritosUsuario(
    String nombreUsuario,
    String correo,
    List<QueryDocumentSnapshot> favoritos,
  ) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Favoritos de $nombreUsuario',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Correo: $correo'),
          pw.SizedBox(height: 20),
          ...favoritos.map((favDoc) {
            final fav = favDoc.data() as Map<String, dynamic>;
            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 10),
              child: pw.Row(
                children: [
                  pw.Text('- '),
                  pw.Expanded(child: pw.Text(fav['nombre'] ?? '')),
                ],
              ),
            );
          }),
          pw.SizedBox(height: 20),
          pw.Text('Total favoritos: ${favoritos.length}'),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Favoritos_$nombreUsuario.pdf',
    );
  }

  static Future<void> generarExcelFavoritos() async {
    final usuarios =
        (await FirebaseFirestore.instance.collection('app-usuarios').get())
            .docs;
    final excel = Excel.createExcel();
    final sheet = excel['Favoritos'];
    sheet.appendRow(['Usuario', 'Cantidad favoritos']);

    for (final userDoc in usuarios) {
      final favoritos = await FirebaseFirestore.instance
          .collection('app-usuarios')
          .doc(userDoc.id)
          .collection('favoritos')
          .get();
      sheet.appendRow([
        userDoc.data()['nombre'] ?? 'Sin nombre',
        favoritos.docs.length.toString(),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;
    if (kIsWeb) {
      final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
      html.AnchorElement(href: url)
        ..setAttribute('download', 'favoritos.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/favoritos.xlsx');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    }
  }

  static Future<void> generarCsvFavoritos() async {
    final usuarios =
        (await FirebaseFirestore.instance.collection('app-usuarios').get())
            .docs;
    List<List<dynamic>> rows = [
      ['Usuario', 'Cantidad favoritos'],
    ];

    for (final userDoc in usuarios) {
      final favoritos = await FirebaseFirestore.instance
          .collection('app-usuarios')
          .doc(userDoc.id)
          .collection('favoritos')
          .get();
      rows.add([
        userDoc.data()['nombre'] ?? 'Sin nombre',
        favoritos.docs.length.toString(),
      ]);
    }

    final bytes = Uint8List.fromList(
      const ListToCsvConverter().convert(rows).codeUnits,
    );
    if (kIsWeb) {
      final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
      html.AnchorElement(href: url)
        ..setAttribute('download', 'favoritos.csv')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/favoritos.csv');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    }
  }

  // ==========================================
  // REPORTE RECETAS
  // ==========================================

  static Future<void> generarReporteRecetas() async {
    final recetas =
        (await FirebaseFirestore.instance
                .collection('app-recetas-completas')
                .get())
            .docs;
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Reporte Recetas',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: ['Nombre', 'Categoría', 'Calorías'],
            data: recetas
                .map(
                  (doc) => [
                    doc['nombre'] ?? '',
                    doc['categoria'] ?? '',
                    '${doc['calorias'] ?? 0}',
                  ],
                )
                .toList(),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Reporte_Recetas.pdf',
    );
  }

  static Future<void> generarExcelRecetas() async {
    final recetas =
        (await FirebaseFirestore.instance
                .collection('app-recetas-completas')
                .get())
            .docs;
    final excel = Excel.createExcel();
    final sheet = excel['Recetas'];
    sheet.appendRow(['Nombre', 'Categoría', 'Calorías']);

    for (final doc in recetas) {
      sheet.appendRow([
        doc['nombre'] ?? '',
        doc['categoria'] ?? '',
        '${doc['calorias'] ?? 0}',
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;
    if (kIsWeb) {
      final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
      html.AnchorElement(href: url)
        ..setAttribute('download', 'recetas.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/recetas.xlsx');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    }
  }

  static Future<void> generarCsvRecetas() async {
    final recetas =
        (await FirebaseFirestore.instance
                .collection('app-recetas-completas')
                .get())
            .docs;
    List<List<dynamic>> rows = [
      ['Nombre', 'Categoría', 'Calorías'],
    ];

    for (final doc in recetas) {
      rows.add([
        doc['nombre'] ?? '',
        doc['categoria'] ?? '',
        '${doc['calorias'] ?? 0}',
      ]);
    }

    final bytes = Uint8List.fromList(
      const ListToCsvConverter().convert(rows).codeUnits,
    );
    if (kIsWeb) {
      final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
      html.AnchorElement(href: url)
        ..setAttribute('download', 'recetas.csv')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/recetas.csv');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    }
  }

  // ==========================================
  // REPORTE GENERAL
  // ==========================================

  static Future<void> generarReporteGeneral() async {
    await generarReporteUsuarios('Todos');
  }

  static Future<void> generarReporteUsuario(Map<String, dynamic> data) async {
    final creadoEn = data['creadoEn'];
    final ultimoAcceso = data['ultimoAcceso'];
    String fechaRegistro = creadoEn != null
        ? creadoEn.toDate().toString()
        : 'Sin registro';
    String fechaUltimoAcceso = ultimoAcceso != null
        ? ultimoAcceso.toDate().toString()
        : 'Sin acceso';

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Reporte Usuario',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text('Nombre: ${data['nombre'] ?? ''}'),
            pw.SizedBox(height: 10),
            pw.Text('Correo: ${data['correo'] ?? data['email'] ?? ''}'),
            pw.SizedBox(height: 10),
            pw.Text('Rol: ${data['rol'] ?? 'user'}'),
            pw.SizedBox(height: 10),
            pw.Text('Estado: Activo'),
            pw.SizedBox(height: 10),
            pw.Text('Fecha registro: $fechaRegistro'),
            pw.SizedBox(height: 10),
            pw.Text('Último acceso: $fechaUltimoAcceso'),
          ],
        ),
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Usuario_${data['nombre']}.pdf',
    );
  }

  // ==========================================
  // REPORTES PLANIFICADORES
  // ==========================================

  static Future<String> _obtenerNombreRecetaPlanes(String? id) async {
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

  static Future<List<List<dynamic>>> _prepararDatosPlanificadores(
    DateTime fecha,
  ) async {
    final usuarios =
        (await FirebaseFirestore.instance.collection('app-usuarios').get())
            .docs;
    List<List<dynamic>> rows = [
      ['Usuario', 'Desayuno', 'Almuerzo', 'Cena'],
    ];
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    final fechaStr = '${fecha.year}-$mes-$dia';

    for (final userDoc in usuarios) {
      final docId = '${userDoc.id}_$fechaStr';
      final planSnap = await FirebaseFirestore.instance
          .collection('app-planes')
          .doc(docId)
          .get();
      String desayuno = 'No planificado';
      String almuerzo = 'No planificado';
      String cena = 'No planificado';

      if (planSnap.exists && planSnap.data() != null) {
        final planData = planSnap.data()!;
        desayuno = await _obtenerNombreRecetaPlanes(
          planData['desayuno']?.toString(),
        );
        almuerzo = await _obtenerNombreRecetaPlanes(
          planData['almuerzo']?.toString(),
        );
        cena = await _obtenerNombreRecetaPlanes(planData['cena']?.toString());
      }
      rows.add([
        userDoc.data()['nombre']?.toString() ?? 'Sin nombre',
        desayuno,
        almuerzo,
        cena,
      ]);
    }
    return rows;
  }

  static Future<void> generarReportePlanificadoresPdf(DateTime fecha) async {
    final rows = await _prepararDatosPlanificadores(fecha);
    final pdf = pw.Document();
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'Reporte de Planificadores ($dia/$mes/${fecha.year})',
            style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 20),
          pw.Table.fromTextArray(
            headers: rows.first.cast<String>(),
            data: rows.sublist(1).map((row) => row.cast<String>()).toList(),
          ),
        ],
      ),
    );

    // SOLUCIÓN NATIVA PARA PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Planificadores_${fecha.year}_$mes\_$dia.pdf',
    );
  }

  static Future<void> generarExcelPlanificadores(DateTime fecha) async {
    final rows = await _prepararDatosPlanificadores(fecha);
    final excel = Excel.createExcel();
    final sheet = excel['Planificadores'];

    for (var row in rows) {
      sheet.appendRow(row);
    }

    final bytes = excel.encode();
    if (bytes == null) return;
    final fechaStr =
        '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

    if (kIsWeb) {
      final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
      html.AnchorElement(href: url)
        ..setAttribute('download', 'planificadores_$fechaStr.xlsx')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/planificadores_$fechaStr.xlsx');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    }
  }

  static Future<void> generarCsvPlanificadores(DateTime fecha) async {
    final rows = await _prepararDatosPlanificadores(fecha);
    final bytes = Uint8List.fromList(
      const ListToCsvConverter().convert(rows).codeUnits,
    );
    final fechaStr =
        '${fecha.year}-${fecha.month.toString().padLeft(2, '0')}-${fecha.day.toString().padLeft(2, '0')}';

    if (kIsWeb) {
      final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes]));
      html.AnchorElement(href: url)
        ..setAttribute('download', 'planificadores_$fechaStr.csv')
        ..click();
      html.Url.revokeObjectUrl(url);
    } else {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/planificadores_$fechaStr.csv');
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    }
  }

  // ==========================================
  // REPORTE INDIVIDUAL (La implementación que pediste)
  // ==========================================

  static Future<void> generarReporteIndividual(
    String uid,
    String nombreUsuario,
    Map<String, dynamic> plan,
    DateTime fecha,
  ) async {
    final pdf = pw.Document();
    final mes = fecha.month.toString().padLeft(2, '0');
    final dia = fecha.day.toString().padLeft(2, '0');
    final fechaStr = '${fecha.year}-$mes-$dia';

    // Obtener nombres reales de las recetas
    String desayuno = await _obtenerNombreRecetaPlanes(
      plan['desayuno']?.toString(),
    );
    String almuerzo = await _obtenerNombreRecetaPlanes(
      plan['almuerzo']?.toString(),
    );
    String cena = await _obtenerNombreRecetaPlanes(plan['cena']?.toString());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Planificación Individual',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 20),
            pw.Text(
              'Usuario: $nombreUsuario',
              style: pw.TextStyle(fontSize: 18),
            ),
            pw.Text(
              'Fecha: $dia/$mes/${fecha.year}',
              style: pw.TextStyle(fontSize: 14),
            ),
            pw.SizedBox(height: 30),
            pw.Table.fromTextArray(
              headers: ['Comida', 'Receta Planificada'],
              data: [
                ['Desayuno', desayuno],
                ['Almuerzo', almuerzo],
                ['Cena', cena],
              ],
            ),
          ],
        ),
      ),
    );

    // SOLUCIÓN NATIVA PARA PDF
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Planificacion_${nombreUsuario}_$fechaStr.pdf',
    );
  }
}
