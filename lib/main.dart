import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart'; 
import 'firebase_options.dart'; 
import 'screens/login_page.dart'; // Importa la pantalla que acabamos de crear

void main() async {
  // Configuración necesaria para Firebase
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

import 'screens/app_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'App Recetas',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      home: const AppMainScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Recetas 🍲")),
      body: ListView(
        children: const [
          ListTile(title: Text("🍕 Pizza"), subtitle: Text("Deliciosa pizza")),
          ListTile(title: Text("🍝 Pasta"), subtitle: Text("Pasta italiana")),
          ListTile(title: Text("🍔 Hamburguesa"), subtitle: Text("Con queso")),
        ],
      ),
      // Aquí definimos que la primera pantalla sea el Login
      home: const LoginPage(), 
    );
  }
}
