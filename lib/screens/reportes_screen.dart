import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../servicios/pdf_servicios.dart';

class ReportesScreen extends StatefulWidget {
  const ReportesScreen({super.key});

  @override
  State<ReportesScreen> createState() =>
      _ReportesScreenState();
}

class _ReportesScreenState
    extends State<ReportesScreen> {
  
  String seccion = 'usuarios';

    String buscarUsuario = '';
    final buscarCtrl =
          TextEditingController();
   

  String formatoUsuarios =
      'PDF';
      String buscarFavorito = '';

final buscarFavoritoCtrl =
    TextEditingController();

String formatoFavoritos =
    'PDF';
String buscarReceta = '';

final buscarRecetaCtrl =
    TextEditingController();

String formatoRecetas =
    'PDF';

String categoriaSeleccionada =
    'Todas';
List<String> categorias =
    ['Todas'];

@override
void initState() {
  

  super.initState();

  cargarCategorias();
}
Future<void>
    cargarCategorias() async {

  final snapshot =
      await FirebaseFirestore
          .instance
          .collection(
            'app-Categorías',
          )
          .get();

  final nombres =
    snapshot.docs.map((doc) {

  final data =
      doc.data();

  return data['nombre']
          ?.toString() ??
      '';

}).where((nombre) {

 return nombre
    .toLowerCase() !=
        'todas';

}).toList();

  setState(() {

    categorias = [
      'Todas',
      ...nombres,
    ];
  });
}



  @override
  Widget build(BuildContext context) {
    final Color verde = const Color(0xFF2FA36B);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),

      appBar: AppBar(
        backgroundColor: verde,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Reportes',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [

            //resumen de todo

            Row(
              children: [

                Expanded(
                  child: _cardResumen(
                    titulo: 'Usuarios',
                    icono: Icons.people,
                    stream: FirebaseFirestore.instance
                        .collection('app-usuarios')
                        .snapshots(),
                    color: Colors.blue,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _cardResumen(
                    titulo: 'Recetas',
                    icono: Icons.restaurant_menu,
                    stream: FirebaseFirestore.instance
                        .collection('app-recetas-completas')
                        .snapshots(),
                    color: Colors.orange,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              children: [

                Expanded(
                  child: _cardResumen(
                    titulo: 'Categorías',
                    icono: Icons.category,
                    stream: FirebaseFirestore.instance
                        .collection('app-Categorías')
                        .snapshots(),
                    color: Colors.purple,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: _cardResumen(
                    titulo: 'Favoritos',
                    icono: Icons.favorite,
                    stream: FirebaseFirestore.instance
                        .collection('app-usuarios')
                        .snapshots(),
                    color: Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
                        Row(
              children: [

                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        seccion = 'usuarios';
                      });
                    },

                    child: const Text(
                      'Usuarios',
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        seccion = 'favoritos';
                      });
                    },

                    child: const Text(
                      'Favoritos',
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        seccion = 'recetas';
                      });
                    },

                    child: const Text(
                      'Recetas',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),
/*
            ElevatedButton.icon(
              onPressed: () {
                PdfService.generarReporteGeneral();
              },

              icon: const Icon(Icons.picture_as_pdf),

              label: const Text(
                'PDF GENERAL',
              ),
            ),

            const SizedBox(height: 24),
*/
         //los usuarios /users/admins
if (seccion == 'usuarios') ...[

  Row(
    children: [

      Expanded(
        child: TextField(
          controller: buscarCtrl,
          decoration: InputDecoration(
            hintText:
                'Buscar usuario',
            prefixIcon:
                const Icon(Icons.search),
                suffixIcon:
    buscarUsuario.isNotEmpty

        ? IconButton(
            icon: const Icon(
              Icons.close,
            ),

            onPressed: () {

              setState(() {

                buscarUsuario = '';
                buscarCtrl.clear();
              });
            },
          )

        : null,
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
              buscarUsuario = value
                  .toLowerCase();
            });
          },
        ),
      ),

      const SizedBox(width: 10),

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

        child: DropdownButton<String>(
          value: formatoUsuarios,

          underline:
              const SizedBox(),

          items: const [

            DropdownMenuItem(
              value: 'PDF',
              child: Text('PDF'),
            ),

            DropdownMenuItem(
              value: 'Excel',
              child: Text('Excel'),
            ),

            DropdownMenuItem(
              value: 'CSV',
              child: Text('CSV'),
            ),
          ],

          onChanged: (value) {
            setState(() {
              formatoUsuarios =
                  value!;
            });
          },
        ),
      ),
      const SizedBox(width: 10),

ElevatedButton(
  onPressed: () async {

    if (formatoUsuarios ==
        'PDF') {

      await PdfService
          .generarReporteUsuarios();
    }

    else if (
        formatoUsuarios ==
            'Excel') {

      await PdfService
          .generarExcelUsuarios();
    }

    else if (
        formatoUsuarios ==
            'CSV') {

      await PdfService
          .generarCsvUsuarios();
    }
  },

  child: const Text(
    'Reporte',
  ),
),

      
    ],
  ),

  const SizedBox(height: 20),

  _titulo('Usuarios'),

  const SizedBox(height: 12),

  StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore.instance
        .collection('app-usuarios')
        .snapshots(),

    builder: (context, snapshot) {

      if (!snapshot.hasData) {
        return const Center(
          child:
              CircularProgressIndicator(),
        );
      }

      final usuarios =
          snapshot.data!.docs.where(
        (doc) {

          final data = doc.data()
              as Map<String, dynamic>;

          final nombre =
              (data['nombre'] ?? '')
                  .toString()
                  .toLowerCase();

          return nombre.contains(
            buscarUsuario,
          );
        },
      ).toList();

      return Column(
        children:
            usuarios.map((doc) {

          final data =
              doc.data()
                  as Map<String, dynamic>;

          return GestureDetector(
            onTap: () {

              showDialog(
                context: context,

                builder: (_) =>
                    AlertDialog(

                  title: Text(
                    data['nombre'] ??
                        '',
                  ),

                  content: Column(
                    mainAxisSize:
                        MainAxisSize.min,

                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [

                      Text(
                        'Correo: ${data['correo'] ?? data['email'] ?? ''}',
                      ),

                      const SizedBox(
                          height: 8),

                      Text(
                        'Rol: ${data['rol'] ?? 'user'}',
                      ),

                      const SizedBox(
                          height: 8),

                      Text(
                        'Estado: Activo',
                      ),
                      const SizedBox(height: 8),

Text(
  'Fecha registro: '
  '${data['creadoEn'] != null ? data['creadoEn'].toDate().toString() : 'Sin registro'}',
),

const SizedBox(height: 8),

Text(
  'Último acceso: '
  '${data['ultimoAcceso'] != null ? data['ultimoAcceso'].toDate().toString() : 'Sin acceso'}',
),

                      const SizedBox(
                          height: 8),

                      ElevatedButton.icon(
                        onPressed: () {
                          PdfService
    .generarReporteUsuario(
      data,
    );
                        },

                        icon: const Icon(
                          Icons.picture_as_pdf,
                        ),

                        label: const Text(
                          'PDF usuario',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },

            child: Container(
              margin:
                  const EdgeInsets.only(
                bottom: 10,
              ),

              padding:
                  const EdgeInsets.all(
                14,
              ),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  16,
                ),
              ),

              child: Row(
                children: [

                  CircleAvatar(
                    backgroundColor:
                        verde.withValues(
                      alpha: 0.1,
                    ),

                    child: Icon(
                      Icons.person,
                      color: verde,
                    ),
                  ),

                  const SizedBox(
                      width: 12),

                  Expanded(
                    child: Text(
                      data['nombre'] ??
                          'Sin nombre',

                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),

                  const Icon(
                    Icons
                        .arrow_forward_ios,
                    size: 16,
                  ),
                ],
              ),
            ),
          );

        }).toList(),
      );
    },
  ),

  const SizedBox(height: 30),
],
      //las recetas
if (seccion == 'recetas') ...[
Row(
  children: [

    Expanded(
      child: TextField(

        controller:
            buscarRecetaCtrl,

        decoration: InputDecoration(

          hintText:
              'Buscar receta',

          prefixIcon:
              const Icon(
            Icons.search,
          ),

          suffixIcon:
              buscarReceta
                      .isNotEmpty

                  ? IconButton(
                      icon:
                          const Icon(
                        Icons.close,
                      ),

                      onPressed: () {

                        setState(() {

                          buscarReceta =
                              '';

                          buscarRecetaCtrl
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
                BorderRadius
                    .circular(
              14,
            ),

            borderSide:
                BorderSide.none,
          ),
        ),

        onChanged: (value) {

          setState(() {

            buscarReceta =
                value
                    .toLowerCase();
          });
        },
      ),
    ),

    const SizedBox(width: 10),

    Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 12,
      ),

      decoration: BoxDecoration(
        color: Colors.white,


        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),

      child:
          DropdownButton<String>(

        value:
            formatoRecetas,

        underline:
            const SizedBox(),

        items: const [

          DropdownMenuItem(
            value: 'PDF',
            child: Text('PDF'),
          ),

          DropdownMenuItem(
            value: 'Excel',
            child: Text('Excel'),
          ),

          DropdownMenuItem(
            value: 'CSV',
            child: Text('CSV'),
          ),
        ],

        onChanged: (value) {

          setState(() {

            formatoRecetas =
                value!;
          });
        },
      ),
    ),

    const SizedBox(width: 10),

    ElevatedButton(

      onPressed: () async {

        if (formatoRecetas ==
            'PDF') {

          await PdfService
              .generarReporteRecetas();
        }

        else if (
            formatoRecetas ==
                'Excel') {

          await PdfService
    .generarExcelRecetas();
        }

        else if (
            formatoRecetas ==
                'CSV') {

          await PdfService
    .generarCsvRecetas();
        }
      },

      child: const Text(
        'Reporte',
      ),
    ),
  ],
),
  
  const SizedBox(height: 14),

  Container(

    padding:
        const EdgeInsets.symmetric(
      horizontal: 12,
    ),

    decoration: BoxDecoration(
      color: Colors.white,

      borderRadius:
          BorderRadius.circular(
        14,
      ),
    ),

    child: DropdownButton<String>(

      value:
          categoriaSeleccionada,

      isExpanded: true,

      underline:
          const SizedBox(),

      items: categorias.map((categoria) {

  return DropdownMenuItem(

    value: categoria,

    child: Text(categoria),
  );

}).toList(),

      onChanged: (value) {

        setState(() {

          categoriaSeleccionada =
              value!;
        });
      },
    ),
  ),

  const SizedBox(height: 14),


  const SizedBox(height: 20),

  _titulo('Recetas'),

  const SizedBox(height: 12),

  StreamBuilder<QuerySnapshot>(

    stream:
        FirebaseFirestore.instance
            .collection(
              'app-recetas-completas',
            )
            .snapshots(),

    builder: (context, snapshot) {

      if (!snapshot.hasData) {

        return const Center(
          child:
              CircularProgressIndicator(),
        );
      }

      final recetas =
          snapshot.data!.docs.where(
        (doc) {

          final data =
              doc.data()
                  as Map<String,
                      dynamic>;

          final nombre =
              (data['nombre'] ??
                      '')
                  .toString()
                  .toLowerCase();

           final categoria =
    (data['categoria'] ??
            '')
        .toString()
        .toLowerCase();

          final coincideBusqueda =
              nombre.contains(
            buscarReceta,
          );

          final coincideCategoria =
              categoriaSeleccionada ==
                      'Todas'
                  ? true
                  : categoria ==
    categoriaSeleccionada
        .toLowerCase();

          return coincideBusqueda &&
              coincideCategoria;
        },
      ).toList();

      return Column(

        children:
            recetas.map((doc) {

          final data =
              doc.data()
                  as Map<String,
                      dynamic>;

          return GestureDetector(

            onTap: () {

              showDialog(
                context: context,

                builder: (_) =>
                    AlertDialog(

                  title: Text(
                    data['nombre'] ??
                        '',
                  ),

                  content: Column(
                    mainAxisSize:
                        MainAxisSize.min,

                    children: [

                      Image.network(
                        data['imagen'] ??
                            '',

                        height: 120,

                        errorBuilder:
                            (_, __, ___) =>
                                const Icon(
                          Icons.image,
                          size: 80,
                        ),
                      ),

                      const SizedBox(
                        height: 12,
                      ),

                      Text(
                        'Categoría: ${data['categoria'] ?? ''}',
                      ),

                      const SizedBox(
                        height: 8,
                      ),

                      Text(
                        '${data['calorias'] ?? 0} calorías',
                      ),
                    ],
                  ),
                ),
              );
            },

            child: Container(

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
                  

                  ClipRRect(

                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),

                    child: Image.network(

                      data['imagen'] ??
                          '',

                      width: 60,
                      height: 60,

                      fit: BoxFit.cover,

                      errorBuilder:
                          (_, __, ___) =>
                              Container(
                        width: 60,
                        height: 60,
                        color:
                            Colors.grey[200],

                        child:
                            const Icon(
                          Icons.image,
                        ),
                      ),
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
                              '',

                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 6,
                        ),

                        Text(
                          'Categoría: ${data['categoria'] ?? ''}',
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons
                        .arrow_forward_ios,
                    size: 16,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    },
  ),

  const SizedBox(height: 30),
],
//las categorías



// =========================
// FAVORITOS POR USUARIO
// =========================
if (seccion == 'favoritos') ...[

  Row(
    children: [

      Expanded(
        child: TextField(

          controller:
              buscarFavoritoCtrl,

          decoration: InputDecoration(

            hintText:
                'Buscar usuario',

            prefixIcon:
                const Icon(
              Icons.search,
            ),

             suffixIcon:
                  buscarFavorito.isNotEmpty

                    ? IconButton(
                        icon:
                            const Icon(
                          Icons.close,
                        ),

                        onPressed: () {

                          setState(() {

                            buscarFavorito =
                                '';

                            buscarFavoritoCtrl
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
                  BorderRadius
                      .circular(
                14,
              ),

              borderSide:
                  BorderSide.none,
            ),
          ),

          onChanged: (value) {

            setState(() {

              buscarFavorito =
                  value
                      .toLowerCase();
            });
          },
        ),
      ),

      const SizedBox(width: 10),

      Container(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 12,
        ),

        decoration: BoxDecoration(
          color: Colors.white,

          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),

        child:
            DropdownButton<String>(

          value:
              formatoFavoritos,

          underline:
              const SizedBox(),

          items: const [

            DropdownMenuItem(
              value: 'PDF',
              child: Text('PDF'),
            ),

            DropdownMenuItem(
              value: 'Excel',
              child: Text('Excel'),
            ),

            DropdownMenuItem(
              value: 'CSV',
              child: Text('CSV'),
            ),
          ],

          onChanged: (value) {

            setState(() {

              formatoFavoritos =
                  value!;
            });
          },
        ),
      ),

      const SizedBox(width: 10),

      ElevatedButton(
        onPressed: () async {

  if (formatoFavoritos ==
      'PDF') {

    await PdfService
        .generarReporteFavoritos();
  }

  else if (
      formatoFavoritos ==
          'Excel') {

    await PdfService
    .generarExcelFavoritos();
  }

  else if (
      formatoFavoritos ==
          'CSV') {

            await PdfService
    .generarCsvFavoritos();

    
  }
},
        

        child:
            const Text('Reporte'),
      ),
    ],
  ),

  const SizedBox(height: 20),

  _titulo(
    'Favoritos usuarios',
  ),

  const SizedBox(height: 12),

  StreamBuilder<QuerySnapshot>(
    stream: FirebaseFirestore
        .instance
        .collection(
          'app-usuarios',
        )
        .snapshots(),

    builder: (context, snapshot) {

      if (!snapshot.hasData) {

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
                  as Map<String,
                      dynamic>;

          final nombre =
              (data['nombre'] ??
                      '')
                  .toString()
                  .toLowerCase();

          return nombre.contains(
            buscarFavorito,
          );
        },
      ).toList();

      return Column(
        children:
            usuarios.map((userDoc) {

          final userData =
              userDoc.data()
                  as Map<String,
                      dynamic>;

          final uid =
              userDoc.id;

          return GestureDetector(

            onTap: () {

              showDialog(
                context: context,

                builder: (_) =>
                    AlertDialog(

                  title: Text(
                    userData[
                            'nombre'] ??
                        '',
                  ),

                  content:
                      FutureBuilder<
                          QuerySnapshot>(

                    future:
                        FirebaseFirestore
                            .instance
                            .collection(
                              'app-usuarios',
                            )
                            .doc(uid)
                            .collection(
                              'favoritos',
                            )
                            .get(),

                    builder:
                        (context,
                            favSnapshot) {

                      if (!favSnapshot
                          .hasData) {

                        return const CircularProgressIndicator();
                      }

                      final favoritos =
                          favSnapshot
                              .data!
                              .docs;

                      return SizedBox(
                        width: 300,

                        child: Column(
                          mainAxisSize:
                              MainAxisSize
                                  .min,

                          children: [

                            Text(
                              '${favoritos.length} favoritos',
                              
                            ),
                            const SizedBox(height: 14),

ElevatedButton.icon(

  onPressed: () {

    PdfService
        .generarReporteFavoritosUsuario(

      userData['nombre'] ?? '',
      
      userData['correo'] ??
          userData['email'] ??
          '',

      favoritos,
    );
  },

  icon: const Icon(
    Icons.picture_as_pdf,
  ),

  label: const Text(
    'PDF usuario',
  ),
),

                            const SizedBox(
                              height: 12,
                            ),

                            ...favoritos
                                .map(
                              (favDoc) {

                                final fav =
                                    favDoc.data()
                                        as Map<String,
                                            dynamic>;

                                return ListTile(

                                  leading:
                                      const Icon(
                                    Icons.favorite,
                                    color:
                                        Colors.red,
                                  ),

                                  title: Text(
                                    fav['nombre'] ??
                                        '',
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              );
            },

            child: Container(

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
                        Colors.red
                            .withValues(
                      alpha: 0.1,
                    ),

                    child:
                        const Icon(
                      Icons.favorite,
                      color:
                          Colors.red,
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Text(
                      userData[
                              'nombre'] ??
                          'Sin nombre',

                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),

                  const Icon(
                    Icons
                        .arrow_forward_ios,
                    size: 16,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    },
  ),

  const SizedBox(height: 30),
],
          ],
        ),
      ),
    );
  }
  //resumen de todo

  Widget _cardResumen({
    required String titulo,
    required IconData icono,
    required Stream<QuerySnapshot> stream,
    required Color color,
  }) {
    return StreamBuilder<QuerySnapshot>(
      stream: stream,

      builder: (context, snapshot) {

        final total =
            snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Container(
          padding: const EdgeInsets.all(18),

          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),

          child: Column(
            children: [

              Icon(
                icono,
                size: 30,
                color: color,
              ),

              const SizedBox(height: 10),

              Text(
                total.toString(),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                titulo,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  // titulo

  Widget _titulo(String texto) {
    return Align(
      alignment: Alignment.centerLeft,

      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}