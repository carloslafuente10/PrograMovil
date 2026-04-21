import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:programovil/screens/home_screen.dart';
import 'package:programovil/screens/app_main_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LoginPage — respeta el diseño original (blanco, naranja, cubiertos)
// y añade un panel de Registro expandible en la misma pantalla.
// ─────────────────────────────────────────────────────────────────────────────

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  // ── Paleta (igual que la imagen) ───────────────────────────────────────────
 // Mantenemos el nombre de la variable para no romper el código, 
  // pero le asignamos el color verde del banner.
  static const Color _naranja = Color(0xFF38A377); 
  static const Color _naranjaOscuro = Color(0xFF2E8560); // Un verde un poco más oscuro
  static const Color _textoOscuro = Color(0xFF1A1A1A);
  static const Color _textoGris = Color(0xFF888888);
  static const Color _borde = Color(0xFFDDDDDD);

  // ── Controladores Login ────────────────────────────────────────────────────
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // ── Controladores Registro ─────────────────────────────────────────────────
  final _regNombreController = TextEditingController();
  final _regEmailController = TextEditingController();
  final _regPasswordController = TextEditingController();
  final _regConfirmController = TextEditingController();

  // ── Estado ─────────────────────────────────────────────────────────────────
  bool _mostrarRegistro = false;
  bool _loginCargando = false;
  bool _regCargando = false;
  bool _ocultarPass = true;
  bool _ocultarRegPass = true;
  bool _ocultarRegConfirm = true;

  final _regFormKey = GlobalKey<FormState>();

  // ── Animación del panel de registro ───────────────────────────────────────
  late final AnimationController _animCtrl;
  late final Animation<double> _expandAnim;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _expandAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _regNombreController.dispose();
    _regEmailController.dispose();
    _regPasswordController.dispose();
    _regConfirmController.dispose();
    super.dispose();
  }

  void _toggleRegistro() {
    setState(() => _mostrarRegistro = !_mostrarRegistro);
    _mostrarRegistro ? _animCtrl.forward() : _animCtrl.reverse();
  }

  // ── Firebase: Login ────────────────────────────────────────────────────────
  Future<void> acceder() async {
    // Validamos que los campos no estén vacíos
    if (_emailController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty) {
      _snack('Completa todos los campos', esError: true);
      return;
    }

    setState(() => _loginCargando = true);

    try {
      // Intento de inicio de sesión con Firebase
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // Verificamos mounted antes de navegar para evitar errores si la pantalla se cerró
      if (!mounted) return;

      // Navegamos al Home reemplazando la ruta actual
      Navigator.pushReplacement(
  context,
  MaterialPageRoute(builder: (_) => AppMainScreen()), // Esto te lleva a la pantalla con botones
);
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException en acceder(): ${e.code}');

      if (!mounted) return;

      String mensaje = 'Algo salió mal, intenta de nuevo';

      // Manejo manual de errores (Estilo ingeniería artesanal)
      if (e.code == 'user-not-found') {
        mensaje = 'No encontramos una cuenta con ese correo';
      } else if (e.code == 'wrong-password') {
        mensaje = 'La contraseña no es correcta';
      } else if (e.code == 'invalid-email') {
        mensaje = 'El correo no tiene un formato válido';
      } else if (e.code == 'user-disabled') {
        mensaje = 'Esta cuenta fue suspendida';
      } else if (e.code == 'invalid-credential') {
        mensaje = 'Correo o contraseña incorrectos';
      }

      _snack(mensaje, esError: true);
    } finally {
      // Quitamos el estado de carga al terminar, pase lo que pase
      if (mounted) setState(() => _loginCargando = false);
    }
  }

  // ── Firebase: Registro ─────────────────────────────────────────────────────
  Future<void> _crearCuenta() async {
  // 1. Usamos los controladores que REALMENTE están en tu panel de registro
  if (_regNombreController.text.trim().isEmpty ||
      _regEmailController.text.trim().isEmpty ||
      _regPasswordController.text.trim().isEmpty ||
      _regConfirmController.text.trim().isEmpty) {
    _snack('Completa todos los campos', esError: true);
    return;
  }

  // 2. Validación del formulario (la que hace que salgan los textos rojos en los campos)
  if (!_regFormKey.currentState!.validate()) return;

  setState(() => _regCargando = true); // Usamos tu variable de carga de registro

  try {
    // 3. CAMBIO CLAVE: Usamos 'createUser' en lugar de 'signIn'
    final resultado = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: _regEmailController.text.trim(),
      password: _regPasswordController.text.trim(),
    );

    // Guardamos el nombre (esto es un toque de calidad artesanal)
    await resultado.user?.updateDisplayName(_regNombreController.text.trim());

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen()),
    );
  } on FirebaseAuthException catch (e) {
    print('FirebaseAuthException en _crearCuenta(): ${e.code}');
    if (!mounted) return;

    String mensaje = 'Algo salió mal al crear la cuenta';

    // Mantenemos el estilo de errores de Claudio pero para Registro
    if (e.code == 'email-already-in-use') {
      mensaje = 'Este correo ya está registrado';
    } else if (e.code == 'weak-password') {
      mensaje = 'La contraseña es muy débil';
    } else if (e.code == 'invalid-email') {
      mensaje = 'El correo no es válido';
    }

    _snack(mensaje, esError: true);
  } finally {
    if (mounted) setState(() => _regCargando = false);
  }
}

  void _snack(String msg, {bool esError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: esError ? Colors.redAccent : _naranja,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Decoración de campos (igual estilo que la imagen original) ─────────────
  InputDecoration _campo(String hint, IconData icono) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textoGris, fontSize: 15),
      prefixIcon: Icon(icono, color: _textoGris, size: 20),
      contentPadding:
          const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _naranja, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
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

              // ── Ícono cubiertos 
              Icon(
                Icons.restaurant,
                size: 72,
                color: _naranja, // <--- Cambia esto a _naranja
                ),

              const SizedBox(height: 18),

              // ── Título ───────────────────────────────────────────────────
              const Text(
                'Recetas App',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: _textoOscuro,
                  letterSpacing: 0.2,
                ),
              ),

              const SizedBox(height: 36),

              // ── Panel LOGIN ───────────────────────────────────────────────
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: !_mostrarRegistro
                    ? _panelLogin()
                    : _panelRegistro(),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // ── PANEL: Login ───────────────────────────────────────────────────────────
  Widget _panelLogin() {
    return Column(
      key: const ValueKey('login'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Campo correo
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          decoration:
              _campo('Correo electrónico', Icons.email_outlined),
        ),

        const SizedBox(height: 14),

        // Campo contraseña
        TextField(
          controller: _passwordController,
          obscureText: _ocultarPass,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => acceder(),
          decoration: _campo('Contraseña', Icons.lock_outline).copyWith(
            suffixIcon: IconButton(
              icon: Icon(
                _ocultarPass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: _textoGris,
                size: 20,
              ),
              onPressed: () =>
                  setState(() => _ocultarPass = !_ocultarPass),
            ),
          ),
        ),

        const SizedBox(height: 28),

        // Botón ENTRAR
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _loginCargando ? null : acceder,
            style: ElevatedButton.styleFrom(
              backgroundColor: _naranja,
              foregroundColor: Colors.white,
              disabledBackgroundColor: _naranja.withOpacity(0.55),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: _loginCargando
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text(
                    'ENTRAR',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
          ),
        ),

        const SizedBox(height: 24),

        // Separador
        Row(
          children: [
            const Expanded(child: Divider(color: _borde)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                '¿No tienes cuenta?',
                style: TextStyle(
                    color: _textoGris.withOpacity(0.9), fontSize: 13),
              ),
            ),
            const Expanded(child: Divider(color: _borde)),
          ],
        ),

        const SizedBox(height: 16),

        // Botón crear cuenta
        SizedBox(
          height: 52,
          child: OutlinedButton(
            onPressed: _toggleRegistro,
            style: OutlinedButton.styleFrom(
              foregroundColor: _naranjaOscuro,
              side: const BorderSide(color: _naranja, width: 1.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: const Text(
              'CREAR CUENTA',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── PANEL: Registro ────────────────────────────────────────────────────────
  Widget _panelRegistro() {
    return Form(
      key: _regFormKey,
      child: Column(
        key: const ValueKey('registro'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado del panel
          Row(
            children: [
              GestureDetector(
                onTap: _toggleRegistro,
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: _textoGris),
              ),
              const SizedBox(width: 10),
              const Text(
                'Nueva cuenta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _textoOscuro,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Nombre
          TextFormField(
            controller: _regNombreController,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration:
                _campo('Nombre completo', Icons.person_outline_rounded),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Ingresa tu nombre';
              if (v.trim().length < 3)
                return 'Mínimo 3 caracteres';
              return null;
            },
          ),

          const SizedBox(height: 14),

          // Correo
          TextFormField(
            controller: _regEmailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            decoration:
                _campo('Correo electrónico', Icons.email_outlined),
            validator: (v) {
              if (v == null || v.trim().isEmpty)
                return 'Ingresa tu correo';
              final ok =
                  RegExp(r'^[\w\.-]+@[\w\.-]+\.\w{2,4}$').hasMatch(v.trim());
              if (!ok) return 'Correo inválido';
              return null;
            },
          ),

          const SizedBox(height: 14),

          // Contraseña
          TextFormField(
            controller: _regPasswordController,
            obscureText: _ocultarRegPass,
            textInputAction: TextInputAction.next,
            decoration: _campo('Contraseña', Icons.lock_outline).copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _ocultarRegPass
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _textoGris,
                  size: 20,
                ),
                onPressed: () =>
                    setState(() => _ocultarRegPass = !_ocultarRegPass),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Ingresa una contraseña';
              if (v.length < 6) return 'Mínimo 6 caracteres';
              return null;
            },
          ),

          const SizedBox(height: 14),

          // Confirmar contraseña
          TextFormField(
            controller: _regConfirmController,
            obscureText: _ocultarRegConfirm,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _crearCuenta(),
            decoration:
                _campo('Confirmar contraseña', Icons.lock_reset_rounded)
                    .copyWith(
              suffixIcon: IconButton(
                icon: Icon(
                  _ocultarRegConfirm
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: _textoGris,
                  size: 20,
                ),
                onPressed: () => setState(
                    () => _ocultarRegConfirm = !_ocultarRegConfirm),
              ),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirma tu contraseña';
              if (v != _regPasswordController.text)
                return 'Las contraseñas no coinciden';
              return null;
            },
          ),

          const SizedBox(height: 28),

          // Botón CREAR CUENTA
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: _regCargando ? null : _crearCuenta,
              style: ElevatedButton.styleFrom(
                backgroundColor: _naranja,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _naranja.withOpacity(0.55),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
              child: _regCargando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Text(
                      'CREAR CUENTA',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Volver al login (texto)
          Center(
            child: TextButton(
              onPressed: _toggleRegistro,
              style: TextButton.styleFrom(foregroundColor: _textoGris),
              child: const Text(
                '¿Ya tienes cuenta? Inicia sesión',
                style: TextStyle(fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}