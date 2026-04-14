import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'screens/favoritos_provider.dart';

void main() async {

  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(

    options: DefaultFirebaseOptions.currentPlatform,

  );

  runApp(

    const MyApp(),

  );

}

class MyApp extends StatefulWidget {

  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();

}

class _MyAppState extends State<MyApp> {

  final FavoritosState _favoritosState =
      FavoritosState();

  @override
  Widget build(BuildContext context) {

    return FavoritosProvider(

      state: _favoritosState,

      child: ListenableBuilder(

        listenable: _favoritosState,

        builder: (context, _) {

          return MaterialApp(

            debugShowCheckedModeBanner: false,

            title: 'App Recetas',

            theme: ThemeData(

              primarySwatch: Colors.orange,

              useMaterial3: true,

            ),

            home: const LoginPage(),

          );

        },

      ),

    );

  }

}