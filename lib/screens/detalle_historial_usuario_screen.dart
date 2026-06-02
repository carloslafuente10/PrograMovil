import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/widgets.dart' as pw;

import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

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