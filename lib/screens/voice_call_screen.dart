import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

// ═══════════════════════════════════════════════════════════════════════════
// VoiceCallScreen — Asistente de voz NID
//
// FLUJO COMPLETO:
//   1. Al abrir → carga catálogo Firestore (RAG) en segundo plano.
//   2. Saludo inicial automático: NID se presenta con la frase exacta.
//   3. Usuario pulsa micrófono → STT transcribe su voz.
//   4. IntentRouter detecta la intención local (siguiente paso, repetir,
//      listar ingredientes, etc.) antes de gastar tokens en Groq.
//   5. Si la intención requiere IA → Groq + historial + catálogo.
//   6. Respuesta limpia (sin markdown) → flutter_tts la reproduce.
//
// DEPENDENCIAS (pubspec.yaml):
//   speech_to_text: ^6.6.0
//   flutter_tts:    ^4.0.2
//   cloud_firestore, http, flutter_dotenv  ← ya están en el proyecto
// ═══════════════════════════════════════════════════════════════════════════

class VoiceCallScreen extends StatefulWidget {
  const VoiceCallScreen({super.key});

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with SingleTickerProviderStateMixin {

  // ─────────────────────────────────────────────
  // PALETA CIBERPUNK ANDINO
  // ─────────────────────────────────────────────
  static const Color _negro      = Color(0xFF0A0A0F);
  static const Color _moradoNeon = Color(0xFF7B2FBE);
  static const Color _cianNeon   = Color(0xFF00F5FF);
  static const Color _doradoInca = Color(0xFFFFD700);
  static const Color _verdeApp   = Color(0xFF2D9E73);

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
  String _respuestaNID   = "";   // Última respuesta visible y en caché para TTS
  bool   _escuchando     = false;
  bool   _procesando     = false;
  bool   _hablando       = false;

  // ─────────────────────────────────────────────
  // CATÁLOGO RAG (Firestore)
  // _catalogoContexto  → String plano para inyectar en el prompt
  // _recetasData       → datos estructurados para el IntentRouter local
  // _catalogoCargado   → semáforo UI
  // ─────────────────────────────────────────────
  /// Índice slim: solo "ID | Nombre | Categoría | Calorías | Tiempo"
  /// Se inyecta en Groq cuando NO hay receta activa (~500 tokens máx.)
  String _catalogoContexto = "";

  /// Texto completo de la receta que el usuario eligió en esta sesión.
  /// Se inyecta en Groq EN LUGAR del catálogo una vez que el usuario
  /// menciona una receta concreta. Reduce el contexto de ~5 000 → ~300 tokens.
  String _recetaActivaContexto = "";

  bool   _catalogoCargado  = false;

  /// Cada entrada: { 'nombre', 'categoria', 'calorias', 'tiempo',
  ///                 'ingredientes': List<String>, 'pasos': List<String> }
  final List<Map<String, dynamic>> _recetasData = [];

  // ─────────────────────────────────────────────
  // ESTADO DE RECETA ACTIVA (control paso a paso)
  // ─────────────────────────────────────────────

  /// Nombre de la receta que el usuario eligió en esta sesión
  String? _recetaActivaNombre;

  /// Pasos de la receta activa (lista limpia de Strings)
  List<String> _pasosActivos = [];

  /// Ingredientes de la receta activa (lista limpia de Strings)
  List<String> _ingredientesActivos = [];

  /// Índice del paso que NID está dictando actualmente (0-based)
  int _pasoActualIndex = -1; // -1 = no se ha iniciado el dictado

  // ─────────────────────────────────────────────
  // HISTORIAL PARA GROQ (memoria a corto plazo)
  // Formato: [{"role": "user"/"assistant", "content": "..."}]
  // Se envía completo en cada llamada para mantener el hilo.
  // ─────────────────────────────────────────────
  final List<Map<String, String>> _historial = [];

  // ─────────────────────────────────────────────
  // ANIMACIÓN DE PULSO DEL AVATAR
  // ─────────────────────────────────────────────
  late AnimationController _pulsoController;
  late Animation<double>    _pulsoAnimation;

  // ═══════════════════════════════════════════════════════════════════════
  // SYSTEM PROMPT — POLÍTICA ZERO-KNOWLEDGE + FORMATO TTS LIMPIO
  //
  // ESTRUCTURA:
  //   [A] Identidad de NID
  //   [B] Catálogo oficial inyectado en {{CATALOGO}}
  //   [C] Protocolo de verificación obligatorio (checklist mental)
  //   [D] Protocolo de rechazo absoluto + frase exacta
  //   [E] Reglas de formato para TTS (sin markdown, sin listas)
  //   [F] Reglas de brevedad y dosificación del contenido
  // ═══════════════════════════════════════════════════════════════════════
  static const String _systemPromptTemplate = """
[A — IDENTIDAD]
Eres NID, el asistente culinario de voz de PrograMovil.
Tu esencia es la de un guía gastronómico andino preciso y solemne.
Tu ÚNICO propósito es asistir al usuario usando el CATÁLOGO OFICIAL que se te entrega.

[B — CATÁLOGO OFICIAL — FUENTE ÚNICA DE VERDAD]
El siguiente catálogo es la ÚNICA fuente de información que puedes usar.
Tu conocimiento previo sobre cocina NO EXISTE en este contexto.
════════════════════════════════════════
CATÁLOGO OFICIAL DE RECETAS PROGRA-MOVIL:
{{CATALOGO}}
════════════════════════════════════════

[C — PROTOCOLO DE VERIFICACIÓN (ejecutar antes de CADA respuesta)]
Antes de responder, verifica mentalmente:
  1. El nombre de la receta aparece textualmente en el catálogo.
  2. Los ingredientes que mencionaré están listados en esa entrada.
  3. Los pasos que describiré provienen literalmente de ese catálogo.
Si cualquier verificación falla → activa el Protocolo D sin excepción.

[D — PROTOCOLO DE RECHAZO ABSOLUTO]
Si el plato, receta o ingrediente NO está en el catálogo, responde EXACTAMENTE:
"Lo siento, esa receta no se encuentra en nuestro sistema de PrograMovil actualmente."
PROHIBIDO: completar, deducir, inventar ingredientes, pasos, cantidades o sustitutos que no estén en el catálogo.
PROHIBIDO: usar conocimiento externo aunque la receta sea mundialmente conocida.

[E — FORMATO TTS OBLIGATORIO — NUNCA VIOLAR]
Tus respuestas serán leídas en voz alta por un motor Text-to-Speech.
OBLIGATORIO:
  - Sin asteriscos, guiones decorativos, corchetes, ni emojis.
  - Sin listas numeradas ni con viñetas. Solo texto fluido y natural.
  - Sin encabezados ni negritas. Solo prosa conversacional.
  - Sin símbolos especiales de ningún tipo.

[F — BREVEDAD Y DOSIFICACIÓN — REGLA DE ORO]
NUNCA listes ingredientes ni pasos de forma automática al confirmar una receta.
Cuando el usuario mencione un plato: confirma el nombre, menciona calorías y tiempo estimado si están en el catálogo, y pregunta si desea revisar ingredientes o ir directo a los pasos.
Máximo 3 oraciones por respuesta.
""";

  // ─────────────────────────────────────────────
  // SALUDO INICIAL EXACTO DE NID
  // Se pronuncia automáticamente al terminar de
  // cargar el catálogo. No gasta tokens de API.
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

    _configurarTts();
    _cargarCatalogoYSaludar(); // Carga Firestore y luego pronuncia el saludo
  }

