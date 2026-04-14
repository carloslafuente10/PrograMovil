import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DetalleRecetaScreen extends StatelessWidget {

  final String nombreReceta;

  const DetalleRecetaScreen({
    super.key,
    required this.nombreReceta,
  });

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: Text(nombreReceta),
      ),

      body: FutureBuilder<QuerySnapshot>(

        future: FirebaseFirestore.instance
            .collection("app-recetas-completas")
            .get(),

        builder: (context, snapshot) {

          if (snapshot.connectionState == ConnectionState.waiting) {

            return const Center(
              child: CircularProgressIndicator(),
            );

          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {

            return const Center(
              child: Text("No hay recetas en Firebase"),
            );

          }

          final docs = snapshot.data!.docs;

          Map<String, dynamic>? receta;

          for (var doc in docs) {

            final data = doc.data() as Map<String, dynamic>;

            final nombreFirebase =
                (data["nombre"] ?? "").toString().trim();

            if (nombreFirebase == nombreReceta.trim()) {

              receta = data;

              break;

            }

          }

          if (receta == null) {

            return const Center(
              child: Text("Receta no encontrada"),
            );

          }

          final ingredientes =
              List<String>.from(receta["nomIngredientes"] ?? []);

          final cantidades =
              List<String>.from(receta["cantIngredientes"] ?? []);

          final imagenes =
              List<String>.from(receta["imgIngredientes"] ?? []);

          final calorias =
              receta["calorias"] ?? "";

          final tiempo =
              receta["tiempo"] ?? "";

          final imagenPrincipal =
              receta["imagen"] ?? "";

          return ListView(

            padding: const EdgeInsets.all(20),

            children: [

              if (imagenPrincipal != "")
                Image.network(imagenPrincipal),

              const SizedBox(height: 20),

              Text(
                receta["nombre"] ?? "",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text("Calorías: $calorias"),
              Text("Tiempo: $tiempo min"),

              const SizedBox(height: 20),

              const Text(
                "Ingredientes",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              ListView.builder(

                shrinkWrap: true,

                physics: const NeverScrollableScrollPhysics(),

                itemCount: ingredientes.length,

                itemBuilder: (context, i) {

                  return ListTile(

                    leading: imagenes.length > i
                        ? Image.network(
                            imagenes[i],
                            width: 40,
                          )
                        : const Icon(Icons.restaurant),

                    title: Text(ingredientes[i]),

                    subtitle: Text(
                      cantidades.length > i
                          ? cantidades[i]
                          : "",
                    ),

                  );

                },

              ),

            ],

          );

        },

      ),

    );

  }

}