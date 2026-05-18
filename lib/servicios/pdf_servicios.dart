import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:universal_html/html.dart'
    as html;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';

class PdfService {
  // REPORTE USUARIOS

  static Future<void>
      generarReporteUsuarios(
  String filtroEstado,
) async {

    final pdf = pw.Document();

    final snapshot =
        await FirebaseFirestore.instance
            .collection('app-usuarios')
            .get();

    final usuarios = snapshot.docs;

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,

        build: (context) => [

          pw.Text(
            'Reporte de Usuarios',
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight:
                  pw.FontWeight.bold,
            ),
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

            data: usuarios.map((doc) {

              final data = doc.data();
              final creadoEn =
    data['creadoEn'];

final ultimoAcceso =
    data['ultimoAcceso'];

String fechaRegistro =
    'Sin registro';

String fechaUltimoAcceso =
    'Sin acceso';

String estado =
    'Inactivo';

if (creadoEn != null) {

  fechaRegistro =
      creadoEn
          .toDate()
          .toString()
          .split('.')
          .first;
}

if (ultimoAcceso != null) {

  final fecha =
      ultimoAcceso.toDate();

  fechaUltimoAcceso =
      fecha
          .toString()
          .split('.')
          .first;

  final diferencia =
      DateTime.now()
          .difference(fecha)
          .inDays;

  if (diferencia <= 30) {

  estado = 'Activo';
}

else if (
    diferencia <= 60) {

  estado = 'Inactivo';
}

else {

  estado =
      'Inhabilitado';
} 
}
if (filtroEstado !=
        'Todos' &&
    estado !=
        filtroEstado) {

  return null;
}

return  <String>[

  (data['nombre'] ?? '')
          .toString()
          .isEmpty
      ? 'Sin nombre'
      : data['nombre'],

  data['correo'] ??
      data['email'] ??
      '',

  data['rol'] ??
      'user',

  fechaRegistro,

  fechaUltimoAcceso,

  estado,
];

              

           }).whereType<List<String>>()
  .toList(),
          ),
        ],
      ),
    );

    final Uint8List bytes =
        await pdf.save();

    

    if (kIsWeb) {

      final blob =
          html.Blob([bytes]);

      final url =
          html.Url
              .createObjectUrlFromBlob(
        blob,
      );

      final anchor =
          html.AnchorElement(
        href: url,
      )
            ..setAttribute(
              'download',
              'reporte_usuarios.pdf',
            )
            ..click();

      html.Url
          .revokeObjectUrl(url);

    }

    
    // ANDROID
    

    else {

      final dir =
          await getApplicationDocumentsDirectory();

      final file = File(
        '${dir.path}/reporte_usuarios.pdf',
      );

      await file.writeAsBytes(
        bytes,
      );

      await OpenFile.open(
        file.path,
      );
    }
  }
