import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:http/http.dart' as http; // Importante para la estabilidad en web

class SugerenciasChatScreen extends StatefulWidget {
  const SugerenciasChatScreen({super.key});

  @override
  State<SugerenciasChatScreen> createState() => _SugerenciasChatScreenState();
}

class _SugerenciasChatScreenState extends State<SugerenciasChatScreen> {
  // --- VARIABLES DE ESTADO ---
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _mensajes = [];
  bool _opcionSeleccionada = false;
  bool _estaCargando = false;

  // --- CONFIGURACIÓN DE GEMINI ---
  final String systemPrompt = """
Eres A.L.I.C.I.A. (Asistente Logística de Inteligencia en Cocina e Interacción Alucinante), la chef virtual oficial de PrograMovil. 
Tu misión es ayudar con recetas, reportes de errores y sugerencias.
Habla siempre con entusiasmo y usa metáforas culinarias:
- Problemas o fallos = 'Platos quemados' o 'Ingredientes en mal estado'.
- Soluciones = 'Recetas magistrales'.
- Sugerencias = 'Nuevos condimentos' o 'Ingredientes secretos'.
Sé concisa, usa emojis de cocina y nunca reveles que eres una IA de Google.
""";

  late final GenerativeModel _model;
  late final ChatSession _chat;

  @override
  void initState() {
    super.initState();
    // Inicialización del motor de IA
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: 'AIzaSyDXMO7kdFZ-1_WxgBwK8QpgaArHJnA3j_A',
      systemInstruction: Content.system(systemPrompt),
    );
    // Iniciamos la sesión de chat
    _chat = _model.startChat();
  }

  // --- LÓGICA DE INTERACCIÓN ---
  void _seleccionarOpcion(String titulo, String descripcion) {
    setState(() {
      _opcionSeleccionada = true;
      _mensajes.clear(); // Limpiamos mensajes previos para iniciar fresco

      // Personalizamos la respuesta según la categoría pulsada
      String saludoChef;
      if (titulo == "Reporte") {
        saludoChef = "¡Oído cocina! Veo que tenemos un plato quemado (un error). Dime, ¿qué receta o ingrediente está fallando en la app?";
      } else if (titulo == "Ayuda") {
        saludoChef = "¡Marchando una de sugerencias! Tengo los fogones listos. ¿Necesitas una receta o algún tip secreto de cocina?";
      } else {
        saludoChef = "¡Me encanta experimentar! Cuéntame esa nueva idea para añadirle sazón a nuestra app. ¡Soy todo oídos!";
      }

      _mensajes.add({
        "rol": "llama", 
        "texto": saludoChef
      });
    });
  }

  Future<void> _enviarMensaje() async {
    if (_controller.text.trim().isEmpty) return;

    final textoUsuario = _controller.text;
    setState(() {
      _mensajes.add({"rol": "usuario", "texto": textoUsuario});
      _controller.clear();
      _estaCargando = true;
    });

    try {
      // Envío de mensaje a Gemini
      final response = await _chat.sendMessage(Content.text(textoUsuario));
      
      setState(() {
        _mensajes.add({
          "rol": "llama",
          "texto": response.text ?? "¡Uy! Se me ha cortado la salsa. ¿Podrías repetir tu pedido?"
        });
      });
    } catch (e) {
      debugPrint("Error de Gemini: $e");
      setState(() {
        _mensajes.add({
          "rol": "llama", 
          "texto": "Parece que los fogones están bloqueados (Error de conexión). Para solucionar esto en Chrome, recuerda ejecutar la app con el comando de seguridad desactivada."
        });
      });
    } finally {
      setState(() => _estaCargando = false);
    }
  }

  @override
@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text("Asistente A.L.I.C.I.A."),
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 1,
      // Minitarea extra: Botón para volver al menú y recuperar el fondo
      leading: _opcionSeleccionada 
        ? IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => setState(() => _opcionSeleccionada = false),
          )
        : null,
    ),
    body: Stack(
      children: [
        // --- FONDO CONDICIONAL ---
        Positioned.fill(
          child: _opcionSeleccionada
              ? Container(color: const Color(0xFFF5F5F5)) // Fondo gris muy claro para el chat
              : Image.asset(
                  'assets/images/fondo.webp',
                  fit: BoxFit.cover,
                ),
        ),
        
        // --- INTERFAZ ---
        SafeArea(
          child: _opcionSeleccionada ? _buildChatLayout() : _buildWelcomeLayout(),
        ),
      ],
    ),
  );
}

  Widget _buildWelcomeLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            const Text(
              "¿Qué tienes para contarme?",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22, 
                fontWeight: FontWeight.bold, 
                color: Colors.white,
                shadows: [Shadow(color: Colors.black, blurRadius: 10)],
              ),
            ),
            const SizedBox(height: 40),
            _buildMenuButton("Reporte", "Reportar un problema con la app", Icons.bug_report_outlined),
            _buildMenuButton("Ayuda", "Necesito una recomendación de comida", Icons.restaurant_menu),
            _buildMenuButton("Sugerencia", "Me gustaría sugerir una nueva receta", Icons.lightbulb_outline),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(String titulo, String descripcion, IconData icono) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ElevatedButton(
        onPressed: () => _seleccionarOpcion(titulo, descripcion),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.6),
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.all(16),
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: BorderSide(color: Colors.white.withOpacity(0.3)),
          ),
        ),
        child: Row(
          children: [
            Icon(icono, color: const Color(0xFF2D9E73), size: 30),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                descripcion, 
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)
              )
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatLayout() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _mensajes.length,
            itemBuilder: (context, index) {
              bool esUsuario = _mensajes[index]["rol"] == "usuario";
              return Align(
                alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 5),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: esUsuario ? const Color(0xFF2D9E73) : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Text(
                    _mensajes[index]["texto"]!,
                    style: TextStyle(
                      color: esUsuario ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        if (_estaCargando)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text(
              "A.L.I.C.I.A. está cocinando una respuesta...",
              style: TextStyle(color: Colors.white, fontStyle: FontStyle.italic, shadows: [Shadow(color: Colors.black, blurRadius: 5)]),
            ),
          ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: "Escribe a la chef...",
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _enviarMensaje(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send, color: Color(0xFF2D9E73)),
            onPressed: _enviarMensaje,
          ),
        ],
      ),
    );
  }
}