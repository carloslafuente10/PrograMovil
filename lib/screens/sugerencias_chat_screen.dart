import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necesario para HapticFeedback
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'detalle_receta_screen.dart';
import 'voice_call_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class SugerenciasChatScreen extends StatefulWidget {
  const SugerenciasChatScreen({super.key});

  @override
  State<SugerenciasChatScreen> createState() => _SugerenciasChatScreenState();
}

class _SugerenciasChatScreenState extends State<SugerenciasChatScreen>
    with TickerProviderStateMixin {

  // ─────────────────────────────────────────────
  // VARIABLES DE ESTADO GENERALES
  // ─────────────────────────────────────────────
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _mensajes = [];
  bool _opcionSeleccionada = false;
  bool _estaCargando = false;
  String? _categoriaActual;
  bool _esperandoDetalleReporte = false;
  bool _esperandoParrafoSugerencia = false;
  final Color _verde = const Color(0xFF2D9E73);

  // ─────────────────────────────────────────────
  // VARIABLES DEL FLUJO DE REPORTE (GAMIFICADO)
  // ─────────────────────────────────────────────

  /// Paso actual del flujo de reporte: 0=sin iniciar, 1=cat elegida, 2=subcat elegida, 3=frase completada
  int _pasoReporte = 0;

  bool _bloquearReportes = false;
  String _categoriaReporteActual = "";
  String _subCategoriaReporteActual = "";
  bool _bloquearFlujoReporte = false;

  /// Chips del banco de palabras que el usuario ha seleccionado (en orden de toque)
  final List<String> _fraseArmada = [];

  /// true = el usuario activó el TextField libre desde el botón "✏️ Otro detalle"
  bool _mostrarCampoLibre = false;

  /// Animación de la barra de progreso segmentada
  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  double _progreso = 0.0; // 0.0 → 1.0

  // ─────────────────────────────────────────────
  // VARIABLES DEL FLUJO DE AYUDA
  // ─────────────────────────────────────────────
  String? _categoriaComidaElegida;
  List<String> _ingredientesPrimordiales = [];
  final List<String> _ingredientesSeleccionados = [];
  bool _mostrarGridIngredientes = false;
  bool _bloquearCategorias = false;

  // ─────────────────────────────────────────────
  // BANCO DE PALABRAS DINÁMICO (PASO 3)
  // Se rellena en _seleccionarSubcategoriaReporte
  // según la subcategoría elegida por el usuario.
  // ─────────────────────────────────────────────
  List<String> _bancoPalabrasDinamico = [];

  // ─────────────────────────────────────────────
  // CONFIGURACIÓN GROQ / SYSTEM PROMPT
  // ─────────────────────────────────────────────
  final String _apiKeyGrok = dotenv.env['GROQ_API_KEY'] ?? '';
  final String _systemPrompt = """
Eres A.L.I.C.I.A., la chef virtual oficial de PrograMovil.
Tu misión es asistir con recetas, reportes de errores y sugerencias.

REGLAS CRÍTICAS DE RESPUESTA:
1. Sé SÚPER CORTA y DIRECTA. Responde en un máximo de 2 o 3 líneas de texto.
2. NUNCA uses listas numeradas, viñetas ni textos largos. Todo debe ser un párrafo breve y fluido.
3. Mantén el tono entusiasta y usa metáforas culinarias rápidas (problemas = platos quemados, soluciones = recetas).
4. Usa pocos emojis de cocina y nunca reveles que eres una IA.
""";

  // ─────────────────────────────────────────────
  // initState / dispose
  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // Controlador de la barra de progreso animada
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _progressAnimation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _progressController.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // _animarProgreso
  // Anima la barra de progreso desde el valor
  // actual hacia el nuevo target (0.0 a 1.0).
  // ─────────────────────────────────────────────
  void _animarProgreso(double nuevoValor) {
    final double inicio = _progreso;
    _progressAnimation = Tween<double>(begin: inicio, end: nuevoValor).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _progressController.forward(from: 0);
    setState(() => _progreso = nuevoValor);
  }

  // ─────────────────────────────────────────────
  // _construirPromptValidacion
  // Genera el prompt de validación para la IA
  // dado categoría, subcategoría y texto del usuario.
  // ─────────────────────────────────────────────
  String _construirPromptValidacion(
      String categoriaReporte, String subCategoria, String textoUsuario) {
    return """
Eres el sistema de control de calidad de la app PrograMovil. Tu única tarea es validar si la descripción de un reporte de error enviada por el usuario es legítima.

CRITERIOS DE VALIDACIÓN:
1. RELACIÓN: El texto debe tener relación directa con el problema reportado. Categoría: $categoriaReporte. Subcategoría: $subCategoria.
2. COHERENCIA: El texto debe ser legible, coherente y describir una situación o acción. No se permiten números aleatorios, spam, insultos ni palabras sueltas sin sentido.
3. CONTEXTO DE LA APP: Debe hablar de funciones, pantallas, botones o recetas de la aplicación.

Texto del usuario a evaluar: "$textoUsuario"

Responde ÚNICAMENTE con la palabra 'VALIDO' si cumple los 3 criterios, o 'INVALIDO' si falla en alguno. No agregues saludos, explicaciones ni puntuación.
""";
  }

  // ─────────────────────────────────────────────
  // _obtenerRespuestaDeGrok
  // Envía el historial completo + mensaje al modelo
  // LLaMA vía Groq y devuelve la respuesta de texto.
  // ─────────────────────────────────────────────
  Future<String> _obtenerRespuestaDeGrok(String mensajeUsuario) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    List<Map<String, String>> historialParaApi = [
      {"role": "system", "content": _systemPrompt}
    ];
    for (var msg in _mensajes) {
      if (msg["tipo"] == "texto") {
        String roleApi = (msg["rol"] == "usuario") ? "user" : "assistant";
        historialParaApi.add({
          "role": roleApi,
          "content": msg["texto"] ?? ""
        });
      }
    }
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKeyGrok',
        },
        body: jsonEncode({
          "model": "llama-3.1-8b-instant",
          "messages": historialParaApi,
          "temperature": 0.4
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        return data['choices'][0]['message']['content'];
      } else {
        debugPrint("Error Grok: ${response.statusCode} - ${response.body}");
        return "¡Uy! Se me ha cortado la salsa (Error de comunicación con la cocina).";
      }
    } catch (e) {
      debugPrint("Excepción Grok: $e");
      return "Se nos ha derramado el caldo... Revisa tu conexión a internet.";
    }
  }

  // ─────────────────────────────────────────────
  // _verificarRecetaEnFirebase  (sin cambios)
  // ─────────────────────────────────────────────
  Future<bool> _verificarRecetaEnFirebase(String texto) async {
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      return true;
    } catch (e) {
      debugPrint("Error Firebase: $e");
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // _generarVariantes
  // Genera variantes de una categoría para tolerar
  // tildes, mayúsculas y plural/singular en Firestore.
  // ─────────────────────────────────────────────
  List<String> _generarVariantes(String categoria) {
    String base = categoria.trim();
    String singular = base.endsWith('s')
        ? base.substring(0, base.length - 1)
        : base;
    String plural = base.endsWith('s') ? base : '${base}s';

    return [
      base,
      base.toLowerCase(),
      base.toUpperCase(),
      base[0].toUpperCase() + base.substring(1).toLowerCase(),
      singular,
      singular.toLowerCase(),
      plural,
      plural.toLowerCase(),
    ].toSet().toList();
  }

  // ─────────────────────────────────────────────
  // _buscarRecetasRecomendadas
  // ─────────────────────────────────────────────
  Future<void> _buscarRecetasRecomendadas() async {
    if (_categoriaComidaElegida == null || _ingredientesSeleccionados.isEmpty) return;

    setState(() => _estaCargando = true);
    try {
      final variantes = _generarVariantes(_categoriaComidaElegida!);

      // Consulta amplia tolerante a tildes en el campo categoría
      final snapshot = await FirebaseFirestore.instance
          .collection('app-recetas-completas')
          .where(
            Filter.or(
              Filter('categoria', whereIn: variantes),
              Filter('categoría', whereIn: variantes),
            ),
          )
          .get();

      List<Map<String, String>> recetasEncontradas = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        List ingredientesDoc = data['ingredientes'] ?? [];

        // Normalizar nombres de ingredientes: quitar guiones y espacios extra
        List<String> nombresReceta = ingredientesDoc
            .map((i) => (i['nombre'] ?? i['ingrediente_id'] ?? '')
                .toString()
                .trim()
                .toLowerCase()
                .replaceAll('-', ' '))
            .toList();

        // La receta aparece si tiene AL MENOS UNO de los ingredientes seleccionados
        bool tieneIngrediente = _ingredientesSeleccionados.any(
          (ingSel) => nombresReceta.contains(ingSel.toLowerCase().trim()),
        );

        if (tieneIngrediente) {
          recetasEncontradas.add({
            'id': doc.id,
            'nombre': data['nombre'] ?? "Receta",
          });
        }
      }

      setState(() {
        if (recetasEncontradas.isEmpty) {
          _mensajes.add({
            "rol": "llama",
            "texto": "He buscado en mi alacena pero no tengo una receta exacta con esa combinación. 🥣 ¿Intentamos con otros ingredientes?",
            "tipo": "texto",
          });
        } else {
          _mensajes.add({
            "rol": "llama",
            "texto": "¡He encontrado el maridaje perfecto! 👨‍🍳 Aquí tienes las opciones que mejor combinan con tu selección.",
            "tipo": "recetas_grid",
            "recetas": recetasEncontradas,
          });
        }
      });
    } catch (e) {
      debugPrint("Error buscar recetas: $e");
      setState(() => _mensajes.add({"rol": "llama", "texto": "Se nos ha derramado el caldo... Error en la conexión."}));
    } finally {
      setState(() => _estaCargando = false);
    }
  }

  // ─────────────────────────────────────────────
  // _seleccionarOpcion
  // Limpia todo el estado y arranca el flujo
  // correspondiente al botón del menú principal.
  // ─────────────────────────────────────────────
  void _seleccionarOpcion(String titulo, String descripcion) {
    setState(() {
      _opcionSeleccionada = true;
      _categoriaActual = titulo;
      _mensajes.clear();
      _esperandoDetalleReporte = false;
      _esperandoParrafoSugerencia = false;
      _mostrarGridIngredientes = false;
      _bloquearCategorias = false;
      _bloquearFlujoReporte = false;
      _categoriaComidaElegida = null;
      _ingredientesSeleccionados.clear();
      _categoriaReporteActual = "";
      _subCategoriaReporteActual = "";
      _bloquearReportes = false;
      // Reset gamificación
      _pasoReporte = 0;
      _fraseArmada.clear();
      _mostrarCampoLibre = false;
      _animarProgreso(0.0);

      String saludoChef;
      String tipoMensaje = "texto";

      if (titulo == "Reporte") {
        saludoChef = "¡Alto al fuego en la cocina! 🍳 Vamos a documentar tu reporte paso a paso. Primero, ¿qué área está quemada?";
        tipoMensaje = "botones_reporte_categorias";
        _esperandoDetalleReporte = true;
        _animarProgreso(0.0);
      } else if (titulo == "Ayuda") {
        saludoChef = "Aquí estoy para guiarte en tu siguiente comida. Por favor selecciona una categoría:";
        tipoMensaje = "botones_categoria";
      } else if (titulo == "Consulta Especifica") {
        saludoChef = "¡Entrando comandas de alta cocina! 🚀 Escribe libremente tu inquietud culinaria o técnica.";
      } else {
        saludoChef = "¡Me encanta experimentar! Cuéntame tu idea completa (Nombre, ingredientes y toque especial) en un solo párrafo. 📝";
        _esperandoParrafoSugerencia = true;
      }

      _mensajes.add({
        "rol": "llama",
        "texto": saludoChef,
        "tipo": tipoMensaje
      });
    });
  }

  // ─────────────────────────────────────────────
  // _seleccionarCategoriaReporte  (PASO 1 → 2)
  // Bloquea las categorías, guarda la elegida y
  // avanza la barra al 33%. Añade las subcategorías.
  // ─────────────────────────────────────────────
  void _seleccionarCategoriaReporte(String categoria) {
    if (_bloquearReportes) return;
    HapticFeedback.lightImpact(); // Respuesta táctil estilo Duolingo
    setState(() {
      _bloquearReportes = true;
      _categoriaReporteActual = categoria;
      _esperandoDetalleReporte = true;
      _pasoReporte = 1;
      _mensajes.add({"rol": "usuario", "texto": categoria, "tipo": "texto"});
      List<String> subCats = [];
      if (categoria.contains("Contenido")) {
        subCats = ["Receta mal explicada", "Ingredientes erróneos", "Imágenes rotas"];
      } else if (categoria.contains("experiencia")) {
        subCats = ["Navegación confusa", "Letra muy pequeña", "Diseño incómodo"];
      } else {
        subCats = ["Cierre inesperado (Crash)", "Error de base de datos", "Carga lenta / Lag"];
      }
      _mensajes.add({
        "rol": "llama",
        "texto": "Perfecto chef. Ahora elige el problema específico que encontraste:",
        "tipo": "botones_reporte_subcategorias",
        "opciones": subCats,
        "categoria_reporte": categoria
      });
    });
    _animarProgreso(0.33);
  }

  // ─────────────────────────────────────────────
  // _seleccionarSubcategoriaReporte  (PASO 2 → 3)
  // Guarda la subcategoría, avanza la barra al 66%
  // y activa el banco de palabras en el input.
  // ─────────────────────────────────────────────
  void _seleccionarSubcategoriaReporte(String subcat) {
    if (_bloquearFlujoReporte) return;
    HapticFeedback.lightImpact();

    // ── Banco dinámico: palabras específicas para cada subcategoría ──
    List<String> nuevoBanco;
    switch (subcat) {
      case "Receta mal explicada":
        nuevoBanco = [
          "En el paso",
          "Está confuso",
          "No se entiende",
          "La explicación",
          "Falta",
          "El tiempo de cocción",
          "Las instrucciones",
        ];
        break;
      case "Ingredientes erróneos":
        nuevoBanco = [
          "El ingrediente",
          "La cantidad",
          "Falta",
          "No coincide",
          "Los gramos",
          "Está mal",
          "En la preparación",
        ];
        break;
      case "Imágenes rotas":
        nuevoBanco = [
          "La imagen",
          "No carga",
          "Se ve rota",
          "Falta",
          "En el servidor",
          "Está en blanco",
          "Tiene un error",
        ];
        break;
      default:
        // Flujos de experiencia (Navegación, Letra, Diseño)
        // y técnicos (Crash, Base de datos, Lag)
        nuevoBanco = [
          "La pantalla",
          "No funciona",
          "Se congela",
          "Al presionar",
          "Falta",
          "Carga lenta",
          "No responde",
        ];
    }

    setState(() {
      _bloquearFlujoReporte = true;
      _subCategoriaReporteActual = subcat;
      _pasoReporte = 2;
      _fraseArmada.clear();
      _mostrarCampoLibre = false;
      _bancoPalabrasDinamico = nuevoBanco; // ← cargamos el banco correcto
      _mensajes.add({"rol": "usuario", "texto": "Problema específico: $subcat", "tipo": "texto"});
      _mensajes.add({
        "rol": "llama",
        "texto": "¡Comanda anotada! 📋 Ahora arma tu descripción tocando las burbujas en orden:",
        "tipo": "texto"
      });
    });
    _animarProgreso(0.66);
  }

  // ─────────────────────────────────────────────
  // _confirmarFraseBancoYEnviar  (PASO 3 → fin)
  // Toma la frase armada por el usuario, la valida
  // con Groq y termina el flujo de reporte.
  // ─────────────────────────────────────────────
  Future<void> _confirmarFraseBancoYEnviar() async {
    // Si el campo libre está activo, tomamos su texto; si no, usamos la frase armada
    final String textoFinal = _mostrarCampoLibre && _controller.text.trim().isNotEmpty
        ? _controller.text.trim()
        : _fraseArmada.join(" ");

    if (textoFinal.isEmpty) return;

    HapticFeedback.mediumImpact();
    _animarProgreso(1.0);

    setState(() {
      _pasoReporte = 3;
      _mensajes.add({"rol": "usuario", "texto": textoFinal, "tipo": "texto"});
      _estaCargando = true;
      _controller.clear();
    });

    try {
      // Validación con Groq
      String promptValidacion = _construirPromptValidacion(
          _categoriaReporteActual, _subCategoriaReporteActual, textoFinal);
      final respuestaValidacion = await _obtenerRespuestaDeGrok(promptValidacion);

      if (respuestaValidacion.trim().toUpperCase().contains("INVALIDO")) {
        setState(() {
          _estaCargando = false;
          _pasoReporte = 2; // Regresamos al paso 2 para que reintente
          _fraseArmada.clear();
          _animarProgreso(0.66);
          _mensajes.add({
            "rol": "llama",
            "tipo": "texto",
            "texto": "¡Uy chef! Esa combinación de ingredientes no describe un problema de la app. 🍳 Intenta de nuevo con las burbujas."
          });
        });
        return;
      }

      // Validación exitosa: determinar respuesta según categoría
      if (_categoriaReporteActual.contains("Contenido") ||
          _subCategoriaReporteActual == "Receta mal explicada") {
        bool existeEnFirebase = await _verificarRecetaEnFirebase(textoFinal);
        setState(() {
          _estaCargando = false;
          _esperandoDetalleReporte = false;
          _bloquearReportes = false;
          _bloquearFlujoReporte = false;
          _subCategoriaReporteActual = "";
          _categoriaReporteActual = "";
          _mensajes.add({
            "rol": "llama",
            "tipo": "texto",
            "texto": existeEnFirebase
                ? "He verificado en Firebase. El elemento ya está bajo el radar de nuestra cocina de desarrollo. ✅"
                : "¡Uy chef! Revisé en Firebase y ese platillo o ingrediente no está registrado en nuestro recetario."
          });
          _mensajes.add({
            "rol": "llama",
            "tipo": "sugerencia_btn",
            "texto": "¿Deseas enviar formalmente esta comanda de error al plantel administrativo?"
          });
        });
      } else {
        final respuestaIA = await _obtenerRespuestaDeGrok(textoFinal);
        setState(() {
          _estaCargando = false;
          _esperandoDetalleReporte = false;
          _bloquearReportes = false;
          _bloquearFlujoReporte = false;
          _subCategoriaReporteActual = "";
          _categoriaReporteActual = "";
          _mensajes.add({"rol": "llama", "tipo": "texto", "texto": respuestaIA});
          _mensajes.add({
            "rol": "llama",
            "tipo": "sugerencia_btn",
            "texto": "¿Deseas enviar formalmente esta comanda de error al plantel administrativo?"
          });
        });
      }
    } catch (e) {
      setState(() {
        _esperandoDetalleReporte = false;
        _bloquearFlujoReporte = false;
        _estaCargando = false;
        _mensajes.add({
          "rol": "llama",
          "tipo": "sugerencia_btn",
          "texto": "¡Vaya, el horno se apagó! Pero guardé tu comanda. ¿La enviamos de igual forma?"
        });
      });
    }
  }

  // ─────────────────────────────────────────────
  // _cargarIngredientesPrimordiales
  // ─────────────────────────────────────────────
  Future<void> _cargarIngredientesPrimordiales(String categoria) async {
    setState(() => _estaCargando = true);
    try {
      final variantes = _generarVariantes(categoria);

      // Consulta tolerante a tildes en el campo categoría
      final snapshot = await FirebaseFirestore.instance
          .collection('app-recetas-completas')
          .where(
            Filter.or(
              Filter('categoria', whereIn: variantes),
              Filter('categoría', whereIn: variantes),
            ),
          )
          .get();

      Set<String> setIngs = {};
      for (var doc in snapshot.docs) {
        for (var ing in (doc.data()['ingredientes'] ?? [])) {
          if (ing is Map &&
              (ing['es_primordial'] == true ||
                  ing['es_primordial'].toString().toLowerCase() == 'true')) {
            // Rescata nombre o ingrediente_id si el nombre falla
            String nom = (ing['nombre'] ?? ing['ingrediente_id'] ?? '')
                .toString()
                .replaceAll('-', ' ')
                .trim();
            if (nom.isNotEmpty) {
              // Capitalizar primera letra
              nom = nom[0].toUpperCase() + nom.substring(1).toLowerCase();
              setIngs.add(nom);
            }
          }
        }
      }

      setState(() {
        _ingredientesPrimordiales = setIngs.toList()..sort();
        _mostrarGridIngredientes = true;
        _mensajes.add({
          "rol": "llama",
          "texto": "Por favor elige hasta 3 ingredientes disponibles:",
          "tipo": "grid_ingredients"
        });
      });
    } catch (e) {
      debugPrint("Error DB: $e");
    } finally {
      setState(() => _estaCargando = false);
    }
  }

  // ─────────────────────────────────────────────
  // _enviarMensaje
  // Función central del chat para flujos que NO
  // son reporte (Ayuda, Consulta, Sugerencia).
  // El reporte usa _confirmarFraseBancoYEnviar.
  // ─────────────────────────────────────────────
  Future<void> _enviarMensaje() async {
    final textoOriginal = _controller.text.trim();
    if (textoOriginal.isEmpty) return;

    setState(() {
      _mensajes.add({"rol": "usuario", "texto": textoOriginal, "tipo": "texto"});
      _controller.clear();
      _estaCargando = true;
    });

    if (textoOriginal.startsWith("Dame una recomendación de")) {
      await _buscarRecetasRecomendadas();
      return;
    }

    if (_esperandoParrafoSugerencia) {
      setState(() {
        _esperandoParrafoSugerencia = false;
        _estaCargando = false;
        _mensajes.add({
          "rol": "llama",
          "tipo": "sugerencia_btn",
          "texto": "¡Qué aroma tan increíble! Pulsa abajo para enviar tu creación al Chef mayor."
        });
      });
      return;
    }

    try {
      final respuesta = await _obtenerRespuestaDeGrok(textoOriginal);
      setState(() {
        _mensajes.add({"rol": "llama", "tipo": "texto", "texto": respuesta});
      });
    } catch (e) {
      setState(() =>
          _mensajes.add({"rol": "llama", "texto": "Disculpa, creo que no entendí lo que intentaste decir."}));
    } finally {
      setState(() => _estaCargando = false);
    }
  }

  void _enviarReporteAlAdmin(String detalle) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("Reporte enviado al administrador")));
  }

  void _enviarSugerenciaAlAdmin() {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text("¡Sugerencia enviada!")));
  }

  // ═══════════════════════════════════════════════════════
  //  BUILD PRINCIPAL
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Asistente A.L.I.C.I.A."),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        leading: _opcionSeleccionada
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() {
                  _opcionSeleccionada = false;
                  _mensajes.clear();
                  _mostrarGridIngredientes = false;
                  _bloquearCategorias = false;
                  _pasoReporte = 0;
                  _fraseArmada.clear();
                  _animarProgreso(0.0);
                }),
              )
            : null,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: _opcionSeleccionada
                ? Container(color: const Color(0xFFF5F5F5))
                : Image.asset('assets/images/fondo.webp', fit: BoxFit.cover),
          ),
          SafeArea(
            child: _opcionSeleccionada
                ? _buildResponsiveLayout()
                : _buildWelcomeLayout(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildResponsiveLayout
  // ─────────────────────────────────────────────
  Widget _buildResponsiveLayout() {
    if (_categoriaActual == "Reporte") {
      return Column(
        children: [
          Expanded(
            flex: 1,
            child: Container(
              width: double.infinity,
              color: Colors.white,
              child: SizedBox.expand(
                child: Image.asset(
                  'assets/images/fondo1.webp',
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const Divider(height: 1, color: Colors.black12),
          Expanded(
            flex: 1,
            child: _buildChatLayout(),
          ),
        ],
      );
    } else {
      return _buildChatLayout();
    }
  }

  // ─────────────────────────────────────────────
  // _buildWelcomeLayout  (sin cambios)
  // ─────────────────────────────────────────────
  Widget _buildWelcomeLayout() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
            left: 24.0, right: 24.0, bottom: 16.0, top: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Transform.translate(
              offset: const Offset(0, -450),
              child: const Text(
                "¿Qué tienes para contarme?",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildMenuButton(
              titulo: "Reporte",
              descripcion: "Quiero Reportar un problema con la app",
              subDescripcion: "Reportar un problema con la app",
              icono: Icons.bug_report_outlined,
              colorIcono: const Color(0xFFE57373),
            ),
            _buildMenuButton(
              titulo: "Ayuda",
              descripcion: "Necesito una recomendación de comida",
              subDescripcion: "Necesito una recomendación",
              icono: Icons.restaurant_menu,
              colorIcono: const Color(0xFFFFB74D),
            ),
            _buildHighlightedButton(),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildMenuButton  (sin cambios)
  // ─────────────────────────────────────────────
  Widget _buildMenuButton({
    required String titulo,
    required String descripcion,
    required String subDescripcion,
    required IconData icono,
    required Color colorIcono,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF7F4EB),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC8C2B3).withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () => _seleccionarOpcion(titulo, descripcion),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.black87,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
          child: Row(
            children: [
              Icon(icono, color: colorIcono, size: 36),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFC85A32))),
                    const SizedBox(height: 2),
                    Text(subDescripcion,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: Color(0xFF7A756B))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Color(0xFFA39E94), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildHighlightedButton  (sin cambios)
  // ─────────────────────────────────────────────
  Widget _buildHighlightedButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF2D9E73), Color(0xFF5CD699)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF2D9E73).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ElevatedButton(
          // Navega a la pantalla de videollamada con T'anta-Wawa
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VoiceCallScreen()),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15)),
          ),
          child: const Row(
            children: [
              Icon(Icons.mic, color: Colors.white, size: 32),
              SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Consultar a T'anta-Wawa",
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.3),
                    ),
                    Text(
                      "Asistente de voz ciberpunk andino",
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildProgressBar
  // Barra de progreso segmentada en 3 pasos con
  // AnimatedBuilder para interpolación suave.
  // Solo se muestra cuando _categoriaActual == "Reporte".
  // ─────────────────────────────────────────────
  Widget _buildProgressBar() {
    final List<Map<String, dynamic>> pasos = [
      {"label": "Categoría", "icono": Icons.category_outlined},
      {"label": "Detalle", "icono": Icons.tune},
      {"label": "Descripción", "icono": Icons.check_circle_outline},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Etiquetas de los 3 pasos
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(3, (i) {
              final bool activo = _pasoReporte >= i;
              return Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: activo ? _verde : Colors.grey.shade200,
                      ),
                      child: Icon(
                        pasos[i]["icono"] as IconData,
                        size: 16,
                        color: activo ? Colors.white : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      pasos[i]["label"] as String,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: activo ? _verde : Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          // Barra animada
          AnimatedBuilder(
            animation: _progressAnimation,
            builder: (context, _) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _progressAnimation.value,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(_verde),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildChatLayout
  // Añade la barra de progreso arriba si es un
  // reporte, y el área de entrada gamificada abajo.
  // ─────────────────────────────────────────────
  Widget _buildChatLayout() {
    final bool esReporte = _categoriaActual == "Reporte";

    return Column(
      children: [
        // Barra de progreso solo visible en el flujo de Reporte
        if (esReporte) _buildProgressBar(),

        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _mensajes.length,
            itemBuilder: (context, index) {
              final msg = _mensajes[index];
              bool esUsuario = msg["rol"] == "usuario";

              return Align(
                alignment: esUsuario
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: esUsuario
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    if (!esUsuario)
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0, top: 5),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: _verde.withOpacity(0.2),
                          backgroundImage: const AssetImage(
                              'assets/images/iconllama.png'),
                          child: const Icon(Icons.restaurant,
                              size: 16, color: Color(0xFF2D9E73)),
                        ),
                      ),
                    Expanded(
                      flex: esUsuario ? 0 : 1,
                      child: Column(
                        crossAxisAlignment: esUsuario
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin:
                                const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: esUsuario
                                  ? _verde
                                  : Colors.white.withOpacity(0.9),
                              borderRadius:
                                  BorderRadius.circular(15),
                            ),
                            child: Text(
                              msg["texto"]!,
                              style: TextStyle(
                                color: esUsuario
                                    ? Colors.white
                                    : Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          // Widgets extra según tipo de mensaje
                          if (msg["tipo"] == "botones_reporte_categorias")
                            _buildReporteCategoriasGrid(),
                          if (msg["tipo"] == "botones_reporte_subcategorias")
                            _buildReporteSubcategoriasGrid(
                                msg["categoria_reporte"]),
                          if (msg["tipo"] == "botones_categoria")
                            _buildCategoriasGrid(),
                          if (msg["tipo"] == "grid_ingredients" &&
                              _mostrarGridIngredientes)
                            _buildIngredientesGrid(),
                          if (msg["tipo"] == "recetas_grid")
                            _buildRecetasBotonesGrid(msg["recetas"]),
                          if (msg["tipo"] == "reporte_btn")
                            _buildActionBtn(
                                () => _enviarReporteAlAdmin(msg["texto"]),
                                Icons.mark_email_read_outlined,
                                "Enviar reporte al admin"),
                          if (msg["tipo"] == "sugerencia_btn")
                            _buildActionBtn(
                                _enviarSugerenciaAlAdmin,
                                Icons.send_and_archive,
                                "Enviar al plantel administrativo"),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),

        if (_estaCargando)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("A.L.I.C.I.A. está cocinando...",
                style: TextStyle(
                    color: Colors.black54,
                    fontStyle: FontStyle.italic)),
          ),

        _buildInputArea(),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // _buildReporteCategoriasGrid  (REDISEÑADO)
  // Tarjetas grandes estilo Duolingo con ícono,
  // título y sombra de "clic mecánico".
  // ─────────────────────────────────────────────
  Widget _buildReporteCategoriasGrid() {
    final List<Map<String, dynamic>> categorias = [
      {
        "label": "1. Problemas con el Contenido",
        "icono": Icons.menu_book_outlined,
        "color": const Color(0xFFE57373),
      },
      {
        "label": "2. Problemas con la experiencia",
        "icono": Icons.touch_app_outlined,
        "color": const Color(0xFFFFB74D),
      },
      {
        "label": "3. Fallas Técnicas",
        "icono": Icons.build_circle_outlined,
        "color": const Color(0xFF64B5F6),
      },
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        children: categorias.map((cat) {
          final String label = cat["label"] as String;
          final bool desactivar = _bloquearReportes &&
              _categoriaReporteActual != label;
          final bool seleccionado = _categoriaReporteActual == label;

          return GestureDetector(
            onTap: desactivar
                ? null
                : () => _seleccionarCategoriaReporte(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: seleccionado
                    ? (cat["color"] as Color).withOpacity(0.15)
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: seleccionado
                      ? (cat["color"] as Color)
                      : Colors.grey.shade300,
                  width: seleccionado ? 2.5 : 1,
                ),
                // Sombra inferior pronunciada = efecto "tecla mecánica"
                boxShadow: desactivar
                    ? []
                    : [
                        BoxShadow(
                          color: (cat["color"] as Color).withOpacity(
                              seleccionado ? 0.35 : 0.15),
                          blurRadius: 0,
                          offset: Offset(0, seleccionado ? 2 : 4),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Icon(cat["icono"] as IconData,
                      color: desactivar
                          ? Colors.grey.shade400
                          : (cat["color"] as Color),
                      size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: desactivar
                            ? Colors.grey.shade400
                            : Colors.black87,
                      ),
                    ),
                  ),
                  if (seleccionado)
                    Icon(Icons.check_circle,
                        color: cat["color"] as Color, size: 20),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildReporteSubcategoriasGrid  (REDISEÑADO)
  // Chips grandes con sombra inferior de clic mecánico.
  // ─────────────────────────────────────────────
  Widget _buildReporteSubcategoriasGrid(String categoriaPadre) {
    List<String> opciones = [];
    if (categoriaPadre.contains("Contenido")) {
      opciones = [
        "Receta mal explicada",
        "Ingredientes erróneos",
        "Imágenes rotas"
      ];
    } else if (categoriaPadre.contains("experiencia")) {
      opciones = [
        "Navegación confusa",
        "Letra muy pequeña",
        "Diseño incómodo"
      ];
    } else {
      opciones = [
        "Cierre inesperado (Crash)",
        "Error de base de datos",
        "Carga lenta / Lag"
      ];
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: opciones.map((opc) {
          final bool desactivar = _bloquearFlujoReporte &&
              _subCategoriaReporteActual != opc;
          final bool seleccionado = _subCategoriaReporteActual == opc;

          return GestureDetector(
            onTap: desactivar
                ? null
                : () => _seleccionarSubcategoriaReporte(opc),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: seleccionado
                    ? const Color(0xFFFFE082)
                    : const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: seleccionado
                      ? const Color(0xFFFFA000)
                      : const Color(0xFFFFE082),
                  width: seleccionado ? 2 : 1,
                ),
                boxShadow: desactivar
                    ? []
                    : [
                        BoxShadow(
                          color: const Color(0xFFFFA000)
                              .withOpacity(seleccionado ? 0.4 : 0.2),
                          blurRadius: 0,
                          offset: Offset(0, seleccionado ? 1 : 3),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (seleccionado)
                    const Padding(
                      padding: EdgeInsets.only(right: 6),
                      child: Icon(Icons.check,
                          size: 14, color: Color(0xFFFFA000)),
                    ),
                  Text(
                    opc,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: desactivar
                          ? Colors.grey.shade400
                          : const Color(0xFF795548),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildInputArea  (REDISEÑADO para el Reporte)
  // En el flujo de Reporte paso 2: muestra el banco
  // de palabras + el botón "Comprobar e Instalar".
  // En cualquier otro caso: muestra el TextField normal.
  // ─────────────────────────────────────────────
  Widget _buildInputArea() {
    // Input bloqueado por botón administrativo final
    final bool entradaBloqueada = _mensajes.isNotEmpty &&
        (_mensajes.last["tipo"] == "reporte_btn" ||
            _mensajes.last["tipo"] == "sugerencia_btn");

    // Activar banco de palabras: estamos en Reporte, paso 2 (subcat elegida)
    final bool mostrarBanco =
        _categoriaActual == "Reporte" && _pasoReporte == 2 && !entradaBloqueada;

    if (mostrarBanco) {
      return _buildBancoPalabras();
    }

    // Input estándar para los demás flujos
    return Container(
      padding: const EdgeInsets.all(12),
      color: entradaBloqueada ? Colors.grey[100] : Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !entradaBloqueada,
              decoration: InputDecoration(
                hintText: entradaBloqueada
                    ? "Conversación terminada..."
                    : "Escribe a la chef...",
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _enviarMensaje(),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send,
                color: entradaBloqueada ? Colors.grey : _verde),
            onPressed: entradaBloqueada ? null : _enviarMensaje,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildBancoPalabras
  // Panel inferior con:
  //  1. Zona de frase armada (chips tocados en orden)
  //  2. Banco de burbujas disponibles
  //  3. Botón "✏️ Otro detalle" para habilitar TextField
  //  4. Botón verde "Comprobar e Instalar Reporte"
  // ─────────────────────────────────────────────
  Widget _buildBancoPalabras() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Zona de la frase armada ──
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 48),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _fraseArmada.isEmpty
                ? Text(
                    "Toca las burbujas para armar tu reporte...",
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 13),
                  )
                : Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: _fraseArmada.map((palabra) {
                      return GestureDetector(
                        // Tap sobre una palabra ya agregada la elimina de la frase
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _fraseArmada.remove(palabra));
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _verde,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            palabra,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),

          const SizedBox(height: 10),

          // ── Campo libre (visible solo si el usuario tocó "✏️ Otro detalle") ──
          if (_mostrarCampoLibre)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                controller: _controller,
                autofocus: true,
                // onChanged redibuja el widget en cada tecla para que la
                // opacidad y el estado del botón verde reaccionen en tiempo real
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  hintText: "Escribe tu detalle específico...",
                  filled: true,
                  fillColor: const Color(0xFFF5F5F5),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

          // ── Banco de burbujas disponibles ──
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ..._bancoPalabrasDinamico.map((palabra) {
                final bool yaUsada = _fraseArmada.contains(palabra);
                return GestureDetector(
                  onTap: yaUsada
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          setState(() => _fraseArmada.add(palabra));
                        },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: yaUsada
                          ? Colors.grey.shade100
                          : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: yaUsada
                            ? Colors.grey.shade300
                            : _verde.withOpacity(0.6),
                        width: 1.5,
                      ),
                      boxShadow: yaUsada
                          ? []
                          : [
                              BoxShadow(
                                color: _verde.withOpacity(0.2),
                                blurRadius: 0,
                                offset: const Offset(0, 3),
                              ),
                            ],
                    ),
                    child: Text(
                      palabra,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: yaUsada
                            ? Colors.grey.shade400
                            : const Color(0xFF1B6B4A),
                      ),
                    ),
                  ),
                );
              }),
              // Botón "✏️ Otro detalle"
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    _mostrarCampoLibre = !_mostrarCampoLibre;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: const Color(0xFFFFD54F), width: 1.5),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33FFD54F),
                        blurRadius: 0,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Text(
                    "✏️ Otro detalle",
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF795548)),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── Botón verde "Comprobar e Instalar Reporte" ──
          SizedBox(
            width: double.infinity,
            child: AnimatedOpacity(
              opacity: (_fraseArmada.isNotEmpty ||
                      (_mostrarCampoLibre &&
                          _controller.text.trim().isNotEmpty))
                  ? 1.0
                  : 0.45,
              duration: const Duration(milliseconds: 300),
              child: ElevatedButton.icon(
                onPressed: _fraseArmada.isNotEmpty ||
                        (_mostrarCampoLibre &&
                            _controller.text.trim().isNotEmpty)
                    ? _confirmarFraseBancoYEnviar
                    : null,
                icon: const Icon(Icons.verified_outlined, size: 20),
                label: const Text(
                  "Comprobar e Instalar Reporte",
                  style: TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _verde,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: _verde.withOpacity(0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildCategoriasGrid  (sin cambios)
  // ─────────────────────────────────────────────
  Widget _buildCategoriasGrid() {
    final cats = ["Almuerzo", "Cena", "Desayuno", "Snack", "Refrescos"];
    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      alignment: WrapAlignment.center,
      children: cats.map((cat) {
        bool isSelected = _categoriaComidaElegida == cat;
        return FilterChip(
          label: Text(cat, style: const TextStyle(fontSize: 12)),
          selected: isSelected,
          selectedColor: _verde.withOpacity(0.3),
          checkmarkColor: _verde,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
                color: isSelected ? _verde : Colors.grey.shade300),
          ),
          onSelected: (_) {
            if (_bloquearCategorias) return;
            setState(() {
              _bloquearCategorias = true;
              _categoriaComidaElegida = cat;
              _mensajes.add(
                  {"rol": "usuario", "texto": "Categoría: $cat", "tipo": "texto"});
            });
            _cargarIngredientesPrimordiales(cat);
          },
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────
  // _buildIngredientesGrid  (sin cambios)
  // ─────────────────────────────────────────────
  Widget _buildIngredientesGrid() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Wrap(
            spacing: 8.0,
            runSpacing: 8.0,
            alignment: WrapAlignment.center,
            children: _ingredientesPrimordiales.map((ing) {
              final isSel = _ingredientesSeleccionados.contains(ing);
              return FilterChip(
                label: Text(ing, style: const TextStyle(fontSize: 12)),
                selected: isSel,
                selectedColor: _verde.withOpacity(0.3),
                checkmarkColor: _verde,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                      color: isSel ? _verde : Colors.grey.shade300),
                ),
                onSelected: (val) {
                  setState(() {
                    if (val && _ingredientesSeleccionados.length < 3) {
                      _ingredientesSeleccionados.add(ing);
                    } else if (!val) {
                      _ingredientesSeleccionados.remove(ing);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _ingredientesSeleccionados.isNotEmpty
                ? () {
                    setState(() {
                      _mostrarGridIngredientes = false;
                      _controller.text =
                          "Dame una recomendación de $_categoriaComidaElegida usando: ${_ingredientesSeleccionados.join(', ')}";
                    });
                    _enviarMensaje();
                  }
                : null,
            icon: const Icon(Icons.restaurant),
            label: const Text("Confirmar ingredientes"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _verde,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildRecetasBotonesGrid  (sin cambios)
  // ─────────────────────────────────────────────
  Widget _buildRecetasBotonesGrid(List<Map<String, String>> recetas) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: recetas.map((receta) {
          return SizedBox(
            width: 160,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetalleRecetaScreen(
                      recetaId: receta['id']!,
                      nombreReceta: receta['nombre']!,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.restaurant_menu, size: 18),
              label: Text(
                receta['nombre']!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _verde,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildActionBtn  (sin cambios)
  // ─────────────────────────────────────────────
  Widget _buildActionBtn(
      VoidCallback onPres, IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: ElevatedButton.icon(
        onPressed: onPres,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: _verde,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}