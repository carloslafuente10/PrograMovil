import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:programovil/screens/app_main_screen.dart';
import 'admin_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  // Paleta de la app
  static const Color _verde = Color(0xFF38A377);
  static const Color _verdeOscuro = Color(0xFF2E8560);
  static const Color _textoOscuro = Color(0xFF1A1A1A);
  static const Color _textoGris = Color(0xFF888888);
  static const Color _borde = Color(0xFFDDDDDD);

  // Variable para el código OTP
  String _codigoGenerado = '';

  // Controllers
  final correoCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final regNombreCtrl = TextEditingController();
  final regCorreoCtrl = TextEditingController();
  final regPassCtrl = TextEditingController();
  final regConfirmCtrl = TextEditingController();
  final codigoOTPController = TextEditingController();

  bool registrando = false;
  bool loginCargando = false;
  bool regCargando = false;
  bool ocultarPass = true;
  bool ocultarRegPass = true;
  bool ocultarRegConfirm = true;

  final _regFormKey = GlobalKey<FormState>();
  late final AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    correoCtrl.dispose();
    passCtrl.dispose();
    regNombreCtrl.dispose();
    regCorreoCtrl.dispose();
    regPassCtrl.dispose();
    regConfirmCtrl.dispose();
    codigoOTPController.dispose();
    super.dispose();
  }

  void _toggleRegistro() {
    setState(() => registrando = !registrando);
    registrando ? _animCtrl.forward() : _animCtrl.reverse();
  }

  Future<void> _guardarUsuario(User user, {String nombre = ''}) async {
    final docRef = FirebaseFirestore.instance
        .collection('app-usuarios')
        .doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'email': user.email ?? '',
        'nombre': nombre,
        'creadoEn': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> acceder() async {
    final email = correoCtrl.text.trim();
    final password = passCtrl.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _snack('Completa todos los campos', esError: true);
      return;
    }

    setState(() => loginCargando = true);

    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('app-usuarios')
          .doc(uid)
          .get();
      final data = doc.data();

      // Actualizar último acceso
      await FirebaseFirestore.instance
          .collection('app-usuarios')
          .doc(uid)
          .update({'ultimoAcceso': FieldValue.serverTimestamp()});

      String rol = 'user';
      if (data != null && data.containsKey('rol')) {
        rol = data['rol'];
      }
      if (!mounted) return;
      _snack('¡Bienvenido!');
      if (rol == 'admin') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminScreen()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AppMainScreen(key: AppMainScreen.globalKey),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      _snack('Error: Credenciales incorrectas', esError: true);
    } catch (e) {
      _snack('Error al conectar con el servidor', esError: true);
    } finally {
      if (mounted) setState(() => loginCargando = false);
    }
  }

  Future<void> _crearCuenta() async {
    if (!_regFormKey.currentState!.validate()) return;
    setState(() => regCargando = true);
    try {
      final resultado = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: regCorreoCtrl.text.trim(),
            password: regPassCtrl.text.trim(),
          );
      await resultado.user?.updateDisplayName(regNombreCtrl.text.trim());
      await _guardarUsuario(resultado.user!, nombre: regNombreCtrl.text.trim());
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => AppMainScreen(key: AppMainScreen.globalKey),
        ),
      );
    } on FirebaseAuthException catch (e) {
      _snack(
        e.code == 'email-already-in-use'
            ? 'El correo ya existe'
            : 'Error en registro',
        esError: true,
      );
    } finally {
      if (mounted) setState(() => regCargando = false);
    }
  }

  Future<void> _enviarCorreoReal(String emailUsuario) async {
    final random = Random();
    _codigoGenerado = (100000 + random.nextInt(900000)).toString();

    const serviceId = 'servicio_recetas';
    const templateId = 'reset_password_template';
    const publicKey = '2557bg-ii7G5aladA';

    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'origin': 'http://localhost',
      },
      body: json.encode({
        'service_id': serviceId,
        'template_id': templateId,
        'user_id': publicKey,
        'template_params': {
          'User_email': emailUsuario,
          'my_code': _codigoGenerado,
        },
      }),
    );

    if (response.statusCode != 200) {
      print('DETALLE DEL ERROR EMAILJS: ${response.body}');
      throw Exception('Error: ${response.body}');
    }
  }

  void _modalRecuperarContra() {
    final correoParaRecuperar = correoCtrl.text.trim();
    if (correoParaRecuperar.isEmpty || !correoParaRecuperar.contains('@')) {
      _snack(
        'Escribe un correo válido en el campo de inicio de sesión',
        esError: true,
      );
      return;
    }

    int pasoRecuperacion = 1;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            pasoRecuperacion == 1
                ? 'Verificación de cuenta'
                : 'Ingresa el código',
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pasoRecuperacion == 1) ...[
                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 50,
                  color: _verde,
                ),
                const SizedBox(height: 15),
                const Text(
                  'Enviaremos un código de seguridad a:',
                  textAlign: TextAlign.center,
                ),
                Text(
                  correoParaRecuperar,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _verde,
                  ),
                ),
              ] else ...[
                const Text(
                  'Escribe el código que recibiste por EmailJS:',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: _textoGris),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: codigoOTPController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration: _buildInput('000000', Icons.lock_outline),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                codigoOTPController.clear();
                Navigator.pop(ctx);
              },
              child: const Text(
                'Cancelar',
                style: TextStyle(color: _textoGris),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: _verde,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                if (pasoRecuperacion == 1) {
                  try {
                    await _enviarCorreoReal(correoParaRecuperar);
                    setModalState(() => pasoRecuperacion = 2);
                    _snack('Código enviado con éxito');
                  } catch (e) {
                    _snack('Error al enviar el correo.', esError: true);
                  }
                } else {
                  if (codigoOTPController.text == _codigoGenerado) {
                    Navigator.pop(ctx);
                    try {
                      await FirebaseAuth.instance.sendPasswordResetEmail(
                        email: correoParaRecuperar,
                      );
                      _modalAvisoFinal(correoParaRecuperar);
                      codigoOTPController.clear();
                    } catch (e) {
                      _snack('Error de Firebase: $e', esError: true);
                    }
                  } else {
                    _snack('Código incorrecto', esError: true);
                  }
                }
              },
              child: Text(
                pasoRecuperacion == 1 ? 'ENVIAR' : 'VERIFICAR',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const SizedBox(height: 64),
              const Icon(Icons.restaurant, size: 72, color: _verde),
              const SizedBox(height: 18),
              const Text(
                'Recetas App',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _textoOscuro,
                ),
              ),
              const SizedBox(height: 36),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: !registrando ? _panelLogin() : _panelRegistro(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _panelLogin() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: correoCtrl,
          decoration: _buildInput('Correo electrónico', Icons.email_outlined),
        ),
        const SizedBox(height: 15),
        TextField(
          controller: passCtrl,
          obscureText: ocultarPass,
          decoration: _buildInput('Contraseña', Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                ocultarPass ? Icons.visibility_off : Icons.visibility,
                color: _textoGris,
              ),
              onPressed: () => setState(() => ocultarPass = !ocultarPass),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _modalRecuperarContra,
            child: const Text(
              '¿Olvidaste tu contraseña?',
              style: TextStyle(color: _verde),
            ),
          ),
        ),
        const SizedBox(height: 15),
        _botonPrincipal(
          onPressed: acceder,
          texto: 'ENTRAR',
          cargando: loginCargando,
        ),
        const SizedBox(height: 25),
        _divisorSeparador(),
        const SizedBox(height: 15),
        _botonSecundario(onPressed: _toggleRegistro, texto: 'CREAR CUENTA'),
      ],
    );
  }

  Widget _panelRegistro() {
    return Form(
      key: _regFormKey,
      child: Column(
        key: const ValueKey('registro'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: regNombreCtrl,
            decoration: _buildInput('Nombre completo', Icons.person_outline),
            validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: regCorreoCtrl,
            decoration: _buildInput('Correo electrónico', Icons.email_outlined),
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Email inválido' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: regPassCtrl,
            obscureText: ocultarRegPass,
            decoration: _buildInput('Contraseña', Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  ocultarRegPass ? Icons.visibility_off : Icons.visibility,
                ),
                onPressed: () =>
                    setState(() => ocultarRegPass = !ocultarRegPass),
              ),
            ),
            validator: (v) =>
                (v != null && v.length < 6) ? 'Mínimo 6 caracteres' : null,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: regConfirmCtrl,
            obscureText: ocultarRegConfirm,
            decoration: _buildInput('Confirmar contraseña', Icons.lock_reset),
            validator: (v) => v != regPassCtrl.text ? 'No coinciden' : null,
          ),
          const SizedBox(height: 28),
          _botonPrincipal(
            onPressed: _crearCuenta,
            texto: 'REGISTRARME',
            cargando: regCargando,
          ),
          TextButton(
            onPressed: _toggleRegistro,
            child: const Text(
              '¿Ya tienes cuenta? Inicia sesión',
              style: TextStyle(color: _textoGris),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInput(String hint, IconData icono) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icono, color: _textoGris),
      filled: true,
      fillColor: Colors.white,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _verde),
      ),
    );
  }

  void _snack(String msg, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: esError ? Colors.redAccent : _verde,
      ),
    );
  }

  Widget _botonPrincipal({
    required VoidCallback onPressed,
    required String texto,
    bool cargando = false,
  }) {
    return ElevatedButton(
      onPressed: cargando ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: _verde,
        shape: const StadiumBorder(),
      ),
      child: cargando
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(texto, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _botonSecundario({
    required VoidCallback onPressed,
    required String texto,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: _verde),
        shape: const StadiumBorder(),
      ),
      child: Text(texto, style: const TextStyle(color: _verde)),
    );
  }

  Widget _divisorSeparador() {
    return const Row(
      children: [
        Expanded(child: Divider()),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Text('O'),
        ),
        Expanded(child: Divider()),
      ],
    );
  }

  void _modalAvisoFinal(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¡Casi listo!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.mark_email_unread_rounded,
              size: 60,
              color: Color(0xFF38A377),
            ),
            const SizedBox(height: 20),
            Text(
              'Por seguridad, hemos enviado un enlace de confirmación a $email. '
              'Haz clic en el enlace para elegir tu nueva contraseña.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF888888)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'ENTENDIDO',
              style: TextStyle(
                color: Color(0xFF38A377),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
