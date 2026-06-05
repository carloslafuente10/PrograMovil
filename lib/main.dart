import 'package:flutter/material.dart';// Permite construir la interfaz gráfica de la aplicación.
import 'package:firebase_core/firebase_core.dart';// Proporciona la inicialización y configuración de Firebase.
import 'package:firebase_auth/firebase_auth.dart';// Gestiona la autenticación de usuarios mediante Firebase Authentication.
import 'package:cloud_firestore/cloud_firestore.dart';// Permite consultar y almacenar información en Firebase Firestore.
import 'package:provider/provider.dart';// Implementa la gestión de estado mediante el patrón Provider.
import 'package:flutter_dotenv/flutter_dotenv.dart';// Permite cargar variables de entorno desde un archivo .env.
import 'firebase_options.dart';// Archivo de configuración automática de Firebase para cada plataforma.
import 'screens/login_page.dart';// Pantalla de inicio de sesión.
import 'screens/app_main_screen.dart';// Pantalla principal de la aplicación para usuarios.
import 'screens/admin_screen.dart'; //  FIX: import necesario para redirigir al admin
import 'screens/favoritos_provider.dart';// Proveedor encargado de gestionar las recetas favoritas.
import 'screens/Pasos de preparacion/ingredient_progress_provider.dart';// Proveedor que controla el progreso de ingredientes de una receta.
import 'screens/Pasos de preparacion/recipe_service.dart';// Servicio para consultar recetas e ingredientes.
// Punto de entrada de la aplicación. Inicializa Firebase y las variables de entorno.
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}
// Widget principal que configura proveedores, tema y navegación inicial.
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
          home: const AuthGate(),
        ),
      ),
    );
  }
}

// ── AuthGate: decide a dónde ir al abrir la app ───────────────────────────────
//FIX Problema 3: verifica el ROL del usuario en Firestore al reabrir la app
// Antes solo verificaba si había sesión → admin iba a AppMainScreen (pantalla de usuario)
// Ahora: sesión activa → consulta app-usuarios → si rol==admin va a AdminScreen
//                                               → si no, va a AppMainScreen
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

        // No hay sesión → mostrar login
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginPage();
        }

        //  Hay sesión activa → verificar rol en Firestore antes de navegar
        return _RolGate(uid: snapshot.data!.uid);
      },
    );
  }
}

// Widget separado que consulta el rol y redirige correctamente
class _RolGate extends StatelessWidget {
  final String uid;
  const _RolGate({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('app-usuarios')
          .doc(uid)
          .get(),
      builder: (context, snap) {

        // Mientras carga el doc de Firestore
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF7F7F5),
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF2D9E73),
              ),
            ),
          );
        }

        // Error al cargar o doc no existe → ir a login por seguridad
        if (snap.hasError || !snap.hasData || !snap.data!.exists) {
          return const LoginPage();
        }

        final data = snap.data!.data() as Map<String, dynamic>?;
        final rol  = data?['rol'] ?? 'user';

        //  Admin va a AdminScreen, usuario normal va a AppMainScreen con globalKey
        if (rol == 'admin') {
          return const AdminScreen();
        } else {
          return AppMainScreen(key: AppMainScreen.globalKey);
        }
      },
    );
  }
}