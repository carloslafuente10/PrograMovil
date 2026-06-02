import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necesario para HapticFeedback
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'detalle_receta_screen.dart';
import 'voice_call_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'components/receta_card_widget.dart';
import 'voice_transition_screen.dart';

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
  bool _mostrarInterpretacionReporte = false;
  bool _mostrarDetalleManualExtendido = false;
  bool _mostrarPasoFinalTimbre = false;
  String _interpretacionIA = "";

  // ─────────────────────────────────────────────
  // VARIABLES DEL FLUJO DE REPORTE (GAMIFICADO)
  // ─────────────────────────────────────────────
  int _pasoReporte = 0;
  bool _bloquearReportes = false;
  String _categoriaReporteActual = "";
  String _subCategoriaReporteActual = "";
  bool _bloquearFlujoReporte = false;
  final List<String> _fraseArmada = [];
  bool _mostrarCampoLibre = false;

  // ─────────────────────────────────────────────
  // VARIABLES DEL NUEVO WIZARD DE REPORTES (IMAGEN)
  // ─────────────────────────────────────────────
  /// Paso actual del wizard visual (0-7):
  /// 0 = Selección categoría principal
  /// 1 = Selección subcategoría
  /// 2 = Selección de detalles (chips multi-select)
  /// 3 = Interpretando (loading IA)
  /// 4 = Veredicto A.L.I.C.I.A.
  /// 5 = Agregar contexto extra
  /// 6 = Revisar reporte
  /// 7 = Reporte enviado (éxito)
  /// 8 = Mis reportes (historial)
  int _wizardPaso = 0;

  /// Categoría elegida en paso 0 del wizard
  String _wizardCategoria = "";

  /// Subcategoría elegida en paso 1 del wizard
  String _wizardSubcategoria = "";

  /// Chips de detalles seleccionados en paso 2
  final List<String> _wizardDetallesSeleccionados = [];

  /// Chips de contexto seleccionados en paso 5
  final List<String> _wizardContextoSeleccionado = [];

  /// Campo libre de contexto (paso 5)
  String _wizardContextoLibre = "";

  /// ID del reporte generado (paso 7)
  String _wizardReporteId = "";

  /// Nivel de confianza IA (paso 4)
  int _wizardConfianzaIA = 0;

  /// Causa detectada por IA (paso 4)
  String _wizardCausaIA = "";

  // Mock data de historial de reportes (conectar a Firebase en el futuro)
  final List<Map<String, dynamic>> _historialReportes = [
    {
      "id": "ALICIA-24831",
      "titulo": "No carga imágenes",
      "estado": "ENVIADO",
      "hace": "Hace 1 min",
    },
    {
      "id": "ALICIA-24671",
      "titulo": "Problemas de login",
      "estado": "EN PROGRESO",
      "hace": "Hace 2 días",
    },
    {
      "id": "ALICIA-24412",
      "titulo": "La app se congela",
      "estado": "RESUELTO",
      "hace": "Hace 5 días",
    },
  ];

  late AnimationController _progressController;
  late Animation<double> _progressAnimation;
  double _progreso = 0.0;

  // ─────────────────────────────────────────────
  // VARIABLES DEL FLUJO DE AYUDA
  // ─────────────────────────────────────────────
  String? _categoriaComidaElegida;
  List<String> _ingredientesPrimordiales = [];
  final List<String> _ingredientesSeleccionados = [];
  bool _mostrarGridIngredientes = false;
  bool _bloquearCategorias = false;

  // ─────────────────────────────────────────────
  // VARIABLES DEL TEMPORIZADOR NATIVO
  // ─────────────────────────────────────────────
  Timer? _countdownTimer;
  Duration _timerDuration = Duration.zero;
  bool _timerActivo = false;

  List<String> _bancoPalabrasDinamico = [];

  // ─────────────────────────────────────────────
  // CONFIGURACIÓN GROQ / SYSTEM PROMPT (De tu compañero)
  // ─────────────────────────────────────────────
  final String _apiKeyGrok = dotenv.env['GROQ_API_KEY'] ?? '';
  final String _systemPrompt = """
Eres A.L.I.C.I.A., la chef virtual oficial del Mercado Andino.
Tu misión es asistir con recetas, reportes de errores y sugerencias basándote ÚNICAMENTE en el contexto que se te entregue.

REGLAS CRÍTICAS DE RESPUESTA:
1. Sé SÚPER CORTA y DIRECTA. Responde en un máximo de 2 o 3 líneas de texto.
2. NUNCA uses listas numeradas, viñetas ni textos largos. Todo debe ser un párrafo breve y fluido.
3. Mantén el tono entusiasta y usa metáforas culinarias rápidas (problemas = platos quemados, soluciones = recetas).
4. Usa pocos emojis de cocina y nunca reveles que eres una IA.

REGLA DE CALORÍAS Y TIEMPOS:
Nunca declares valores absolutos. SIEMPRE usa lenguaje de estimación.
  - Correcto: "Aproximadamente 350 calorías", "Alrededor de 20 minutos".
  - Prohibido: "Tiene 350 kcal", "Toma exactamente 20 minutos".
  - REGLA DEL TEMPORIZADOR: Cada vez que menciones una cantidad de tiempo en una receta o paso (ej. "alrededor de 10 minutos"), finaliza esa oración preguntando de forma natural si el usuario desea iniciar un temporizador.
Si el usuario responde afirmativamente ("sí", "dale", "inicia", "perfecto", "claro"), añade al FINAL de tu respuesta el comando oculto [TIMER:X] donde X es el número entero de minutos.
Este comando no debe ser leído en voz alta ni mostrado visualmente al usuario;
es solo una instrucción interna para la aplicación.

REGLA DE RECETAS PASO A PASO:
Jamás entregues la receta completa ni múltiples pasos en un solo mensaje.
Al confirmar una receta, pregunta: "¿Te parece si empezamos por el primer paso?" y detente.
Solo avanza al siguiente paso cuando el usuario lo confirme explícitamente.
REGLA DE PORCIONES DINÁMICAS:
Si el usuario pide adaptar para N personas, calcula tú mismo cada cantidad y devuélvela en texto fluido.
Prohibido pedirle al usuario que haga el cálculo por su cuenta.
REGLA DE PERSISTENCIA:
Si en un mensaje anterior confirmaste que una receta existe, mantén esa confirmación durante toda la conversación.
Jamás te contradigas diciendo que no cuentas con una receta que ya confirmaste.
""";

  @override
  void initState() {
    super.initState();
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
    _countdownTimer?.cancel();
    _progressController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _animarProgreso(double nuevoValor) {
    final double inicio = _progreso;
    _progressAnimation = Tween<double>(begin: inicio, end: nuevoValor).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.easeInOut),
    );
    _progressController.forward(from: 0);
    setState(() => _progreso = nuevoValor);
  }

  // ─────────────────────────────────────────────
  // MOTOR DEL TEMPORIZADOR (De tu compañero)
  // ─────────────────────────────────────────────
  void _iniciarTemporizador(int minutos) {
    _cancelarTemporizador();
    setState(() {
      _timerDuration = Duration(minutes: minutos);
      _timerActivo = true;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_timerDuration.inSeconds > 0) {
          _timerDuration -= const Duration(seconds: 1);
        } else {
          _cancelarTemporizador();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text("¡Listo! El tiempo del paso ha terminado 🍳"),
                ],
              ),
              backgroundColor: _verde,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      });
    });
  }

  void _cancelarTemporizador() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    if (mounted) setState(() => _timerActivo = false);
  }

  // ─────────────────────────────────────────────
  // SANITIZACIÓN DE RECETAS (De tu compañero)
  // ─────────────────────────────────────────────
  String _sanitizarRecetaParaContexto(Map<String, dynamic> data) {
    final String nombre = (data['nombre'] ?? '').toString().trim();
    final String categoria = (data['categoria'] ?? '').toString().trim();
    final String calorias = (data['calorias'] ?? '').toString().trim();
    final String tiempo = (data['tiempo'] ?? '').toString().trim();

    final List rawIng = data['ingredientes'] ?? [];
    final List<String> ingsLimpios = rawIng
        .map<String>((ing) {
          if (ing is Map) {
            final String nom =
                (ing['nombre'] ?? ing['name'] ?? ing['ingrediente'] ?? '')
                    .toString()
                    .trim();
            final String can =
                (ing['cantidad'] ??
                        ing['amount'] ??
                        ing['gramos'] ??
                        ing['unidades'] ??
                        '')
                    .toString()
                    .trim();
            final String uni = (ing['unidad'] ?? ing['unit'] ?? '')
                .toString()
                .trim();
            if (nom.isEmpty) return '';
            if (can.isNotEmpty && uni.isNotEmpty) return "$can $uni de $nom";
            if (can.isNotEmpty) return "$can de $nom";
            return nom;
          }
          return ing.toString().trim();
        })
        .where((s) => s.isNotEmpty)
        .toList();

    final List rawPasos = data['pasos'] ?? [];
    final List<String> pasosLimpios = rawPasos
        .map<String>((paso) {
          if (paso is Map) {
            return (paso['descripcion'] ??
                    paso['texto'] ??
                    paso['detalle'] ??
                    paso['step'] ??
                    paso.toString())
                .toString()
                .trim();
          }
          return paso.toString().trim();
        })
        .where((s) => s.isNotEmpty)
        .toList();

    final StringBuffer ctx = StringBuffer();
    if (nombre.isNotEmpty) ctx.writeln("RECETA: $nombre");
    if (categoria.isNotEmpty) ctx.writeln("  Categoría: $categoria");
    if (calorias.isNotEmpty) ctx.writeln("  Calorías aproximadas: $calorias");
    if (tiempo.isNotEmpty) ctx.writeln("  Tiempo aproximado: $tiempo");
    if (ingsLimpios.isNotEmpty)
      ctx.writeln("  Ingredientes: ${ingsLimpios.join(', ')}");
    for (int i = 0; i < pasosLimpios.length; i++) {
      ctx.writeln("  Paso ${i + 1}: ${pasosLimpios[i]}");
    }
    return ctx.toString();
  }

  String _construirPromptValidacion(
    String categoriaReporte,
    String subCategoria,
    String textoUsuario,
  ) {
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

  Future<String> _obtenerRespuestaDeGrok(String mensajeUsuario) async {
    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');
    List<Map<String, String>> historialParaApi = [
      {"role": "system", "content": _systemPrompt},
    ];
    for (var msg in _mensajes) {
      if (msg["tipo"] == "texto") {
        String roleApi = (msg["rol"] == "usuario") ? "user" : "assistant";
        historialParaApi.add({"role": roleApi, "content": msg["texto"] ?? ""});
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
          "temperature": 0.4,
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

  Future<bool> _verificarRecetaEnFirebase(String texto) async {
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      return true;
    } catch (e) {
      debugPrint("Error Firebase: $e");
      return false;
    }
  }

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
  // BÚSQUEDA DE RECETAS (Fusión Porcentajes + Contexto)
  // ─────────────────────────────────────────────
  Future<void> _buscarRecetasRecomendadas() async {
    if (_categoriaComidaElegida == null || _ingredientesSeleccionados.isEmpty)
      return;
    setState(() => _estaCargando = true);
    try {
      final variantes = _generarVariantes(_categoriaComidaElegida!);
      final snapshot = await FirebaseFirestore.instance
          .collection('app-recetas-completas')
          .where(
            Filter.or(
              Filter('categoria', whereIn: variantes),
              Filter('categoría', whereIn: variantes),
            ),
          )
          .get();

      List<Map<String, dynamic>> recetasEncontradas = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final String contextoSanitizado = _sanitizarRecetaParaContexto(
          data,
        ); // De tu compañero
        List ingredientesDoc = data['ingredientes'] ?? [];

        List<String> nombresReceta = ingredientesDoc
            .map(
              (i) =>
                  (i is Map
                          ? (i['nombre'] ??
                                i['name'] ??
                                i['ingrediente_id'] ??
                                '')
                          : i.toString())
                      .toString()
                      .trim()
                      .toLowerCase()
                      .replaceAll('-', ' '),
            )
            .where((n) => n.isNotEmpty)
            .toList();

        if (nombresReceta.isEmpty) continue;

        int coincidencias = 0;
        for (String ingSel in _ingredientesSeleccionados) {
          if (nombresReceta.any(
            (nr) =>
                nr.contains(ingSel.toLowerCase().trim()) ||
                ingSel.toLowerCase().trim().contains(nr),
          )) {
            coincidencias++;
          }
        }

        // Lógica de porcentajes y límite visual (Tu lógica)
        if (coincidencias > 0) {
          double porcentaje = (coincidencias / nombresReceta.length) * 100;
          if (porcentaje > 100) porcentaje = 100.0;

          recetasEncontradas.add({
            'id': doc.id,
            'nombre': data['nombre']?.toString() ?? "Receta",
            'img': data['imagen']?.toString() ?? '',
            'calorias':
                (data['calorías'] ?? data['calorias'])?.toString() ?? '—',
            'tiempo': data['tiempo']?.toString() ?? '—',
            'categoria':
                (data['categoría'] ?? data['categoria'])?.toString() ?? '',
            'porcentaje': porcentaje,
            'contexto':
                contextoSanitizado, // Listo para inyectar si se necesita
          });
        }
      }

      recetasEncontradas.sort(
        (a, b) =>
            (b['porcentaje'] as double).compareTo(a['porcentaje'] as double),
      );
      if (recetasEncontradas.length > 4) {
        recetasEncontradas = recetasEncontradas.sublist(0, 4);
      }

      setState(() {
        if (recetasEncontradas.isEmpty) {
          _mensajes.add({
            "rol": "llama",
            "texto":
                "He buscado en mi alacena pero no tengo una receta exacta con esa combinación. 🥣 ¿Intentamos con otros ingredientes?",
            "tipo": "texto",
          });
        } else {
          _mensajes.add({
            "rol": "llama",
            "texto":
                "¡He encontrado el maridaje perfecto! 👨‍🍳 Aquí tienes las opciones que mejor combinan con tu selección.",
            "tipo": "recetas_grid",
            "recetas": recetasEncontradas,
          });
        }
      });
    } catch (e) {
      debugPrint("Error buscar recetas: $e");
      setState(
        () => _mensajes.add({
          "rol": "llama",
          "texto": "Se nos ha derramado el caldo... Error en la conexión.",
          "tipo": "texto",
        }),
      );
    } finally {
      setState(() => _estaCargando = false);
    }
  }

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
      _pasoReporte = 0;
      _fraseArmada.clear();
      _mostrarCampoLibre = false;
      _animarProgreso(0.0);

      String saludoChef;
      String tipoMensaje = "texto";

      if (titulo == "Reporte") {
        // Resetear wizard visual
        _wizardPaso = 0;
        _wizardCategoria = "";
        _wizardSubcategoria = "";
        _wizardDetallesSeleccionados.clear();
        _wizardContextoSeleccionado.clear();
        _wizardContextoLibre = "";
        _wizardReporteId = "";
        _wizardConfianzaIA = 0;
        _wizardCausaIA = "";

        saludoChef =
            "¡Alto al fuego en la cocina! 🍳 Vamos a documentar tu reporte paso a paso. Primero, ¿qué área está quemada?";
        tipoMensaje = "botones_reporte_categorias";
        _esperandoDetalleReporte = true;
        _animarProgreso(0.0);
      } else if (titulo == "Ayuda") {
        saludoChef =
            "Aquí estoy para guiarte en tu siguiente comida. Por favor selecciona una categoría:";
        tipoMensaje = "botones_categoria";
      } else if (titulo == "Consulta Especifica") {
        saludoChef =
            "¡Entrando comandas de alta cocina! 🚀 Escribe libremente tu inquietud culinaria o técnica.";
      } else {
        saludoChef =
            "¡Me encanta experimentar! Cuéntame tu idea completa (Nombre, ingredientes y toque especial) en un solo párrafo. 📝";
        _esperandoParrafoSugerencia = true;
      }

      _mensajes.add({"rol": "llama", "texto": saludoChef, "tipo": tipoMensaje});
    });
  }

  void _seleccionarCategoriaReporte(String categoria) {
    if (_bloquearReportes) return;
    HapticFeedback.lightImpact();
    setState(() {
      _bloquearReportes = true;
      _categoriaReporteActual = categoria;
      _esperandoDetalleReporte = true;
      _pasoReporte = 1;
      _mensajes.add({"rol": "usuario", "texto": categoria, "tipo": "texto"});
      List<String> subCats = [];
      if (categoria.contains("Contenido")) {
        subCats = [
          "Receta mal explicada",
          "Ingredientes erróneos",
          "Imágenes rotas",
        ];
      } else if (categoria.contains("experiencia")) {
        subCats = [
          "Navegación confusa",
          "Letra muy pequeña",
          "Diseño incómodo",
        ];
      } else {
        subCats = [
          "Cierre inesperado (Crash)",
          "Error de base de datos",
          "Carga lenta / Lag",
        ];
      }
      _mensajes.add({
        "rol": "llama",
        "texto":
            "Perfecto chef. Ahora elige el problema específico que encontraste:",
        "tipo": "botones_reporte_subcategorias",
        "opciones": subCats,
        "categoria_reporte": categoria,
      });
    });
    _animarProgreso(0.33);
  }

  void _seleccionarSubcategoriaReporte(String subcat) {
    if (_bloquearFlujoReporte) return;
    HapticFeedback.lightImpact();
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
      _bancoPalabrasDinamico = nuevoBanco;
      _mensajes.add({
        "rol": "usuario",
        "texto": "Problema específico: $subcat",
        "tipo": "texto",
      });
      _mensajes.add({
        "rol": "llama",
        "texto":
            "¡Comanda anotada! 📋 Ahora arma tu descripción tocando las burbujas en orden:",
        "tipo": "texto",
      });
    });
    _animarProgreso(0.66);
  }

  Future<void> _confirmarFraseBancoYEnviar() async {
    final String textoFinal =
        _mostrarCampoLibre && _controller.text.trim().isNotEmpty
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
      String promptValidacion = _construirPromptValidacion(
        _categoriaReporteActual,
        _subCategoriaReporteActual,
        textoFinal,
      );
      final respuestaValidacion = await _obtenerRespuestaDeGrok(
        promptValidacion,
      );
      if (respuestaValidacion.trim().toUpperCase().contains("INVALIDO")) {
        setState(() {
          _estaCargando = false;
          _pasoReporte = 2;
          _fraseArmada.clear();
          _animarProgreso(0.66);
          _mensajes.add({
            "rol": "llama",
            "tipo": "texto",
            "texto":
                "¡Uy chef! Esa combinación de ingredientes no describe un problema de la app. 🍳 Intenta de nuevo con las burbujas.",
          });
        });
        return;
      }

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
                : "¡Uy chef! Revisé en Firebase y ese platillo o ingrediente no está registrado en nuestro recetario.",
          });
          _mensajes.add({
            "rol": "llama",
            "tipo": "sugerencia_btn",
            "texto":
                "¿Deseas enviar formalmente esta comanda de error al plantel administrativo?",
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
          _mensajes.add({
            "rol": "llama",
            "tipo": "texto",
            "texto": respuestaIA,
          });
          _mensajes.add({
            "rol": "llama",
            "tipo": "sugerencia_btn",
            "texto":
                "¿Deseas enviar formalmente esta comanda de error al plantel administrativo?",
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
          "texto":
              "¡Vaya, el horno se apagó! Pero guardé tu comanda. ¿La enviamos de igual forma?",
        });
      });
    }
  }

  Future<void> _cargarIngredientesPrimordiales(String categoria) async {
    setState(() => _estaCargando = true);
    try {
      final variantes = _generarVariantes(categoria);
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
            String nom = (ing['nombre'] ?? ing['ingrediente_id'] ?? '')
                .toString()
                .replaceAll('-', ' ')
                .trim();
            if (nom.isNotEmpty) {
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
          "texto": "Por favor elige los ingredientes disponibles:",
          "tipo": "grid_ingredients",
        });
      });
    } catch (e) {
      debugPrint("Error DB: $e");
    } finally {
      setState(() => _estaCargando = false);
    }
  }

  // ─────────────────────────────────────────────
  // ENVÍO DE MENSAJES (Fusión Regex Temporizador)
  // ─────────────────────────────────────────────
  Future<void> _enviarMensaje() async {
    final textoOriginal = _controller.text.trim();
    if (textoOriginal.isEmpty) return;

    setState(() {
      _mensajes.add({
        "rol": "usuario",
        "texto": textoOriginal,
        "tipo": "texto",
      });
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
          "texto":
              "¡Qué aroma tan increíble! Pulsa abajo para enviar tu creación al Chef mayor.",
        });
      });
      return;
    }

    try {
      final respuesta = await _obtenerRespuestaDeGrok(textoOriginal);

      // Motor Regex del Temporizador (De tu compañero)
      final timerMatch = RegExp(r'\[TIMER:(\d+)\]').firstMatch(respuesta);
      final String respuestaLimpia = respuesta
          .replaceAll(RegExp(r'\[TIMER:\d+\]'), '')
          .trim();

      if (timerMatch != null) {
        _iniciarTemporizador(int.parse(timerMatch.group(1)!));
      }

      setState(() {
        _mensajes.add({
          "rol": "llama",
          "tipo": "texto",
          "texto": respuestaLimpia,
        });
      });
    } catch (e) {
      setState(
        () => _mensajes.add({
          "rol": "llama",
          "texto": "Disculpa, creo que no entendí lo que intentaste decir.",
        }),
      );
    } finally {
      setState(() => _estaCargando = false);
    }
  }

  // ─────────────────────────────────────────────
  // LÓGICA DE ENVÍO DE REPORTES Y EMAILJS (Tu lógica)
  // ─────────────────────────────────────────────
  Future<void> _procesarEnvioAlAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Error: Debes iniciar sesión para reportar."),
        ),
      );
      return;
    }

    setState(() => _estaCargando = true);
    try {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);
      final Timestamp inicioDeHoy = Timestamp.fromDate(startOfDay);

      final snapshot = await FirebaseFirestore.instance
          .collection('app_reportes')
          .where('uid', isEqualTo: user.uid)
          .where('fecha', isGreaterThanOrEqualTo: inicioDeHoy)
          .count()
          .get();

      if (snapshot.count != null && snapshot.count! >= 3) {
        setState(() {
          _estaCargando = false;
          _mensajes.add({
            "rol": "llama",
            "tipo": "texto",
            "texto":
                "¡Límite alcanzado! 🛑 Ya has enviado 3 reportes hoy. Nuestros ingenieros están revisando tus comandas. Vuelve a intentarlo mañana.",
          });
        });
        return;
      }

      String textoReporte = "Sin detalle";
      if (_mensajes.length >= 2) {
        textoReporte =
            _mensajes[_mensajes.length - 2]["texto"] ?? "Sin detalle";
      }

      await FirebaseFirestore.instance.collection('app_reportes').add({
        'uid': user.uid,
        'categoria': _categoriaReporteActual,
        'subcategoria': _subCategoriaReporteActual,
        'detalle': textoReporte,
        'fecha': FieldValue.serverTimestamp(),
      });

      final url = Uri.parse('https://api.emailjs.com/api/v1.0/email/send');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'service_id': 'service_p1xoabd',
          'template_id': 'template_olqqlqg',
          'user_id': 'ldU0dd5S1pMTSYDwk',
          'template_params': {
            'user_uid': user.uid,
            'categoria': _categoriaReporteActual,
            'subcategoria': _subCategoriaReporteActual,
            'detalle': textoReporte,
          },
        }),
      );
      if (response.statusCode != 200) {
        throw Exception("Fallo en la API de correos: ${response.body}");
      }

      setState(() {
        _estaCargando = false;
        _mensajes.add({
          "rol": "llama",
          "tipo": "texto",
          "texto":
              "¡Comanda entregada al Chef Mayor! 👨‍🍳 Tu reporte ha sido enviado con éxito al correo del administrador.",
        });
      });
    } catch (e) {
      debugPrint("Error al enviar reporte: $e");
      setState(() {
        _estaCargando = false;
        _mensajes.add({
          "rol": "llama",
          "tipo": "texto",
          "texto":
              "Se derramó la sopa en el servidor. Revisa tu conexión e intenta de nuevo.",
        });
      });
    }
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
          // Temporizador de tu compañero integrado en la vista
          _buildTimerWidget(),
        ],
      ),
    );
  }

  Widget _buildResponsiveLayout() {
    if (_categoriaActual == "Reporte") {
      return _buildReporteWizard();
    } else {
      return _buildChatLayout();
    }
  }

  // ═══════════════════════════════════════════════════════
  //  NUEVO WIZARD DE REPORTES — replica fiel de la imagen
  // ═══════════════════════════════════════════════════════

  // Paleta oscura del wizard (extrae los colores de la imagen)
  static const Color _wBg = Color(0xFF1A1035);
  static const Color _wCard = Color(0xFF231845);
  static const Color _wCardBorder = Color(0xFF3A2E5E);
  static const Color _wGreen = Color(0xFF4DDB6B);
  static const Color _wGreenDark = Color(0xFF2DBB50);
  static const Color _wPurple = Color(0xFF7B5EA7);
  static const Color _wYellow = Color(0xFFFFCC00);
  static const Color _wRed = Color(0xFFFF4E6A);
  static const Color _wBlue = Color(0xFF4E9EFF);
  static const Color _wText = Color(0xFFECE8FF);
  static const Color _wTextSub = Color(0xFFAA9FCF);

  // ═══════════════════════════════════════════════════════════════
  // MAPA DE DATOS: categorías → subcategorías → grupos de burbujas
  // Modificar aquí para añadir/quitar opciones sin tocar widgets
  // ═══════════════════════════════════════════════════════════════
  static const Map<String, List<Map<String, dynamic>>> _mapaReportes = {
    "Problemas de contenido": [
      {
        "titulo": "Receta mal explicada",
        "icono": "menu_book",
        "grupos": [
          {
            "etiqueta": null,
            "burbujas": [
              "En el paso", "Está confuso", "No se entiende",
              "La explicación", "Falta", "El tiempo de cocción",
              "Las instrucciones"
            ]
          }
        ]
      },
      {
        "titulo": "Ingredientes erróneos",
        "icono": "eco",
        "grupos": [
          {
            "etiqueta": null,
            "burbujas": [
              "El ingrediente", "La cantidad", "Falta",
              "No coincide", "Los gramos", "Está mal",
              "En la preparación"
            ]
          }
        ]
      },
      {
        "titulo": "Imágenes rotas",
        "icono": "broken_image",
        "grupos": [
          {
            "etiqueta": null,
            "burbujas": [
              "La imagen", "No carga", "Se ve rota",
              "Falta", "En el servidor", "Está en blanco",
              "Tiene un error"
            ]
          }
        ]
      },
    ],
    "Problemas con la experiencia": [
      {
        "titulo": "Navegación confusa",
        "icono": "explore",
        "grupos": [
          {
            "etiqueta": null,
            "burbujas": [
              "La pantalla", "No funciona", "Se congela",
              "Al presionar", "Falta", "Carga Lenta",
              "No responde"
            ]
          }
        ]
      },
      {
        "titulo": "Letra muy pequeña",
        "icono": "text_fields",
        "grupos": [
          {
            "etiqueta": null,
            "burbujas": [
              "No se lee", "Es ilegible", "Está muy junta",
              "Falta contraste", "Se corta"
            ]
          }
        ]
      },
      {
        "titulo": "Diseño incómodo",
        "icono": "dashboard_customize",
        "grupos": [
          {
            "etiqueta": null,
            "burbujas": [
              "Están muy juntos", "Muy pequeños", "Se superponen",
              "Están muy abajo / Muy arriba", "Es confuso",
              "No se nota"
            ]
          }
        ]
      },
    ],
    "Fallas técnicas": [
      {
        "titulo": "Cierre inesperado",
        "icono": "power_off",
        "grupos": [
          {
            "etiqueta": "¿En qué momento ocurrió?",
            "burbujas": [
              "Al abrir la app", "Al tocar una receta",
              "A mitad de la cocina", "Al usar el asistente",
              "Al cargar una imagen"
            ]
          },
          {
            "etiqueta": "¿Qué comportamiento viste?",
            "burbujas": [
              "Se cierra sola", "Vuelve al inicio",
              "Pantalla en negro", "Me saca del perfil"
            ]
          }
        ]
      },
      {
        "titulo": "Error al cargar el contenido",
        "icono": "cloud_off",
        "grupos": [
          {
            "etiqueta": "¿Qué faltó o no cargó?",
            "burbujas": [
              "La foto de la receta", "La lista de ingredientes",
              "El temporizador", "Los comentarios",
              "El chat de ALICIA"
            ]
          },
          {
            "etiqueta": "¿Qué estado viste?",
            "burbujas": [
              "Se queda en blanco", "Dice \"Error de conexión\"",
              "Aparece un símbolo de carga",
              "No encuentra el contenido", "Sale un texto roto"
            ]
          }
        ]
      },
      {
        "titulo": "Carga Lenta / Lag",
        "icono": "speed",
        "grupos": [
          {
            "etiqueta": "¿Al hacer qué acción?",
            "burbujas": [
              "Al buscar recetas", "Al pasar de pantalla",
              "Al hacer scroll/desplazar", "Al activar el timer"
            ]
          },
          {
            "etiqueta": "¿Qué sensación tuviste?",
            "burbujas": [
              "Va a tirones", "Se congela unos segundos",
              "Tarda demasiado", "Reacciona tarde",
              "Se siente pesada"
            ]
          }
        ]
      },
    ],
  };

  // ─────────────────────────────────────────────────────────────
  // Helper: icono string → IconData
  // ─────────────────────────────────────────────────────────────
  IconData _iconoDesdeString(String nombre) {
    switch (nombre) {
      case "menu_book": return Icons.menu_book_outlined;
      case "eco": return Icons.eco_outlined;
      case "broken_image": return Icons.broken_image_outlined;
      case "explore": return Icons.explore_outlined;
      case "text_fields": return Icons.text_fields;
      case "dashboard_customize": return Icons.dashboard_customize_outlined;
      case "power_off": return Icons.power_off_outlined;
      case "cloud_off": return Icons.cloud_off_outlined;
      case "speed": return Icons.speed_outlined;
      default: return Icons.help_outline;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Helper: generar respuesta interpretada de ALICIA
  // ─────────────────────────────────────────────────────────────
  String _generarRespuestaAlicia() {
    final String cat = _wizardCategoria;
    final String sub = _wizardSubcategoria;
    final List<String> sel = List<String>.from(_wizardDetallesSeleccionados);
    final String burbujas = sel.isEmpty
        ? "el problema indicado"
        : sel.length == 1
            ? '"${sel[0]}"'
            : sel.sublist(0, sel.length - 1).map((b) => '"$b"').join(", ") +
              ' y "${sel.last}"';

    String base =
        "Entiendo que estás teniendo problemas con \"$sub\" dentro de \"$cat\". "
        "Según lo que marcaste, el inconveniente está relacionado con $burbujas. ";

    // Respuesta contextual según categoría y subcategoría
    if (cat == "Problemas de contenido") {
      if (sub == "Receta mal explicada") {
        base += "Parece que algún paso o instrucción en la receta no está claro o falta información clave. "
            "Lo reportaré al equipo de contenido para que revisen y corrijan esa sección. 📋";
      } else if (sub == "Ingredientes erróneos") {
        base += "Puede que algún ingrediente, su cantidad o unidad de medida no coincida con lo esperado. "
            "Nuestro equipo lo verificará contra la receta original. 🥄";
      } else {
        base += "Las imágenes pueden no haberse cargado correctamente desde el servidor. "
            "Le avisaré al equipo técnico para que revisen los recursos visuales. 🖼️";
      }
    } else if (cat == "Problemas con la experiencia") {
      if (sub == "Navegación confusa") {
        base += "Parece que hay una pantalla o botón que no responde como debería. "
            "Nuestro equipo de UX revisará ese flujo de navegación. 🧭";
      } else if (sub == "Letra muy pequeña") {
        base += "El tamaño o contraste del texto puede estar afectando la legibilidad. "
            "Tomaré nota para que el equipo de diseño ajuste la tipografía. 🔠";
      } else {
        base += "Algunos elementos del diseño pueden estar mal posicionados o superpuestos. "
            "El equipo de interfaz lo revisará en la próxima actualización. 🎨";
      }
    } else {
      // Fallas técnicas
      if (sub == "Cierre inesperado") {
        base += "La app parece estar cerrándose de forma inesperada en ese momento específico. "
            "Le pasaré los detalles exactos al equipo de ingeniería para rastrear el error. 🔧";
      } else if (sub == "Error al cargar el contenido") {
        base += "Parece que hay un problema al obtener o mostrar ciertos datos desde el servidor. "
            "Nuestros ingenieros revisarán los logs de carga de ese contenido. ☁️";
      } else {
        base += "El rendimiento de la app en ese punto puede estar siendo afectado por procesos internos. "
            "Lo escalaré al equipo de optimización con los detalles que me diste. ⚡";
      }
    }

    if (_wizardContextoLibre.trim().isNotEmpty) {
      base += "\n\nAdemás agregaste: \"${_wizardContextoLibre.trim()}\". Ese detalle extra ayudará mucho al diagnóstico. 🙌";
    }

    return base;
  }

  // ═══════════════════════════════════════════════════════
  // WIZARD PRINCIPAL
  // ═══════════════════════════════════════════════════════
  Widget _buildReporteWizard() {
    return Stack(
      children: [
        // Fondo: imagen de Alicia en el país de las maravillas
        Positioned.fill(
          child: Image.asset(
            'assets/images/fondo_alicia.webp',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D0826), Color(0xFF1A1035), Color(0xFF2B0E4B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
        ),
        // Capa de oscurecimiento semi-transparente para legibilidad
        Positioned.fill(
          child: Container(color: const Color(0xCC0D0826)),
        ),
        // Contenido del wizard
        Column(
          children: [
            _buildWizardHeader(),
            Expanded(child: _buildWizardStep()),
          ],
        ),
      ],
    );
  }

  /// Barra superior con pasos y flecha atrás
  Widget _buildWizardHeader() {
  // CAMBIO 1: Ahora el total real de pasos con barra secuencial es 6 (del Paso 0 al Paso 5)
  const int totalPasos = 6; 
  
  // CAMBIO 2: La barra se mostrará solo del paso 0 al 5. Al llegar al paso 6 (Mis Reportes) se oculta.
  final bool mostrarBarra = _wizardPaso < 6;

  return Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
    color: _wBg,
    child: Column(
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: _wText, size: 22),
              onPressed: () {
                if (_wizardPaso == 0) {
                  setState(() {
                    _opcionSeleccionada = false;
                    _mensajes.clear();
                    _animarProgreso(0.0);
                  });
                } else if (_wizardPaso == 8) { 
                  // Mantenemos tus condiciones preventivas de navegación por seguridad
                  setState(() => _wizardPaso = 7);
                } else {
                  setState(() => _wizardPaso = (_wizardPaso - 1).clamp(0, 8));
                }
              },
            ),
            const Expanded(
              child: Text(
                "Reportes",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _wText,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  letterSpacing: 0.3,
                ),
              ),
            ),
            const SizedBox(width: 44), // balance
          ],
        ),
        if (mostrarBarra) ...[
          const SizedBox(height: 6),
          _buildWizardProgressDots(totalPasos),
        ],
      ],
    ),
  );
}

  Widget _buildWizardProgressDots(int total) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final bool activo = i == _wizardPaso;
        final bool pasado = i < _wizardPaso;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: activo ? 24 : 10,
              height: 10,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(5),
                color: activo
                    ? _wGreen
                    : pasado
                        ? _wGreenDark
                        : _wCardBorder,
              ),
            ),
            if (i < total - 1)
              Container(
                width: 18,
                height: 2,
                color: pasado ? _wGreenDark : _wCardBorder,
                margin: const EdgeInsets.symmetric(horizontal: 3),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildWizardStep() {
    switch (_wizardPaso) {
      case 0: return _buildWizardPaso0CategoriaPrincipal();
      case 1: return _buildWizardPaso1Subcategoria();
      case 2: return _buildWizardPaso2Burbujas();
      case 3: return _buildWizardPaso3Interpretando();
      case 4: return _buildWizardPaso4AliciaInterpreta();
      case 5: return _buildWizardPaso5Enviado();
      case 6: return _buildWizardPaso6MisReportes();
      default: return _buildWizardPaso0CategoriaPrincipal();
    }
  }

  // ══════════════════════════════════════════════════════════════
  // VENTANA 1: Categorías principales
  // ══════════════════════════════════════════════════════════════
  Widget _buildWizardPaso0CategoriaPrincipal() {
  final List<Map<String, dynamic>> categorias = [
    {
      "titulo": "Problemas de contenido",
      "subtitulo": "Recetas, imágenes, ingredientes",
      "icono": Icons.menu_book_outlined,
      "color": const Color(0xFFFF9B3D),
      "colorBg": const Color(0xFF3D2410),
    },
    {
      "titulo": "Problemas con la experiencia",
      "subtitulo": "Navegación, diseño, legibilidad",
      "icono": Icons.explore_outlined,
      "color": const Color(0xFF9B6EFF),
      "colorBg": const Color(0xFF2B1F55),
    },
    {
      "titulo": "Fallas técnicas",
      "subtitulo": "Cierres, carga lenta, errores",
      "icono": Icons.build_circle_outlined,
      "color": const Color(0xFFFF4E6A),
      "colorBg": const Color(0xFF3D0F18),
    },
  ];

  return Stack(
    children: [
      // 1. Imagen de fondo de Alicia que cubre toda la sección
      Positioned.fill(
        child: Image.asset(
          'assets/images/fondo_alicia.png', // <-- Asegúrate de colocar aquí la ruta correcta de tu PNG
          fit: BoxFit.cover,
        ),
      ),
      
      // 2. Contenido interactivo (Textos y Botones) por encima del fondo
      SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              "¿Qué ocurrió? 🍳",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _wText,
                fontWeight: FontWeight.w800,
                fontSize: 24,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Te ayudaré a identificar tu problema\ny enviarlo al equipo correcto.",
              textAlign: TextAlign.center,
              style: TextStyle(color: _wTextSub, fontSize: 13),
            ),
            
            // ─── ESPACIADOR PARA BAJAR LOS BOTONES ───────────────────
            // Ajusta este número (por ejemplo, 140, 160 o 180) para calibrar 
            // con precisión a qué altura del mostrador quieres que inicien.
            SizedBox(height: MediaQuery.of(context).size.height * 0.48),
            // ─────────────────────────────────────────────────────────
            
            ...categorias.map((cat) {
              return GestureDetector(
                onTap: () {
                  // TODO: registrar categoría en analytics al seleccionar
                  HapticFeedback.lightImpact();
                  setState(() {
                    _wizardCategoria = cat["titulo"] as String;
                    _wizardSubcategoria = "";
                    _wizardDetallesSeleccionados.clear();
                  });
                  Future.delayed(
                    const Duration(milliseconds: 200),
                    () => setState(() => _wizardPaso = 1),
                  );
                },
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
                  decoration: BoxDecoration(
                    color: (cat["colorBg"] as Color).withOpacity(0.85),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: (cat["color"] as Color).withOpacity(0.5),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (cat["color"] as Color).withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (cat["color"] as Color).withOpacity(0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          cat["icono"] as IconData,
                          color: cat["color"] as Color,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cat["titulo"] as String,
                              style: TextStyle(
                                color: cat["color"] as Color,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              cat["subtitulo"] as String,
                              style: const TextStyle(
                                color: _wTextSub,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: _wTextSub,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    ],
  );
}
  // ══════════════════════════════════════════════════════════════
  // VENTANA 2: Subcategorías (dependen de categoría elegida)
  // ══════════════════════════════════════════════════════════════
  Widget _buildWizardPaso1Subcategoria() {
    final List<Map<String, dynamic>> subcats =
        (_mapaReportes[_wizardCategoria] ?? []).map((s) {
      return {
        "titulo": s["titulo"] as String,
        "icono": _iconoDesdeString(s["icono"] as String),
      };
    }).toList();

    // Colores por categoría padre
    final Color colorPadre = _wizardCategoria == "Problemas de contenido"
        ? const Color(0xFFFF9B3D)
        : _wizardCategoria == "Problemas con la experiencia"
            ? const Color(0xFF9B6EFF)
            : const Color(0xFFFF4E6A);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Miga de pan
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: colorPadre.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colorPadre.withOpacity(0.4)),
                ),
                child: Text(
                  _wizardCategoria,
                  style: TextStyle(
                    color: colorPadre,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            "Selecciona una subcategoría",
            style: TextStyle(
              color: _wText,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            "¿Qué parte de la app tiene el problema?",
            style: TextStyle(color: _wTextSub, fontSize: 13),
          ),
          const SizedBox(height: 20),
          ...subcats.map((sub) {
            return GestureDetector(
              onTap: () {
                // TODO: registrar subcategoría elegida para métricas
                HapticFeedback.lightImpact();
                setState(() {
                  _wizardSubcategoria = sub["titulo"] as String;
                  _wizardDetallesSeleccionados.clear();
                  _wizardContextoLibre = "";
                });
                Future.delayed(
                  const Duration(milliseconds: 200),
                  () => setState(() => _wizardPaso = 2),
                );
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: _wCard.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _wCardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorPadre.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        sub["icono"] as IconData,
                        color: colorPadre,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        sub["titulo"] as String,
                        style: const TextStyle(
                          color: _wText,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: _wTextSub, size: 20),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // VENTANA 3: Burbujas / frases clave (multi-select + detalle propio)
  // ══════════════════════════════════════════════════════════════
  Widget _buildWizardPaso2Burbujas() {
    // Obtener los grupos de burbujas para la subcategoría actual
    final List<Map<String, dynamic>> subcats =
        _mapaReportes[_wizardCategoria] ?? [];
    final Map<String, dynamic>? subcatData = subcats.cast<Map<String, dynamic>?>()
        .firstWhere(
          (s) => s != null && s["titulo"] == _wizardSubcategoria,
          orElse: () => null,
        );
    final List<dynamic> grupos =
        subcatData != null ? (subcatData["grupos"] as List<dynamic>) : [];

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Selecciona lo que coincide",
                  style: TextStyle(
                    color: _wText,
                    fontWeight: FontWeight.w800,
                    fontSize: 21,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Puedes elegir varias opciones",
                  style: TextStyle(color: _wTextSub, fontSize: 13),
                ),
                const SizedBox(height: 18),

                // Renderizar grupos de burbujas
                ...grupos.map((grupo) {
                  final String? etiqueta = grupo["etiqueta"] as String?;
                  final List<String> burbujas =
                      (grupo["burbujas"] as List<dynamic>).cast<String>();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (etiqueta != null) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _wPurple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            etiqueta,
                            style: const TextStyle(
                              color: _wPurple,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: burbujas.map((burbuja) {
                          final bool sel =
                              _wizardDetallesSeleccionados.contains(burbuja);
                          return GestureDetector(
                            onTap: () {
                              // TODO: actualizar contadores de burbujas en analytics
                              HapticFeedback.lightImpact();
                              setState(() {
                                if (sel) {
                                  _wizardDetallesSeleccionados.remove(burbuja);
                                } else {
                                  _wizardDetallesSeleccionados.add(burbuja);
                                }
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: sel
                                    ? _wGreen.withOpacity(0.2)
                                    : _wCard.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: sel ? _wGreen : _wCardBorder,
                                  width: sel ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    burbuja,
                                    style: TextStyle(
                                      color: sel ? _wGreen : _wText,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (sel) ...[
                                    const SizedBox(width: 6),
                                    const Icon(
                                      Icons.check_circle,
                                      color: _wGreen,
                                      size: 15,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                    ],
                  );
                }),

                // Chip "Crear detalle propio"
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    setState(() => _mostrarCampoLibre = !_mostrarCampoLibre);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A3E).withOpacity(0.85),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: _wYellow.withOpacity(0.6),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _mostrarCampoLibre
                              ? Icons.edit_off_outlined
                              : Icons.add,
                          color: _wYellow,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _mostrarCampoLibre
                              ? "Cerrar detalle propio"
                              : "+ Crear detalle propio",
                          style: const TextStyle(
                            color: _wYellow,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Campo libre de texto (detalle propio)
                if (_mostrarCampoLibre) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller,
                    style: const TextStyle(color: _wText, fontSize: 13),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: "Escribe tu detalle específico...",
                      hintStyle:
                          const TextStyle(color: _wTextSub, fontSize: 13),
                      filled: true,
                      fillColor: _wCard.withOpacity(0.9),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: _wCardBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: _wCardBorder),
                      ),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.add_circle, color: _wGreen),
                        onPressed: () {
                          final t = _controller.text.trim();
                          if (t.isNotEmpty) {
                            // TODO: guardar detalle personalizado junto a las burbujas
                            setState(() {
                              _wizardDetallesSeleccionados.add(t);
                              _controller.clear();
                              _mostrarCampoLibre = false;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 8),

                // Campo opcional: contexto libre (se guarda en _wizardContextoLibre)
                const SizedBox(height: 10),
                const Text(
                  "¿Quieres agregar más contexto? (opcional)",
                  style: TextStyle(
                      color: _wTextSub,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextField(
                  style: const TextStyle(color: _wText, fontSize: 13),
                  maxLines: 2,
                  onChanged: (v) => _wizardContextoLibre = v,
                  decoration: InputDecoration(
                    hintText:
                        "Ej: Solo me pasa al intentar subir fotos...",
                    hintStyle:
                        const TextStyle(color: _wTextSub, fontSize: 12),
                    filled: true,
                    fillColor: _wCard.withOpacity(0.9),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _wCardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: _wCardBorder),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        // Botón CONTINUAR
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _wizardDetallesSeleccionados.isEmpty
                  ? null
                  : () {
                      // TODO: guardar selección en Firestore antes de avanzar
                      HapticFeedback.mediumImpact();
                      setState(() {
                        _mostrarCampoLibre = false;
                        _wizardPaso = 3;
                      });
                      _iniciarInterpretacionIA();
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _wGreen,
                disabledBackgroundColor: _wCardBorder,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                "CONTINUAR",
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // VENTANA 4: Interpretando (pantalla de carga)
  // ══════════════════════════════════════════════════════════════
 Widget _buildWizardPaso3Interpretando() {
  final size = MediaQuery.of(context).size;

  return Stack(
    children: [
      // 1. Imagen de fondo .webp que cubre absolutamente toda la pantalla
      Positioned.fill(
        child: Image.asset(
          'assets/images/alicia_interpreta.webp',
          fit: BoxFit.cover,
        ),
      ),

      // 2. Capa de contraste oscura para que los textos no se pierdan con el fondo
      Positioned.fill(
        child: Container(
          color: Colors.black.withOpacity(0.45), // Ajusta el nivel de oscuridad si prefieres
        ),
      ),

      // 3. Contenido interactivo desplazado drásticamente hacia arriba de manera segura
      Positioned(
        top: size.height * 0.05, // <-- MODIFICADO: Cambiado de 0.15 a 0.05 para subir el bloque por completo
        left: 0,
        right: 0,
        bottom: 0, // Mantiene el espacio inferior disponible para el scroll si fuera necesario
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start, // Mantener empujado hacia el inicio superior
            children: [
              // Espacio superior mínimo equilibrado para no chocar con la barra de estado
              const SizedBox(height: 10), // <-- MODIFICADO: Ajustado de 20 a 10
              
              const Text(
                "Interpretando tu reporte...",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _wText,
                  fontWeight: FontWeight.w800,
                  fontSize: 24, // Subimos ligeramente el tamaño para darle más peso
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Estoy analizando la información para\nencontrar la causa más probable.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _wTextSub, 
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 40),
              
              // Barra de progreso con sus colores e integridad original
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: const LinearProgressIndicator(
                  backgroundColor: _wCardBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(_wGreen),
                  minHeight: 6,
                ),
              ),
              const SizedBox(height: 24),
              
              // Texto informativo inferior con la estrella dorada
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: _wYellow, size: 14),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      "T'anta-Wawa está revisando patrones,\nregistros y posibles soluciones.",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _wYellow.withOpacity(0.9),
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
  // ══════════════════════════════════════════════════════════════
  // VENTANA 5: ALICIA interpreta — bocadillo + respuesta contextual
  // ══════════════════════════════════════════════════════════════
  Widget _buildWizardPaso4AliciaInterpreta() {
    final String respuesta = _generarRespuestaAlicia();

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Veredicto de A.L.I.C.I.A.",
                  style: TextStyle(
                    color: _wText,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  "Esto es lo que encontré:",
                  style: TextStyle(color: _wTextSub, fontSize: 13),
                ),
                const SizedBox(height: 20),

                // Avatar + bocadillo de ALICIA
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar circular de ALICIA
                    ClipOval(
                      child: Container(
                        width: 52,
                        height: 52,
                        color: _wGreen.withOpacity(0.15),
                        child: Image.asset(
                          'assets/images/iconllama.png',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.restaurant,
                            size: 30,
                            color: _wGreen,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Bocadillo de diálogo
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "A.L.I.C.I.A.",
                            style: TextStyle(
                              color: _wGreen,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: 1.1,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF162D22).withOpacity(0.9),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(4),
                                topRight: Radius.circular(14),
                                bottomLeft: Radius.circular(14),
                                bottomRight: Radius.circular(14),
                              ),
                              border: Border.all(
                                  color: _wGreen.withOpacity(0.4)),
                              boxShadow: [
                                BoxShadow(
                                  color: _wGreen.withOpacity(0.15),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Text(
                              respuesta,
                              style: const TextStyle(
                                color: _wText,
                                fontSize: 13,
                                height: 1.55,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Resumen de lo que se detectó
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _wCard.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _wCardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Resumen de tu reporte",
                        style: TextStyle(
                          color: _wTextSub,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildRevisionFila(
                        Icons.category_outlined,
                        const Color(0xFFFF9B3D),
                        "Categoría",
                        _wizardCategoria,
                      ),
                      const Divider(
                          color: _wCardBorder, height: 16),
                      _buildRevisionFila(
                        Icons.tune,
                        _wPurple,
                        "Subcategoría",
                        _wizardSubcategoria,
                      ),
                      if (_wizardDetallesSeleccionados
                          .isNotEmpty) ...[
                        const Divider(
                            color: _wCardBorder, height: 16),
                        const Text(
                          "Detalles marcados",
                          style: TextStyle(
                            color: _wTextSub,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _wizardDetallesSeleccionados
                              .map(
                                (d) => Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _wGreen
                                        .withOpacity(0.15),
                                    borderRadius:
                                        BorderRadius.circular(20),
                                    border: Border.all(
                                        color: _wGreen
                                            .withOpacity(0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize:
                                        MainAxisSize.min,
                                    children: [
                                      Text(
                                        d,
                                        style: const TextStyle(
                                          color: _wGreen,
                                          fontSize: 12,
                                          fontWeight:
                                              FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                          Icons.check_circle,
                                          color: _wGreen,
                                          size: 13),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                      if (_wizardContextoLibre.trim().isNotEmpty) ...[
                        const Divider(
                            color: _wCardBorder, height: 16),
                        _buildRevisionFila(
                          Icons.chat_bubble_outline,
                          _wYellow,
                          "Contexto extra",
                          _wizardContextoLibre.trim(),
                          isSubtext: true,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        // Botones de acción finales
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _estaCargando
                      ? null
                      : () {
                          // TODO: llamar _procesarEnvioAlAdmin() con los datos del wizard
                          HapticFeedback.heavyImpact();
                          _enviarReporteWizard();
                        },
                  icon: _estaCargando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.send_outlined, size: 20),
                  label: Text(
                    _estaCargando
                        ? "Enviando..."
                        : "ENVIAR AL PLANTEL DE COCINA",
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      letterSpacing: 0.8,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _wGreen,
                    disabledBackgroundColor: _wCardBorder,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    // TODO: volver al paso de burbujas para editar selección
                    setState(() => _wizardPaso = 2);
                  },
                  icon: const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: _wTextSub,
                  ),
                  label: const Text(
                    "Editar reporte",
                    style: TextStyle(color: _wTextSub, fontSize: 14),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _wCardBorder),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Helper reutilizable para filas de revisión
  // ─────────────────────────────────────────────────────────────
  Widget _buildRevisionFila(
    IconData icon,
    Color color,
    String label,
    String valor, {
    bool isSubtext = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: _wTextSub,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valor,
                style: const TextStyle(
                  color: _wText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: isSubtext ? 3 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PANTALLA DE ÉXITO: ¡Reporte enviado!
  // ══════════════════════════════════════════════════════════════
Widget _buildWizardPaso5Enviado() {
  final size = MediaQuery.of(context).size;

  return Stack(
    children: [
      // 1. Imagen de fondo PNG/WebP que cubre absolutamente toda la pantalla
      Positioned.fill(
        child: Image.asset(
          'assets/images/Exito.png', // Corregido con la mayúscula correcta para evitar fallos de renderizado
          fit: BoxFit.cover,
        ),
      ),

      // 2. Contenido interactivo montado encima y empujado hacia abajo
      Positioned.fill(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          child: Column(
            children: [
              // Incrementado a 0.52 para empujar el contenido hacia la mitad inferior de la pantalla de forma limpia
              SizedBox(height: size.height * 0.35),

              const SizedBox(height: 24),
              const Text(
                "¡Reporte enviado!",
                style: TextStyle(
                  color: _wText,
                  fontWeight: FontWeight.w900,
                  fontSize: 26,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Tu reporte fue enviado al plantel de cocina.",
                textAlign: TextAlign.center,
                style: TextStyle(color: _wTextSub, fontSize: 14),
              ),
              const SizedBox(height: 24),

              // ID del reporte
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: _wCard.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _wCardBorder),
                ),
                child: Column(
                  children: [
                    const Text(
                      "ID del reporte",
                      style: TextStyle(color: _wTextSub, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _wizardReporteId.isNotEmpty
                              ? _wizardReporteId
                              : "ALICIA-????",
                          style: const TextStyle(
                            color: _wGreen,
                            fontWeight: FontWeight.w900,
                            fontSize: 22,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            // TODO: Clipboard.setData(ClipboardData(text: _wizardReporteId))
                            HapticFeedback.lightImpact();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("ID copiado al portapapeles"),
                                duration: Duration(seconds: 2),
                              ),
                            );
                          },
                          child: const Icon(
                            Icons.copy_outlined,
                            color: _wTextSub,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "El equipo te responderá directamente a tu correo.\nRevisa tu bandeja de entrada.",
                textAlign: TextAlign.center,
                style: TextStyle(color: _wTextSub, fontSize: 12),
              ),
              const SizedBox(height: 28),
              
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // Resetear todo el wizard para un nuevo reporte
                    setState(() {
                      _wizardPaso = 0;
                      _wizardCategoria = "";
                      _wizardSubcategoria = "";
                      _wizardDetallesSeleccionados.clear();
                      _wizardContextoLibre = "";
                      _wizardReporteId = "";
                      _mostrarCampoLibre = false;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _wCardBorder),
                    foregroundColor: _wText,
                    backgroundColor: Colors.white.withOpacity(0.05), // Sutil contraste sobre la ilustración
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    "Crear otro reporte",
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}



  // ══════════════════════════════════════════════════════════════
  // HISTORIAL: Mis reportes
  // ══════════════════════════════════════════════════════════════
  // ══════════════════════════════════════════════════════════════
  // HISTORIAL: Mis reportes
  // ══════════════════════════════════════════════════════════════
  Widget _buildWizardPaso6MisReportes() {
    Color _estadoColor(String estado) {
      switch (estado) {
        case "ENVIADO": return _wBlue;
        case "EN PROGRESO": return _wYellow;
        // ─── SE ELIMINÓ EL CASO "RESUELTO" AQUÍ ───
        default: return _wTextSub;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text(
            "Mis reportes",
            style: TextStyle(
              color: _wText,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _historialReportes.length,
            itemBuilder: (context, index) {
              final reporte = _historialReportes[index];
              final Color estadoColor =
                  _estadoColor(reporte["estado"]!);
              return GestureDetector(
                onTap: () {
                  // TODO: navegar al detalle del reporte (Firestore doc)
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _wCard.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _wCardBorder),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: estadoColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.receipt_long_outlined,
                          color: estadoColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  reporte["id"]!,
                                  style: const TextStyle(
                                    color: _wTextSub,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding:
                                      const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 2),
                                  decoration: BoxDecoration(
                                    color: estadoColor
                                        .withOpacity(0.18),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    reporte["estado"]!,
                                    style: TextStyle(
                                      color: estadoColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              reporte["titulo"]!,
                              style: const TextStyle(
                                color: _wText,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              reporte["hace"]!,
                              style: const TextStyle(
                                color: _wTextSub,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          color: _wTextSub, size: 20),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // LÓGICA: Simula interpretación IA (paso 3 → 4)
  // ══════════════════════════════════════════════════════════════
  Future<void> _iniciarInterpretacionIA() async {
    // TODO: reemplazar con llamada real a Groq usando _construirPromptValidacion
    // o un prompt específico que tome _wizardCategoria, _wizardSubcategoria
    // y _wizardDetallesSeleccionados para generar una causa probable.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _wizardPaso = 4);
  }

  // ══════════════════════════════════════════════════════════════
  // LÓGICA: Envío final del reporte al backend
  // ══════════════════════════════════════════════════════════════
  Future<void> _enviarReporteWizard() async {
    setState(() => _estaCargando = true);
    try {
      // TODO: guardar en Firestore — sustituir el bloque comentado por el real:
      // final user = FirebaseAuth.instance.currentUser;
      // await FirebaseFirestore.instance.collection('app_reportes').add({
      //   'uid': user?.uid,
      //   'categoria': _wizardCategoria,
      //   'subcategoria': _wizardSubcategoria,
      //   'detalles': _wizardDetallesSeleccionados,
      //   'contextoLibre': _wizardContextoLibre,
      //   'respuestaAlicia': _generarRespuestaAlicia(),
      //   'fecha': FieldValue.serverTimestamp(),
      // });
      // TODO: llamar a EmailJS igual que en _procesarEnvioAlAdmin para notificar al admin

      await Future.delayed(const Duration(seconds: 1));

      final String nuevoId =
          "ALICIA-${DateTime.now().millisecondsSinceEpoch % 100000}";

      // Agregar al historial mock — reemplazar por StreamBuilder de Firestore
      _historialReportes.insert(0, {
        "id": nuevoId,
        "titulo": _wizardSubcategoria,
        "estado": "ENVIADO",
        "hace": "Hace 1 min",
      });

      setState(() {
        _wizardReporteId = nuevoId;
        _estaCargando = false;
        _wizardPaso = 5;
      });
    } catch (e) {
      setState(() => _estaCargando = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                "Error al enviar el reporte. Intenta de nuevo."),
          ),
        );
      }
    }
  }

  Widget _buildWelcomeLayout() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(
          left: 24.0,
          right: 24.0,
          bottom: 16.0,
          top: 40.0,
        ),
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
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Row(
            children: [
              Icon(icono, color: colorIcono, size: 36),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFC85A32),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subDescripcion,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        color: Color(0xFF7A756B),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Color(0xFFA39E94),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }

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
          // CAMBIO AQUÍ: Ahora viaja a la ventana de transición interactiva
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => VoiceTransitionScreen()),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
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
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      "Asistente de voz ciberpunk andino",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Colors.white70,
                      ),
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
  // FUSIÓN: Avatar Animado (De tu compañero) + Burbuja TextFlexible (Tuya)
  // ─────────────────────────────────────────────
  Widget _buildChatLayout() {
    final bool esReporte = _categoriaActual == "Reporte";
    return Column(
      children: [
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
                        // Avatar animado inyectado aquí
                        child: ClipOval(
                          child: Container(
                            width: 36,
                            height: 36,
                            color: _verde.withOpacity(0.15),
                            child: IndexedStack(
                              index: _estaCargando ? 0 : 1,
                              sizing: StackFit.expand,
                              children: [
                                Image.asset(
                                  'assets/images/nid_speaking.webp', // index 0: relatando
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                                Image.asset(
                                  'assets/images/nid_idle.webp', // index 1: esperando
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Flexible(
                      // Solución al bottom overflow que aplicaste
                      child: Column(
                        crossAxisAlignment: esUsuario
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 5),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: esUsuario
                                  ? _verde
                                  : Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(15),
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
                          if (msg["tipo"] == "botones_reporte_categorias")
                            _buildReporteCategoriasGrid(),
                          if (msg["tipo"] == "botones_reporte_subcategorias")
                            _buildReporteSubcategoriasGrid(
                              msg["categoria_reporte"],
                            ),
                          if (msg["tipo"] == "botones_categoria")
                            _buildCategoriasGrid(),
                          if (msg["tipo"] == "grid_ingredients" &&
                              _mostrarGridIngredientes)
                            _buildIngredientesGrid(),
                          if (msg["tipo"] == "recetas_grid")
                            _buildRecetasGridCards(msg["recetas"]),
                          if (msg["tipo"] == "reporte_btn" ||
                              msg["tipo"] == "sugerencia_btn")
                            _buildActionBtn(
                              _procesarEnvioAlAdmin,
                              Icons.send_and_archive,
                              "Enviar al plantel administrativo",
                            ),
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
            child: Text(
              "A.L.I.C.I.A. está cocinando...",
              style: TextStyle(
                color: Colors.black54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),

        _buildInputArea(),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // UI ARQUITECTURA TÁCTIL (Tus diseños conservados)
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
          final bool desactivar =
              _bloquearReportes && _categoriaReporteActual != label;
          final bool seleccionado = _categoriaReporteActual == label;

          return GestureDetector(
            onTap: desactivar
                ? null
                : () => _seleccionarCategoriaReporte(label),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                boxShadow: desactivar
                    ? []
                    : [
                        BoxShadow(
                          color: (cat["color"] as Color).withOpacity(
                            seleccionado ? 0.35 : 0.15,
                          ),
                          blurRadius: 0,
                          offset: Offset(0, seleccionado ? 2 : 4),
                        ),
                      ],
              ),
              child: Row(
                children: [
                  Icon(
                    cat["icono"] as IconData,
                    color: desactivar
                        ? Colors.grey.shade400
                        : (cat["color"] as Color),
                    size: 28,
                  ),
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
                    Icon(
                      Icons.check_circle,
                      color: cat["color"] as Color,
                      size: 20,
                    ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildReporteSubcategoriasGrid(String categoriaPadre) {
    List<String> opciones = [];
    if (categoriaPadre.contains("Contenido")) {
      opciones = [
        "Receta mal explicada",
        "Ingredientes erróneos",
        "Imágenes rotas",
      ];
    } else if (categoriaPadre.contains("experiencia")) {
      opciones = ["Navegación confusa", "Letra muy pequeña", "Diseño incómodo"];
    } else {
      opciones = [
        "Cierre inesperado (Crash)",
        "Error de base de datos",
        "Carga lenta / Lag",
      ];
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: opciones.map((opc) {
          final bool desactivar =
              _bloquearFlujoReporte && _subCategoriaReporteActual != opc;
          final bool seleccionado = _subCategoriaReporteActual == opc;

          return GestureDetector(
            onTap: desactivar
                ? null
                : () => _seleccionarSubcategoriaReporte(opc),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                          color: const Color(
                            0xFFFFA000,
                          ).withOpacity(seleccionado ? 0.4 : 0.2),
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
                      child: Icon(
                        Icons.check,
                        size: 14,
                        color: Color(0xFFFFA000),
                      ),
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

  Widget _buildInputArea() {
    final bool entradaBloqueada =
        _mensajes.isNotEmpty &&
        (_mensajes.last["tipo"] == "reporte_btn" ||
            _mensajes.last["tipo"] == "sugerencia_btn");
    final bool mostrarBanco =
        _categoriaActual == "Reporte" && _pasoReporte == 2 && !entradaBloqueada;
    if (mostrarBanco) return _buildBancoPalabras();

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
            icon: Icon(
              Icons.send,
              color: entradaBloqueada ? Colors.grey : _verde,
            ),
            onPressed: entradaBloqueada ? null : _enviarMensaje,
          ),
        ],
      ),
    );
  }

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
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.45,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. ÁREA DE VISUALIZACIÓN DE BURBUJAS SELECCIONADAS
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: _fraseArmada.isEmpty
                  ? Text(
                      "Toca las burbujas para armar tu reporte...",
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
                    )
                  : Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _fraseArmada.map((palabra) {
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            setState(() => _fraseArmada.remove(palabra));
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: _verde,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              palabra,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
            ),
            const SizedBox(height: 10),

            // 2. INPUT PARA ESCRIBIR PALABRAS QUE SE CONVIERTEN EN BURBUJAS (EVITA RESPUESTA DE RECETAS)
            if (_mostrarCampoLibre)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextField(
                  controller: _controller,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: "Escribe una palabra y presiona enviar...",
                    filled: true,
                    fillColor: const Color(0xFFF5F5F5),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.add_circle, color: _verde),
                      onPressed: () {
                        final texto = _controller.text.trim();
                        if (texto.isNotEmpty) {
                          setState(() {
                            // En lugar de enviarlo a la IA, se agrega localmente como burbuja
                            _fraseArmada.add(texto);
                            _controller.clear();
                          });
                        }
                      },
                    ),
                  ),
                  onSubmitted: (val) {
                    final texto = val.trim();
                    if (texto.isNotEmpty) {
                      setState(() {
                        _fraseArmada.add(texto);
                        _controller.clear();
                      });
                    }
                  },
                ),
              ),

            // 3. BANCO DE PALABRAS DINÁMICO PREDEFINIDO
            if (!_mostrarInterpretacionReporte && !_mostrarPasoFinalTimbre) ...[
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: yaUsada ? Colors.grey.shade100 : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: yaUsada ? Colors.grey.shade300 : _verde.withOpacity(0.6),
                            width: 1.5,
                          ),
                          boxShadow: yaUsada ? [] : [
                            BoxShadow(
                              color: _verde.withOpacity(0.2),
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          palabra,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: yaUsada ? Colors.grey.shade400 : const Color(0xFF1B6B4A),
                          ),
                        ),
                      ),
                    );
                  }),
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _mostrarCampoLibre = !_mostrarCampoLibre);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFFFD54F), width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Color(0x33FFD54F), offset: Offset(0, 3)),
                        ],
                      ),
                      child: const Text(
                        "✏️ Otro detalle",
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF795548)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // BOTÓN: COMPROBAR E INSTALAR REPORTE
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _fraseArmada.isNotEmpty
                      ? () {
                          // Forzamos la interpretación técnica de A.L.I.C.I.A
                          setState(() {
                            _mostrarInterpretacionReporte = true;
                            _interpretacionIA = _fraseArmada.join(" y ");
                          });
                        }
                      : null,
                  icon: const Icon(Icons.verified_outlined, size: 20),
                  label: const Text("Comprobar e Instalar Reporte", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _verde,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],

            // 4. FLUJO DE INTERPRETACIÓN EXCLUSIVO DE SOPORTE (A.L.I.C.I.A)
            if (_mostrarInterpretacionReporte && !_mostrarPasoFinalTimbre) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _verde.withOpacity(0.5)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "🤖 A.L.I.C.I.A Interpreta:",
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[850], fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      "El error al que te refieres tiene que ver con \"Problema detectado en base a: $_interpretacionIA\".",
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (_mostrarDetalleManualExtendido)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: TextField(
                    controller: _controller,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: "Escribe detalladamente a mano tu problema...",
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _mostrarDetalleManualExtendido = true;
                        });
                      },
                      style: OutlinedButton.styleFrom(side: BorderSide(color: _verde)),
                      child: const Text("Agregar más detalle", style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _mostrarPasoFinalTimbre = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: _verde, foregroundColor: Colors.white),
                      child: const Text("Sí, es correcto", style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
              if (_mostrarDetalleManualExtendido)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _mostrarPasoFinalTimbre = true;
                        });
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: _verde, foregroundColor: Colors.white),
                      child: const Text("Terminar de redactar"),
                    ),
                  ),
                ),
            ],

            // 5. PASO FINAL: INTERFAZ DEL TIMBRE DE COCINA 3D NATIVO
            if (_mostrarPasoFinalTimbre) _buildTimbreMesaCocinaSection(),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildTimbreMesaCocinaSection() {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      const SizedBox(height: 10),
      GestureDetector(
        onTap: () {
          HapticFeedback.vibrate();
          // Aquí pones la llamada a la función real de tu backend que guarda el reporte
          // Ej: _enviarReporteFinalAPlantel();
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('🔔 Reporte enviado con éxito a la cocina')),
          );
          setState(() {
            // Reiniciamos los estados del flujo de reporte
            _mostrarPasoFinalTimbre = false;
            _mostrarInterpretacionReporte = false;
            _mostrarDetalleManualExtendido = false;
            _fraseArmada.clear();
          });
        },
        child: Column(
          children: [
            // Cuerpito del Timbre de Mesa en 3D
            Stack(
              alignment: Alignment.topCenter,
              children: [
                // Base o Plato del timbre
                Container(
                  width: 140,
                  height: 35,
                  margin: const EdgeInsets.only(top: 45),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: const BorderRadius.all(Radius.elliptical(140, 35)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 6),
                      ),
                    ],
                    gradient: LinearGradient(
                      colors: [Colors.grey.shade500, Colors.grey.shade300, Colors.grey.shade600],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
                // Campana metálica esférica
                Container(
                  width: 100,
                  height: 65,
                  margin: const EdgeInsets.only(top: 12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade700,
                    borderRadius: const BorderRadius.all(Radius.elliptical(100, 65)),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFB71C1C), Color(0xFFEF5350), Color(0xFF7F0000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                // Botón superior / Pulsador
                Container(
                  width: 32,
                  height: 16,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(6),
                    gradient: LinearGradient(
                      colors: [Colors.grey.shade900, Colors.grey.shade600],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Enviar reporte al plantel de cocina para ser revisado",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: Color(0xFFB71C1C),
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      // TEXTO OBLIGATORIO DE RESPUESTA POR CORREO
      const Text(
        "¡Se te enviará la respuesta a tu correo cuando el problema ya esté solucionado!",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
      const SizedBox(height: 6),
      // TEXTO ADVERTENCIA DE SATURACIÓN
      Text(
        "Tres reportes por día serán suficientes para no saturar la cocina",
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade500,
          fontStyle: FontStyle.italic,
        ),
      ),
    ],
  );
}

  // ─────────────────────────────────────────────
  // UI DEL TEMPORIZADOR NATIVO (De tu compañero)
  // ─────────────────────────────────────────────
  Widget _buildTimerWidget() {
    if (!_timerActivo) return const SizedBox.shrink();

    final int min = _timerDuration.inMinutes;
    final int seg = _timerDuration.inSeconds % 60;
    final String display =
        "${min.toString().padLeft(2, '0')}:${seg.toString().padLeft(2, '0')}";
    return Positioned(
      bottom: 100,
      left: 16,
      right: 16,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _verde, width: 2),
            boxShadow: [
              BoxShadow(
                color: _verde.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _verde.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.timer_rounded, color: _verde, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "TEMPORIZADOR ACTIVO",
                      style: TextStyle(
                        fontSize: 10,
                        color: _verde.withOpacity(0.75),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    Text(
                      display,
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        color: _verde,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: _cancelarTemporizador,
                tooltip: "Cancelar temporizador",
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.redAccent,
                  size: 22,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriasGrid() {
    final List<Map<String, dynamic>> cats = [
      {
        "nombre": "Desayuno",
        "icono": Icons.free_breakfast,
        "color": const Color(0xFFFFB74D),
      },
      {
        "nombre": "Almuerzo",
        "icono": Icons.lunch_dining,
        "color": const Color(0xFFE57373),
      },
      {
        "nombre": "Cena",
        "icono": Icons.dinner_dining,
        "color": const Color(0xFF7986CB),
      },
      {
        "nombre": "Snack",
        "icono": Icons.fastfood,
        "color": const Color(0xFF81C784),
      },
      {
        "nombre": "Refrescos",
        "icono": Icons.local_drink,
        "color": const Color(0xFF4FC3F7),
      },
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 10,
        runSpacing: 12,
        alignment: WrapAlignment.center,
        children: cats.map((cat) {
          final String nombre = cat["nombre"];
          final bool isSelected = _categoriaComidaElegida == nombre;
          final bool desactivar = _bloquearCategorias && !isSelected;
          final Color baseColor = cat["color"];

          return GestureDetector(
            onTap: desactivar
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    if (_bloquearCategorias) return;
                    setState(() {
                      _bloquearCategorias = true;
                      _categoriaComidaElegida = nombre;
                      _mensajes.add({
                        "rol": "usuario",
                        "texto": "Categoría: $nombre",
                        "tipo": "texto",
                      });
                    });
                    _cargarIngredientesPrimordiales(nombre);
                  },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? baseColor.withOpacity(0.15) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? baseColor : Colors.grey.shade300,
                  width: isSelected ? 2.5 : 1.5,
                ),
                boxShadow: desactivar
                    ? []
                    : [
                        BoxShadow(
                          color: baseColor.withOpacity(isSelected ? 0.5 : 0.2),
                          blurRadius: 0,
                          offset: Offset(0, isSelected ? 1 : 4),
                        ),
                      ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    cat["icono"],
                    size: 18,
                    color: desactivar ? Colors.grey.shade400 : baseColor,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: desactivar ? Colors.grey.shade400 : Colors.black87,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.check_circle, size: 16, color: baseColor),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildIngredientesGrid() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          Wrap(
            spacing: 10.0,
            runSpacing: 12.0,
            alignment: WrapAlignment.center,
            children: _ingredientesPrimordiales.map((ing) {
              final bool isSel = _ingredientesSeleccionados.contains(ing);
              return GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() {
                    if (isSel) {
                      _ingredientesSeleccionados.remove(ing);
                    } else if (_ingredientesSeleccionados.length < 8) {
                      _ingredientesSeleccionados.add(ing);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: isSel ? _verde.withOpacity(0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSel ? _verde : Colors.grey.shade300,
                      width: isSel ? 2 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isSel
                            ? _verde.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.15),
                        blurRadius: 0,
                        offset: Offset(0, isSel ? 1 : 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSel)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Icon(
                            Icons.check_circle,
                            size: 16,
                            color: _verde,
                          ),
                        ),
                      Text(
                        ing,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: isSel ? _verde : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: AnimatedOpacity(
              opacity: _ingredientesSeleccionados.isNotEmpty ? 1.0 : 0.45,
              duration: const Duration(milliseconds: 300),
              child: ElevatedButton.icon(
                onPressed: _ingredientesSeleccionados.isNotEmpty
                    ? () {
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _mostrarGridIngredientes = false;
                          _controller.text =
                              "Dame una recomendación de $_categoriaComidaElegida usando: ${_ingredientesSeleccionados.join(', ')}";
                        });
                        _enviarMensaje();
                      }
                    : null,
                icon: const Icon(Icons.restaurant_menu, size: 20),
                label: const Text(
                  "Cocinar con estos ingredientes",
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _verde,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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

  Widget _buildRecetasGridCards(List<dynamic> recetasData) {
    final recetas = recetasData.cast<Map<String, dynamic>>();
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: recetas.map((receta) {
          return SizedBox(
            width: 150,
            height: 215,
            child: GestureDetector(
              onTap: () {
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
              child: RecetaCardWidget(
                receta: receta,
                verde: _verde,
                porcentajeMatch: receta['porcentaje'] as double,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActionBtn(VoidCallback onPres, IconData icon, String label) {
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
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}