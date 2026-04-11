import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
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
    );
  }
}
