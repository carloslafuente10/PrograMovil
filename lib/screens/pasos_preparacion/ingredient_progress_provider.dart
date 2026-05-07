import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart'; 
import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'screens/favoritos_provider.dart'; 
import 'screens/pasos_preparacion/ingredient_progress_provider.dart';
import 'screens/pasos_preparacion/recipe_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return FavoritosProvider( 
      notifier: FavoritosState(),
      child: MultiProvider( 
        providers: [
          ChangeNotifierProvider(
            create: (_) => IngredientProgressProvider(service: RecipeService()),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'App Recetas',
          theme: ThemeData(
            primarySwatch: Colors.orange, 
            useMaterial3: true,
          ),
          home: const LoginPage(), 
        ),
      ),
    );
  }
}