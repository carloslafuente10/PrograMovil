import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DetalleRecetaScreen extends StatelessWidget {

  final String nombreReceta;

  const DetalleRecetaScreen({
    super.key,
    required this.nombreReceta,
  });

  static const Color _verde = Color(0xFF2D9E73);

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F5),

      appBar: AppBar(

        backgroundColor: Colors.white,

        foregroundColor: const Color(0xFF1A1A1A),

        elevation: 0,

        title: Text(

          nombreReceta,

          style: const TextStyle(

            fontSize: 16,

            fontWeight: FontWeight.w600,

          ),

        ),

      ),

      body: FutureBuilder<QuerySnapshot>(

        future: FirebaseFirestore.instance

            .collection("app-recetas-completas")

            .get(),

        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {

            return const Center(

              child: CircularProgressIndicator(

                color: _verde,

              ),

            );

          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {

            return const Center(

              child: Text(

                "No hay recetas en Firebase",

              ),

            );

          }

          Map<String, dynamic>? receta;

          for (var doc in snapshot.data!.docs) {

            final data = doc.data() as Map<String, dynamic>;

            if ((data["nombre"] ?? "").toString().trim() ==
                nombreReceta.trim()) {

              receta = data;

              break;

            }

          }

          if (receta == null) {

            return const Center(

              child: Text(

                "Receta no encontrada",

              ),

            );

          }

          final String imagenPrincipal = receta["imagen"] ?? "";

          final String nombre = receta["nombre"] ?? nombreReceta;

          final String calorias =
              receta["calorías"]?.toString() ??
              receta["calorias"]?.toString() ??
              "—";

          final String tiempo =
              receta["tiempo"]?.toString() ??
              "—";

          final String categoria =
              receta["categoría"]?.toString() ??
              receta["categoria"]?.toString() ??
              "";

          final String rating =
              receta["rating"]?.toString() ??
              "";

          final List<String> ingredientes =
              List<String>.from(receta["nomIngredientes"] ?? []);

          final List<String> cantidades =
              List<String>.from(receta["cantIngredientes"] ?? []);

          final List<String> imagenes =
              List<String>.from(receta["imgIngredientes"] ?? []);

          return ListView(

            padding: EdgeInsets.zero,

            children: [

              if (imagenPrincipal.isNotEmpty)

                SizedBox(

                  height: 240,

                  width: double.infinity,

                  child: Image.network(

                    imagenPrincipal,

                    fit: BoxFit.cover,

                    errorBuilder: (_, __, ___) => Container(

                      height: 240,

                      color: const Color(0xFFE8E8E8),

                      child: const Icon(

                        Icons.restaurant,

                        size: 60,

                        color: Colors.white54,

                      ),

                    ),

                  ),

                ),

              Container(

                color: Colors.white,

                padding: const EdgeInsets.all(20),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Text(

                      nombre,

                      style: const TextStyle(

                        fontSize: 22,

                        fontWeight: FontWeight.bold,

                        color: Color(0xFF1A1A1A),

                      ),

                    ),

                    const SizedBox(height: 12),

                    Wrap(

                      spacing: 12,

                      runSpacing: 8,

                      children: [

                        _InfoChip(

                          icon: Icons.local_fire_department,

                          iconColor: Colors.orange,

                          label: '$calorias Cal',

                        ),

                        _InfoChip(

                          icon: Icons.access_time,

                          iconColor: _verde,

                          label: '$tiempo min',

                        ),

                        if (categoria.isNotEmpty)

                          _InfoChip(

                            icon: Icons.category_outlined,

                            iconColor: Colors.blueGrey,

                            label: categoria,

                          ),

                        if (rating.isNotEmpty)

                          _InfoChip(

                            icon: Icons.star_rounded,

                            iconColor: Colors.amber,

                            label: rating,

                          ),

                      ],

                    ),

                  ],

                ),

              ),

              const SizedBox(height: 8),

              Container(

                color: Colors.white,

                padding: const EdgeInsets.all(20),

                child: Column(

                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [

                    Row(

                      children: [

                        const Icon(

                          Icons.restaurant_menu,

                          color: _verde,

                          size: 20,

                        ),

                        const SizedBox(width: 8),

                        Text(

                          'Ingredientes (${ingredientes.length})',

                          style: const TextStyle(

                            fontSize: 17,

                            fontWeight: FontWeight.bold,

                            color: Color(0xFF1A1A1A),

                          ),

                        ),

                      ],

                    ),

                    const SizedBox(height: 16),

                    if (ingredientes.isEmpty)

                      Text(

                        'No hay ingredientes disponibles',

                        style: TextStyle(

                          color: Colors.grey[500],

                        ),

                      )

                    else

                      ListView.separated(

                        shrinkWrap: true,

                        physics: const NeverScrollableScrollPhysics(),

                        itemCount: ingredientes.length,

                        separatorBuilder: (_, __) => Divider(

                          height: 1,

                          color: Colors.grey[100],

                        ),

                        itemBuilder: (context, i) {

                          final imgUrl =
                              (imagenes.length > i)
                                  ? imagenes[i].trim()
                                  : '';

                          final cantidad =
                              (cantidades.length > i)
                                  ? cantidades[i]
                                  : '';

                          return Padding(

                            padding: const EdgeInsets.symmetric(

                              vertical: 10,

                            ),

                            child: Row(

                              children: [

                                ClipRRect(

                                  borderRadius:

                                      BorderRadius.circular(8),

                                  child: imgUrl.isNotEmpty

                                      ? Image.network(

                                          imgUrl,

                                          width: 50,

                                          height: 50,

                                          fit: BoxFit.cover,

                                          errorBuilder: (_, __, ___) =>
                                              _IngredienteIconPlaceholder(),

                                        )

                                      : _IngredienteIconPlaceholder(),

                                ),

                                const SizedBox(width: 14),

                                Expanded(

                                  child: Text(

                                    ingredientes[i],

                                    style: const TextStyle(

                                      fontSize: 13,

                                      color: Color(0xFF1A1A1A),

                                      fontWeight: FontWeight.w500,

                                    ),

                                  ),

                                ),

                                if (cantidad.isNotEmpty)

                                  Container(

                                    padding:

                                        const EdgeInsets.symmetric(

                                      horizontal: 10,

                                      vertical: 4,

                                    ),

                                    decoration: BoxDecoration(

                                      color:

                                          _verde.withOpacity(0.1),

                                      borderRadius:

                                          BorderRadius.circular(8),

                                    ),

                                    child: Text(

                                      cantidad,

                                      style:

                                          const TextStyle(

                                        fontSize: 12,

                                        color: _verde,

                                        fontWeight:

                                            FontWeight.w600,

                                      ),

                                    ),

                                  ),

                              ],

                            ),

                          );

                        },

                      ),

                  ],

                ),

              ),

              const SizedBox(height: 24),

            ],

          );

        },

      ),

    );

  }

}

