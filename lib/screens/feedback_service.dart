// feedback_service.dart
// Servicio principal que conecta nuestra app con Gemini y Firestore.
// Lo hacemos "artesanal" con el paquete http para no depender de SDKs
// que a veces rompen entre versiones.

import 'dart:convert'; // Para jsonEncode y jsonDecode
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class FeedbackService {

  // ─── CONFIGURACIÓN ────────────────────────────────────────────────────────

  // TU API KEY de Google AI Studio (aistudio.google.com)
  // ⚠️ En producción real esto va en variables de entorno o Firebase Remote Config.
  // Para el proyecto universitario así está bien, pero anótalo en la defensa.
  static const String _apiKey = 'AIzaSyDXMO7kdFZ-1_WxgBwK8QpgaArHJnA3j_A';

  // Endpoint de Gemini 2.0 Flash.
  // Usamos "gemini-2.0-flash" que es rápido y barato, perfecto para clasificar texto.
  // La estructura de la URL es: .../models/{MODELO}:generateContent?key={API_KEY}
  static const String _geminiUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent';

  // Referencia a nuestra colección en Firestore (ya la tienes creada).
  final CollectionReference _sugerenciasRef =
      FirebaseFirestore.instance.collection('sugerencias');


  // ─── FUNCIÓN PRINCIPAL ────────────────────────────────────────────────────

  /// Recibe el texto que escribió el usuario, lo manda a Gemini para que lo
  /// analice y clasifique, y guarda el resultado en Firestore.
  ///
  /// Retorna true si todo salió bien, false si algo falló.
  Future<bool> procesarYGuardarSugerencia(String textoOriginal) async {

    try {
      // PASO 1: Llamamos a Gemini y obtenemos el JSON estructurado.
      final Map<String, dynamic> analisis = await _analizarConGemini(textoOriginal);

      // PASO 2: Con el resultado, guardamos todo en Firestore.
      await _guardarEnFirestore(textoOriginal, analisis);

      return true;

    } catch (e) {
      // Si algo falla (sin internet, API key inválida, etc.), lo mostramos
      // en consola para debug y retornamos false para que la UI lo maneje.
      print('❌ Error en FeedbackService: $e');
      return false;
    }
  }


  // ─── PASO 1: CONEXIÓN CON GEMINI ─────────────────────────────────────────

  /// Hace la petición HTTP a la API de Gemini y retorna un Map con
  /// los campos: categoria, prioridad, resumen_ia.
  Future<Map<String, dynamic>> _analizarConGemini(String textoOriginal) async {

    // Construimos el "body" de la petición.
    // Google espera un JSON con esta estructura específica:
    // { "system_instruction": {...}, "contents": [...], "generationConfig": {...} }
    final Map<String, dynamic> requestBody = {

      // ── SYSTEM PROMPT ──────────────────────────────────────────────────────
      // Le decimos a Gemini quién es y cuál es su trabajo.
      // "system_instruction" se aplica a toda la conversación, no es parte del
      // mensaje del usuario. Es como configurar la "personalidad" del modelo.
      "system_instruction": {
        "parts": [
          {
            "text": """
Eres el clasificador inteligente de PrograMovil, una app boliviana de recetas 
de cocina y entrenamiento físico. Tu ÚNICO trabajo es analizar el feedback 
del usuario y retornar un JSON. No escribas texto fuera del JSON.

CATEGORÍAS (elige exactamente UNA):
- BUG: error técnico, crash o comportamiento inesperado
- NUEVA_RECETA: solicitud de agregar una receta específica  
- MEJORA_UI: sugerencia de diseño o navegación
- FEEDBACK_POSITIVO: elogio o comentario positivo
- CONSULTA: pregunta sobre funcionalidad o contenido

PRIORIDADES:
- ALTA: BUG que impide usar la app
- MEDIA: mejoras funcionales o bugs menores
- BAJA: sugerencias, elogios o consultas

FORMATO OBLIGATORIO DE RESPUESTA (solo esto, nada más):
{
  "categoria": "string",
  "prioridad": "string",
  "resumen_ia": "string de máximo 80 caracteres en español"
}
"""
          }
        ]
      },

      // ── MENSAJE DEL USUARIO ────────────────────────────────────────────────
      // "contents" es el historial de la conversación.
      // Como es un solo turno, ponemos solo el mensaje del usuario con role "user".
      "contents": [
        {
          "role": "user",
          "parts": [
            {"text": textoOriginal}
          ]
        }
      ],

      // ── CONFIGURACIÓN DE GENERACIÓN ────────────────────────────────────────
      // Aquí está el truco más importante del código:
      // "responseMimeType": "application/json" le dice a Gemini que FORZOSAMENTE
      // debe responder en JSON válido. Sin esto, a veces añade texto extra como
      // "Aquí está tu respuesta:" antes del JSON, y nuestro jsonDecode falla.
      "generationConfig": {
        "responseMimeType": "application/json",
        "temperature": 0.1, // Temperatura baja = respuestas más determinísticas y consistentes.
        "maxOutputTokens": 200, // El JSON que esperamos es pequeño, no necesitamos más.
      }
    };

    // Hacemos el POST a la API.
    // Usamos Uri.parse() porque http.post necesita un objeto Uri, no un String.
    final http.Response response = await http.post(
      Uri.parse('$_geminiUrl?key=$_apiKey'),
      headers: {
        // Le decimos que enviamos JSON y que esperamos JSON de vuelta.
        'Content-Type': 'application/json',
      },
      // jsonEncode convierte nuestro Map de Dart a un String JSON para enviarlo.
      // Sin esto mandaríamos el objeto Dart como texto y la API no lo entendería.
      body: jsonEncode(requestBody),
    );

    // Verificamos que la petición fue exitosa (código 200).
    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API respondió con error ${response.statusCode}: ${response.body}'
      );
    }

    // La respuesta de Google tiene muchas capas de anidamiento.
    // La estructura es: candidates[0] > content > parts[0] > text
    // Por eso necesitamos "desempacar" con varios jsonDecode y accesos al Map.

    // Primer jsonDecode: convierte el body (String) en un Map de Dart.
    final Map<String, dynamic> responseJson = jsonDecode(response.body);

    // Navegamos por la estructura de respuesta de Gemini para llegar al texto.
    final String textoRespuesta =
        responseJson['candidates'][0]['content']['parts'][0]['text'];

    // Segundo jsonDecode: el "texto" que devuelve Gemini ES en sí mismo un JSON
    // (gracias al responseMimeType que configuramos). Lo convertimos a Map.
    final Map<String, dynamic> analisisEstructurado = jsonDecode(textoRespuesta);

    return analisisEstructurado;
  }


  // ─── PASO 2: GUARDADO EN FIREBASE ─────────────────────────────────────────

  /// Toma el texto original y el análisis de Gemini, y los guarda
  /// como un nuevo documento en la colección /sugerencias de Firestore.
  Future<void> _guardarEnFirestore(
    String textoOriginal,
    Map<String, dynamic> analisis,
  ) async {

    // Creamos el documento que vamos a guardar.
    // Combinamos el texto del usuario con los campos que Gemini nos devolvió.
    await _sugerenciasRef.add({
      // El texto original del usuario, sin modificar.
      'texto_original': textoOriginal,

      // Los campos que viene del análisis de Gemini.
      // Usamos ?? 'DESCONOCIDO' como fallback por si acaso Gemini no devuelve
      // algún campo (raro con el JSON mode, pero es buena práctica defensiva).
      'categoria':  analisis['categoria']  ?? 'OTRO',
      'prioridad':  analisis['prioridad']  ?? 'BAJA',
      'resumen_ia': analisis['resumen_ia'] ?? 'Sin resumen disponible.',

      // Metadatos útiles para el administrador.
      'estado':     'PENDIENTE',
      'timestamp':  FieldValue.serverTimestamp(), // Firestore pone la hora del servidor.
    });
  }
}