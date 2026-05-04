import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'admin_recetas_screen.dart';

class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Panel Administrador"),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _boton(
              context,
              "Gestionar Recetas",
              () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AdminRecetasScreen(),
                  ),
                );
              },
            ),
            _boton(context, "Ingredientes", () {}),
            _boton(context, "Categorías", () {}),
            _boton(context, "Sustitutos", () {}),

            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("Cerrar sesión"),
            )
          ],
        ),
      ),
    );
  }

  Widget _boton(BuildContext context, String texto, VoidCallback onPressed) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
        child: Text(texto),
      ),
    );
  }
}