class _InfoChip extends StatelessWidget {

  final IconData icon;

  final Color iconColor;

  final String label;

  const _InfoChip({

    required this.icon,

    required this.iconColor,

    required this.label,

  });

  @override
  Widget build(BuildContext context) {

    return Container(

      padding: const EdgeInsets.symmetric(

        horizontal: 12,

        vertical: 6,

      ),

      decoration: BoxDecoration(

        color: iconColor.withOpacity(0.08),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(

          color: iconColor.withOpacity(0.2),

        ),

      ),

      child: Row(

        mainAxisSize: MainAxisSize.min,

        children: [

          Icon(

            icon,

            size: 14,

            color: iconColor,

          ),

          const SizedBox(width: 5),

          Text(

            label,

            style: TextStyle(

              fontSize: 12,

              fontWeight: FontWeight.w600,

              color: iconColor,

            ),

          ),

        ],

      ),

    );

  }

}

class _IngredienteIconPlaceholder extends StatelessWidget {

  @override
  Widget build(BuildContext context) {

    return Container(

      width: 50,

      height: 50,

      decoration: BoxDecoration(

        color: const Color(0xFFE8E8E8),

        borderRadius: BorderRadius.circular(8),

      ),

      child: const Icon(

        Icons.restaurant,

        size: 24,

        color: Colors.white70,

      ),

    );

  }

}