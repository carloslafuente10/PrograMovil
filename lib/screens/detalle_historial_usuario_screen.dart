import 'package:flutter/material.dart';// Pantalla que muestra el detalle del historial de actividades de un usuario específico, con la capacidad de filtrar por fecha y exportar el reporte en formato PDF. Utiliza Firestore para obtener los datos del historial y la librería pdf para generar el documento a partir de los registros filtrados.
import 'package:cloud_firestore/cloud_firestore.dart';// Librería para trabajar con Firestore, la base de datos en la nube de Firebase, que se utiliza para almacenar y recuperar los registros del historial de actividades de los usuarios.
import 'package:pdf/widgets.dart' as pw;// Librería para crear documentos PDF de manera programática, que se utiliza para generar el reporte de actividades del usuario en formato PDF a partir de los datos obtenidos de Firestore.

import 'package:printing/printing.dart';// Librería que facilita la impresión y el compartir documentos PDF generados en Flutter, utilizada para compartir el reporte de actividades del usuario después de ser generado con la librería pdf.
import 'package:pdf/pdf.dart';// Librería que proporciona constantes y utilidades para trabajar con PDF, como colores y estilos, utilizada en conjunto con la librería pdf para diseñar el reporte de actividades del usuario.
// Pantalla que muestra el detalle del historial de actividades de un usuario específico, con la capacidad de filtrar por fecha y exportar el reporte en formato PDF. Utiliza Firestore para obtener los datos del historial y la librería pdf para generar el documento a partir de los registros filtrados.
class DetalleHistorialUsuarioScreen
    extends StatefulWidget {

  final String uid;

  final String usuario;

  const DetalleHistorialUsuarioScreen({

    super.key,

    required this.uid,

    required this.usuario,
  });

  @override
  State<DetalleHistorialUsuarioScreen>
      createState() =>
          _DetalleHistorialUsuarioScreenState();
}
// Estado de la pantalla DetalleHistorialUsuarioScreen, que maneja la lógica para seleccionar la fecha, filtrar los registros del historial por esa fecha, generar el reporte en PDF y mostrarlo al usuario. Incluye un StreamBuilder para escuchar los cambios en Firestore y actualizar la lista de actividades en tiempo real.
class _DetalleHistorialUsuarioScreenState
    extends State<
        DetalleHistorialUsuarioScreen> {

  DateTime fechaSeleccionada =
      DateTime.now();
Future<void> exportarPdf(
  List<QueryDocumentSnapshot> docs,
) async {

  final pdf = pw.Document();

  pdf.addPage(

    pw.Page(

      build: (context) {

        return pw.Column(

          crossAxisAlignment:
              pw.CrossAxisAlignment.start,

          children: [

            pw.Text(

              'Reporte de actividades',

              style: pw.TextStyle(

                fontSize: 24,

                fontWeight:
                    pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 12),

            pw.Text(
              'Usuario: ${widget.usuario}',
            ),

            pw.Text(

              'Fecha: '
              '${fechaSeleccionada.day}/'
              '${fechaSeleccionada.month}/'
              '${fechaSeleccionada.year}',
            ),

            pw.SizedBox(height: 20),

            pw.TableHelper.fromTextArray(

  border:
      pw.TableBorder.all(),

  headerStyle: pw.TextStyle(

    fontWeight:
        pw.FontWeight.bold,
  ),

  headerDecoration:

      const pw.BoxDecoration(

    color:
        PdfColors.grey300,
  ),

  cellAlignment:
      pw.Alignment.centerLeft,

  cellPadding:
      const pw.EdgeInsets.all(8),

  headers: [

    'Hora',

    'Tipo',

    'Acción',
  ],

  data:
      docs.map((doc) {

    final data =
        doc.data()
            as Map<String, dynamic>;

    final fecha =
        (data['fecha']
                as Timestamp)
            .toDate();

    final hora =

        '${fecha.hour.toString().padLeft(2, '0')}:'
        '${fecha.minute.toString().padLeft(2, '0')}';

    return [

      hora,

      data['tipo'] ?? '',

      data['accion'] ?? '',
    ];

  }).toList(),
)
          ],
        );
      },
    ),
  );

  await Printing.sharePdf(

  bytes: await pdf.save(),

  filename:
      'reporte_'
      '${widget.usuario}_'
      '${fechaSeleccionada.day}_'
      '${fechaSeleccionada.month}_'
      '${fechaSeleccionada.year}.pdf',
);
}

// Método build que construye la interfaz de usuario de la pantalla, incluyendo un AppBar con el nombre del usuario y un botón para seleccionar la fecha, y un cuerpo que muestra una tabla con las actividades del usuario filtradas por la fecha seleccionada. Utiliza un StreamBuilder para escuchar los cambios en Firestore y actualizar la tabla en tiempo real.
  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        backgroundColor:
            const Color(0xFF2D9E73),

        foregroundColor:
            Colors.white,

        title: Text(
          widget.usuario,
        ),

        actions: [

          IconButton(

            onPressed: () async {

              final fecha =
                  await showDatePicker(

                context: context,

                initialDate:
                    fechaSeleccionada,

                firstDate:
                    DateTime(2024),

                lastDate:
                    DateTime(2030),
              );

              if (fecha != null) {

                setState(() {

                  fechaSeleccionada =
                      fecha;
                });
              }
            },

            icon: const Icon(
              Icons.calendar_month,
            ),
          ),
        ],
      ),

      body:
          StreamBuilder<QuerySnapshot>(

        stream:
            FirebaseFirestore.instance

                .collection(
                  'app-historial',
                )

                .where(
  'uid',
  isEqualTo:
      widget.uid,
)



.snapshots(),

        builder: (context, snapshot) {

          if (!snapshot.hasData) {

            return const Center(

              child:
                  CircularProgressIndicator(),
            );
          }

          final docs =
              snapshot.data!.docs.where((
                doc,
              ) {

            final data =
                doc.data()
                    as Map<String, dynamic>;

            final fecha =
                (data['fecha']
                        as Timestamp)
                    .toDate();

            final fechaDoc = DateTime(
              fecha.year,
              fecha.month,
              fecha.day,
            );

            final seleccionada =
                DateTime(

              fechaSeleccionada.year,

              fechaSeleccionada.month,

              fechaSeleccionada.day,
            );

            return fechaDoc ==
                seleccionada;

          }).toList();
          docs.sort((a, b) {

  final fechaA =
      ((a.data()
              as Map<String, dynamic>)['fecha']
          as Timestamp)
      .toDate();

  final fechaB =
      ((b.data()
              as Map<String, dynamic>)['fecha']
          as Timestamp)
      .toDate();

  return fechaB.compareTo(
    fechaA,
  );
});

          if (docs.isEmpty) {

            return const Center(

              child: Text(
                'Sin actividades',
              ),
            );
          }

          return Column(

  children: [

    Align(

      alignment:
          Alignment.centerRight,

      child: Padding(

        padding:
            const EdgeInsets.all(14),

        child: ElevatedButton.icon(

          onPressed: () {

            exportarPdf(docs);
          },

          icon: const Icon(
            Icons.picture_as_pdf,
          ),

          label: const Text(
            'Exportar PDF',
          ),
        ),
      ),
    ),

    Expanded(

  child: SingleChildScrollView(

    scrollDirection:
        Axis.horizontal,

    child: SingleChildScrollView(

      padding:
          const EdgeInsets.all(14),

      child: DataTable(

    columns: const [

      DataColumn(
        label: Text('Hora'),
      ),

      DataColumn(
        label: Text('Tipo'),
      ),

      DataColumn(
        label: Text('Acción'),
      ),
    ],

    rows:
        docs.map((doc) {

      final data =
          doc.data()
              as Map<String, dynamic>;

      final fecha =
          (data['fecha']
                  as Timestamp)
              .toDate();

      return DataRow(

        cells: [

          DataCell(

            Text(

              '${fecha.hour.toString().padLeft(2, '0')}:'
            '${fecha.minute.toString().padLeft(2, '0')}'
            ),
          ),

          DataCell(

            Text(
              data['tipo'] ?? '',
            ),
          ),

          DataCell(

            Text(
              data['accion'] ?? '',
            ),
          ),
        ],
      );

    }).toList(),
        ),
    ),
  ),
    ),
],
);
        },
      ),
    );
  }
}