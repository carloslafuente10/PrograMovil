import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_main_screen.dart'; // Importamos tu pantalla de los círculos

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> acceder() async {
    setState(() => _isLoading = true);
    try {
      // Intenta iniciar sesión con el correo falso que creaste
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      
      if (mounted) {
        // Si sale bien, saltamos a la pantalla principal (la de los círculos)
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AppMainScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      String mensaje = "Error: ${e.message}";
      if (e.code == 'user-not-found') mensaje = "El correo no existe en Firebase";
      if (e.code == 'wrong-password') mensaje = "La contraseña es incorrecta";
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(30.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.restaurant_menu, size: 80, color: Colors.orange),
            const SizedBox(height: 20),
            const Text("Recetas App", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: "Correo electrónico",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: "Contraseña",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 30),
            _isLoading 
              ? const CircularProgressIndicator()
              : SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: acceder,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                    child: const Text("ENTRAR", style: TextStyle(color: Colors.white, fontSize: 18)),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}