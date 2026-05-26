import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import '../servicios/historial_servicio.dart';

class GestionarUsuariosScreen
    extends StatefulWidget {

  const GestionarUsuariosScreen({
    super.key,
  });

  @override
  State<GestionarUsuariosScreen>
      createState() =>
          _GestionarUsuariosScreenState();
}

class _GestionarUsuariosScreenState
    extends State<
        GestionarUsuariosScreen> {

  String buscarUsuario = '';

  final buscarCtrl =
      TextEditingController();

  String filtroRol =
      'Todos';

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor:
          const Color(
        0xFFF8F8F8,
      ),

      appBar: AppBar(

        backgroundColor:
            const Color(
          0xFF2D9E73,
        ),

        foregroundColor:
            Colors.white,

        title: const Text(
          'Gestionar usuarios',
        ),
      ),

      body: Padding(

        padding:
            const EdgeInsets.all(
          16,
        ),

        child: Column(
          children: [

            // BUSCADOR + FILTRO

            Row(
              children: [

                Expanded(
                  child: TextField(

                    controller:
                        buscarCtrl,

                    decoration:
                        InputDecoration(

                      hintText:
                          'Buscar usuario',

                      prefixIcon:
                          const Icon(
                        Icons.search,
                      ),

                      suffixIcon:
                          buscarUsuario
                                  .isNotEmpty

                              ? IconButton(

                                  icon:
                                      const Icon(
                                    Icons.close,
                                  ),

                                  onPressed:
                                      () {

                                    setState(() {

                                      buscarUsuario =
                                          '';

                                      buscarCtrl
                                          .clear();
                                    });
                                  },
                                )

                              : null,

                      filled: true,

                      fillColor:
                          Colors.white,

                      border:
                          OutlineInputBorder(

                        borderRadius:
                            BorderRadius.circular(
                          14,
                        ),

                        borderSide:
                            BorderSide.none,
                      ),
                    ),

                    onChanged:
                        (value) {

                      setState(() {

                        buscarUsuario =
                            value
                                .toLowerCase();
                      });
                    },
                  ),
                ),

                const SizedBox(
                  width: 10,
                ),

                Container(

                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 12,
                  ),

                  decoration:
                      BoxDecoration(

                    color:
                        Colors.white,

                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),

                  child:
                      DropdownButton<
                          String>(

                    value:
                        filtroRol,

                    underline:
                        const SizedBox(),

                    items: const [

                      DropdownMenuItem(
                        value: 'Todos',
                        child: Text(
                          'Todos',
                        ),
                      ),

                      DropdownMenuItem(
                        value: 'user',
                        child: Text(
                          'Usuarios',
                        ),
                      ),

                      DropdownMenuItem(
                        value: 'admin',
                        child: Text(
                          'Admins',
                        ),
                      ),
                    ],

                    onChanged:
                        (value) {

                      setState(() {

                        filtroRol =
                            value!;
                      });
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 20,
            ),

            // LISTA USUARIOS

            Expanded(

              child:
                  StreamBuilder<
                      QuerySnapshot>(

                stream:
                    FirebaseFirestore
                        .instance
                        .collection(
                          'app-usuarios',
                        )
                        .snapshots(),

                builder:
                    (context,
                        snapshot) {

                  if (!snapshot
                      .hasData) {

                    return const Center(
                      child:
                          CircularProgressIndicator(),
                    );
                  }

                  final usuarios =
                      snapshot.data!.docs.where(
                    (doc) {

                      final data =
                          doc.data()
                              as Map<
                                  String,
                                  dynamic>;

                      final nombre =
                          (data['nombre'] ??
                                  '')
                              .toString()
                              .toLowerCase();

                      final rol =
                          data['rol'] ??
                              'user';

                      final coincideBusqueda =
                          nombre.contains(
                        buscarUsuario,
                      );

                      final coincideRol =
                          filtroRol ==
                                  'Todos'
                              ? true
                              : rol ==
                                  filtroRol;

                      return coincideBusqueda &&
                          coincideRol;
                    },
                  ).toList();

                  return ListView.builder(

                    itemCount:
                        usuarios.length,

                    itemBuilder:
                        (context,
                            index) {

                      final usuario =
                          usuarios[index];

                      final data =
                          usuario.data()
                              as Map<
                                  String,
                                  dynamic>;

                      final rol =
                          data['rol'] ??
                              'user';

                      final esAdmin =
                          rol ==
                              'admin';

                      return Container(

                        margin:
                            const EdgeInsets.only(
                          bottom: 10,
                        ),

                        padding:
                            const EdgeInsets.all(
                          14,
                        ),

                        decoration:
                            BoxDecoration(

                          color:
                              Colors.white,

                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                        ),

                        child: Row(
                          children: [

                            CircleAvatar(

                              backgroundColor:
                                  esAdmin

                                      ? Colors.orange
                                          .withValues(
                                        alpha:
                                            0.1,
                                      )

                                      : Colors.blue
                                          .withValues(
                                        alpha:
                                            0.1,
                                      ),

                              child: Icon(

                                esAdmin

                                    ? Icons.admin_panel_settings

                                    : Icons.person,

                                color:
                                    esAdmin

                                        ? Colors.orange

                                        : Colors.blue,
                              ),
                            ),

                            const SizedBox(
                              width: 12,
                            ),

                            Expanded(

                              child: Column(

                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,

                                children: [

                                  Text(

                                    data['nombre'] ??
                                        'Sin nombre',

                                    style:
                                        const TextStyle(
                                      fontWeight:
                                          FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(
                                    height: 4,
                                  ),

                                  Text(
                                    data['correo'] ??
                                        '',
                                  ),

                                  const SizedBox(
                                    height: 4,
                                  ),

                                  Text(
                                    esAdmin

                                        ? 'Administrador'

                                        : 'Usuario',
                                  ),
                                ],
                              ),
                            ),

                            ElevatedButton(

                              onPressed:
                                  () async {

                                final nuevoRol =
                                    esAdmin

                                        ? 'user'

                                        : 'admin';

                                await FirebaseFirestore
    .instance
    .collection(
      'app-usuarios',
    )
    .doc(
      usuario.id,
    )
    .update({

  'rol':
      nuevoRol,
});
await HistorialService
    .registrar(

  accion:
      esAdmin

          ? 'Quitó permisos admin a ${data['nombre']}'

          : 'Convirtió en admin a ${data['nombre']}',

  tipo:
      'roles',
);

// usuario actual

final actualUser =
    FirebaseAuth
        .instance
        .currentUser;

// si se quitó admin
// a sí mismo

if (actualUser != null &&
    actualUser.uid ==
        usuario.id &&
    nuevoRol ==
        'user') {

  await FirebaseAuth
      .instance
      .signOut();

  if (!mounted) return;

  Navigator.pushAndRemoveUntil(

    context,

    MaterialPageRoute(

      builder: (_) =>
          const LoginPage(),
    ),

    (route) => false,
  );
}
                              },

                              child: Text(

                                esAdmin

                                    ? 'Quitar admin'

                                    : 'Hacer admin',
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}