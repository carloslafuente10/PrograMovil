import 'package:flutter/material.dart';
import 'detalle_receta_screen.dart';

class HomeScreen extends StatelessWidget {

  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {

    final recetas = [

      {
        "nombre": "Arepas rellenas",
        "img": "assets/images/platos/Arepas rellenas.jpg"
      },

      {
        "nombre": "Ceviche Peruano",
        "img": "assets/images/platos/Ceviche peruano.webp"
      },

      {
        "nombre": "Ensalada César",
        "img": "assets/images/platos/Ensalada César.jpg"
      },

      {
        "nombre": "Majadito",
        "img": "assets/images/platos/Majadito.jpg"
      },

      {
        "nombre": "Pique macho",
        "img": "assets/images/platos/Pique macho.jpg"
      },

      {
        "nombre": "Quesadillas",
        "img": "assets/images/platos/Quesadillas.webp"
      },

      {
        "nombre": "Salteña",
        "img": "assets/images/platos/Salteña.jpg"
      },

      {
        "nombre": "Silpancho",
        "img": "assets/images/platos/Silpancho.jpg"
      },

      {
        "nombre": "Sopa de maní",
        "img": "assets/images/platos/Sopa de mani.jpg"
      },

      {
        "nombre": "Tacos al pastor",
        "img": "assets/images/platos/Tacos al pastor.jpg"
      },

      {
        "nombre": "Trancapecho",
        "img": "assets/images/platos/Trancapecho.jpg"
      },

      {
        "nombre": "Anticucho",
        "img": "assets/images/platos/Anticucho.webp"
      },

    ];

    return Scaffold(

      appBar: AppBar(
        title: const Text("Home Recetas"),
      ),

      body: ListView(

        padding: const EdgeInsets.all(20),

        children: [

          const Text(
            "Home Recetas",
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 20),

          ...recetas.map(

            (r) => GestureDetector(

              onTap: () {

                Navigator.push(

                  context,

                  MaterialPageRoute(

                    builder: (context) => DetalleRecetaScreen(

                      nombreReceta: r["nombre"]!,

                    ),

                  ),

                );

              },

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Image.asset(
                    r["img"]!,
                    width: 300,
                  ),

                  const SizedBox(height: 5),

                  Text(
                    r["nombre"]!,
                    style: const TextStyle(fontSize: 18),
                  ),

                  const SizedBox(height: 20),

                ],

              ),

            ),

          ).toList(),

        ],

      ),

    );

  }

}