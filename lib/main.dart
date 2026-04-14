import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
<<<<<<< Updated upstream

import 'firebase_options.dart';
import 'screens/login_page.dart';
=======
import 'firebase_options.dart';
>>>>>>> Stashed changes
import 'screens/app_main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
<<<<<<< Updated upstream
    options: DefaultFirebaseOptions.currentPlatform,
=======
    options:
    DefaultFirebaseOptions.currentPlatform,
>>>>>>> Stashed changes
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
<<<<<<< Updated upstream
      title: 'App Recetas',
      theme: ThemeData(
        primarySwatch: Colors.orange,
        useMaterial3: true,
      ),
      // Puedes cambiar aquí entre Login o App principal
      home: const LoginPage(),
      // home: const AppMainScreen(),
=======
      home: AppMainScreen(),
>>>>>>> Stashed changes
    );
  }
}