static Future<void>
    generarExcelUsuarios(
  String filtroEstado,
) async {

  final snapshot =
      await FirebaseFirestore.instance
          .collection('app-usuarios')
          .get();

  final usuarios = snapshot.docs;

  final excel = Excel.createExcel();

  final sheet =
      excel['Usuarios'];

  sheet.appendRow([
  'Nombre',
  'Correo',
  'Rol',
  'Registro',
  'Último acceso',
  'Estado',
]);

  for (final doc in usuarios) {

    final data = doc.data();
    final creadoEn =
    data['creadoEn'];

final ultimoAcceso =
    data['ultimoAcceso'];

String fechaRegistro =
    'Sin registro';

String fechaUltimoAcceso =
    'Sin acceso';

String estado =
    'Inactivo';

if (creadoEn != null) {

  fechaRegistro =
      creadoEn
          .toDate()
          .toString()
          .split('.')
          .first;
}

if (ultimoAcceso != null) {

  final fecha =
      ultimoAcceso.toDate();

  fechaUltimoAcceso =
      fecha
          .toString()
          .split('.')
          .first;

  final diferencia =
      DateTime.now()
          .difference(fecha)
          .inDays;

  if (diferencia <= 30) {

  estado = 'Activo';
}

else if (
    diferencia <= 60) {

  estado = 'Inactivo';
}

else {

  estado =
      'Inhabilitado';
} 
}
if (filtroEstado !=
        'Todos' &&
    estado !=
        filtroEstado) {

  continue;
}

sheet.appendRow([

  (data['nombre'] ?? '')
          .toString()
          .isEmpty
      ? 'Sin nombre'
      : data['nombre'],

  data['correo'] ??
      data['email'] ??
      '',

  data['rol'] ??
      'user',

  fechaRegistro,

  fechaUltimoAcceso,

  estado,
]);
    
  }

  final bytes =
      excel.encode();

  if (bytes == null) return;

  if (kIsWeb) {

    final blob =
        html.Blob([bytes]);

    final url =
        html.Url
            .createObjectUrlFromBlob(
      blob,
    );

    html.AnchorElement(
      href: url,
    )
          ..setAttribute(
            'download',
            'usuarios.xlsx',
          )
          ..click();

    html.Url
        .revokeObjectUrl(url);

  }

  else {

    final dir =
        await getApplicationDocumentsDirectory();

    final file = File(
      '${dir.path}/usuarios.xlsx',
    );

    await file.writeAsBytes(
      bytes,
    );

    await OpenFile.open(
      file.path,
    );
  }
}

  static Future<void>
    generarCsvUsuarios(
  String filtroEstado,
) async{

  final snapshot =
      await FirebaseFirestore.instance
          .collection('app-usuarios')
          .get();

  final usuarios = snapshot.docs;

  List<List<dynamic>> rows = [];
  
  rows.add([
  'Nombre',
  'Correo',
  'Rol',
  'Registro',
  'Último acceso',
  'Estado',
]);
  for (final doc in usuarios) {

    final data = doc.data();
    final creadoEn =
    data['creadoEn'];

final ultimoAcceso =
    data['ultimoAcceso'];

String fechaRegistro =
    'Sin registro';

String fechaUltimoAcceso =
    'Sin acceso';

String estado =
    'Inactivo';

if (creadoEn != null) {

  fechaRegistro =
      creadoEn
          .toDate()
          .toString()
          .split('.')
          .first;
}

if (ultimoAcceso != null) {

  final fecha =
      ultimoAcceso.toDate();

  fechaUltimoAcceso =
      fecha
          .toString()
          .split('.')
          .first;

  final diferencia =
      DateTime.now()
          .difference(fecha)
          .inDays;

  if (diferencia <= 30) {

  estado = 'Activo';
}

else if (
    diferencia <= 60) {

  estado = 'Inactivo';
}

else {

  estado =
      'Inhabilitado';
} 
}
if (filtroEstado !=
        'Todos' &&
    estado !=
        filtroEstado) {

  continue;
}
rows.add([

  (data['nombre'] ?? '')
          .toString()
          .isEmpty
      ? 'Sin nombre'
      : data['nombre'],

  data['correo'] ??
      data['email'] ??
      '',

  data['rol'] ??
      'user',

  fechaRegistro,

  fechaUltimoAcceso,

  estado,
]);
    
  }

  String csvData =
      const ListToCsvConverter()
          .convert(rows);

  final bytes =
      Uint8List.fromList(
    csvData.codeUnits,
  );

  if (kIsWeb) {

    final blob =
        html.Blob([bytes]);

    final url =
        html.Url
            .createObjectUrlFromBlob(
      blob,
    );

    html.AnchorElement(
      href: url,
    )
          ..setAttribute(
            'download',
            'usuarios.csv',
          )
          ..click();

    html.Url
        .revokeObjectUrl(url);

  }

  else {

    final dir =
        await getApplicationDocumentsDirectory();

    final file = File(
      '${dir.path}/usuarios.csv',
    );

    await file.writeAsBytes(
      bytes,
    );

    await OpenFile.open(
      file.path,
    );
  }
}
static Future<void>
    generarReporteFavoritos() async {

  final snapshot =
      await FirebaseFirestore.instance
          .collection('app-usuarios')
          .get();

  final usuarios = snapshot.docs;

  final pdf = pw.Document();

  List<List<String>> rows = [];

  rows.add([
    'Usuario',
    'Cantidad favoritos',
  ]);

  for (final userDoc in usuarios) {

    final userData =
        userDoc.data();

    final favoritos =
        await FirebaseFirestore
            .instance
            .collection(
              'app-usuarios',
            )
            .doc(userDoc.id)
            .collection(
              'favoritos',
            )
            .get();

    rows.add([

      userData['nombre'] ??
          'Sin nombre',

      favoritos.docs.length
          .toString(),
    ]);
  }

  pdf.addPage(

    pw.MultiPage(

      pageFormat:
          PdfPageFormat.a4,

      build: (context) => [

        pw.Text(
          'Reporte Favoritos',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight:
                pw.FontWeight.bold,
          ),
        ),

        pw.SizedBox(height: 20),

        pw.Table.fromTextArray(
          headers: rows.first,

          data: rows
              .sublist(1),
        ),
      ],
    ),
  );

  final bytes =
      await pdf.save();

  if (kIsWeb) {

    final blob =
        html.Blob([bytes]);

    final url =
        html.Url
            .createObjectUrlFromBlob(
      blob,
    );

    html.AnchorElement(
      href: url,
    )
          ..setAttribute(
            'download',
            'favoritos.pdf',
          )
          ..click();

    html.Url
        .revokeObjectUrl(url);

  }

  else {

    final dir =
        await getApplicationDocumentsDirectory();

    final file = File(
      '${dir.path}/favoritos.pdf',
    );

    await file.writeAsBytes(
      bytes,
    );

    await OpenFile.open(
      file.path,
    );
  }
}
static Future<void>
    generarReporteFavoritosUsuario(

  String nombreUsuario,
  String correo,
  List<QueryDocumentSnapshot>
      favoritos,

) async {

  final pdf = pw.Document();

  pdf.addPage(

    pw.MultiPage(

      pageFormat:
          PdfPageFormat.a4,

      build: (context) => [

        pw.Text(

          'Favoritos de $nombreUsuario',

          style: pw.TextStyle(
            fontSize: 24,
            fontWeight:
                pw.FontWeight.bold,
          ),
        ),

        pw.SizedBox(height: 20),

        pw.Text(
          'Correo: $correo',
        ),

        pw.SizedBox(height: 20),

        ...favoritos.map((favDoc) {

          final fav =
              favDoc.data()
                  as Map<String,
                      dynamic>;

          return pw.Container(

            margin:
                const pw.EdgeInsets.only(
              bottom: 10,
            ),

            child: pw.Row(

              children: [

                pw.Text('- '),

                pw.Expanded(

                  child: pw.Text(

                    fav['nombre'] ??
                        '',
                  ),
                ),
              ],
            ),
          );
        }),

        pw.SizedBox(height: 20),

        pw.Text(
          'Total favoritos: ${favoritos.length}',
        ),
      ],
    ),
  );

  final bytes =
      await pdf.save();

  if (kIsWeb) {

    final blob =
        html.Blob([bytes]);

    final url =
        html.Url
            .createObjectUrlFromBlob(
      blob,
    );

    html.AnchorElement(
      href: url,
    )
          ..setAttribute(
            'download',
            'favoritos_$nombreUsuario.pdf',
          )
          ..click();

    html.Url
        .revokeObjectUrl(url);

  }

  else {

    final dir =
        await getApplicationDocumentsDirectory();

    final file = File(
      '${dir.path}/favoritos_$nombreUsuario.pdf',
    );

    await file.writeAsBytes(
      bytes,
    );

    await OpenFile.open(
      file.path,
    );
  }
}
static Future<void>
    generarExcelFavoritos() async {

  final snapshot =
      await FirebaseFirestore.instance
          .collection('app-usuarios')
          .get();

  final usuarios = snapshot.docs;

  final excel = Excel.createExcel();

  final sheet =
      excel['Favoritos'];

  sheet.appendRow([
    'Usuario',
    'Cantidad favoritos',
  ]);

  for (final userDoc in usuarios) {

    final userData =
        userDoc.data();

    final favoritos =
        await FirebaseFirestore
            .instance
            .collection(
              'app-usuarios',
            )
            .doc(userDoc.id)
            .collection(
              'favoritos',
            )
            .get();
    

    sheet.appendRow([

      userData['nombre'] ??
          'Sin nombre',

      favoritos.docs.length
          .toString(),
    ]);
  }

  final bytes =
      excel.encode();

  if (bytes == null) return;

  if (kIsWeb) {

    final blob =
        html.Blob([bytes]);

    final url =
        html.Url
            .createObjectUrlFromBlob(
      blob,
    );

    html.AnchorElement(
      href: url,
    )
          ..setAttribute(
            'download',
            'favoritos.xlsx',
          )
          ..click();

    html.Url
        .revokeObjectUrl(url);

  }

  else {

    final dir =
        await getApplicationDocumentsDirectory();

    final file = File(
      '${dir.path}/favoritos.xlsx',
    );

    await file.writeAsBytes(
      bytes,
    );

    await OpenFile.open(
      file.path,
    );
  }
}
static Future<void>
    generarCsvFavoritos() async {

  final snapshot =
      await FirebaseFirestore.instance
          .collection('app-usuarios')
          .get();

  final usuarios = snapshot.docs;

  List<List<dynamic>> rows = [];

  rows.add([
    'Usuario',
    'Cantidad favoritos',
  ]);

  for (final userDoc in usuarios) {

    final userData =
        userDoc.data();

    final favoritos =
        await FirebaseFirestore
            .instance
            .collection(
              'app-usuarios',
            )
            .doc(userDoc.id)
            .collection(
              'favoritos',
            )
            .get();
    

    rows.add([

      userData['nombre'] ??
          'Sin nombre',

      favoritos.docs.length
          .toString(),
    ]);
  }

  String csvData =
      const ListToCsvConverter()
          .convert(rows);

  final bytes =
      Uint8List.fromList(
    csvData.codeUnits,
  );

  if (kIsWeb) {

    final blob =
        html.Blob([bytes]);

    final url =
        html.Url
            .createObjectUrlFromBlob(
      blob,
    );

    html.AnchorElement(
      href: url,
    )
          ..setAttribute(
            'download',
            'favoritos.csv',
          )
          ..click();

    html.Url
        .revokeObjectUrl(url);

  }

  else {

    final dir =
        await getApplicationDocumentsDirectory();

    final file = File(
      '${dir.path}/favoritos.csv',
    );

    await file.writeAsBytes(
      bytes,
    );

    await OpenFile.open(
      file.path,
    );
  }
}
static Future<void>
    generarReporteRecetas() async {

  final snapshot =
      await FirebaseFirestore.instance
          .collection(
            'app-recetas-completas',
          )
          .get();

  final recetas = snapshot.docs;

  final pdf = pw.Document();

  pdf.addPage(

    pw.MultiPage(

      pageFormat:
          PdfPageFormat.a4,

      build: (context) => [

        pw.Text(
          'Reporte Recetas',
          style: pw.TextStyle(
            fontSize: 24,
            fontWeight:
                pw.FontWeight.bold,
          ),
        ),

        pw.SizedBox(height: 20),

        pw.Table.fromTextArray(

          headers: [
            'Nombre',
            'Categoría',
            'Calorías',
          ],

          data: recetas.map((doc) {

            final data =
                doc.data();
                

            return [

              data['nombre'] ??
                  '',

              data['categoria'] ??
                  '',

              '${data['calorias'] ?? 0}',
            ];

          }).toList(),
        ),
      ],
    ),
  );

  final bytes =
      await pdf.save();

  if (kIsWeb) {

    final blob =
        html.Blob([bytes]);

    final url =
        html.Url
            .createObjectUrlFromBlob(
      blob,
    );

    html.AnchorElement(
      href: url,
    )
          ..setAttribute(
            'download',
            'recetas.pdf',
          )
          ..click();

    html.Url
        .revokeObjectUrl(url);

  }

  else {

    final dir =
        await getApplicationDocumentsDirectory();

    final file = File(
      '${dir.path}/recetas.pdf',
    );

    await file.writeAsBytes(
      bytes,
    );

    await OpenFile.open(
      file.path,
    );
  }
}
static Future<void>
    generarExcelRecetas() async {

  final snapshot =
      await FirebaseFirestore.instance
          .collection(
            'app-recetas-completas',
          )
          .get();

  final recetas = snapshot.docs;

  final excel = Excel.createExcel();

  final sheet =
      excel['Recetas'];

  sheet.appendRow([
    'Nombre',
    'Categoría',
    'Calorías',
  ]);

  for (final doc in recetas) {

    final data = doc.data();

    sheet.appendRow([

      data['nombre'] ?? '',

      data['categoria'] ?? '',

      '${data['calorias'] ?? 0}',
    ]);
  }

  final bytes =
      excel.encode();

  if (bytes == null) return;

  if (kIsWeb) {

    final blob =
        html.Blob([bytes]);

    final url =
        html.Url
            .createObjectUrlFromBlob(
      blob,
    );

    html.AnchorElement(
      href: url,
    )
          ..setAttribute(
            'download',
            'recetas.xlsx',
          )
          ..click();

    html.Url
        .revokeObjectUrl(url);

  }

  else {

    final dir =
        await getApplicationDocumentsDirectory();

    final file = File(
      '${dir.path}/recetas.xlsx',
    );

    await file.writeAsBytes(
      bytes,
    );

    await OpenFile.open(
      file.path,
    );
  }
}
static Future<void>
    generarCsvRecetas() async {

  final snapshot =
      await FirebaseFirestore.instance
          .collection(
            'app-recetas-completas',
          )
          .get();

  final recetas = snapshot.docs;

  List<List<dynamic>> rows = [];

  rows.add([
    'Nombre',
    'Categoría',
    'Calorías',
  ]);

  for (final doc in recetas) {

    final data = doc.data();

    rows.add([

      data['nombre'] ?? '',

      data['categoria'] ?? '',

      '${data['calorias'] ?? 0}',
    ]);
  }

  String csvData =
      const ListToCsvConverter()
          .convert(rows);

  final bytes =
      Uint8List.fromList(
    csvData.codeUnits,
  );

  if (kIsWeb) {

    final blob =
        html.Blob([bytes]);

    final url =
        html.Url
            .createObjectUrlFromBlob(
      blob,
    );

    html.AnchorElement(
      href: url,
    )
          ..setAttribute(
            'download',
            'recetas.csv',
          )
          ..click();

    html.Url
        .revokeObjectUrl(url);

  }

  else {

    final dir =
        await getApplicationDocumentsDirectory();

    final file = File(
      '${dir.path}/recetas.csv',
    );

    await file.writeAsBytes(
      bytes,
    );

    await OpenFile.open(
      file.path,
    );
  }
}

  // REPORTE GENERAL

  static Future<void>
      generarReporteGeneral() async {

    await generarReporteUsuarios(
  'Todos',
);

  }

  static Future<void>
    generarReporteUsuario(
  Map<String, dynamic> data,
) async {


final creadoEn =
    data['creadoEn'];

final ultimoAcceso =
    data['ultimoAcceso'];

String fechaRegistro =
    'Sin registro';

String fechaUltimoAcceso =
    'Sin acceso';

if (creadoEn != null) {

  fechaRegistro =
      creadoEn
          .toDate()
          .toString();
}

if (ultimoAcceso != null) {

  fechaUltimoAcceso =
      ultimoAcceso
          .toDate()
          .toString();
}


  final pdf = pw.Document();

  pdf.addPage(
    pw.Page(

      pageFormat: PdfPageFormat.a4,

      build: (context) {

        return pw.Column(
          crossAxisAlignment:
              pw.CrossAxisAlignment.start,

          children: [

            pw.Text(
              'Reporte Usuario',
              style: pw.TextStyle(
                fontSize: 24,
                fontWeight:
                    pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 20),

            pw.Text(
              'Nombre: ${data['nombre'] ?? ''}',
            ),

            pw.SizedBox(height: 10),

            pw.Text(
              'Correo: ${data['correo'] ?? data['email'] ?? ''}',
            ),

            pw.SizedBox(height: 10),

            pw.Text(
              'Rol: ${data['rol'] ?? 'user'}',
            ),

            pw.SizedBox(height: 10),

            pw.Text(
              'Estado: Activo',
            ),
            pw.SizedBox(height: 10),

pw.Text(
  'Fecha registro: $fechaRegistro',
),

pw.SizedBox(height: 10),

pw.Text(
  'Último acceso: $fechaUltimoAcceso',
),
          ],
        );
      },
    ),
  );

  final Uint8List bytes =
      await pdf.save();

  if (kIsWeb) {

    final blob =
        html.Blob([bytes]);

    final url =
        html.Url
            .createObjectUrlFromBlob(
      blob,
    );

    final anchor =
        html.AnchorElement(
      href: url,
    )
          ..setAttribute(
            'download',
            'usuario_${data['nombre']}.pdf',
          )
          ..click();

    html.Url
        .revokeObjectUrl(url);

  }

  else {

    final dir =
        await getApplicationDocumentsDirectory();

    final file = File(
      '${dir.path}/usuario_${data['nombre']}.pdf',
    );

    await file.writeAsBytes(
      bytes,
    );

    await OpenFile.open(
      file.path,
    );
  }
}
}