  @override
  void dispose() {
    _pulsoController.dispose();
    _speech.stop();
    _tts.stop();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // _configurarTts
  // Voz pausada y levemente grave para NID.
  // ─────────────────────────────────────────────
  Future<void> _configurarTts() async {
    await _tts.setLanguage("es-US");
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(0.85);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _hablando = false);
    });
  }

  // ═══════════════════════════════════════════════════════
  // CARGA DE CATÁLOGO FIRESTORE (RAG)
  //
  // Construye dos estructuras en paralelo:
  //   1. _catalogoContexto (String) → se inyecta en el prompt
  //   2. _recetasData (List)        → permite lógica local sin API
  //
  // Manejo robusto de tipos: ingredientes y pasos pueden llegar
  // como String simples o como Map con claves variables.
  // ═══════════════════════════════════════════════════════
  Future<void> _cargarCatalogoYSaludar() async {
    setState(() => _procesando = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('app-recetas-completas')
          .get();

      // ── Índice slim para el catálogo (solo metadatos básicos, sin ingredientes ni pasos) ──
      // Objetivo: mantener el contexto inicial < 500 tokens aunque haya muchas recetas.
      // Los ingredientes y pasos SOLO se envían a Groq cuando el usuario elige una receta.
      final StringBuffer buffer = StringBuffer();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // ── Metadatos básicos ──
        final String nombre    = (data['nombre']    ?? 'Sin nombre').toString();
        final String categoria = (data['categoria'] ?? '').toString();
        final String calorias  = (data['calorias']  ?? '').toString();
        final String tiempo    = (data['tiempo']    ?? '').toString();

        // ── Línea slim: ID | Nombre | meta ──
        final List<String> meta = ["ID:${doc.id}", "RECETA:$nombre"];
        if (categoria.isNotEmpty) meta.add("Categoría:$categoria");
        if (calorias.isNotEmpty)  meta.add("Calorías:$calorias");
        if (tiempo.isNotEmpty)    meta.add("Tiempo:$tiempo");
        buffer.writeln(meta.join(" | "));

        // ── Ingredientes: tolerante a String y Map ──
        final List rawIngredientes = data['ingredientes'] ?? [];
        final List<String> ingredientesLimpios = rawIngredientes.map<String>((ing) {
          if (ing is Map) {
            final n = (ing['nombre']   ?? ing['name']  ?? '').toString();
            final c = (ing['cantidad'] ?? ing['amount'] ?? '').toString();
            return c.isNotEmpty ? "$n ($c)" : n;
          }
          return ing.toString();
        }).where((s) => s.isNotEmpty).toList();

        // ── Pasos: tolerante a String y Map con claves variables ──
        final List rawPasos = data['pasos'] ?? [];
        final List<String> pasosLimpios = rawPasos.map<String>((paso) {
          if (paso is Map) {
            return (paso['descripcion'] ??
                    paso['texto']       ??
                    paso['detalle']     ??
                    paso['step']        ??
                    paso.toString()).toString();
          }
          return paso.toString();
        }).where((s) => s.isNotEmpty).toList();

        // ── Guardar estructura completa LOCAL para el IntentRouter y para
        //    construir _recetaActivaContexto cuando el usuario elija una receta ──
        _recetasData.add({
          'id':           doc.id,
          'nombre':       nombre,
          'categoria':    categoria,
          'calorias':     calorias,
          'tiempo':       tiempo,
          'ingredientes': ingredientesLimpios,
          'pasos':        pasosLimpios,
        });
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

    // ── Saludo inicial obligatorio: se pronuncia sin gastar tokens ──
    await _hablar(_saludoInicial, guardarEnHistorial: false);
  }

  // ═══════════════════════════════════════════════════════
  // INTENT ROUTER — Detección local de intenciones
  //
  // Procesa el texto del usuario ANTES de llamar a Groq.
  // Si detecta una intención manejable localmente (siguiente
  // paso, repetir, listar ingredientes, etc.) la resuelve
  // sin gastar tokens. Solo delega a Groq lo que requiere
  // comprensión semántica real.
  //
  // Devuelve true si manejó la intención; false si debe
  // continuar hacia _consultarNID().
  // ═══════════════════════════════════════════════════════
  Future<bool> _intentRouter(String texto) async {
    final String t = texto.toLowerCase().trim();

    // ── 1. REPETIR ÚLTIMA RESPUESTA ──────────────────────
    // "qué dijiste", "repite eso", "no te entendí"
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

    // ── 2. SIGUIENTE PASO ────────────────────────────────
    // "siguiente", "siguiente paso", "continúa", "adelante"
    if (_recetaActivaNombre != null && _pasosActivos.isNotEmpty &&
        (t == "siguiente" ||
         t.contains("siguiente paso") ||
         t.contains("continúa") ||
         t.contains("continua") ||
         t.contains("adelante") ||
         t.contains("el siguiente"))) {
      _pasoActualIndex++;
      if (_pasoActualIndex < _pasosActivos.length) {
        final String msg =
            "Paso ${_pasoActualIndex + 1}: ${_pasosActivos[_pasoActualIndex]}";
        await _hablar(msg, guardarEnHistorial: true);
      } else {
        await _hablar(
          "Has completado todos los pasos de $_recetaActivaNombre. ¡Buen provecho!",
          guardarEnHistorial: true,
        );
        _pasoActualIndex = _pasosActivos.length - 1; // No salir del array
      }
      return true;
    }

    // ── 3. PASO ANTERIOR ─────────────────────────────────
    // "paso anterior", "regresa", "vuelve"
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

    // ── 4. REPETIR PASO ACTUAL ───────────────────────────
    // "repite el paso", "repite eso", "de nuevo"
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

    // ── 5. INICIAR PASOS / EMPEZAR A COCINAR ─────────────
    // "empezar a cocinar", "dime los pasos", "quiero cocinar"
    if (_recetaActivaNombre != null && _pasosActivos.isNotEmpty &&
        (t.contains("empezar a cocinar") ||
         t.contains("dime los pasos") ||
         t.contains("quiero cocinar") ||
         t.contains("empecemos") ||
         t.contains("ir a los pasos") ||
         t.contains("preparación") ||
         t.contains("preparacion"))) {
      _pasoActualIndex = 0;
      final String msg =
          "Comenzamos con $_recetaActivaNombre. "
          "Paso 1: ${_pasosActivos[0]}";
      await _hablar(msg, guardarEnHistorial: true);
      return true;
    }

    // ── 6. LISTAR INGREDIENTES DE LA RECETA ACTIVA ───────
    // "dime los ingredientes", "qué necesito", "muéstrame los ingredientes"
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

    // ── 7. LISTAR RECETAS POR CATEGORÍA ──────────────────
    // "qué recetas de desayuno hay", "recetas de cena"
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

    // ── Ninguna intención local detectada → delegar a Groq ──
    return false;
  }

  // ═══════════════════════════════════════════════════════
  // TOGGLE MICRÓFONO
  // Inicia o detiene el STT. Al confirmar texto, primero
  // pasa por el IntentRouter; si no lo resuelve, va a Groq.
  // ═══════════════════════════════════════════════════════
  Future<void> _toggleMicrofono() async {
    if (!_catalogoCargado || _procesando || _hablando) return;

    if (_escuchando) {
      await _speech.stop();
      setState(() {
        _escuchando    = false;
        _preguntaFinal = _textoEscuchado;
      });
      if (_preguntaFinal.trim().isNotEmpty) {
        await _procesarTextoUsuario(_preguntaFinal.trim());
      }
    } else {
      setState(() {
        _textoEscuchado = "";
        _respuestaNID   = "";
      });

      final disponible = await _speech.initialize(
        onError: (err) {
          debugPrint("STT Error: ${err.errorMsg}");
          setState(() => _escuchando = false);
        },
      );

      if (disponible) {
        setState(() => _escuchando = true);
        _speech.listen(
          localeId:  "es_ES",
          listenFor: const Duration(seconds: 30),
          pauseFor:  const Duration(seconds: 4),
          onResult:  (result) {
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
    }
  }

  // ═══════════════════════════════════════════════════════
  // PROCESADOR CENTRAL
  // Punto único de entrada para todo texto del usuario.
  // 1. Pasa primero por IntentRouter (lógica local, sin API).
  // 2. Si IntentRouter devuelve false → consulta Groq.
  // ═══════════════════════════════════════════════════════
  Future<void> _procesarTextoUsuario(String texto) async {
    // Intentar resolver localmente
    final bool resueltaLocalmente = await _intentRouter(texto);
    if (resueltaLocalmente) return;

    // No resuelta → delegar a Groq
    await _consultarNID(texto);
  }

  // ═══════════════════════════════════════════════════════
  // CONSULTA AL LLM (GROQ + RAG + HISTORIAL)
  //
  // Flujo:
  //   A. Agrega el turno del usuario al historial.
  //   B. Construye [system + historial completo] y llama a Groq.
  //   C. Limpia la respuesta de caracteres no aptos para TTS.
  //   D. Si la respuesta confirma una receta → activa la receta.
  //   E. Agrega la respuesta al historial.
  //   F. Reproduce vía TTS.
  // ═══════════════════════════════════════════════════════
  Future<void> _consultarNID(String pregunta) async {
    setState(() {
      _procesando   = true;
      _respuestaNID = "";
    });

    // ── A. Registrar turno del usuario ──
    _historial.add({"role": "user", "content": pregunta});

    // ── B. Construir payload ──
    // Si ya hay una receta activa → inyectar SOLO su texto completo (~300 tokens).
    // Si aún no → inyectar el índice slim con todos los nombres/meta (~<500 tokens).
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

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          "model":       "llama-3.1-8b-instant",
          "temperature": 0.1, // Mínima creatividad = máxima fidelidad al catálogo
          "max_tokens":  300,
          "messages":    mensajesApi,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        String respuesta = data['choices'][0]['message']['content'] ?? "";

        // ── C. Limpiar caracteres no aptos para TTS ──
        respuesta = _limpiarParaTts(respuesta);

        // ── D. Si Groq confirmó una receta → activarla localmente ──
        _intentarActivarReceta(pregunta, respuesta);

        // ── E. Guardar respuesta en historial ──
        _historial.add({"role": "assistant", "content": respuesta});

        // Límite de 20 turnos para no inflar el contexto
        if (_historial.length > 20) {
          _historial.removeRange(0, 2);
        }

        setState(() {
          _procesando   = false;
        });

        // ── F. Reproducir ──
        await _hablar(respuesta, guardarEnHistorial: false); // Ya está en historial

      } else {
        debugPrint("Groq error: ${response.statusCode} ${response.body}");
        _historial.removeLast(); // Revertir turno fallido
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

  // ─────────────────────────────────────────────
  // _limpiarParaTts
  // Elimina todo caracter que cause errores de
  // lectura en el motor de voz de Chrome/Flutter:
  // asteriscos, guiones decorativos, corchetes,
  // listas numeradas, etc.
  // ─────────────────────────────────────────────
  String _limpiarParaTts(String texto) {
    return texto
        .replaceAll(RegExp(r'\*+'), '')           // Asteriscos simples y dobles
        .replaceAll(RegExp(r'\[.*?\]'), '')        // [texto entre corchetes]
        .replaceAll(RegExp(r'^\s*[-•–—]\s', multiLine: true), '') // Viñetas
        .replaceAll(RegExp(r'^\s*\d+\.\s', multiLine: true), '')  // "1. " listas
        .replaceAll(RegExp(r'#+\s'), '')           // Encabezados markdown
        .replaceAll('_', '')                       // Cursivas markdown
        .replaceAll('`', '')                       // Code markdown
        .replaceAll(RegExp(r'\n{2,}'), '\n')       // Saltos dobles → simple
        .trim();
  }

  // ─────────────────────────────────────────────
  // _intentarActivarReceta
  // Heurística: si el usuario mencionó un plato
  // y Groq lo confirmó (no rechazó), lo buscamos
  // en _recetasData y lo activamos para el control
  // paso a paso local.
  // ─────────────────────────────────────────────
  void _intentarActivarReceta(String pregunta, String respuestaNid) {
    // Si Groq rechazó → no activar
    if (respuestaNid.contains("no se encuentra en nuestro sistema")) return;

    final String p = pregunta.toLowerCase();
    for (final receta in _recetasData) {
      final String nombre = receta['nombre'].toString().toLowerCase();
      if (p.contains(nombre) || nombre.split(' ').any((w) => w.length > 3 && p.contains(w))) {

        // ── Construir el texto completo de esta receta para inyectar en Groq ──
        // A partir de este punto, cada llamada a Groq usará SOLO este texto
        // en lugar del catálogo completo. Pasa de ~5 000 tokens a ~300 tokens.
        final StringBuffer rb = StringBuffer();
        rb.writeln("RECETA: ${receta['nombre']}");
        if ((receta['categoria'] as String).isNotEmpty) rb.writeln("  Categoría: ${receta['categoria']}");
        if ((receta['calorias']  as String).isNotEmpty) rb.writeln("  Calorías: ${receta['calorias']}");
        if ((receta['tiempo']    as String).isNotEmpty) rb.writeln("  Tiempo: ${receta['tiempo']}");
        final List<String> ings = List<String>.from(receta['ingredientes']);
        if (ings.isNotEmpty) rb.writeln("  Ingredientes: ${ings.join(', ')}");
        final List<String> pasos = List<String>.from(receta['pasos']);
        for (int i = 0; i < pasos.length; i++) {
          rb.writeln("  Paso ${i + 1}: ${pasos[i]}");
        }

        setState(() {
          _recetaActivaContexto  = rb.toString();   // ← contexto acotado para Groq
          _recetaActivaNombre    = receta['nombre'].toString();
          _pasosActivos          = List<String>.from(receta['pasos']);
          _ingredientesActivos   = List<String>.from(receta['ingredientes']);
          _pasoActualIndex       = -1;
        });
        debugPrint("Receta activada: $_recetaActivaNombre");
        debugPrint("Tokens aprox. contexto receta: ${_recetaActivaContexto.length ~/ 4}");
        return;
      }
    }
  }

  // ─────────────────────────────────────────────
  // _hablar
  // Punto único de reproducción TTS.
  // Actualiza _respuestaNID (caché para "repite eso")
  // y opcionalmente agrega al historial de Groq.
  // ─────────────────────────────────────────────
  Future<void> _hablar(String texto, {required bool guardarEnHistorial}) async {
    final String limpio = _limpiarParaTts(texto);
    setState(() {
      _respuestaNID = limpio;
      _hablando     = true;
    });
    if (guardarEnHistorial) {
      _historial.add({"role": "assistant", "content": limpio});
    }
    await _tts.speak(limpio);
  }

  // ═══════════════════════════════════════════════════════
  //  BUILD PRINCIPAL
  // ═══════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _negro,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: _cianNeon),
          onPressed: () {
            _speech.stop();
            _tts.stop();
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "N I D",
          style: TextStyle(
            color: _cianNeon,
            fontWeight: FontWeight.w800,
            letterSpacing: 4,
          ),
        ),
        actions: [
          // Botón de reinicio de conversación
          if (_historial.isNotEmpty && !_procesando && !_escuchando)
            IconButton(
              tooltip: "Nueva conversación",
              icon: const Icon(Icons.refresh, color: _cianNeon, size: 20),
              onPressed: () {
                setState(() {
                  _historial.clear();
                  _preguntaFinal        = "";
                  _respuestaNID         = "";
                  _textoEscuchado       = "";
                  _recetaActivaNombre   = null;
                  _recetaActivaContexto = "";  // ← liberar contexto acotado
                  _pasosActivos         = [];
                  _ingredientesActivos  = [];
                  _pasoActualIndex      = -1;
                });
              },
            ),
          // Indicador RAG
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                Icon(Icons.circle,
                    size: 8,
                    color: _catalogoCargado ? _verdeApp : Colors.orange),
                const SizedBox(width: 4),
                Text(
                  _catalogoCargado ? "RAG activo" : "Cargando...",
                  style: TextStyle(
                    fontSize: 10,
                    color: _catalogoCargado ? _verdeApp : Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(flex: 5, child: _buildAvatar()),
            Expanded(flex: 4, child: _buildPanelTexto()),
            _buildControles(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildAvatar
  // Círculo animado con patrón andino geométrico.
  // Pulsa al ritmo de _pulsoAnimation cuando habla.
  // El anillo cambia de color según el estado.
  // ─────────────────────────────────────────────
  Widget _buildAvatar() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulsoAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _hablando ? _pulsoAnimation.value : 1.0,
                child: child,
              );
            },
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_moradoNeon.withOpacity(0.3), _negro],
                ),
                border: Border.all(
                  color: _escuchando
                      ? _cianNeon
                      : _hablando
                          ? _doradoInca
                          : _moradoNeon,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_escuchando ? _cianNeon : _moradoNeon)
                        .withOpacity(0.5),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(160, 160),
                      painter: _AndeanPatternPainter(),
                    ),
                    // Reemplazar con Image.asset cuando tengas el asset de NID
                    Icon(
                      Icons.auto_awesome,
                      size: 64,
                      color: _doradoInca.withOpacity(0.9),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "N I D",
            style: TextStyle(
              color: _doradoInca,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 6,
            ),
          ),
          const SizedBox(height: 4),
          // Indicador de receta activa y paso actual
          if (_recetaActivaNombre != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                _pasoActualIndex >= 0
                    ? "${_recetaActivaNombre!.toUpperCase()}  •  PASO ${_pasoActualIndex + 1}/${_pasosActivos.length}"
                    : _recetaActivaNombre!.toUpperCase(),
                style: TextStyle(
                  color: _verdeApp.withOpacity(0.85),
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(
              key: ValueKey(_estadoActual),
              _estadoActual,
              style: TextStyle(
                color: _cianNeon.withOpacity(0.7),
                fontSize: 11,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Texto de estado dinámico debajo del nombre
  String get _estadoActual {
    if (_procesando && !_catalogoCargado) return "CARGANDO CATÁLOGO...";
    if (_procesando)  return "NID ESTÁ PENSANDO...";
    if (_escuchando)  return "ESCUCHANDO...";
    if (_hablando)    return "NID ESTÁ HABLANDO...";
    return "LISTO PARA ESCUCHARTE";
  }

  // ─────────────────────────────────────────────
  // _buildPanelTexto
  // Muestra: transcripción en tiempo real,
  // indicador de procesamiento y respuesta de NID.
  // Incluye chips de acciones rápidas contextuales.
  // ─────────────────────────────────────────────
  Widget _buildPanelTexto() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0F1A),
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

            // ── Indicador de turnos en memoria ──
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

            // ── Texto del usuario ──
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

            // ── Respuesta de NID o estados intermedios ──
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

              // ── Chips de acciones rápidas (si hay receta activa) ──
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
  // _buildAccionesRapidas
  // Chips contextuales que aparecen cuando hay
  // una receta activa. Permiten acciones comunes
  // sin hablar, ideal para manos ocupadas en cocina.
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
  // _buildControles
  // Botón principal del micrófono.
  // Botón rojo para interrumpir TTS si NID habla.
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

          // Botón principal del micrófono
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
// _AndeanPatternPainter
// Patrón geométrico andino (rombos tipo wiphala) para el fondo del avatar.
// Reemplazar con Image.asset('assets/images/nid_avatar.png') cuando
// tengas el asset listo.
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