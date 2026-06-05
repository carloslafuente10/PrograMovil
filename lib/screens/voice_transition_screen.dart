import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

// ═══════════════════════════════════════════════════════════════════════════
// VoiceTransitionScreen — Pantalla de transición + Asistente NID integrado
//
// FLUJO COMBINADO:
//   1. La pantalla se muestra con fondo de imagen y dos botones 3D.
//   2. El botón "Seleccionar una receta de mi catálogo" navega a otra pantalla.
//   3. El botón "Saltar este paso" activa a NID en el lugar:
//      a. Carga el catálogo Firestore en segundo plano (RAG).
//      b. NID pronuncia el saludo inicial.
//      c. El micrófono queda disponible para el usuario.
//   4. Toda la lógica de STT, TTS, IntentRouter, Groq y Fallback
//      opera exactamente igual que en VoiceCallScreen original.
//
// DEPENDENCIAS (pubspec.yaml):
//   speech_to_text: ^6.6.0
//   flutter_tts:    ^4.0.2
//   cloud_firestore, http, flutter_dotenv  ← ya están en el proyecto
// ═══════════════════════════════════════════════════════════════════════════

class VoiceTransitionScreen extends StatefulWidget {
  const VoiceTransitionScreen({super.key});

  @override
  State<VoiceTransitionScreen> createState() => _VoiceTransitionScreenState();
}

