import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../servicios/pdf_servicios.dart';

class ReportesScreen extends StatelessWidget {
  const ReportesScreen({super.key});

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

         //los usuarios /users/admins

           Row(
  mainAxisAlignment:
      MainAxisAlignment.spaceBetween,

  children: [

    _titulo('Usuarios registrados'),

    ElevatedButton.icon(
      onPressed: () {
        PdfService.generarReporteUsuarios();
      },

      icon: const Icon(Icons.picture_as_pdf),

      label: const Text(
        'PDF',
      ),
    ),
  ],
),

            const SizedBox(height: 12),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('app-usuarios')
                  .snapshots(),

              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final usuarios = snapshot.data!.docs;

                return Column(
                  children: usuarios.map((doc) {

                    final data =
                        doc.data() as Map<String, dynamic>;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),

                      padding: const EdgeInsets.all(14),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),

                      child: Row(
                        children: [

                          CircleAvatar(
                            backgroundColor:
                                verde.withValues(alpha: 0.1),

                            child: Icon(
                              Icons.person,
                              color: verde,
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,

                              children: [

                                Text(
                                  data['nombre'] ?? 'Sin nombre',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  data['correo'] ??
                                      data['email'] ??
                                      'Sin correo',
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  'Rol: ${data['rol'] ?? 'user'}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );

                  }).toList(),
                );
              },
            ),

            const SizedBox(height: 30),

      //las recetas

            _titulo('Recetas registradas'),

            const SizedBox(height: 12),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('app-recetas-completas')
                  .snapshots(),

              builder: (context, snapshot) {

                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final recetas = snapshot.data!.docs;

                return Column(
                  children: recetas.map((doc) {

                    final data =
                        doc.data() as Map<String, dynamic>;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),

                      padding: const EdgeInsets.all(14),

                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),

                      child: Row(
                        children: [

                          ClipRRect(
                            borderRadius:
                                BorderRadius.circular(12),

                            child: Image.network(
                              data['imagen'] ?? '',
                              width: 60,
                              height: 60,
                              fit: BoxFit.cover,

                              errorBuilder:
                                  (_, __, ___) =>
                                      Container(
                                width: 60,
                                height: 60,
                                color: Colors.grey[200],
                                child: const Icon(Icons.image),
                              ),
                            ),
                          ),

                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,

                              children: [

                                Text(
                                  data['nombre'] ??
                                      'Sin nombre',
                                  style: const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),

                                const SizedBox(height: 6),

                                Text(
                                  'Categoría: ${data['categoria'] ?? 'Sin categoría'}',
                                ),

                                const SizedBox(height: 4),

                                Text(
                                  '${data['calorias'] ?? 0} calorías',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );

                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 30),

//las categorías

_titulo('Categorías registradas'),

const SizedBox(height: 12),

StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('app-Categorías')
      .snapshots(),

  builder: (context, snapshot) {

    if (!snapshot.hasData) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final categorias = snapshot.data!.docs;

    return Column(
      children: categorias.map((doc) {

        final data =
            doc.data() as Map<String, dynamic>;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),

          padding: const EdgeInsets.all(14),

          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),

          child: Row(
            children: [

              CircleAvatar(
                backgroundColor:
                    Colors.purple.withValues(alpha: 0.1),

                child: const Icon(
                  Icons.category,
                  color: Colors.purple,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  data['nombre'] ??
                      'Sin nombre',

                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
        );

      }).toList(),
    );
  },
),
const SizedBox(height: 30),

// =========================
// FAVORITOS POR USUARIO
// =========================

_titulo('Favoritos por usuario'),

const SizedBox(height: 12),

StreamBuilder<QuerySnapshot>(
  stream: FirebaseFirestore.instance
      .collection('app-usuarios')
      .snapshots(),

  builder: (context, snapshot) {

    if (!snapshot.hasData) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    final usuarios = snapshot.data!.docs;

    return Column(
      children: usuarios.map((userDoc) {

        final userData =
            userDoc.data() as Map<String, dynamic>;

        final uid = userDoc.id;

        return FutureBuilder<QuerySnapshot>(
          future: FirebaseFirestore.instance
              .collection('app-usuarios')
              .doc(uid)
              .collection('favoritos')
              .get(),

          builder: (context, favSnapshot) {

            if (!favSnapshot.hasData) {
              return const SizedBox();
            }

            final favoritos =
                favSnapshot.data!.docs;

            return Container(
              margin: const EdgeInsets.only(
                bottom: 14,
              ),

              padding: const EdgeInsets.all(16),

              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.circular(18),
              ),

              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,

                children: [

                  Row(
                    children: [

                      CircleAvatar(
                        backgroundColor:
                            Colors.red.withValues(
                          alpha: 0.1,
                        ),

                        child: const Icon(
                          Icons.favorite,
                          color: Colors.red,
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,

                          children: [

                            Text(
                              userData['nombre'] ??
                                  'Sin nombre',

                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),

                            Text(
                              userData['correo'] ??
                                  userData['email'] ??
                                  '',
                              style: TextStyle(
                                color:
                                    Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),

                        decoration: BoxDecoration(
                          color:
                              Colors.red.withValues(
                            alpha: 0.1,
                          ),

                          borderRadius:
                              BorderRadius.circular(
                            20,
                          ),
                        ),

                        child: Text(
                          '${favoritos.length} favoritos',
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  if (favoritos.isEmpty)
                    Text(
                      'No tiene favoritos',
                      style: TextStyle(
                        color: Colors.grey[500],
                      ),
                    ),

                  ...favoritos.map((favDoc) {

                    final fav =
                        favDoc.data()
                            as Map<String, dynamic>;

                    return Container(
                      margin: const EdgeInsets.only(
                        bottom: 8,
                      ),

                      padding:
                          const EdgeInsets.all(10),

                      decoration: BoxDecoration(
                        color: const Color(
                          0xFFF8F8F8,
                        ),

                        borderRadius:
                            BorderRadius.circular(
                          12,
                        ),
                      ),

                      child: Row(
                        children: [

                          const Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 18,
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: Text(
                              fav['nombre'] ??
                                  'Sin nombre',
                            ),
                          ),
                        ],
                      ),
                    );

                  }),
                ],
              ),
            );
          },
        );

      }).toList(),
    );
  },
),
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