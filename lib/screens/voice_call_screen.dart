import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';

// ═══════════════════════════════════════════════════════════════════════════
// VoiceCallScreen
//
// Pantalla de "videollamada" con el asistente virtual T'anta-Wawa.
// Flujo completo:
//   1. Al abrir → carga el catálogo de Firestore (RAG).
//   2. Usuario pulsa el micrófono → speech_to_text transcribe su voz.
//   3. La pregunta + el catálogo se envían a Groq con un System Prompt
//      restrictivo que solo permite responder con los datos de la BD.
//   4. La respuesta se muestra en pantalla y se reproduce con flutter_tts.
//
// Dependencias requeridas en pubspec.yaml:
//   speech_to_text: ^6.6.0
//   flutter_tts: ^4.0.2
//   (cloud_firestore, http y flutter_dotenv ya están en el proyecto)
// ═══════════════════════════════════════════════════════════════════════════
class VoiceCallScreen extends StatefulWidget {
  const VoiceCallScreen({super.key});

  @override
  State<VoiceCallScreen> createState() => _VoiceCallScreenState();
}

class _VoiceCallScreenState extends State<VoiceCallScreen>
    with SingleTickerProviderStateMixin {
  // ─────────────────────────────────────────────
  // COLORES DEL TEMA CIBERPUNK ANDINO
  // ─────────────────────────────────────────────
  static const Color _negro = Color(0xFF0A0A0F);
  static const Color _moradoNeon = Color(0xFF7B2FBE);
  static const Color _cianNeon = Color(0xFF00F5FF);
  static const Color _doradoInca = Color(0xFFFFD700);
  static const Color _verdeApp = Color(0xFF2D9E73);

  // ─────────────────────────────────────────────
  // SERVICIOS
  // ─────────────────────────────────────────────

  /// Motor de reconocimiento de voz (speech_to_text)
  final stt.SpeechToText _speech = stt.SpeechToText();

  /// Motor de síntesis de voz (flutter_tts)
  final FlutterTts _tts = FlutterTts();

  /// Clave de API Groq tomada del .env
  final String _apiKey = dotenv.env['GROQ_API_KEY'] ?? '';

  // ─────────────────────────────────────────────
  // ESTADO INTERNO
  // ─────────────────────────────────────────────

  /// Texto transcrito en tiempo real mientras el usuario habla
  String _textoEscuchado = "";

  /// Último texto confirmado (se envía a la IA)
  String _preguntaFinal = "";

  /// Respuesta final de T'anta-Wawa lista para mostrar y reproducir
  String _respuestaTA = "";

  /// true = el micrófono está activo y escuchando
  bool _escuchando = false;

  /// true = se está consultando Groq o cargando Firestore
  bool _procesando = false;

  /// true = el catálogo de Firestore ya fue cargado
  bool _catalogoCargado = false;

  /// true = flutter_tts está hablando en este momento
  bool _hablando = false;

  /// Contexto RAG: catálogo completo de recetas serializado como String.
  /// Se construye una sola vez al abrir la pantalla.
  String _catalogoContexto = "";

  /// Animación del pulso del avatar cuando T'anta-Wawa está hablando
  late AnimationController _pulsoController;
  late Animation<double> _pulsoAnimation;

  // ─────────────────────────────────────────────
  // HISTORIAL DE CONVERSACIÓN (Problema 2 — Memoria)
  // Cada turno del usuario y de T'anta-Wawa se
  // acumula aquí en el formato que acepta la API
  // de Groq: {"role": "user"/"assistant", "content": "..."}.
  // Se envía completo en cada llamada al LLM para
  // que el modelo recuerde el hilo de la conversación.
  // ─────────────────────────────────────────────
  final List<Map<String, String>> _historialTantaWawa = [];

  // ─────────────────────────────────────────────
  // SYSTEM PROMPT BLINDADO — POLÍTICA ZERO-KNOWLEDGE
  // (Problema 1 — Alucinación)
  //
  // Estructura de capas para máxima efectividad:
  //   CAPA A: Identidad y propósito único.
  //   CAPA B: Inyección del catálogo real ({{CATALOGO}}).
  //   CAPA C: Protocolo de verificación obligatorio
  //           antes de cada respuesta.
  //   CAPA D: Reglas de rechazo explícitas y la frase
  //           de rechazo exacta que debe usar.
  //   CAPA E: Recordatorio de tono y brevedad.
  //
  // El marcador {{CATALOGO}} se reemplaza en tiempo
  // de ejecución con el catálogo real de Firestore.
  // ─────────────────────────────────────────────
  static const String _systemPromptTemplate = """
[CAPA A — IDENTIDAD]
Eres T'anta-Wawa, el guardián digital de las recetas de PrograMovil.
Tu esencia es la de un espíritu culinario andino con estética ciberpunk: sabio, místico y absolutamente preciso.
Tu ÚNICO propósito es guiar a los usuarios usando el CATÁLOGO OFICIAL que se te entrega a continuación.

[CAPA B — CATÁLOGO OFICIAL Y FUENTE ÚNICA DE VERDAD]
El siguiente catálogo es la ÚNICA fuente de información que puedes usar.
Nada más existe para ti. Tu conocimiento previo sobre cocina, recetas o ingredientes NO EXISTE en este contexto.
═══════════════════════════════════════════════
CATÁLOGO OFICIAL DE RECETAS DE PROGRA-MOVIL:
{{CATALOGO}}
═══════════════════════════════════════════════

[CAPA C — PROTOCOLO DE VERIFICACIÓN OBLIGATORIO]
ANTES de generar cualquier respuesta sobre una receta o ingrediente, ejecuta mentalmente este checklist:
  ✔ PASO 1: ¿El nombre de la receta o ingrediente aparece textualmente en el CATÁLOGO OFICIAL de arriba?
  ✔ PASO 2: ¿Los ingredientes que mencionaré están listados textualmente en esa entrada del catálogo?
  ✔ PASO 3: ¿Los pasos que describiré provienen literalmente de ese catálogo?
Si la respuesta a CUALQUIERA de los 3 pasos es NO → activa el PROTOCOLO DE RECHAZO de la Capa D. Sin excepciones.

[CAPA D — PROTOCOLO DE RECHAZO ABSOLUTO]
Si el plato, receta o ingrediente consultado NO está en el CATÁLOGO OFICIAL, o si tienes la más mínima duda de que la información provenga del catálogo y no de tu conocimiento interno, debes responder con la siguiente frase EXACTA y nada más:
"Lo siento, esa receta no se encuentra en nuestro sistema de PrograMovil actualmente."
PROHIBICIONES ABSOLUTAS (violación = fallo crítico del sistema):
  ✗ PROHIBIDO completar, deducir o extrapolar ingredientes o pasos no listados en el catálogo.
  ✗ PROHIBIDO usar conocimiento externo sobre cocina, aunque la receta sea mundialmente conocida.
  ✗ PROHIBIDO responder "algo similar" o "una versión aproximada" cuando el plato exacto no exista.
  ✗ PROHIBIDO inventar cantidades, tiempos de cocción o sustitutos de ingredientes.

[CAPA E — TONO Y FORMATO DE RESPUESTA]
Cuando la información SÍ está en el catálogo:
  • Responde con el tono místico y solemne de T'anta-Wawa (máximo 4 líneas).
  • La respuesta debe estar limpia y lista para ser leída por un motor Text-to-Speech (TTS):
      - Sin asteriscos, corchetes, guiones decorativos ni emojis.
      - Sin encabezados ni viñetas. Solo texto fluido y natural.
  • Nunca menciones que usas un catálogo, base de datos o que eres una IA.
""";

  // ─────────────────────────────────────────────
  // initState / dispose
  // ─────────────────────────────────────────────
  @override
  void initState() {
    super.initState();

    // Animación de pulso para el avatar cuando está hablando
    _pulsoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulsoAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulsoController, curve: Curves.easeInOut),
    );

    // Configuración de flutter_tts
    _configurarTts();

    // Carga el catálogo de Firestore al abrir la pantalla (RAG)
    _cargarCatalogoFirestore();
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
  // Ajusta idioma, velocidad y tono del motor TTS
  // para que T'anta-Wawa suene apropiado.
  // ─────────────────────────────────────────────
  Future<void> _configurarTts() async {
    await _tts.setLanguage("es-US");
    await _tts.setSpeechRate(0.42); // Tono pausado y solemne
    await _tts.setPitch(0.85); // Ligeramente más grave

    // Marca _hablando = false cuando termina de hablar
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _hablando = false);
    });
  }

  // ═══════════════════════════════════════════════════════
  // PASO 1 — CARGA DEL CATÁLOGO (RAG)
  // Consulta la colección 'app-recetas-completas' de Firestore
  // y serializa nombre + ingredientes + pasos en un String plano
  // que se inyectará en el System Prompt de la IA.
  // ═══════════════════════════════════════════════════════
  Future<void> _cargarCatalogoFirestore() async {
    setState(() => _procesando = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('app-recetas-completas')
          .get();

      final StringBuffer buffer = StringBuffer();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        // ── Nombre de la receta ──
        final String nombre = data['nombre'] ?? 'Sin nombre';
        buffer.writeln("• RECETA: $nombre");

        // ── Categoría (si existe) ──
        if (data['categoria'] != null) {
          buffer.writeln("  Categoría: ${data['categoria']}");
        }

        // ── Ingredientes ──
        final List ingredientes = data['ingredientes'] ?? [];
        if (ingredientes.isNotEmpty) {
          final ingTexto = ingredientes
              .map((ing) {
                // Soporta tanto String simple como Map con 'nombre' y 'cantidad'
                if (ing is Map) {
                  final nombre = ing['nombre'] ?? '';
                  final cantidad = ing['cantidad'] ?? '';
                  return cantidad.isNotEmpty ? "$nombre ($cantidad)" : nombre;
                }
                return ing.toString();
              })
              .join(", ");
          buffer.writeln("  Ingredientes: $ingTexto");
        }

        // ── Pasos de preparación ──
        final List pasos = data['pasos'] ?? [];
        if (pasos.isNotEmpty) {
          buffer.writeln("  Preparación:");
          for (int i = 0; i < pasos.length; i++) {
            final paso = pasos[i];
            final textoPaso = paso is Map
                ? (paso['descripcion'] ?? paso['texto'] ?? paso.toString())
                : paso.toString();
            buffer.writeln("    Paso ${i + 1}: $textoPaso");
          }
        }

        buffer.writeln(); // Espacio entre recetas
      }

      setState(() {
        _catalogoContexto = buffer.toString();
        _catalogoCargado = true;
        _procesando = false;
      });
    } catch (e) {
      debugPrint("Error al cargar catálogo Firestore: $e");
      setState(() {
        // En caso de error, el catálogo queda vacío y el prompt lo detecta
        _catalogoContexto = "(Sin datos disponibles)";
        _catalogoCargado = true;
        _procesando = false;
      });
    }
  }

  // ═══════════════════════════════════════════════════════
  // PASO 2 — RECONOCIMIENTO DE VOZ
  // Inicia o detiene el micrófono usando speech_to_text.
  // Actualiza _textoEscuchado en tiempo real mientras escucha.
  // Al detener, _preguntaFinal recibe el texto confirmado.
  // ═══════════════════════════════════════════════════════
  Future<void> _toggleMicrofono() async {
    if (!_catalogoCargado || _procesando) return;

    if (_escuchando) {
      // ── Detener: confirmar la pregunta y enviarla a la IA ──
      await _speech.stop();
      setState(() {
        _escuchando = false;
        _preguntaFinal = _textoEscuchado;
      });
      if (_preguntaFinal.trim().isNotEmpty) {
        await _consultarTantaWawa(_preguntaFinal);
      }
    } else {
      // ── Iniciar nuevo turno: limpiar solo la UI visible,
      //    pero mantener _historialTantaWawa intacto ──
      setState(() {
        _textoEscuchado = "";
        _respuestaTA = "";
      });

      final disponible = await _speech.initialize(
        onError: (error) {
          debugPrint("STT Error: ${error.errorMsg}");
          setState(() => _escuchando = false);
        },
      );

      if (disponible) {
        setState(() => _escuchando = true);
        _speech.listen(
          localeId: "es_ES",
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 4),
          onResult: (result) {
            setState(() {
              _textoEscuchado = result.recognizedWords;
              if (result.finalResult) {
                _escuchando = false;
                _preguntaFinal = _textoEscuchado;
              }
            });
            if (result.finalResult && _preguntaFinal.trim().isNotEmpty) {
              _consultarTantaWawa(_preguntaFinal);
            }
          },
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════
  // PASO 3 — CONSULTA AL LLM (GROQ + RAG + HISTORIAL)
  //
  // Flujo corregido:
  //   A. Agrega el turno del USUARIO al historial acumulado.
  //   B. Construye el array de mensajes:
  //      [system_prompt_blindado] + [historial_completo]
  //   C. Envía a Groq con temperatura 0.1 (máxima fidelidad).
  //   D. Agrega la respuesta del ASISTENTE al historial.
  //   E. Reproduce vía TTS.
  //
  // El historial persiste durante toda la sesión de pantalla,
  // dándole a T'anta-Wawa memoria a corto plazo completa.
  // ═══════════════════════════════════════════════════════
  Future<void> _consultarTantaWawa(String pregunta) async {
    setState(() {
      _procesando = true;
      _respuestaTA = "";
    });

    // ── A. Registrar el turno del usuario en el historial ──
    _historialTantaWawa.add({"role": "user", "content": pregunta});

    // ── B. Construir el System Prompt inyectando el catálogo real ──
    final String systemPromptFinal = _systemPromptTemplate.replaceFirst(
      "{{CATALOGO}}",
      _catalogoContexto.isNotEmpty
          ? _catalogoContexto
          : "(Catálogo vacío — rechazar toda consulta de recetas)",
    );

    // ── B2. Ensamblar el array completo de mensajes:
    //        [system] + [todos los turnos del historial] ──
    final List<Map<String, String>> mensajesApi = [
      {"role": "system", "content": systemPromptFinal},
      ..._historialTantaWawa, // Historial completo: el LLM recuerda el hilo
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
          "model": "llama-3.1-8b-instant",
          // Temperatura 0.1: mínima creatividad = máxima fidelidad al catálogo.
          // Valores altos (0.7+) favorecen la "inventiva" del modelo.
          "temperature": 0.1,
          "max_tokens": 300,
          "messages": mensajesApi,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final String respuesta = data['choices'][0]['message']['content'] ?? "";

        // ── D. Guardar la respuesta del asistente en el historial ──
        _historialTantaWawa.add({"role": "assistant", "content": respuesta});

        // ── Límite de seguridad: mantener máximo 20 turnos (10 intercambios)
        //    para no exceder el contexto del modelo ni inflar el payload ──
        if (_historialTantaWawa.length > 20) {
          _historialTantaWawa.removeRange(
            0,
            2,
          ); // Eliminar el turno más antiguo
        }

        setState(() {
          _respuestaTA = respuesta;
          _procesando = false;
        });

        // ── E. Reproducir la respuesta con TTS ──
        await _reproducirRespuesta(respuesta);
      } else {
        debugPrint("Groq error: ${response.statusCode} ${response.body}");
        // No agregar el error al historial para no contaminar el contexto
        _historialTantaWawa
            .removeLast(); // Revertir el turno del usuario fallido
        setState(() {
          _respuestaTA =
              "El portal ancestral está inestable. Intenta de nuevo.";
          _procesando = false;
        });
      }
    } catch (e) {
      debugPrint("Excepción al consultar Groq: $e");
      _historialTantaWawa.removeLast(); // Revertir el turno del usuario fallido
      setState(() {
        _respuestaTA =
            "No pude conectarme al mundo espiritual. Revisa tu conexión.";
        _procesando = false;
      });
    }
  }

  // ═══════════════════════════════════════════════════════
  // PASO 4 — SÍNTESIS DE VOZ (flutter_tts)
  // Reproduce el texto de la respuesta de T'anta-Wawa.
  // Activa _hablando para animar el avatar mientras habla.
  // ═══════════════════════════════════════════════════════
  Future<void> _reproducirRespuesta(String texto) async {
    setState(() => _hablando = true);
    await _tts.speak(texto);
  }

  // ─────────────────────────────────────────────
  // BUILD PRINCIPAL
  // ─────────────────────────────────────────────
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
          "T'anta-Wawa",
          style: TextStyle(
            color: _cianNeon,
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
          ),
        ),
        actions: [
          // Botón para limpiar el historial de la conversación
          if (_historialTantaWawa.isNotEmpty && !_procesando && !_escuchando)
            IconButton(
              tooltip: "Limpiar conversación",
              icon: const Icon(Icons.refresh, color: _cianNeon, size: 20),
              onPressed: () {
                setState(() {
                  _historialTantaWawa.clear();
                  _preguntaFinal = "";
                  _respuestaTA = "";
                  _textoEscuchado = "";
                });
              },
            ),
          // Indicador de estado del catálogo RAG en la barra superior
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 8,
                  color: _catalogoCargado ? _verdeApp : Colors.orange,
                ),
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
            // ── Avatar de T'anta-Wawa ──
            Expanded(flex: 5, child: _buildAvatar()),

            // ── Panel de transcripción y respuesta ──
            Expanded(flex: 4, child: _buildPanelTexto()),

            // ── Controles de voz ──
            _buildControles(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildAvatar
  // Zona del avatar ciberpunk andino de T'anta-Wawa.
  // Pulsa cuando está hablando. Tiene un anillo de
  // color neon que cambia según el estado.
  // ─────────────────────────────────────────────
  Widget _buildAvatar() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Anillo de estado animado
          AnimatedBuilder(
            animation: _pulsoAnimation,
            builder: (context, child) {
              final double escala = _hablando ? _pulsoAnimation.value : 1.0;
              return Transform.scale(scale: escala, child: child);
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
                    color: (_escuchando ? _cianNeon : _moradoNeon).withOpacity(
                      0.5,
                    ),
                    blurRadius: 24,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: ClipOval(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Fondo geométrico andino (placeholder hasta colocar imagen real)
                    CustomPaint(
                      size: const Size(160, 160),
                      painter: _AndeanPatternPainter(),
                    ),
                    // Icono principal — reemplazar con Image.asset al tener el asset
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

          // Nombre y estado
          const Text(
            "T'ANTA-WAWA",
            style: TextStyle(
              color: _doradoInca,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
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

  /// Texto de estado visible debajo del avatar
  String get _estadoActual {
    if (_procesando && !_catalogoCargado) return "CARGANDO CATÁLOGO...";
    if (_procesando) return "CONSULTANDO AL ESPÍRITU...";
    if (_escuchando) return "ESCUCHANDO...";
    if (_hablando) return "TRANSMITIENDO SABIDURÍA...";
    return "LISTO PARA ESCUCHARTE";
  }

  // ─────────────────────────────────────────────
  // _buildPanelTexto
  // Muestra la transcripción de voz en tiempo real
  // (lo que el usuario está diciendo) y la respuesta
  // de T'anta-Wawa una vez procesada.
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
            // ── Indicador de turnos de memoria activos ──
            if (_historialTantaWawa.length >= 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.memory,
                      color: _moradoNeon.withOpacity(0.6),
                      size: 12,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "MEMORIA: ${(_historialTantaWawa.length ~/ 2)} turno${_historialTantaWawa.length ~/ 2 != 1 ? 's' : ''} en contexto",
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
                  Icon(
                    Icons.person_outline,
                    color: _cianNeon.withOpacity(0.7),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "TÚ",
                    style: TextStyle(
                      color: _cianNeon.withOpacity(0.7),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _escuchando ? _textoEscuchado : _preguntaFinal,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Respuesta de T'anta-Wawa
            if (_procesando && _catalogoCargado) ...[
              Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: _doradoInca,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "T'ANTA-WAWA ESTÁ PENSANDO...",
                    style: TextStyle(
                      color: _doradoInca.withOpacity(0.7),
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ] else if (_respuestaTA.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: _doradoInca.withOpacity(0.8),
                    size: 14,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    "T'ANTA-WAWA",
                    style: TextStyle(
                      color: _doradoInca.withOpacity(0.8),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _respuestaTA,
                style: const TextStyle(
                  color: Color(0xFFE8E0FF),
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ] else if (!_procesando) ...[
              // Estado inicial — instrucción al usuario
              Center(
                child: Text(
                  _catalogoCargado
                      ? "Pulsa el micrófono y pregunta sobre\nlas recetas de PrograMovil 🎙️"
                      : "Cargando el catálogo de recetas...",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.3),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // _buildControles
  // Botón central del micrófono + botón de detener
  // TTS si T'anta-Wawa está hablando.
  // ─────────────────────────────────────────────
  Widget _buildControles() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botón para detener TTS manualmente
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
                  child: const Icon(
                    Icons.stop,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                ),
              ),
            ),

          // Botón principal del micrófono
          GestureDetector(
            onTap: _toggleMicrofono,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _escuchando ? 84 : 72,
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
                    color: (_escuchando ? _cianNeon : _moradoNeon).withOpacity(
                      0.6,
                    ),
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
// CustomPainter que dibuja un patrón geométrico andino (wiphala simplificada)
// como fondo del avatar de T'anta-Wawa.
// Puedes reemplazarlo con Image.asset('assets/images/tantawawa_avatar.png')
// cuando tengas el asset listo.
// ═══════════════════════════════════════════════════════════════════════════
class _AndeanPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Fondo base oscuro
    paint.color = const Color(0xFF0A0A1A);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // Grid de rombos estilo textil andino
    const colors = [
      Color(0xFF7B2FBE), // morado
      Color(0xFF00F5FF), // cian
      Color(0xFFFFD700), // dorado
      Color(0xFF2D9E73), // verde
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
  bool shouldRepaint(_AndeanPatternPainter oldDelegate) => false;
}