class _VoiceTransitionScreenState extends State<VoiceTransitionScreen>
    with SingleTickerProviderStateMixin {

  // ─────────────────────────────────────────────
  // PALETA CIBERPUNK ANDINO
  // ─────────────────────────────────────────────
  static const Color _verdeNeon    = Color(0xFF2D9E73);
  static const Color _verdeSombra  = Color(0xFF1B6347);
  static const Color _moradoNeon   = Color(0xFF7B2FBE);
  static const Color _moradoSombra = Color(0xFF4A1A75);
  static const Color _negro        = Color(0xFF0A0A0F);
  static const Color _cianNeon     = Color(0xFF00F5FF);
  static const Color _doradoInca   = Color(0xFFFFD700);
  static const Color _verdeApp     = Color(0xFF2D9E73);

  // ─────────────────────────────────────────────
  // ESTADO DE ACTIVACIÓN DE NID
  // NID permanece dormido hasta que el usuario
  // presione "Saltar este paso".
  // ─────────────────────────────────────────────
  bool _nidActivado = true;

  // ─────────────────────────────────────────────
  // SERVICIOS EXTERNOS
  // ─────────────────────────────────────────────
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts         _tts   = FlutterTts();
  final String _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';

  // ─────────────────────────────────────────────
  // ESTADO DE AUDIO / UI
  // ─────────────────────────────────────────────
  String _textoEscuchado = "";
  String _preguntaFinal  = "";
  String _respuestaNID   = "";
  bool   _escuchando     = false;
  bool   _procesando     = false;
  bool   _hablando       = false;

  // ─────────────────────────────────────────────
  // CATÁLOGO RAG (Firestore)
  // ─────────────────────────────────────────────
  String _catalogoContexto     = "";
  String _recetaActivaContexto = "";
  bool   _catalogoCargado      = false;
  final List<Map<String, dynamic>> _recetasData = [];

  // ─────────────────────────────────────────────
  // ESTADO DE RECETA ACTIVA (control paso a paso)
  // ─────────────────────────────────────────────
  String? _recetaActivaNombre;
  List<String> _pasosActivos        = [];
  List<String> _ingredientesActivos = [];
  int _pasoActualIndex = -1;

  // ─────────────────────────────────────────────
  // HISTORIAL PARA GROQ (memoria a corto plazo)
  // ─────────────────────────────────────────────
  final List<Map<String, String>> _historial = [];

  // Minutos ofrecidos en el último paso leído.
  // null = ningún paso activo tiene tiempo que requiera temporizador.
  // Se resetea a null cuando el usuario rechaza, acepta o avanza de paso.
  int? _minutosOfrecidos;

  // ─────────────────────────────────────────────
  // ANIMACIÓN DE PULSO DEL AVATAR
  // ─────────────────────────────────────────────
  late AnimationController _pulsoController;
  late Animation<double>    _pulsoAnimation;

  // ─────────────────────────────────────────────
  // VARIABLES DEL TEMPORIZADOR NATIVO
  // ─────────────────────────────────────────────
  Timer?   _countdownTimer;
  Duration _timerDuration = Duration.zero;
  bool     _timerActivo   = false;

  // ─────────────────────────────────────────────
  // ESTADO DE FONDO ANIMADO (3 webp distintas)
  //
  // presentacion → fondo de bienvenida/reposo
  //   assets/images/nid_presentacion.webp
  // transicion   → flash 250 ms al pulsar mic o botón rojo
  //   assets/images/nid_transicion.webp
  // escuchando   → mientras el micrófono está activo
  //   assets/images/nid_escuchando.webp
  //
  // Agrega esas tres imágenes en pubspec.yaml bajo assets/images/.
  // ─────────────────────────────────────────────
  _EstadoFondo _estadoFondo = _EstadoFondo.presentacion;
  Timer? _transicionTimer;

  // ═══════════════════════════════════════════════════════════════════════════
  // SYSTEM PROMPT — POLÍTICA ZERO-HALLUCINATION + FORMATO TTS
  // ═══════════════════════════════════════════════════════════════════════════
  static const String _systemPromptTemplate = """
Eres NID, asistente culinario de voz de la Cordillera. Responde SOLO con datos del siguiente registro. Tu conocimiento externo está desactivado.

DATOS OFICIALES:
{{CATALOGO}}

BÚSQUEDA: Antes de rechazar, busca por coincidencia exacta, parcial, sin tildes/mayúsculas y por categoría. Solo rechaza si ningún intento coincide.

VERIFICACIÓN: Antes de responder, confirma que nombre, ingredientes, cantidades y pasos provienen literalmente del registro. Si falla alguno, rechaza.

RECHAZO: Si la receta no existe en los datos, responde exactamente: "Lo siento, esa receta no se encuentra en nuestro sistema de ingredientes y recetas actualmente." Sin agregar nada más.

CAMBIO DE RECETA: Si el usuario menciona una receta diferente a la que se venía discutiendo, cambia INMEDIATAMENTE el contexto a la nueva receta. Olvida completamente la receta anterior. No mezcles datos entre recetas distintas.

PROHIBIDO: inventar, deducir o aproximar ingredientes, cantidades, pasos o sustitutos. No uses conocimiento externo. No redondees cifras. No te contradigas entre turnos.

ABREVIACIONES HABLADAS OBLIGATORIAS (el texto se lee por voz, nunca uses abreviaciones escritas):
- "cdta" o "cda" → di siempre "cucharadita" o "cucharada"
- "0.5 kg" → di "medio kilo"
- "0.25 kg" → di "un cuarto de kilo"
- "0.5 l" o "500 ml" → di "medio litro"
- "0.25 l" o "250 ml" → di "un cuarto de litro"
- "1/2" → di "media" o "medio" según corresponda
- "1/4" → di "un cuarto de"
- "tbsp" → di "cucharada"
- "tsp" → di "cucharadita"
- "g" o "gr" sueltos → di "gramos"
- "kg" → di "kilos" o la equivalencia en medio/cuarto si aplica
- Nunca digas unidades en sigla: siempre di la palabra completa

FUNCIONES:
- Confirmar receta: di nombre exacto, calorías aproximadas y tiempo exacto. Pregunta si empezamos. No listes pasos ni ingredientes aún.
- Pasos: dicta uno a la vez, literal del registro. Avanza solo cuando el usuario confirme. Si el paso tiene un tiempo de espera (hornear, hervir, reposar, marinar, enfriar, etc.), PRIMERO dicta el paso completo y LUEGO pregunta al usuario si desea que actives un temporizador. NO actives el temporizador hasta que el usuario confirme explícitamente con palabras como "sí", "dale", "actívalo", "ponlo". Si el usuario no confirma o dice "no", continúa sin temporizador. Cuando el usuario confirme, añade al final [TIMER:X] con X en minutos enteros. Este comando nunca se pronuncia.
- Ingredientes: lista literal del registro usando las abreviaciones habladas. Si no hay sustitutos en el registro, dilo.
- Porciones para N personas: calcula tú las cantidades exactas usando las abreviaciones habladas. No le pidas al usuario que calcule.
- Categorías: lista solo recetas del registro de esa categoría.
- Calorías: usa siempre "aproximadamente N calorías".
- Tiempo: transcribe exacto del registro.

FORMATO TTS: prosa fluida, sin asteriscos, guiones decorativos, corchetes, emojis, listas, negritas ni símbolos. Máximo 3 oraciones por respuesta salvo ingredientes o porciones. No anticipes información no solicitada.
""";

  // ─────────────────────────────────────────────
  // SALUDO INICIAL EXACTO DE NID
  // Se pronuncia automáticamente al terminar de
  // cargar el catálogo, SOLO si NID fue activado.
  // ─────────────────────────────────────────────
  static const String _saludoInicial =
      "Bienvenido cocinero, mi nombre es NID. "
      "Espero que mi ayuda pueda satisfacer las dudas que tengas "
      "para preparar nuestra próxima obra gastronómica.";

  // ─────────────────────────────────────────────
  // initState / dispose
  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    _pulsoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulsoAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulsoController, curve: Curves.easeInOut),
    );

    // NID se activa directamente al entrar a la pantalla.
    _configurarTts().then((_) => _cargarCatalogoYSaludar());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _transicionTimer?.cancel();
    _pulsoController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // _activarNID
  // Llamado al pulsar "Saltar este paso".
  // Cambia el modo de la pantalla y despierta
  // a NID: carga el catálogo y pronuncia el saludo.
  // ─────────────────────────────────────────────
  Future<void> _activarNID() async {
    setState(() => _nidActivado = true);
    await _cargarCatalogoYSaludar();
  }

  // ─────────────────────────────────────────────
  // _configurarTts
  // Voz pausada y levemente grave para NID.
  // En Flutter Web (Edge/Chrome), SpeechSynthesis
  // puede lanzar un [object SpeechSynthesisErrorEvent]
  // si el contexto de audio se suspende. El handler
  // lo intercepta y libera el flag _hablando.
  // ─────────────────────────────────────────────
  Future<void> _configurarTts() async {
    await _tts.setLanguage("es-US");
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(0.85);

    // Captura cualquier error del motor de síntesis del navegador
    // antes de que congele _hablando = true indefinidamente.
    _tts.setErrorHandler((dynamic msg) {
      debugPrint("TTS Error capturado: $msg");
      if (mounted) {
        _cambiarFondo(_EstadoFondo.escuchando);
        setState(() => _hablando = false);
      }
    });

    _tts.setCompletionHandler(() {
      if (mounted) {
        _cambiarFondo(_EstadoFondo.escuchando);
        setState(() => _hablando = false);
      }
    });
  }

  // ─────────────────────────────────────────────
  // _iniciarTemporizador / _cancelarTemporizador
  // ─────────────────────────────────────────────
  void _iniciarTemporizador(int minutos) {
    _cancelarTemporizador();
    setState(() {
      _timerDuration = Duration(minutes: minutos);
      _timerActivo   = true;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (_timerDuration.inSeconds > 0) {
          _timerDuration -= const Duration(seconds: 1);
        } else {
          _cancelarTemporizador();
          _hablar(
            "El temporizador ha terminado. ¡Tu preparación está lista!",
            guardarEnHistorial: false,
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
  // _cambiarFondo — Máquina de transición de fondos
  //
  // Al pulsar mic o botón rojo:
  //   1. Muestra nid_transicion.webp durante 250 ms  (flash)
  //   2. Luego muestra el fondo destino:
  //      · _escuchando == true  → nid_escuchando.webp
  //      · _escuchando == false → nid_presentacion.webp
  //
  // Llamar con [destino] = el estado FINAL deseado.
  // La transición intermedia se gestiona internamente.
  // ─────────────────────────────────────────────
  void _cambiarFondo(_EstadoFondo destino) {
    _transicionTimer?.cancel();
    setState(() => _estadoFondo = _EstadoFondo.transicion);
    _transicionTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _estadoFondo = destino);
    });
  }

  // ═══════════════════════════════════════════════════════
  // _sanitizarRecetaFirestore — HELPER DE SANITIZACIÓN
  // ═══════════════════════════════════════════════════════
  Map<String, dynamic> _sanitizarRecetaFirestore(
      Map<String, dynamic> data, String docId) {

    final String nombre    = (data['nombre']    ?? 'Sin nombre').toString().trim();
    final String categoria = (data['categoria'] ?? '').toString().trim();
    final String calorias  = (data['calorias']  ?? '').toString().trim();
    final String tiempo    = (data['tiempo']    ?? '').toString().trim();

    final List rawIngredientes = data['ingredientes'] ?? [];
    final List<String> ingredientesLimpios = rawIngredientes.map<String>((ing) {
      if (ing is Map) {
        final String nom = (ing['nombre']     ??
                            ing['name']       ??
                            ing['ingrediente']?? '').toString().trim();
        final String can = (ing['cantidad']   ??
                            ing['amount']     ??
                            ing['gramos']     ??
                            ing['unidades']   ?? '').toString().trim();
        final String uni = (ing['unidad']     ??
                            ing['unit']       ?? '').toString().trim();

        if (nom.isEmpty) return '';
        if (can.isNotEmpty && uni.isNotEmpty) return "$can $uni de $nom";
        if (can.isNotEmpty) return "$can de $nom";
        return nom;
      }
      return ing.toString().trim();
    }).where((s) => s.isNotEmpty).toList();

    final List rawPasos = data['pasos'] ?? [];
    final List<String> pasosLimpios = rawPasos.map<String>((paso) {
      if (paso is Map) {
        return (paso['descripcion'] ??
                paso['texto']       ??
                paso['detalle']     ??
                paso['step']        ??
                paso.toString()).toString().trim();
      }
      return paso.toString().trim();
    }).where((s) => s.isNotEmpty).toList();

    final StringBuffer ctx = StringBuffer();
    ctx.writeln("RECETA: $nombre");
    if (categoria.isNotEmpty) ctx.writeln("  Categoría: $categoria");
    if (calorias.isNotEmpty)  ctx.writeln("  Calorías aproximadas: $calorias");
    if (tiempo.isNotEmpty)    ctx.writeln("  Tiempo aproximado: $tiempo");
    if (ingredientesLimpios.isNotEmpty) {
      ctx.writeln("  Ingredientes: ${ingredientesLimpios.join(', ')}");
    }
    for (int i = 0; i < pasosLimpios.length; i++) {
      ctx.writeln("  Paso ${i + 1}: ${pasosLimpios[i]}");
    }

    return {
      'id':            docId,
      'nombre':        nombre,
      'categoria':     categoria,
      'calorias':      calorias,
      'tiempo':        tiempo,
      'ingredientes':  ingredientesLimpios,
      'pasos':         pasosLimpios,
      'contextoTexto': ctx.toString(),
    };
  }

  // ═══════════════════════════════════════════════════════
  // CARGA DE CATÁLOGO FIRESTORE (RAG) + SALUDO INICIAL
  // ═══════════════════════════════════════════════════════
  Future<void> _cargarCatalogoYSaludar() async {
    setState(() => _procesando = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('app-recetas-completas')
          .get();

      final StringBuffer buffer = StringBuffer();

      for (final doc in snapshot.docs) {
        final Map<String, dynamic> sanitizado =
            _sanitizarRecetaFirestore(doc.data(), doc.id);

        final List<String> meta = [
          "ID:${doc.id}",
          "RECETA:${sanitizado['nombre']}",
        ];
        if ((sanitizado['categoria'] as String).isNotEmpty) {
          meta.add("Categoría:${sanitizado['categoria']}");
        }
        if ((sanitizado['calorias'] as String).isNotEmpty) {
          meta.add("Calorías aprox.:${sanitizado['calorias']}");
        }
        if ((sanitizado['tiempo'] as String).isNotEmpty) {
          meta.add("Tiempo aprox.:${sanitizado['tiempo']}");
        }
        buffer.writeln(meta.join(" | "));

        _recetasData.add(sanitizado);
      }

      setState(() {
        _catalogoContexto = buffer.toString();
        _catalogoCargado  = true;
        _procesando       = false;
      });

    } catch (e) {
      debugPrint("Error al cargar catálogo Firestore: $e");
      setState(() {
        _catalogoContexto = "(Sin datos disponibles)";
        _catalogoCargado  = true;
        _procesando       = false;
      });
    }

    await _hablar(_saludoInicial, guardarEnHistorial: false, estadoFondo: _EstadoFondo.presentacion);
  }

  // ═══════════════════════════════════════════════════════
  // INTENT ROUTER — Detección local de intenciones
  // ═══════════════════════════════════════════════════════
  Future<bool> _intentRouter(String texto) async {
    final String t = texto.toLowerCase().trim();

    // ── 1. REPETIR ÚLTIMA RESPUESTA ──
    if (_respuestaNID.isNotEmpty &&
        (t.contains("qué dijiste") ||
         t.contains("que dijiste") ||
         t.contains("repite eso") ||
         t.contains("repítelo") ||
         t.contains("no te entendí") ||
         t.contains("no te entendi"))) {
      await _hablar(_respuestaNID, guardarEnHistorial: false);
      return true;
    }

    // ── 2. SIGUIENTE PASO ──
    if (_recetaActivaNombre != null && _pasosActivos.isNotEmpty &&
        (t == "siguiente" ||
         t.contains("siguiente paso") ||
         t.contains("continúa") ||
         t.contains("continua") ||
         t.contains("adelante") ||
         t.contains("el siguiente"))) {
      _pasoActualIndex++;
      if (_pasoActualIndex < _pasosActivos.length) {
        final String pasoTexto = _pasosActivos[_pasoActualIndex];
        final String msg = "Paso ${_pasoActualIndex + 1}: $pasoTexto";
        // Si el paso contiene un valor de minutos, ofrecer temporizador
        final int? mins = _extraerMinutosDePaso(pasoTexto);
        final String msgConOferta = mins != null
            ? "$msg. ¿Deseas que active un temporizador de $mins ${mins == 1 ? 'minuto' : 'minutos'}?"
            : msg;
        if (mins != null) setState(() => _minutosOfrecidos = mins);
        await _hablar(msgConOferta, guardarEnHistorial: true);
      } else {
        setState(() => _minutosOfrecidos = null);
        await _hablar(
          "Has completado todos los pasos de $_recetaActivaNombre. ¡Buen provecho!",
          guardarEnHistorial: true,
        );
        _pasoActualIndex = _pasosActivos.length - 1;
      }
      return true;
    }

    // ── 3. PASO ANTERIOR ──
    if (_recetaActivaNombre != null && _pasosActivos.isNotEmpty &&
        (t.contains("paso anterior") ||
         t.contains("regresa") ||
         t.contains("vuelve") ||
         t.contains("atrás") ||
         t.contains("atras"))) {
      if (_pasoActualIndex > 0) {
        _pasoActualIndex--;
        final String msg =
            "Volviendo al paso ${_pasoActualIndex + 1}: ${_pasosActivos[_pasoActualIndex]}";
        await _hablar(msg, guardarEnHistorial: true);
      } else {
        await _hablar(
          "Ya estás en el primer paso de $_recetaActivaNombre.",
          guardarEnHistorial: true,
        );
      }
      return true;
    }

    // ── 4. REPETIR PASO ACTUAL ──
    if (_recetaActivaNombre != null &&
        _pasoActualIndex >= 0 &&
        _pasosActivos.isNotEmpty &&
        (t.contains("repite el paso") ||
         t.contains("repite ese") ||
         t.contains("de nuevo") ||
         t.contains("otra vez"))) {
      final String msg =
          "Repitiendo el paso ${_pasoActualIndex + 1}: ${_pasosActivos[_pasoActualIndex]}";
      await _hablar(msg, guardarEnHistorial: false);
      return true;
    }

    // ── 5. INICIAR PASOS / EMPEZAR A COCINAR ──
    if (_recetaActivaNombre != null && _pasosActivos.isNotEmpty &&
        (t.contains("empezar a cocinar") ||
         t.contains("dime los pasos") ||
         t.contains("quiero cocinar") ||
         t.contains("empecemos") ||
         t.contains("ir a los pasos") ||
         t.contains("sí, empieza") ||
         t.contains("si, empieza") ||
         t.contains("dale") ||
         t.contains("preparación") ||
         t.contains("preparacion"))) {
      if (_pasoActualIndex == -1) {
        _pasoActualIndex = 0;
        final String pasoTexto = _pasosActivos[0];
        final int? mins = _extraerMinutosDePaso(pasoTexto);
        final String base =
            "Perfecto, comenzamos con $_recetaActivaNombre. "
            "Paso 1: $pasoTexto.";
        final String msgFinal = mins != null
            ? "$base ¿Deseas que active un temporizador de $mins ${mins == 1 ? 'minuto' : 'minutos'}?"
            : "$base Cuando estés listo, dime 'siguiente'.";
        if (mins != null) setState(() => _minutosOfrecidos = mins);
        await _hablar(msgFinal, guardarEnHistorial: true);
      } else {
        _pasoActualIndex++;
        if (_pasoActualIndex < _pasosActivos.length) {
          final String pasoTexto = _pasosActivos[_pasoActualIndex];
          final int? mins = _extraerMinutosDePaso(pasoTexto);
          final String msg =
              "Paso ${_pasoActualIndex + 1}: $pasoTexto";
          final String msgFinal = mins != null
              ? "$msg. ¿Deseas que active un temporizador de $mins ${mins == 1 ? 'minuto' : 'minutos'}?"
              : msg;
          if (mins != null) setState(() => _minutosOfrecidos = mins);
          await _hablar(msgFinal, guardarEnHistorial: true);
        } else {
          setState(() => _minutosOfrecidos = null);
          await _hablar(
            "Has completado todos los pasos de $_recetaActivaNombre. ¡Buen provecho!",
            guardarEnHistorial: true,
          );
          _pasoActualIndex = _pasosActivos.length - 1;
        }
      }
      return true;
    }

    // ── 6. LISTAR INGREDIENTES DE LA RECETA ACTIVA ──
    if (_recetaActivaNombre != null && _ingredientesActivos.isNotEmpty &&
        (t.contains("ingredientes") ||
         t.contains("qué necesito") ||
         t.contains("que necesito") ||
         t.contains("qué lleva") ||
         t.contains("que lleva"))) {
      final String lista = _ingredientesActivos.join(", ");
      final String msg =
          "Para preparar $_recetaActivaNombre necesitas: $lista.";
      await _hablar(msg, guardarEnHistorial: true);
      return true;
    }

    // ── 7. LISTAR RECETAS POR CATEGORÍA ──
    final List<String> categorias = ["desayuno", "almuerzo", "cena", "refrescos", "snack"];
    for (final cat in categorias) {
      if (t.contains(cat)) {
        final List<String> encontradas = _recetasData
            .where((r) => r['categoria'].toString().toLowerCase().contains(cat))
            .map<String>((r) => r['nombre'].toString())
            .toList();
        if (encontradas.isNotEmpty) {
          final String msg =
              "En la categoría $cat tenemos: ${encontradas.join(', ')}.";
          await _hablar(msg, guardarEnHistorial: true);
        } else {
          await _hablar(
            "No encontré recetas de $cat en nuestro sistema actualmente.",
            guardarEnHistorial: true,
          );
        }
        return true;
      }
    }

    // ── 8. CONFIRMACIÓN / RECHAZO DEL TEMPORIZADOR OFRECIDO ──
    // Solo se activa si NID acaba de ofrecer un temporizador
    // para el paso actual (es decir, _minutosOfrecidos != null).
    if (_minutosOfrecidos != null) {
      final bool confirma =
          t.contains("sí") ||
          t.contains("si") ||
          t.contains("dale") ||
          t.contains("actívalo") ||
          t.contains("activalo") ||
          t.contains("ponlo") ||
          t.contains("pon") ||
          t.contains("sí por favor") ||
          t.contains("quiero") ||
          t.contains("hazlo") ||
          t.contains("okay") ||
          t.contains("ok");
      final bool rechaza =
          t.contains("no") ||
          t.contains("sin temporizador") ||
          t.contains("no hace falta") ||
          t.contains("no gracias") ||
          t.contains("omite") ||
          t.contains("salta");

      if (confirma && !rechaza) {
        final int mins = _minutosOfrecidos!;
        setState(() => _minutosOfrecidos = null);
        _iniciarTemporizador(mins);
        await _hablar(
          "Temporizador de $mins ${mins == 1 ? 'minuto' : 'minutos'} activado. Avísame con 'siguiente' cuando estés listo.",
          guardarEnHistorial: true,
        );
        return true;
      }
      if (rechaza) {
        setState(() => _minutosOfrecidos = null);
        await _hablar(
          "Entendido, sin temporizador. Avísame con 'siguiente' cuando estés listo.",
          guardarEnHistorial: true,
        );
        return true;
      }
    }

    return false;
  }

  // ─────────────────────────────────────────────
  // _extraerMinutosDePaso
  // Detecta patrones como "15 minutos", "30 min",
  // "1 minuto" dentro del texto de un paso.
  // Devuelve el entero de minutos o null si no hay.
  // ─────────────────────────────────────────────
  int? _extraerMinutosDePaso(String paso) {
    final match = RegExp(
      r'\b(\d+)\s*(?:minutos?|mins?)\b',
      caseSensitive: false,
    ).firstMatch(paso);
    if (match == null) return null;
    final int? v = int.tryParse(match.group(1)!);
    if (v == null || v <= 0) return null;
    return v;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // TOGGLE MICRÓFONO — Blindado para Flutter Web (Edge / Chrome)
  //
  // PROBLEMAS RESUELTOS:
  //
  //   [1] Locale inválido en Web Speech API
  //       Edge no acepta "es_ES" (guión bajo). Requiere BCP-47 con guión:
  //       "es-ES", "es-BO". Se normaliza ANTES de llamar a listen().
  //
  //   [2] Error "network" en bucle
  //       El WebSocket del STT queda en CLOSING sin llegar a CLOSED.
  //       Solución: llamar _speech.stop() desde onError para forzar el cierre
  //       del socket y romper el ciclo de reintentos del plugin.
  //
  //   [3] Edge emite "done"/"notListening" tras corte de red con texto vacío
  //       Candado triple en onStatus: solo procesa si _escuchando era true,
  //       mounted es true, y el texto capturado no está vacío.
  //
  //   [4] _speech.initialize() se re-llama en cada tap aunque ya fue
  //       inicializado — inofensivo pero genera logs. Se agrega guard
  //       _sttInicializado para evitarlo.
  // ═══════════════════════════════════════════════════════════════════════════

  /// Semáforo: evita re-inicializar el plugin STT en cada tap.
  bool _sttInicializado = false;

  /// Convierte un localeId de Flutter (guión bajo, e.g. "es_BO") al formato
  /// BCP-47 que requiere la Web Speech API (guión, e.g. "es-BO").
  String _normalizarLocaleWeb(String localeId) =>
      localeId.replaceAll('_', '-');

  Future<void> _toggleMicrofono() async {
    if (!_catalogoCargado || _procesando || _hablando) return;

    // ── Rama DETENER: el usuario pulsó para cortar la escucha activa ──
    if (_escuchando) {
      await _speech.stop();
      final String capturado = _textoEscuchado.trim();
      // Flash → transicion (procesando respuesta)
      _cambiarFondo(_EstadoFondo.transicion);
      setState(() {
        _escuchando    = false;
        _preguntaFinal = capturado;
      });
      if (capturado.isNotEmpty) {
        await _procesarTextoUsuario(capturado);
      }
      return;
    }

    // ── Rama INICIAR: preparar nueva sesión de escucha ──
    setState(() {
      _textoEscuchado = "";
      _respuestaNID   = "";
    });

    // Inicializar el plugin solo la primera vez (guard _sttInicializado).
    // En Web el plugin reutiliza la misma instancia SpeechRecognition del DOM;
    // volver a llamar initialize() después del primer éxito no hace daño,
    // pero genera un error silencioso en Edge que confunde los logs.
    if (!_sttInicializado) {
      final bool ok = await _speech.initialize(
        onError: (err) {
          // [FIX 2] Detener explícitamente para cerrar el socket WebSocket
          // y romper el bucle de error "network" en Edge.
          debugPrint("STT Error [${err.errorMsg}] permanente:${err.permanent}");
          if (mounted && _escuchando) {
            setState(() => _escuchando = false);
            _speech.stop(); // cierra el socket; no lanzar await aquí
          }
        },
        onStatus: (status) {
          debugPrint("STT Status: $status");

          // [FIX 3] Candado triple: solo actuar si el mic estaba genuinamente
          // activo. Descarta el "done" espurio de Edge tras un corte de red.
          if (!mounted || !_escuchando) return;

          if (status == "done" || status == "notListening") {
            final String capturado = _textoEscuchado.trim();
            setState(() => _escuchando = false);
            if (capturado.isNotEmpty) {
              _preguntaFinal = capturado;
              _procesarTextoUsuario(_preguntaFinal);
            }
          }
        },
      );

      if (!ok) {
        debugPrint("STT: micrófono no disponible en este dispositivo/navegador.");
        return;
      }
      _sttInicializado = true;
    }

    // ── [FIX 1] Selección y normalización del locale ──
    // Prioridad: es-BO → es-ES → primera variante es-* disponible.
    // La Web Speech API de Chromium requiere BCP-47 con guión, no guión bajo.
    String localeElegido = "es-ES"; // guardia por defecto ya en formato BCP-47
    try {
      final locales   = await _speech.locales();
      final localeIds = locales.map((l) => l.localeId).toList();
      debugPrint("STT Locales disponibles: $localeIds");

      if (localeIds.contains("es_BO") || localeIds.contains("es-BO")) {
        localeElegido = "es-BO";
      } else if (localeIds.contains("es_ES") || localeIds.contains("es-ES")) {
        localeElegido = "es-ES";
      } else {
        final esLocale = localeIds.firstWhere(
          (id) => id.toLowerCase().startsWith("es"),
          orElse: () => "es-ES",
        );
        localeElegido = _normalizarLocaleWeb(esLocale);
      }
    } catch (e) {
      debugPrint("STT locales() falló, usando es-ES: $e");
    }
    debugPrint("STT Locale elegido (BCP-47): $localeElegido");

    // Flash → escuchando (el mic va a activarse)
    _cambiarFondo(_EstadoFondo.escuchando);
    setState(() => _escuchando = true);

    _speech.listen(
      localeId:       localeElegido,
      listenFor:      const Duration(seconds: 60),
      pauseFor:       const Duration(seconds: 4),
      listenMode:     stt.ListenMode.dictation,
      partialResults: true,
      onResult: (result) {
        if (!mounted) return;

        setState(() {
          _textoEscuchado = result.recognizedWords;
          if (result.finalResult) {
            _escuchando    = false;
            _preguntaFinal = _textoEscuchado;
          }
        });

        if (result.finalResult && _preguntaFinal.trim().isNotEmpty) {
          _procesarTextoUsuario(_preguntaFinal.trim());
        }
      },
    );
  }

  // ═══════════════════════════════════════════════════════
  // PROCESADOR CENTRAL
  // ═══════════════════════════════════════════════════════
  Future<void> _procesarTextoUsuario(String texto) async {
    // ── Detectar cambio de receta ANTES del IntentRouter ──
    // Si el usuario menciona una receta diferente a la activa,
    // resetear el contexto para que Groq no mezcle datos entre recetas.
    if (_recetaActivaNombre != null) {
      final String t = texto.toLowerCase();
      bool mencionaNuevaReceta = false;

      for (final receta in _recetasData) {
        final String nombre = receta['nombre'].toString().toLowerCase();
        // Solo considerar si el nombre mencionado es DISTINTO al activo
        if (nombre == _recetaActivaNombre!.toLowerCase()) continue;

        if (t.contains(nombre) ||
            nombre.split(' ').any((w) => w.length > 3 && t.contains(w))) {
          mencionaNuevaReceta = true;
          // Resetear receta activa para que Groq reciba el catálogo limpio
          setState(() {
            _recetaActivaNombre    = null;
            _recetaActivaContexto  = "";
            _pasosActivos          = [];
            _ingredientesActivos   = [];
            _pasoActualIndex       = -1;
            // Limpiar historial para evitar contaminación cruzada
            _historial.clear();
          });
          debugPrint("Cambio de receta detectado → contexto reseteado");
          break;
        }
      }
      // Si detectó nueva receta, saltarse IntentRouter (que operaba sobre la vieja)
      if (mencionaNuevaReceta) {
        await _consultarNID(texto);
        return;
      }
    }

    final bool resueltaLocalmente = await _intentRouter(texto);
    if (resueltaLocalmente) return;
    await _consultarNID(texto);
  }

  // ═══════════════════════════════════════════════════════
  // CONSULTA AL LLM (GROQ + RAG + HISTORIAL)
  // ═══════════════════════════════════════════════════════
  // Modelo principal y modelo de respaldo (se activa automáticamente en 429)
  static const String _modeloPrincipal = "llama-3.3-70b-versatile";
  static const String _modeloRespaldo  = "llama-3.1-8b-instant";

  Future<void> _consultarNID(String pregunta) async {
    setState(() {
      _procesando   = true;
      _respuestaNID = "";
      _estadoFondo  = _EstadoFondo.transicion; // webp de procesando sin flash
    });

    _historial.add({"role": "user", "content": pregunta});

    final String catalogoParaApi = _recetaActivaContexto.isNotEmpty
        ? _recetaActivaContexto
        : _catalogoContexto;

    final String systemFinal = _systemPromptTemplate.replaceFirst(
      "{{CATALOGO}}",
      catalogoParaApi.isNotEmpty
          ? catalogoParaApi
          : "(Catálogo vacío — rechazar toda consulta de recetas)",
    );

    final List<Map<String, String>> mensajesApi = [
      {"role": "system", "content": systemFinal},
      ..._historial,
    ];

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    // Intenta primero con el modelo principal; si devuelve 429 (rate limit),
    // reintenta automáticamente con el modelo de respaldo.
    Future<http.Response> _llamarGroq(String modelo) => http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $_apiKey',
          },
          body: jsonEncode({
            "model":       modelo,
            "temperature": 0.1,
            "max_tokens":  200,
            "messages":    mensajesApi,
          }),
        );

    try {
      http.Response response = await _llamarGroq(_modeloPrincipal);

      if (response.statusCode == 429) {
        debugPrint("Groq 429 en $_modeloPrincipal — reintentando con $_modeloRespaldo");
        response = await _llamarGroq(_modeloRespaldo);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String respuesta = data['choices'][0]['message']['content'] ?? "";

        final timerMatch = RegExp(r'\[TIMER:(\d+)\]').firstMatch(respuesta);
        if (timerMatch != null) {
          // Solo activar el temporizador si la respuesta indica que el usuario
          // ya confirmó (el tag llega porque el usuario dijo sí, dale, etc.).
          // El prompt instruye a NID a incluirlo SOLO tras confirmación explícita.
          _iniciarTemporizador(int.parse(timerMatch.group(1)!));
          respuesta = respuesta.replaceAll(RegExp(r'\[TIMER:\d+\]'), '').trim();
        }

        respuesta = _limpiarParaTts(respuesta);

        // ── Fallback conversacional ──
        final bool esRespuestaDeRechazo = respuesta.toLowerCase().contains(
          "no se encuentra en nuestro sistema",
        );

        if (esRespuestaDeRechazo) {
          debugPrint("Fallback activado: respuesta de rechazo detectada.");
          final String? respuestaFallback =
              await _consultarAgenteExterno(pregunta);
          if (respuestaFallback != null && respuestaFallback.isNotEmpty) {
            respuesta = respuestaFallback;
          }
        }

        _intentarActivarReceta(pregunta, respuesta);

        _historial.add({"role": "assistant", "content": respuesta});

        if (_historial.length > 10) {
          _historial.removeRange(0, 2);
        }

        setState(() => _procesando = false);

        await _hablar(respuesta, guardarEnHistorial: false);

      } else {
        debugPrint("Groq error: ${response.statusCode} ${response.body}");
        _historial.removeLast();
        setState(() => _procesando = false);
        await _hablar(
          "El portal está inestable. Intenta de nuevo.",
          guardarEnHistorial: false,
        );
      }
    } catch (e) {
      debugPrint("Excepción Groq: $e");
      _historial.removeLast();
      setState(() => _procesando = false);
      await _hablar(
        "No pude conectarme. Revisa tu conexión.",
        guardarEnHistorial: false,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // _consultarAgenteExterno — Fallback acotado (sin alucinaciones)
  // ═══════════════════════════════════════════════════════════════════════════
  Future<String?> _consultarAgenteExterno(String preguntaUsuario) async {
    const String systemFallback =
        "Eres NID, el asistente culinario de voz de PrograMovil, con esencia cibernética andina. "
        "El usuario preguntó por una receta o ingrediente que NO está en la base de datos oficial. "
        "Tu única tarea es: confirmar amablemente que esa información no está disponible en el sistema, "
        "y sugerir al usuario que explore las recetas que sí están registradas o aguarde futuras actualizaciones. "
        "PROHIBIDO ABSOLUTO: inventar ingredientes, cantidades, pasos o cualquier dato culinario. "
        "No menciones conocimiento externo sobre la receta solicitada. "
        "Responde en máximo 2 oraciones, en prosa fluida, sin listas, sin asteriscos, sin emojis.";

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

    try {
      Future<http.Response> _llamarGroqFallback(String modelo) => http.post(
            url,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              "model":       modelo,
              "temperature": 0.2,
              "max_tokens":  80,
              "messages": [
                {"role": "system", "content": systemFallback},
                {"role": "user",   "content": preguntaUsuario},
              ],
            }),
          ).timeout(
            const Duration(seconds: 12),
            onTimeout: () {
              debugPrint("[Fallback] Groq timeout de 12 s");
              return http.Response('{"error":"timeout"}', 408);
            },
          );

      http.Response response = await _llamarGroqFallback(_modeloPrincipal);

      if (response.statusCode == 429) {
        debugPrint("[Fallback] 429 en $_modeloPrincipal — reintentando con $_modeloRespaldo");
        response = await _llamarGroqFallback(_modeloRespaldo);
      }

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String respuestaFallback =
            data['choices'][0]['message']['content'] ?? "";

        final timerMatch =
            RegExp(r'\[TIMER:(\d+)\]').firstMatch(respuestaFallback);
        if (timerMatch != null) {
          _iniciarTemporizador(int.parse(timerMatch.group(1)!));
          respuestaFallback = respuestaFallback
              .replaceAll(RegExp(r'\[TIMER:\d+\]'), '')
              .trim();
        }

        debugPrint("[Fallback] Respuesta acotada del agente externo recibida.");
        return _limpiarParaTts(respuestaFallback);
      } else {
        debugPrint("[Fallback] Error HTTP: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("[Fallback] Excepción: $e");
      return null;
    }
  }

  // ─────────────────────────────────────────────
  // _limpiarParaTts
  // Elimina markdown y expande abreviaciones que
  // el motor TTS leería de forma incorrecta.
  // ─────────────────────────────────────────────
  String _limpiarParaTts(String texto) {
    String t = texto
        .replaceAll(RegExp(r'\*+'), '')
        .replaceAll(RegExp(r'\[.*?\]'), '')
        .replaceAll(RegExp(r'^\s*[-•–—]\s', multiLine: true), '')
        .replaceAll(RegExp(r'^\s*\d+\.\s', multiLine: true), '')
        .replaceAll(RegExp(r'#+\s'), '')
        .replaceAll('_', '')
        .replaceAll('`', '')
        .replaceAll(RegExp(r'\n{2,}'), '\n')
        .trim();

    // ── Abreviaciones habladas ──
    // Fracciones con texto
    t = t.replaceAllMapped(
      RegExp(r'\b0\.5\s*(kg)\b', caseSensitive: false),
      (_) => 'medio kilo',
    );
    t = t.replaceAllMapped(
      RegExp(r'\b0\.25\s*(kg)\b', caseSensitive: false),
      (_) => 'un cuarto de kilo',
    );
    t = t.replaceAllMapped(
      RegExp(r'\b0\.5\s*(l|lt|litros?)\b', caseSensitive: false),
      (_) => 'medio litro',
    );
    t = t.replaceAllMapped(
      RegExp(r'\b500\s*ml\b', caseSensitive: false),
      (_) => 'medio litro',
    );
    t = t.replaceAllMapped(
      RegExp(r'\b250\s*ml\b', caseSensitive: false),
      (_) => 'un cuarto de litro',
    );
    t = t.replaceAllMapped(
      RegExp(r'\b0\.25\s*(l|lt|litros?)\b', caseSensitive: false),
      (_) => 'un cuarto de litro',
    );
    // Fracciones escritas
    t = t.replaceAll(RegExp(r'\b1/2\b'), 'media');
    t = t.replaceAll(RegExp(r'\b1/4\b'), 'un cuarto de');
    // Unidades de medida abreviadas
    t = t.replaceAllMapped(
      RegExp(r'\b(\d+(?:\.\d+)?)\s*cdtas?\b', caseSensitive: false),
      (m) => '${m[1]} cucharadita${_plural(m[1]!)}',
    );
    t = t.replaceAllMapped(
      RegExp(r'\b(\d+(?:\.\d+)?)\s*cdas?\b', caseSensitive: false),
      (m) => '${m[1]} cucharada${_plural(m[1]!)}',
    );
    t = t.replaceAllMapped(
      RegExp(r'\b(\d+(?:\.\d+)?)\s*tbsps?\b', caseSensitive: false),
      (m) => '${m[1]} cucharada${_plural(m[1]!)}',
    );
    t = t.replaceAllMapped(
      RegExp(r'\b(\d+(?:\.\d+)?)\s*tsps?\b', caseSensitive: false),
      (m) => '${m[1]} cucharadita${_plural(m[1]!)}',
    );
    t = t.replaceAllMapped(
      RegExp(r'\b(\d+(?:\.\d+)?)\s*gr?\b(?!\w)', caseSensitive: false),
      (m) => '${m[1]} gramos',
    );
    t = t.replaceAllMapped(
      RegExp(r'\b(\d+(?:\.\d+)?)\s*kg\b', caseSensitive: false),
      (m) {
        final double? v = double.tryParse(m[1]!);
        if (v == null) return '${m[1]} kilos';
        if (v == 0.5) return 'medio kilo';
        if (v == 0.25) return 'un cuarto de kilo';
        return '${m[1]} ${v == 1 ? 'kilo' : 'kilos'}';
      },
    );
    t = t.replaceAllMapped(
      RegExp(r'\b(\d+(?:\.\d+)?)\s*ml\b', caseSensitive: false),
      (m) => '${m[1]} mililitros',
    );
    t = t.replaceAllMapped(
      RegExp(r'\b(\d+(?:\.\d+)?)\s*(l|lt)\b(?!\w)', caseSensitive: false),
      (m) {
        final double? v = double.tryParse(m[1]!);
        if (v == null) return '${m[1]} litros';
        if (v == 0.5) return 'medio litro';
        if (v == 0.25) return 'un cuarto de litro';
        return '${m[1]} ${v == 1 ? 'litro' : 'litros'}';
      },
    );

    return t;
  }

  /// Devuelve "s" si el número es plural (≠ 1), "" si es singular.
  String _plural(String numStr) {
    final double? v = double.tryParse(numStr);
    return (v != null && v == 1.0) ? '' : 's';
  }

  // ─────────────────────────────────────────────
  // _intentarActivarReceta
  // ─────────────────────────────────────────────
  void _intentarActivarReceta(String pregunta, String respuestaNid) {
    if (_recetaActivaNombre != null) return;
    if (respuestaNid.contains("no se encuentra en nuestro sistema")) return;

    final String p = pregunta.toLowerCase();
    for (final receta in _recetasData) {
      final String nombre = receta['nombre'].toString().toLowerCase();
      if (p.contains(nombre) ||
          nombre.split(' ').any((w) => w.length > 3 && p.contains(w))) {

        setState(() {
          _recetaActivaContexto = receta['contextoTexto'] as String;
          _recetaActivaNombre   = receta['nombre'].toString();
          _pasosActivos         = List<String>.from(receta['pasos'] as List);
          _ingredientesActivos  = List<String>.from(receta['ingredientes'] as List);
          _pasoActualIndex      = -1;
        });
        debugPrint("Receta activada: $_recetaActivaNombre");
        return;
      }
    }
  }

  // ─────────────────────────────────────────────
  // _hablar — Punto único de reproducción TTS
  // ─────────────────────────────────────────────
  Future<void> _hablar(
    String texto, {
    required bool guardarEnHistorial,
    _EstadoFondo estadoFondo = _EstadoFondo.hablando,
  }) async {
    final String limpio = _limpiarParaTts(texto);
    setState(() {
      _respuestaNID = limpio;
      _hablando     = true;
    });
    _cambiarFondo(estadoFondo);
    if (guardarEnHistorial) {
      _historial.add({"role": "assistant", "content": limpio});
    }
    await _tts.speak(limpio);
  }

  // ─────────────────────────────────────────────
  // _fondoPorEstado — Devuelve el asset path según
  // el estado de fondo activo.
  // ─────────────────────────────────────────────
  String _fondoPorEstado(_EstadoFondo estado) {
    switch (estado) {
      case _EstadoFondo.transicion:
        return 'assets/images/nid_transicion.webp';
      case _EstadoFondo.escuchando:
        return 'assets/images/nid_escuchando.webp';
      case _EstadoFondo.hablando:
        return 'assets/images/nid_hablando.webp';
      case _EstadoFondo.presentacion:
      default:
        return 'assets/images/nid_presentacion.webp';
    }
  }

  // ─────────────────────────────────────────────
  // Estado dinámico de NID
  // ─────────────────────────────────────────────
  String get _estadoActual {
    if (_procesando && !_catalogoCargado) return "CARGANDO CATÁLOGO...";
    if (_procesando)  return "NID ESTÁ PENSANDO...";
    if (_escuchando)  return "ESCUCHANDO...";
    if (_hablando)    return "NID ESTÁ HABLANDO...";
    return "LISTO PARA ESCUCHARTE";
  }

  // ═══════════════════════════════════════════════════════
  //  BUILD PRINCIPAL
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: Stack(
        fit: StackFit.expand,
        children: [

          // ── Fondo dinámico — 3 estados con transición instantánea ──
          // El AnimatedSwitcher maneja el crossfade entre estados.
          // La transición flash (nid_transicion.webp) dura 250 ms
          // y luego cede al estado destino (ver _cambiarFondo).
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Align(
              key: ValueKey(_estadoFondo),
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: size.width,
                height: size.height * 0.75,
                child: _nidActivado
                    ? Image.asset(
                        _fondoPorEstado(_estadoFondo),
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        'assets/images/fondo.webp',
                        fit: BoxFit.cover,
                      ),
              ),
            ),
          ),

            // ── Panel NID: visible solo cuando NID está activado ──
            if (_nidActivado) ...[
              // Gradiente oscuro inferior para legibilidad del panel
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.45, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        _negro.withOpacity(0.85),
                      ],
                    ),
                  ),
                ),
              ),

              // Temporizador flotante
              _buildTimerWidget(),

              // Panel de texto + controles (parte inferior)
              SafeArea(
                child: Column(
                  children: [
                    // ── AppBar en modo NID ──
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Espacio vacío para mantener el layout del Row
                          const SizedBox.shrink(),
                          // Botón reset + indicador RAG
                          Row(
                            children: [
                              if (_historial.isNotEmpty &&
                                  !_procesando &&
                                  !_escuchando)
                                IconButton(
                                  tooltip: "Nueva conversación",
                                  icon: const Icon(Icons.refresh,
                                      color: _cianNeon, size: 20),
                                  onPressed: () {
                                    setState(() {
                                      _historial.clear();
                                      _preguntaFinal        = "";
                                      _respuestaNID         = "";
                                      _textoEscuchado       = "";
                                      _recetaActivaNombre   = null;
                                      _recetaActivaContexto = "";
                                      _pasosActivos         = [];
                                      _ingredientesActivos  = [];
                                      _pasoActualIndex      = -1;
                                    });
                                    _cancelarTemporizador();
                                  },
                                ),
                              Icon(Icons.circle,
                                  size: 8,
                                  color: _catalogoCargado
                                      ? _verdeApp
                                      : Colors.orange),
                              const SizedBox(width: 4),
                              Text(
                                _catalogoCargado ? "RAG activo" : "Cargando...",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _catalogoCargado
                                      ? _verdeApp
                                      : Colors.orange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const Spacer(flex: 5),

                    // Panel de texto translúcido
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: _buildPanelTexto(),
                      ),
                    ),

                    // Controles (micrófono)
                    _buildControles(),

                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],

            // ── Botones de transición: visibles solo cuando NID está dormido ──
            if (!_nidActivado)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    children: [
                      SizedBox(height: size.height * 0.12),
                      const Spacer(),
                      SizedBox(height: size.height * 0.35),
                      const Spacer(),

                      // Botón 1 — Seleccionar receta del catálogo
                      _buildDuolingoButton(
                        label: "Seleccionar una receta de mi catálogo",
                        colorBase: _verdeNeon,
                        colorSombra: _verdeSombra,
                        onTap: () {
                          // Navega a la pantalla de catálogo sin activar NID
                          Navigator.pop(context);
                        },
                      ),

                      const SizedBox(height: 16),

                      // Botón 2 — Saltar paso → despierta a NID
                      _buildDuolingoButton(
                        label: "Saltar este paso",
                        colorBase: _moradoNeon,
                        colorSombra: _moradoSombra,
                        onTap: _activarNID,
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
          // ── Flecha de regreso — siempre encima de todo ──
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
                onPressed: () {
                  _speech.stop();
                  _tts.stop();
                  Navigator.pop(context);
                },
              ),
            ),
          ),

          ],
        ),
      );
  }

  // ─────────────────────────────────────────────
  // _buildDuolingoButton — Botón relieve 3D
  // ─────────────────────────────────────────────
  Widget _buildDuolingoButton({
    required String label,
    required Color colorBase,
    required Color colorSombra,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: colorBase,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colorSombra,
              offset: const Offset(0, 5),
              blurRadius: 0,
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildTimerWidget — Tarjeta flotante del timer
  // ─────────────────────────────────────────────
  Widget _buildTimerWidget() {
    if (!_timerActivo) return const SizedBox.shrink();

    final int min = _timerDuration.inMinutes;
    final int seg = _timerDuration.inSeconds % 60;
    final String display =
        "${min.toString().padLeft(2, '0')}:${seg.toString().padLeft(2, '0')}";

    return Positioned(
      top: kToolbarHeight + 24 + 8,
      left: 20,
      right: 20,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D1E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _cianNeon, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _cianNeon.withOpacity(0.3),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _cianNeon.withOpacity(0.08),
                shape: BoxShape.circle,
                border: Border.all(color: _cianNeon.withOpacity(0.4)),
              ),
              child: const Icon(Icons.timer_rounded, color: _cianNeon, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "TEMPORIZADOR",
                    style: TextStyle(
                      fontSize: 9,
                      color: _cianNeon.withOpacity(0.65),
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    display,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: _cianNeon,
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: _cancelarTemporizador,
              child: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.redAccent, width: 1),
                  color: Colors.redAccent.withOpacity(0.08),
                ),
                child: const Icon(Icons.close,
                    color: Colors.redAccent, size: 17),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildPanelTexto
  // ─────────────────────────────────────────────
  Widget _buildPanelTexto() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.62),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _moradoNeon.withOpacity(0.4), width: 1),
        boxShadow: [
          BoxShadow(color: _moradoNeon.withOpacity(0.1), blurRadius: 12),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            if (_historial.length >= 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(Icons.memory,
                        color: _moradoNeon.withOpacity(0.6), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      "MEMORIA: ${_historial.length ~/ 2} turnos",
                      style: TextStyle(
                        color: _moradoNeon.withOpacity(0.6),
                        fontSize: 9,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

            if (_textoEscuchado.isNotEmpty || _preguntaFinal.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.person_outline,
                      color: _cianNeon.withOpacity(0.7), size: 14),
                  const SizedBox(width: 6),
                  Text("TÚ",
                      style: TextStyle(
                          color: _cianNeon.withOpacity(0.7),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _escuchando ? _textoEscuchado : _preguntaFinal,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 12),
            ],

            if (_procesando && _catalogoCargado) ...[
              Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 1.5, color: _doradoInca),
                  ),
                  const SizedBox(width: 8),
                  Text("NID ESTÁ PENSANDO...",
                      style: TextStyle(
                          color: _doradoInca.withOpacity(0.7),
                          fontSize: 11,
                          letterSpacing: 1)),
                ],
              ),
            ] else if (_respuestaNID.isNotEmpty) ...[
              Row(
                children: [
                  Icon(Icons.auto_awesome,
                      color: _doradoInca.withOpacity(0.8), size: 14),
                  const SizedBox(width: 6),
                  Text("NID",
                      style: TextStyle(
                          color: _doradoInca.withOpacity(0.8),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _respuestaNID,
                style: const TextStyle(
                    color: Color(0xFFE8E0FF), fontSize: 14, height: 1.5),
              ),
              if (_recetaActivaNombre != null) ...[
                const SizedBox(height: 12),
                _buildAccionesRapidas(),
              ],
            ] else if (!_procesando) ...[
              Center(
                child: Text(
                  _catalogoCargado
                      ? "Pulsa el micrófono y habla con NID"
                      : "Cargando el catálogo de recetas...",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 13,
                      height: 1.5),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildAccionesRapidas — Chips contextuales
  // ─────────────────────────────────────────────
  Widget _buildAccionesRapidas() {
    final List<Map<String, dynamic>> acciones = [
      if (_pasoActualIndex == -1)
        {"label": "Empezar a cocinar", "cmd": "empezar a cocinar"},
      if (_pasoActualIndex >= 0 && _pasoActualIndex < _pasosActivos.length - 1)
        {"label": "Siguiente paso", "cmd": "siguiente paso"},
      if (_pasoActualIndex > 0)
        {"label": "Paso anterior", "cmd": "paso anterior"},
      if (_pasoActualIndex >= 0)
        {"label": "Repetir", "cmd": "repite el paso"},
      {"label": "Ingredientes", "cmd": "dime los ingredientes"},
    ];

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: acciones.map((a) {
        return GestureDetector(
          onTap: () => _procesarTextoUsuario(a["cmd"] as String),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _moradoNeon.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _moradoNeon.withOpacity(0.5)),
            ),
            child: Text(
              a["label"] as String,
              style: const TextStyle(
                  color: Color(0xFFD0BBFF),
                  fontSize: 11,
                  fontWeight: FontWeight.w600),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ─────────────────────────────────────────────
  // _buildControles — Botón del micrófono
  // ─────────────────────────────────────────────
  Widget _buildControles() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_hablando)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: GestureDetector(
                onTap: () async {
                  await _tts.stop();
                  // Flash → escuchando al interrumpir TTS con botón rojo
                  _cambiarFondo(_EstadoFondo.escuchando);
                  setState(() => _hablando = false);
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.redAccent, width: 1.5),
                    color: Colors.redAccent.withOpacity(0.1),
                  ),
                  child: const Icon(Icons.stop,
                      color: Colors.redAccent, size: 22),
                ),
              ),
            ),

          GestureDetector(
            onTap: _toggleMicrofono,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width:  _escuchando ? 84 : 72,
              height: _escuchando ? 84 : 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: _escuchando
                      ? [_cianNeon, _moradoNeon]
                      : [_moradoNeon, const Color(0xFF3D1080)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_escuchando ? _cianNeon : _moradoNeon)
                        .withOpacity(0.6),
                    blurRadius: _escuchando ? 24 : 12,
                    spreadRadius: _escuchando ? 4 : 0,
                  ),
                ],
              ),
              child: Icon(
                _escuchando ? Icons.mic : Icons.mic_none,
                color: Colors.white,
                size: _escuchando ? 36 : 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// _EstadoFondo — Máquina de estados para los 3 fondos webp de NID
// ═══════════════════════════════════════════════════════════════════════════
enum _EstadoFondo {
  presentacion, // Reposo             → assets/images/nid_presentacion.webp
  transicion,   // Flash 250 ms       → assets/images/nid_transicion.webp
  escuchando,   // Mic activo         → assets/images/nid_escuchando.webp
  hablando,     // TTS activo         → assets/images/nid_hablando.webp
}

// ═══════════════════════════════════════════════════════════════════════════
// _AndeanPatternPainter — patrón geométrico andino (rombos tipo wiphala)
// ═══════════════════════════════════════════════════════════════════════════
class _AndeanPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    paint.color = const Color(0xFF0A0A1A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    const colors = [
      Color(0xFF7B2FBE),
      Color(0xFF00F5FF),
      Color(0xFFFFD700),
      Color(0xFF2D9E73),
    ];

    const step = 20.0;
    int colorIndex = 0;

    for (double x = 0; x < size.width; x += step) {
      for (double y = 0; y < size.height; y += step) {
        paint.color = colors[colorIndex % colors.length].withOpacity(0.18);
        final path = Path()
          ..moveTo(x + step / 2, y)
          ..lineTo(x + step, y + step / 2)
          ..lineTo(x + step / 2, y + step)
          ..lineTo(x, y + step / 2)
          ..close();
        canvas.drawPath(path, paint);
        colorIndex++;
      }
    }
  }

  @override
  bool shouldRepaint(_AndeanPatternPainter old) => false;
}


