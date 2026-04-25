import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/app_main_screen.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();
  final _confirmarContrasenaController = TextEditingController();

  bool _ocultarContrasena = true;
  bool _ocultarConfirmarContrasena = true;
  bool _cargando = false;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  static const _naranja = Color(0xFFE64A19);
  static const _naranjaClaro = Color(0xFFFF7043);
  static const _fondoClaro = Color(0xFFFFF8F5);
  static const _grisTexto = Color(0xFF5D4037);
  static const _bordeInput = Color(0xFFFFCCBC);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _nombreController.dispose();
    _correoController.dispose();
    _contrasenaController.dispose();
    _confirmarContrasenaController.dispose();
    super.dispose();
  }

  // ─── Validadores ────────────────────────────────────────────────────────────

  String? _validarNombre(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Por favor ingresa tu nombre completo';
    }
    if (valor.trim().length < 3) {
      return 'El nombre debe tener al menos 3 caracteres';
    }
    return null;
  }

  String? _validarCorreo(String? valor) {
    if (valor == null || valor.trim().isEmpty) {
      return 'Por favor ingresa tu correo electrónico';
    }
    final regExp = RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,4}$');
    if (!regExp.hasMatch(valor.trim())) {
      return 'Ingresa un correo electrónico válido';
    }
    return null;
  }

  String? _validarContrasena(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Por favor ingresa una contraseña';
    }
    if (valor.length < 6) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    return null;
  }

  String? _validarConfirmarContrasena(String? valor) {
    if (valor == null || valor.isEmpty) {
      return 'Por favor confirma tu contraseña';
    }
    if (valor != _contrasenaController.text) {
      return 'Las contraseñas no coinciden';
    }
    return null;
  }

  // ─── Acción de registro ─────────────────────────────────────────────────────

  Future<void> _crearCuenta() async {
    if (!_formKey.currentState!.validate()) return;

    // Verificación extra antes de llamar a Firebase
    if (_contrasenaController.text != _confirmarContrasenaController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Las contraseñas no coinciden'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      // 1. Crear usuario en Firebase Auth
      final credencial = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _correoController.text.trim(),
            password: _contrasenaController.text,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () => throw Exception('Tiempo de espera agotado'),
          );

      // 2. Guardar nombre en el perfil de Auth
      await credencial.user?.updateDisplayName(_nombreController.text.trim());

      // 3. Guardar datos extra en Firestore
      await FirebaseFirestore.instance
          .collection('app-usuarios')
          .doc(credencial.user!.uid)
          .set({
            'nombre': _nombreController.text.trim(),
            'correo': _correoController.text.trim(),
            'creadoEn': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      // 4. Navegar eliminando toda la pila anterior
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AppMainScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);

      String mensaje = 'Ocurrió un error. Intenta de nuevo.';
      if (e.code == 'email-already-in-use') {
        mensaje = 'Este correo ya está registrado.';
      } else if (e.code == 'weak-password') {
        mensaje = 'La contraseña es muy débil.';
      } else if (e.code == 'invalid-email') {
        mensaje = 'El correo no es válido.';
      } else if (e.code == 'network-request-failed') {
        mensaje = 'Sin conexión a internet.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensaje),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  // ─── Widgets auxiliares ─────────────────────────────────────────────────────

  InputDecoration _decoracionCampo({
    required String label,
    required String hint,
    required IconData icono,
    Widget? sufijo,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: _grisTexto),
      hintStyle: TextStyle(color: _grisTexto.withValues(alpha: 0.5)),
      prefixIcon: Icon(icono, color: _naranjaClaro),
      suffixIcon: sufijo,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _bordeInput, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _naranjaClaro, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }

  // ─── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondoClaro,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    // ── Cabecera con ícono ──────────────────────────────────
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [_naranjaClaro, _naranja],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _naranja.withValues(alpha: 0.35),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          size: 52,
                          color: Colors.white,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── Título ─────────────────────────────────────────────
                    const Text(
                      'Sabores de Bolivia',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _naranja,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Crea tu cuenta y descubre las recetas\ntradicionales de Cochabamba',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: _grisTexto.withValues(alpha: 0.75),
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // ── Campo: Nombre Completo ──────────────────────────────
                    TextFormField(
                      controller: _nombreController,
                      textCapitalization: TextCapitalization.words,
                      keyboardType: TextInputType.name,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: _grisTexto),
                      decoration: _decoracionCampo(
                        label: 'Nombre Completo',
                        hint: 'Ej: María Mamani',
                        icono: Icons.person_outline_rounded,
                      ),
                      validator: _validarNombre,
                    ),

                    const SizedBox(height: 16),

                    // ── Campo: Correo Electrónico ───────────────────────────
                    TextFormField(
                      controller: _correoController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: _grisTexto),
                      decoration: _decoracionCampo(
                        label: 'Correo Electrónico',
                        hint: 'tucorreo@ejemplo.com',
                        icono: Icons.email_outlined,
                      ),
                      validator: _validarCorreo,
                    ),

                    const SizedBox(height: 16),

                    // ── Campo: Contraseña ───────────────────────────────────
                    TextFormField(
                      controller: _contrasenaController,
                      obscureText: _ocultarContrasena,
                      textInputAction: TextInputAction.next,
                      style: const TextStyle(color: _grisTexto),
                      decoration: _decoracionCampo(
                        label: 'Contraseña',
                        hint: 'Mínimo 6 caracteres',
                        icono: Icons.lock_outline_rounded,
                        sufijo: IconButton(
                          icon: Icon(
                            _ocultarContrasena
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: _grisTexto.withValues(alpha: 0.6),
                          ),
                          onPressed: () => setState(
                            () => _ocultarContrasena = !_ocultarContrasena,
                          ),
                        ),
                      ),
                      validator: _validarContrasena,
                    ),

                    const SizedBox(height: 16),

                    // ── Campo: Confirmar Contraseña ─────────────────────────
                    TextFormField(
                      controller: _confirmarContrasenaController,
                      obscureText: _ocultarConfirmarContrasena,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _crearCuenta(),
                      style: const TextStyle(color: _grisTexto),
                      decoration: _decoracionCampo(
                        label: 'Confirmar Contraseña',
                        hint: 'Repite tu contraseña',
                        icono: Icons.lock_reset_rounded,
                        sufijo: IconButton(
                          icon: Icon(
                            _ocultarConfirmarContrasena
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: _grisTexto.withValues(alpha: 0.6),
                          ),
                          onPressed: () => setState(
                            () => _ocultarConfirmarContrasena =
                                !_ocultarConfirmarContrasena,
                          ),
                        ),
                      ),
                      validator: _validarConfirmarContrasena,
                    ),

                    const SizedBox(height: 32),

                    // ── Botón CREAR CUENTA ──────────────────────────────────
                    SizedBox(
                      height: 56,
                      child: ElevatedButton(
                        onPressed: _cargando ? null : _crearCuenta,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _naranja,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: _naranja.withValues(
                            alpha: 0.6,
                          ),
                          elevation: 4,
                          shadowColor: _naranja.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                          ),
                        ),
                        child: _cargando
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_outline, size: 20),
                                  SizedBox(width: 10),
                                  Text(
                                    'CREAR CUENTA',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // ── Divisor decorativo ──────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: Divider(color: _bordeInput, thickness: 1.5),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '¿Ya tienes cuenta?',
                            style: TextStyle(
                              color: _grisTexto.withValues(alpha: 0.6),
                              fontSize: 13,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(color: _bordeInput, thickness: 1.5),
                        ),
                      ],
                    ),

                    // ── TextButton → Ir al Login ────────────────────────────
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: _naranja,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text(
                        'Inicia sesión aquí',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          decoration: TextDecoration.underline,
                          decorationColor: _naranja,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
