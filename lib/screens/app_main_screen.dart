import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'favoritos_screen.dart';

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
    super.initState();

    page = [

      HomeScreen(),

      const FavoritosScreen(),

      const Center(
        child: Text("Plan"),
      ),

      const Center(
        child: Text("Configuración"),
      ),

    ];
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF7F7F5),

      bottomNavigationBar: BottomNavigationBar(

        currentIndex: selectedIndex,

        selectedItemColor: const Color(0xFF2D9E73),

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

          BottomNavigationBarItem(

            icon: Icon(Icons.home),

            label: "Inicio",

          ),

          BottomNavigationBarItem(

            icon: Icon(Icons.favorite_border),

            label: "Favoritos",

          ),

          BottomNavigationBarItem(

            icon: Icon(Icons.calendar_month_outlined),

            label: "Plan",

          ),

          BottomNavigationBarItem(

            icon: Icon(Icons.settings_outlined),

            label: "Ajustes",

          ),

        ],

      ),

      body: page[selectedIndex],

    );
  }
}