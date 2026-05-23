import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'screens/login_page.dart';
import 'screens/app_main_screen.dart'; // ← importa tu pantalla principal
import 'screens/favoritos_provider.dart';
import 'screens/Pasos de preparacion/ingredient_progress_provider.dart';
import 'screens/Pasos de preparacion/recipe_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
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
          home: const AuthGate(), // ← cambia esto
        ),
      ),
    );
  }
}

// ── AuthGate: decide a dónde ir al abrir la app ───────────────────────────────
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {

        // Firebase todavía está cargando el estado
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF7F7F5),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2D9E73),
              ),
            ),
          );
        }

        // Hay sesión activa → ir directo a la app
        if (snapshot.hasData && snapshot.data != null) {
          return const AppMainScreen();
        }

        // No hay sesión → mostrar login
        return const LoginPage();
      },
    );
  }
}