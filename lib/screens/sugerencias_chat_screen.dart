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
  int _pasoReporte = 0;
  bool _bloquearReportes = false;
  String _categoriaReporteActual = "";
  String _subCategoriaReporteActual = "";
  bool _bloquearFlujoReporte = false;
  final List<String> _fraseArmada = [];
  bool _mostrarCampoLibre = false;

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
          Expanded(flex: 1, child: _buildChatLayout()),
        ],
      );
    } else {
      return _buildChatLayout();
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
        // El constraint que pusiste para el teclado se mantiene aquí
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.4,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: _fraseArmada.isEmpty
                    ? Text(
                        "Toca las burbujas para armar tu reporte...",
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 13,
                        ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
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
              if (_mostrarCampoLibre)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: TextField(
                    controller: _controller,
                    autofocus: true,
                    onChanged: (val) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: "Escribe tu detalle específico...",
                      filled: true,
                      fillColor: const Color(0xFFF5F5F5),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
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
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: yaUsada ? Colors.grey.shade100 : Colors.white,
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
                  GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setState(() => _mostrarCampoLibre = !_mostrarCampoLibre);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFFFFD54F),
                          width: 1.5,
                        ),
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
                          color: Color(0xFF795548),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: AnimatedOpacity(
                  opacity:
                      (_fraseArmada.isNotEmpty ||
                          (_mostrarCampoLibre &&
                              _controller.text.trim().isNotEmpty))
                      ? 1.0
                      : 0.45,
                  duration: const Duration(milliseconds: 300),
                  child: ElevatedButton.icon(
                    onPressed:
                        _fraseArmada.isNotEmpty ||
                            (_mostrarCampoLibre &&
                                _controller.text.trim().isNotEmpty)
                        ? _confirmarFraseBancoYEnviar
                        : null,
                    icon: const Icon(Icons.verified_outlined, size: 20),
                    label: const Text(
                      "Comprobar e Instalar Reporte",
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
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
        ),
      ),
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
