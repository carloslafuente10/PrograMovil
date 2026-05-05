import 'package:flutter/material.dart';

class SugerenciasChatScreen extends StatefulWidget {
  const SugerenciasChatScreen({super.key});

  @override
  State<SugerenciasChatScreen> createState() => _SugerenciasChatScreenState();
}

class _SugerenciasChatScreenState extends State<SugerenciasChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _mensajes = [];

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
      appBar: AppBar(
        title: const Text("Asistente PrograMovil"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _mensajes.length,
              itemBuilder: (context, index) => ListTile(
                title: Text(_mensajes[index]["texto"]!),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _controller)),
                IconButton(icon: const Icon(Icons.send), onPressed: _enviarMensaje),
              ],
            ),
          ),
        ],
      ),
    );
  }
}