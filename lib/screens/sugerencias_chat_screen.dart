import 'package:flutter/material.dart';

class SugerenciasChatScreen extends StatefulWidget {
  const SugerenciasChatScreen({super.key});

  @override
  State<SugerenciasChatScreen> createState() => _SugerenciasChatScreenState();
}

class _SugerenciasChatScreenState extends State<SugerenciasChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _mensajes = [];
  
  // Controla si mostramos los botones o el chat
  bool _opcionSeleccionada = false;

  void _seleccionarOpcion(String opcion, String mensajeInicial) {
    setState(() {
      _opcionSeleccionada = true;
      // Añadimos el mensaje de la llama y la elección del usuario al chat
      _mensajes.add({"rol": "llama", "texto": "¿Qué tienes para contarme?"});
      _mensajes.add({"rol": "usuario", "texto": "$opcion: $mensajeInicial"});
      // Aquí podrías disparar una respuesta automática del bot según la opción
    });
  }

  void _enviarMensaje() {
    if (_controller.text.trim().isEmpty) return;
    setState(() {
      _mensajes.add({"rol": "usuario", "texto": _controller.text});
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      appBar: AppBar(
        title: const Text("Asistente PrograMovil"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: _opcionSeleccionada ? _buildChatLayout() : _buildWelcomeLayout(),
    );
  }

  // --- DISEÑO DEL MENÚ INICIAL ---
  Widget _buildWelcomeLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.auto_awesome, size: 80, color: Color(0xFF2D9E73)),
            const SizedBox(height: 20),
            const Text(
              "¿Qué tienes para contarme?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            _buildMenuButton(
              "Reporte", 
              "Necesito reportarte un problema con la aplicación", 
              Icons.bug_report_outlined
            ),
            _buildMenuButton(
              "Ayuda", 
              "Necesito una recomendación para preparar una comida de acuerdo a mis necesidades", 
              Icons.restaurant_menu
            ),
            _buildMenuButton(
              "Sugerencia", 
              "Me gustaría sugerir la implementación de una nueva receta", 
              Icons.lightbulb_outline
            ),
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
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          elevation: 2,
        ),
        child: Row(
          children: [
            Icon(icono, color: const Color(0xFF2D9E73), size: 30),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                descripcion,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- DISEÑO DEL CHAT ---
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
                    color: esUsuario ? const Color(0xFF2D9E73) : Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)],
                  ),
                  child: Text(
                    _mensajes[index]["texto"]!,
                    style: TextStyle(color: esUsuario ? Colors.white : Colors.black87),
                  ),
                ),
              );
            },
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
                hintText: "Escribe un mensaje...",
                border: InputBorder.none,
              ),
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