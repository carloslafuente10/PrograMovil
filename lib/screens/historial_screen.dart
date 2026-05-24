import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() =>
      _HistorialScreenState();
}

class _HistorialScreenState
    extends State<HistorialScreen> {

  String filtroTipo = 'Todos';

  String buscar = '';

  DateTime? fechaInicio;

  DateTime? fechaFin;

  final buscarCtrl =
      TextEditingController();

  final List<String> tipos = [

    'Todos',

    'login',

    'logout',

    'favoritos',

    'plan',

    'recetas',

    'admin',
  ];

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(

        backgroundColor:
            const Color(0xFF2D9E73),

        foregroundColor:
            Colors.white,

        title: const Text(
          'Historial',
        ),
      ),

      body: Column(

        children: [

          const SizedBox(height: 14),

          _filtros(),

          const SizedBox(height: 12),

          Expanded(
            child: _listaHistorial(),
          ),
        ],
      ),
    );
  }

  Widget _filtros() {

    return Padding(

      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
      ),

      child: Column(

        children: [

          TextField(

            controller: buscarCtrl,

            decoration: InputDecoration(

              hintText:
                  'Buscar actividad',

              prefixIcon:
                  const Icon(Icons.search),

              filled: true,

              fillColor: Colors.white,

              border:
                  OutlineInputBorder(

                borderRadius:
                    BorderRadius.circular(14),

                borderSide:
                    BorderSide.none,
              ),
            ),

            onChanged: (value) {

              setState(() {

                buscar =
                    value.toLowerCase();
              });
            },
          ),

          const SizedBox(height: 12),

          Container(

            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
            ),

            decoration: BoxDecoration(

              color: Colors.white,

              borderRadius:
                  BorderRadius.circular(14),
            ),

            child:
                DropdownButton<String>(

              value: filtroTipo,

              underline:
                  const SizedBox(),

              isExpanded: true,

              items:
                  tipos.map((tipo) {

                return DropdownMenuItem(

                  value: tipo,

                  child: Text(tipo),
                );
              }).toList(),

              onChanged: (value) {

                setState(() {

                  filtroTipo =
                      value!;
                });
              },
            ),
          ),

          const SizedBox(height: 12),

          Row(

            children: [

              Expanded(

                child: ElevatedButton.icon(

                  onPressed: () async {

                    final fecha =
                        await showDatePicker(

                      context: context,

                      initialDate:
                          DateTime.now(),

                      firstDate:
                          DateTime(2024),

                      lastDate:
                          DateTime(2030),
                    );

                    if (fecha != null) {

                      setState(() {

                        fechaInicio =
                            fecha;
                      });
                    }
                  },

                  icon:
                      const Icon(
                    Icons.calendar_month,
                  ),

                  label: Text(

                    fechaInicio == null

                        ? 'Desde'

                        : '${fechaInicio!.day}/'
                          '${fechaInicio!.month}/'
                          '${fechaInicio!.year}',
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(

                child: ElevatedButton.icon(

                  onPressed: () async {

                    final fecha =
                        await showDatePicker(

                      context: context,

                      initialDate:
                          DateTime.now(),

                      firstDate:
                          DateTime(2024),

                      lastDate:
                          DateTime(2030),
                    );

                    if (fecha != null) {

                      setState(() {

                        fechaFin =
                            fecha;
                      });
                    }
                  },

                  icon:
                      const Icon(
                    Icons.calendar_today,
                  ),

                  label: Text(

                    fechaFin == null

                        ? 'Hasta'

                        : '${fechaFin!.day}/'
                          '${fechaFin!.month}/'
                          '${fechaFin!.year}',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _listaHistorial() {

    return StreamBuilder<QuerySnapshot>(

      stream:
          FirebaseFirestore.instance

              .collection(
                'app-historial',
              )

              .orderBy(
                'fecha',
                descending: true,
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
            snapshot.data!.docs.where((doc) {

          final data =
              doc.data()
                  as Map<String, dynamic>;

          final accion =
              (data['accion'] ?? '')
                  .toString()
                  .toLowerCase();

          final tipo =
              (data['tipo'] ?? '')
                  .toString();

          final fecha =
              (data['fecha']
                      as Timestamp)
                  .toDate();

          bool coincideFecha = true;

final fechaDoc = DateTime(
  fecha.year,
  fecha.month,
  fecha.day,
);

if (fechaInicio != null) {

  final inicio = DateTime(
    fechaInicio!.year,
    fechaInicio!.month,
    fechaInicio!.day,
  );

  coincideFecha =
      !fechaDoc.isBefore(inicio);
}

if (fechaFin != null) {

  final fin = DateTime(
    fechaFin!.year,
    fechaFin!.month,
    fechaFin!.day,
  );

  coincideFecha =
      coincideFecha &&
      !fechaDoc.isAfter(fin);
}

          final coincideBusqueda =
              accion.contains(buscar);

          final coincideTipo =
              filtroTipo == 'Todos'

                  ? true

                  : tipo == filtroTipo;

          return coincideBusqueda &&
              coincideTipo &&
              coincideFecha;

        }).toList();

        if (docs.isEmpty) {

          return const Center(

            child: Text(
              'Sin historial',
            ),
          );
        }

        return ListView.builder(

          padding:
              const EdgeInsets.all(14),

          itemCount: docs.length,

          itemBuilder: (context, index) {

            final data =
                docs[index].data()
                    as Map<String, dynamic>;

            final fecha =
                (data['fecha']
                        as Timestamp)
                    .toDate();

            return Card(

              shape:
                  RoundedRectangleBorder(

                borderRadius:
                    BorderRadius.circular(14),
              ),

              child: ListTile(

                leading: CircleAvatar(

                  backgroundColor:
                      _colorTipo(
                    data['tipo'],
                  ),

                  child: const Icon(

                    Icons.history,

                    color: Colors.white,
                  ),
                ),

                title: Text(
                  data['accion'] ?? '',
                ),

                subtitle: Text(

                  '${data['usuario'] ?? ''}\n'
                  '${fecha.day}/${fecha.month}/${fecha.year} - '
                  '${fecha.hour}:${fecha.minute}',
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _colorTipo(String tipo) {

    switch (tipo) {

      case 'login':
        return Colors.green;

      case 'logout':
        return Colors.grey;

      case 'favoritos':
        return Colors.red;

      case 'plan':
        return Colors.blue;

      case 'recetas':
        return Colors.orange;

      case 'admin':
        return Colors.purple;

      default:
        return Colors.black54;
    }
  }
}