import 'package:flutter/material.dart';

import '../servicios/api_servicio.dart';

import 'home_screen.dart';



class AppMainScreen extends StatefulWidget {
  const AppMainScreen({super.key});

  @override
  State<AppMainScreen> createState() => _AppMainScreenState();
}

class _AppMainScreenState extends State<AppMainScreen> {
  int selectedIndex = 0;

  late final List<Widget> page;

  @override
  void initState() {
    page = [

      // 🔥 HOME (recetas desde backend)
      FutureBuilder(
        future: ApiService.getRecetas(),
        builder: (context, snapshot) {
          // ⏳ cargando
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // ❌ error
          if (snapshot.hasError) {
            return const Center(child: Text("Error al cargar datos"));
          }

          final recetas = snapshot.data as List;

          // 📭 vacío
          if (recetas.isEmpty) {
            return const Center(child: Text("No hay recetas"));
          }

          // 📋 lista
          return ListView.builder(
            itemCount: recetas.length,
            itemBuilder: (context, index) {
              final receta = recetas[index];

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      receta['imagen'] ?? '',
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image_not_supported);
                      },
                    ),
                  ),
                  title: Text(
                    receta['nombre'] ?? 'Sin nombre',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "🔥 ${receta['calorias']} cal • ⏱ ${receta['tiempo']} min",
                  ),
                ),
              );
            },
          );
        },
      ),

      // 🔥 otras pantallas

      HomeScreen(),

      const Center(child: Text("Favoritos")),
      const Center(child: Text("Plan")),
      const Center(child: Text("Configuración")),
    ];

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: const Text("Recetas 🍲"),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        elevation: 10,
        type: BottomNavigationBarType.fixed,
        onTap: (value) {
          setState(() {
            selectedIndex = value;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.favorite), label: "Fav"),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: "Plan"),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Config"),
        ],
      ),

      body: page[selectedIndex],
    );
  }
}