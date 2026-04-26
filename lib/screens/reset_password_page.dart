import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ResetPasswordPage extends StatefulWidget {
  final String email;
  const ResetPasswordPage({super.key, required this.email});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  // Colores de tu tema actual
  static const Color _naranja = Color(0xFF38A377);
  static const Color _textoOscuro = Color(0xFF1A1A1A);
  static const Color _textoGris = Color(0xFF888888);
  static const Color _borde = Color(0xFFDDDDDD);

  final newPassCtrl = TextEditingController();
  final confirmPassCtrl = TextEditingController(); 
  bool cargando = false;

  @override
  void dispose() {
    newPassCtrl.dispose();
    confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> actualizarPassword() async {
    String pass = newPassCtrl.text.trim();
    String confirm = confirmPassCtrl.text.trim();

    if (pass.length < 6) {
      _snack("La contraseña debe tener al menos 6 caracteres", esError: true);
      return;
    }

    if (pass != confirm) {
      _snack("Las contraseñas no coinciden", esError: true);
      return;
    }

    setState(() => cargando = true);

    try {
      final query = await FirebaseFirestore.instance
          .collection('app-usuarios')
          .where('email', isEqualTo: widget.email)
          .get();

      if (query.docs.isNotEmpty) {
        await query.docs.first.reference.update({
          'password': pass, 
          'ultimaActualizacion': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;
        _snack("¡Contraseña actualizada con éxito!", esError: false);
        
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) Navigator.pop(context);
        });
        
      } else {
        throw "No se encontró el usuario en la base de datos";
      }
    } catch (e) {
      _snack("Error: $e", esError: true);
    } finally {
      if (mounted) setState(() => cargando = false);
    }
  }

  void _snack(String msg, {required bool esError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg), 
        backgroundColor: esError ? Colors.redAccent : _naranja,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: _textoGris, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              const Icon(Icons.lock_reset_rounded, size: 80, color: _naranja),
              const SizedBox(height: 24),
              const Text(
                'Nueva Contraseña',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: _textoOscuro),
              ),
              const SizedBox(height: 10),
              Text(
                widget.email,
                textAlign: TextAlign.center,
                style: const TextStyle(color: _textoGris, fontSize: 16),
              ),
              const SizedBox(height: 40),
              
              TextField(
                controller: newPassCtrl,
                obscureText: true,
                decoration: _inputStyle("Nueva contraseña", Icons.vpn_key_outlined),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPassCtrl,
                obscureText: true,
                decoration: _inputStyle("Confirmar contraseña", Icons.check_circle_outline),
              ),
              const SizedBox(height: 40),
              
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: cargando ? null : actualizarPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _naranja,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                    elevation: 0,
                  ),
                  child: cargando 
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("ACTUALIZAR CONTRASEÑA", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputStyle(String hint, IconData icon) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textoGris, fontSize: 15),
      prefixIcon: Icon(icon, color: _textoGris, size: 20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _naranja, width: 1.8),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}