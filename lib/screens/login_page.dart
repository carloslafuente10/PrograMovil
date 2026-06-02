import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:programovil/screens/app_main_screen.dart';
import 'admin_screen.dart';
import '../servicios/historial_servicio.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  static const Color _verde     = Color(0xFF2D9E73);
  static const Color _verdeOsc  = Color(0xFF1B5E20);
  static const Color _mostaza   = Color(0xFFF5A623);
  static const Color _crema     = Color(0xFFFFF8EE);
  static const Color _textoGris = Color(0xFF888888);
  static const Color _borde     = Color(0xFFDDDDDD);

  String _codigoGenerado = '';

  final correoCtrl        = TextEditingController();
  final passCtrl          = TextEditingController();
  final regNombreCtrl     = TextEditingController();
  final regCorreoCtrl     = TextEditingController();
  final regPassCtrl       = TextEditingController();
  final regConfirmCtrl    = TextEditingController();
  final codigoOTPController = TextEditingController();

  bool registrando       = false;
  bool loginCargando     = false;
  bool regCargando       = false;
  bool ocultarPass       = true;
  bool ocultarRegPass    = true;
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
        .collection('app-usuarios').doc(user.uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
       'email':    user.email ?? '',
       'correo':   user.email ?? '',
       'nombre':   nombre,
       'rol':      'user',
       'creadoEn': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> acceder() async {
    final email    = correoCtrl.text.trim();
    final password = passCtrl.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _snack('Completa todos los campos', esError: true);
      return;
    }
    setState(() => loginCargando = true);
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);
      final uid = cred.user!.uid;
      final doc = await FirebaseFirestore.instance
          .collection('app-usuarios').doc(uid).get();
      final data = doc.data();
      await FirebaseFirestore.instance
          .collection('app-usuarios').doc(uid)
          .update({'ultimoAcceso': FieldValue.serverTimestamp()});
      String rol = 'user';
      if (data != null && data.containsKey('rol')) rol = data['rol'];
      if (!mounted) return;
      _snack('¡Bienvenido!');
      await HistorialService.registrar(accion: 'Inició sesión', tipo: 'login');
      if (rol == 'admin') {
        Navigator.pushReplacement(context,
            MaterialPageRoute(builder: (_) => const AdminScreen()));
      } else {
        Navigator.pushReplacement(context,
            MaterialPageRoute(
                builder: (_) => AppMainScreen(key: AppMainScreen.globalKey)));
      }
    } on FirebaseAuthException {
      _snack('Error: Credenciales incorrectas', esError: true);
    } catch (_) {
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
              password: regPassCtrl.text.trim());
      await resultado.user?.updateDisplayName(regNombreCtrl.text.trim());
      await _guardarUsuario(resultado.user!,
          nombre: regNombreCtrl.text.trim());
          await HistorialService.registrar(
          accion: 'Registró una cuenta',
          tipo: 'registro',
          );
      if (!mounted) return;
      Navigator.pushReplacement(context,
          MaterialPageRoute(
              builder: (_) =>
                  AppMainScreen(key: AppMainScreen.globalKey)));
    } on FirebaseAuthException catch (e) {
      _snack(e.code == 'email-already-in-use'
          ? 'El correo ya existe'
          : 'Error en registro',
          esError: true);
    } finally {
      if (mounted) setState(() => regCargando = false);
    }
  }

  Future<void> _enviarCorreoReal(String emailUsuario) async {
    final random = Random();
    _codigoGenerado = (100000 + random.nextInt(900000)).toString();
    const serviceId  = 'servicio_recetas';
    const templateId = 'reset_password_template';
    const publicKey  = '2557bg-ii7G5aladA';
    final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
    final response = await http.post(url,
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
        },
        body: json.encode({
          'service_id':  serviceId,
          'template_id': templateId,
          'user_id':     publicKey,
          'template_params': {
            'User_email': emailUsuario,
            'my_code':    _codigoGenerado,
          },
        }));
    if (response.statusCode != 200) {
      throw Exception('Error: ${response.body}');
    }
  }

  void _modalRecuperarContra() {
    final correoParaRecuperar = correoCtrl.text.trim();
    if (correoParaRecuperar.isEmpty ||
        !correoParaRecuperar.contains('@')) {
      _snack('Escribe un correo válido en el campo de inicio de sesión',
          esError: true);
      return;
    }
    int pasoRecuperacion = 1;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
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
                const Icon(Icons.mark_email_read_outlined,
                    size: 50, color: _verde),
                const SizedBox(height: 15),
                const Text('Enviaremos un código de seguridad a:',
                    textAlign: TextAlign.center),
                Text(correoParaRecuperar,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: _verde)),
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
                      letterSpacing: 8),
                  decoration:
                      _buildInput('000000', Icons.lock_outline),
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
              child: const Text('Cancelar',
                  style: TextStyle(color: _textoGris))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: _verde,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10))),
              onPressed: () async {
                if (pasoRecuperacion == 1) {
                  try {
                    await _enviarCorreoReal(correoParaRecuperar);
                    setModalState(() => pasoRecuperacion = 2);
                    _snack('Código enviado con éxito');
                  } catch (_) {
                    _snack('Error al enviar el correo.', esError: true);
                  }
                } else {
                  if (codigoOTPController.text == _codigoGenerado) {
                    Navigator.pop(ctx);
                    try {
                      await FirebaseAuth.instance
                          .sendPasswordResetEmail(
                              email: correoParaRecuperar);
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
                  style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _crema,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          children: [
            // Imagen de fondo con jaguar
            SizedBox(
              width: double.infinity,
              height: 340,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset('assets/images/login_bg.png',
                      fit: BoxFit.cover, alignment: Alignment.topCenter),
                  // Gradiente inferior para transición suave
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [_crema, _crema.withOpacity(0)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 0),
              child: Column(
                children: [
                  Text('Yagu!',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: _verdeOsc,
                        height: 1,
                        shadows: [
                          Shadow(color: _mostaza.withOpacity(0.3),
                              blurRadius: 8, offset: const Offset(0, 2)),
                        ],
                      )),
                  const SizedBox(height: 6),
                  Text('Cocina, aprende y disfruta',
                      style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400)),
                  const SizedBox(height: 4),
                  Container(
                    height: 3, width: 50,
                    decoration: BoxDecoration(
                        color: _mostaza,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withOpacity(0.07),
                            blurRadius: 20, offset: const Offset(0, 6)),
                      ],
                    ),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: !registrando
                          ? _panelLogin()
                          : _panelRegistro(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            Image.asset('assets/images/vegetables_botton.png',
                width: double.infinity, height: 90, fit: BoxFit.cover),
          ],
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
          keyboardType: TextInputType.emailAddress,
          decoration:
              _buildInput('Correo electrónico', Icons.email_outlined),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: passCtrl,
          obscureText: ocultarPass,
          decoration:
              _buildInput('Contraseña', Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                  ocultarPass
                      ? Icons.visibility_off
                      : Icons.visibility,
                  color: _textoGris),
              onPressed: () =>
                  setState(() => ocultarPass = !ocultarPass),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _modalRecuperarContra,
            child: Text('¿Olvidaste tu contraseña?',
                style: TextStyle(color: _verdeOsc, fontSize: 13)),
          ),
        ),
        const SizedBox(height: 4),
        _botonPrincipal(
            onPressed: acceder,
            texto: 'ENTRAR',
            cargando: loginCargando),
        const SizedBox(height: 20),
        _divisorSeparador(),
        const SizedBox(height: 16),
        _botonSecundario(
            onPressed: _toggleRegistro, texto: 'CREAR CUENTA'),
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
            decoration:
                _buildInput('Nombre completo', Icons.person_outline),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Requerido' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: regCorreoCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration:
                _buildInput('Correo electrónico', Icons.email_outlined),
            validator: (v) =>
                (v == null || !v.contains('@')) ? 'Email inválido' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: regPassCtrl,
            obscureText: ocultarRegPass,
            decoration:
                _buildInput('Contraseña', Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                icon: Icon(ocultarRegPass
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: () =>
                    setState(() => ocultarRegPass = !ocultarRegPass),
              ),
            ),
            validator: (v) => (v != null && v.length < 6)
                ? 'Mínimo 6 caracteres'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: regConfirmCtrl,
            obscureText: ocultarRegConfirm,
            decoration:
                _buildInput('Confirmar contraseña', Icons.lock_reset),
            validator: (v) =>
                v != regPassCtrl.text ? 'No coinciden' : null,
          ),
          const SizedBox(height: 24),
          _botonPrincipal(
              onPressed: _crearCuenta,
              texto: 'REGISTRARME',
              cargando: regCargando),
          TextButton(
            onPressed: _toggleRegistro,
            child: Text('¿Ya tienes cuenta? Inicia sesión',
                style: TextStyle(color: Colors.grey[600])),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInput(String hint, IconData icono) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(icono, color: _verde, size: 20),
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _verde, width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 1)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: Colors.redAccent, width: 1.5)),
    );
  }

  void _snack(String msg, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: esError ? Colors.redAccent : _verde,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
    ));
  }

  Widget _botonPrincipal(
      {required VoidCallback onPressed,
      required String texto,
      bool cargando = false}) {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: cargando ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: _verdeOsc,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: cargando
            ? const SizedBox(
                height: 20, width: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Text(texto,
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 15)),
      ),
    );
  }

  Widget _botonSecundario(
      {required VoidCallback onPressed, required String texto}) {
    return SizedBox(
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: _verdeOsc, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: Text(texto,
            style: TextStyle(
                color: _verdeOsc,
                fontWeight: FontWeight.w700,
                fontSize: 15)),
      ),
    );
  }

  Widget _divisorSeparador() {
    return Row(children: [
      Expanded(child: Divider(color: Colors.grey[300])),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Text('o',
            style: TextStyle(color: Colors.grey[500], fontSize: 13)),
      ),
      Expanded(child: Divider(color: Colors.grey[300])),
    ]);
  }

  void _modalAvisoFinal(String email) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text('¡Casi listo!', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.mark_email_unread_rounded,
                size: 60, color: _verde),
            const SizedBox(height: 20),
            Text(
              'Por seguridad, hemos enviado un enlace de confirmación a $email. '
              'Haz clic en el enlace para elegir tu nueva contraseña.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('ENTENDIDO',
                style: TextStyle(
                    color: _verde, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}