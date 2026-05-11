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

class PdfService {

  
  // REPORTE USUARIOS
  

  static Future<void>
      generarReporteUsuarios() async {

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
            ],

            data: usuarios.map((doc) {

              final data = doc.data();

              return [

                data['nombre'] ?? '',

                data['correo'] ??
                    data['email'] ??
                    '',

                data['rol'] ??
                    'user',
              ];

            }).toList(),
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

  
  // REPORTE GENERAL

  static Future<void>
      generarReporteGeneral() async {

    await generarReporteUsuarios();

  }
}