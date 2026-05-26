import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'detalle_historial_usuario_screen.dart';

class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key});

  @override
  State<HistorialScreen> createState() =>
      _HistorialScreenState();
}

class _HistorialScreenState
    extends State<HistorialScreen> {

  String filtroTipo = 'Todos';
  String filtroRol = 'Todos';

  

  String buscar = '';

  

  final buscarCtrl =
      TextEditingController();

  final List<String> tipos = [

    'Todos',

    'login',

    'logout',

    'favoritos',

    'plan',

    'recetas',

    'roles',
  ];
  final List<String> roles = [

  'Todos',

  'user',

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
                  'Buscar usuario...',

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

                return DropdownMenuItem<String>(

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
        

    value:
        filtroRol,

    underline:
        const SizedBox(),

    isExpanded: true,

    items:
    roles.map((rol) {

  return DropdownMenuItem<String>(

    value: rol,

    child: Text(

      rol == 'Todos'

          ? 'Todos'

          : rol == 'admin'

              ? 'Admins'

              : 'Usuarios',
    ),
  );

}).toList(),

    onChanged: (value) {

      setState(() {

        filtroRol =
            value!;
      });
    },
  ),
),

          const SizedBox(height: 12),

          
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

            .snapshots(),

    builder: (context, snapshot) {

      if (!snapshot.hasData) {

        return const Center(

          child:
              CircularProgressIndicator(),
        );
      }

      final historial =
          snapshot.data!.docs;

      final Map<String, Map<String, dynamic>>
          usuarios = {};

      for (final doc in historial) {

        final data =
            doc.data()
                as Map<String, dynamic>;

        final uid =
            data['uid'] ?? '';

        if (uid.isEmpty) continue;

        final usuario =
            (data['usuario'] ?? '')
                .toString();

        final rol =
            (data['rol'] ?? '')
                .toString();

        final correo =
            (data['correo'] ?? '')
                .toString();

        final coincideBusqueda =

            usuario
                .toLowerCase()
                .contains(
                  buscar,
                );

        final coincideRol =

            filtroRol == 'Todos'

                ? true

                : rol == filtroRol;

        if (coincideBusqueda &&
            coincideRol) {

          usuarios[uid] = {

            'uid': uid,

            'usuario':
                usuario,

            'rol': rol,

            'correo':
                correo,
          };
        }
      }

      final listaUsuarios =
          usuarios.values.toList();

      if (listaUsuarios.isEmpty) {

        return const Center(

          child: Text(
            'Sin usuarios',
          ),
        );
      }

      return ListView.builder(

        padding:
            const EdgeInsets.all(14),

        itemCount:
            listaUsuarios.length,

        itemBuilder: (
          context,
          index,
        ) {

          final usuario =
              listaUsuarios[index];

          return Card(

            shape:
                RoundedRectangleBorder(

              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),

            child: ListTile(

              onTap: () {

                Navigator.push(

                  context,

                  MaterialPageRoute(

                    builder: (_) =>

                        DetalleHistorialUsuarioScreen(

                      uid:
                          usuario['uid'],

                      usuario:
                          usuario['usuario'],
                    ),
                  ),
                );
              },

              leading: CircleAvatar(

                backgroundColor:

                    usuario['rol'] ==
                            'admin'

                        ? Colors.purple

                        : Colors.green,

                child: Icon(

                  usuario['rol'] ==
                          'admin'

                      ? Icons.admin_panel_settings

                      : Icons.person,

                  color:
                      Colors.white,
                ),
              ),

              title: Text(
                usuario['usuario'],
              ),

              subtitle: Text(

                '${usuario['correo']}\n'
                '${usuario['rol']}',
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

      case 'roles':
        return Colors.purple;

      default:
        return Colors.black54;
    }
  }
}