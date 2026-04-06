import 'package:flutter/material.dart';

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
      const Center(child: Text("Home Recetas")),
      const Center(child: Text("Favoritos")),
      const Center(child: Text("Plan")),
      const Center(child: Text("Configuración")),
    ];
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  backgroundColor: Colors.grey[100], // 👈 fondo suave

  bottomNavigationBar: BottomNavigationBar(
    currentIndex: selectedIndex,
    selectedItemColor: Colors.orange,      // activo
    unselectedItemColor: Colors.grey,      // inactivo
    backgroundColor: Colors.white,         // barra blanca
    elevation: 10,                         // sombra 👈 IMPORTANTE
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