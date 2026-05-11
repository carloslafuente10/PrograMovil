import 'package:flutter/material.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

// Importa aquí tus pantallas de destino si es necesario
// import 'tu_ruta/receta_detalle_screen.dart'; 

class SugerenciasChatScreen extends StatefulWidget {
  const SugerenciasChatScreen({super.key});

  @override
  State<SugerenciasChatScreen> createState() => _SugerenciasChatScreenState();
}

class _SugerenciasChatScreenState extends State<SugerenciasChatScreen> {
  // --- VARIABLES DE ESTADO ---
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, dynamic>> _mensajes = [];
  bool _opcionSeleccionada = false;
  bool _estaCargando = false;
  String? _categoriaActual;
  bool _esperandoDetalleReporte = false;
  bool _esperandoParrafoSugerencia = false;

  final Color _verde = const Color(0xFF2D9E73);

  // Estados para el flujo de Recomendación (Ayuda)
  String? _categoriaComidaElegida;
  List<String> _ingredientesPrimordiales = [];
  final List<String> _ingredientesSeleccionados = [];
  bool _mostrarGridIngredientes = false;

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
    _model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: 'AIzaSyDXMO7kdFZ-1_WxgBwK8QpgaArHJnA3j_A',
      systemInstruction: Content.system(systemPrompt),
    );
    _chat = _model.startChat();
  }

  // --- LÓGICA DE BÚSQUEDA EN FIRESTORE ---
  Future<void> _buscarRecetasRecomendadas() async {
    setState(() => _estaCargando = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('app-recetas-completas')
          .where('categoria', isEqualTo: _categoriaComidaElegida)
          .get();

      // Guardamos Mapas con 'id' y 'nombre' para poder navegar luego
      List<Map<String, String>> recetasEncontradas = [];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        String nombreReceta = data['nombre'] ?? "Receta sin nombre";
        List ingredientes = data['ingredientes'] ?? [];

        bool tieneIngrediente = ingredientes.any((ing) => 
          _ingredientesSeleccionados.contains(ing['nombre'].toString())
        );

        if (tieneIngrediente) {
          recetasEncontradas.add({
            'id': doc.id,
            'nombre': nombreReceta,
          });
        }
      }

      if (recetasEncontradas.isNotEmpty) {
        setState(() {
          _mensajes.add({
            "rol": "llama",
            "texto": "¡He encontrado el maridaje perfecto! 👨‍🍳 Aquí tienes las opciones que mejor combinan con tu selección. ¡Pulsa en la que más te apetezca!",
            "tipo": "recetas_grid",
            "recetas": recetasEncontradas // Pasamos la lista de objetos
          });
        });
      } else {
        setState(() {
          _mensajes.add({
            "rol": "llama",
            "texto": "He buscado en mi alacena pero no tengo una receta exacta con esa combinación. 🥣 ¿Intentamos con otros ingredientes?",
            "tipo": "texto"
          });
        });
      }

    } catch (e) {
      debugPrint("Error al buscar recetas: $e");
      setState(() => _mensajes.add({"rol": "llama", "texto": "Se nos ha derramado el caldo... Error en la conexión."}));
    } finally {
      setState(() => _estaCargando = false);
    }
  }

  // --- LÓGICA DE INTERACCIÓN ---
  void _seleccionarOpcion(String titulo, String descripcion) {
    setState(() {
      _opcionSeleccionada = true;
      _categoriaActual = titulo;
      _mensajes.clear();
      _esperandoDetalleReporte = false;
      _esperandoParrafoSugerencia = false;
      _mostrarGridIngredientes = false;
      _ingredientesSeleccionados.clear();

      String saludoChef;
      String tipoMensaje = "texto";

      if (titulo == "Reporte") {
        saludoChef = "¡Oído cocina! Veo que tenemos un plato quemado (un error). Por favor, dime con detalle qué está fallando.";
        _esperandoDetalleReporte = true;
      } else if (titulo == "Ayuda") {
        saludoChef = "Cuéntame, veo que necesitas una pequeña ayuda para decidirte. Por favor selecciona una categoría:";
        tipoMensaje = "botones_categoria";
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

  Future<void> _cargarIngredientesPrimordiales(String categoria) async {
    setState(() => _estaCargando = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('app-recetas-completas')
          .where('categoria', isEqualTo: categoria)
          .get();

      Set<String> primordialesSet = {};
      for (var doc in snapshot.docs) {
        List ingredientes = doc.data()['ingredientes'] ?? [];
        for (var ing in ingredientes) {
          if (ing['es_primordial'] == true) {
            primordialesSet.add(ing['nombre'].toString());
          }
        }
      }

      setState(() {
        _ingredientesPrimordiales = primordialesSet.toList();
        _mostrarGridIngredientes = true;
        _mensajes.add({
          "rol": "llama",
          "texto": "Por favor Elige hasta 3 ingredientes disponibles:",
          "tipo": "grid_ingredients"
        });
      });
    } catch (e) {
      debugPrint("Error en DB: $e");
    } finally {
      setState(() => _estaCargando = false);
    }
  }

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

    if ((_esperandoDetalleReporte || _esperandoParrafoSugerencia) && textoOriginal.length < 20) {
      setState(() {
        _estaCargando = false;
        _mensajes.add({
          "rol": "llama",
          "texto": "¡Uy chef! Esa idea todavía está 'cruda'. Necesito más detalle.",
          "tipo": "texto"
        });
      });
      return;
    }

    if (_esperandoDetalleReporte) {
      setState(() {
        _esperandoDetalleReporte = false;
        _estaCargando = false;
        _mensajes.add({
          "rol": "llama",
          "tipo": "reporte_btn",
          "texto": "¿Deseas enviar este reporte directamente al administrador?"
        });
      });
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
      final response = await _chat.sendMessage(Content.text(textoOriginal));
      setState(() {
        _mensajes.add({
          "rol": "llama",
          "tipo": "texto",
          "texto": response.text ?? "¡Uy! Se me ha cortado la salsa."
        });
      });
    } catch (e) {
      setState(() => _mensajes.add({"rol": "llama", "texto": "Parece que los fogones están bloqueados."}));
    } finally {
      setState(() => _estaCargando = false);
    }
  }

  void _enviarReporteAlAdmin(String detalle) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reporte enviado al administrador")));
  }

  void _enviarSugerenciaAlAdmin() {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Sugerencia enviada!")));
  }

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
          SafeArea(child: _opcionSeleccionada ? _buildChatLayout() : _buildWelcomeLayout()),
        ],
      ),
    );
  }

  Widget _buildWelcomeLayout() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
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
            Icon(icono, color: _verde, size: 30),
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
              final msg = _mensajes[index];
              bool esUsuario = msg["rol"] == "usuario";
              
              return Align(
                alignment: esUsuario ? Alignment.centerRight : Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: esUsuario ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: esUsuario ? _verde : Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Text(
                        msg["texto"]!, 
                        style: TextStyle(
                          color: esUsuario ? Colors.white : Colors.black87, 
                          fontWeight: FontWeight.w500
                        )
                      ),
                    ),
                    if (msg["tipo"] == "botones_categoria") _buildCategoriasGrid(),
                    if (msg["tipo"] == "grid_ingredients" && _mostrarGridIngredientes) _buildIngredientesGrid(),
                    // NUEVO: Grid de botones de recetas encontradas
                    if (msg["tipo"] == "recetas_grid") _buildRecetasBotonesGrid(msg["recetas"]),
                    if (msg["tipo"] == "reporte_btn") 
                       _buildActionBtn(() => _enviarReporteAlAdmin(msg["texto"]), Icons.mark_email_read_outlined, "Enviar reporte al admin"),
                    if (msg["tipo"] == "sugerencia_btn")
                       _buildActionBtn(_enviarSugerenciaAlAdmin, Icons.send_and_archive, "Enviar al plantel administrativo"),
                  ],
                ),
              );
            },
          ),
        ),
        if (_estaCargando) 
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text("A.L.I.C.I.A. está cocinando...", style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic)),
          ),
        _buildInputArea(),
      ],
    );
  }

  // WIDGET NUEVO: Botones para las recetas recomendadas
  Widget _buildRecetasBotonesGrid(List<Map<String, String>> recetas) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: recetas.map((receta) {
          return SizedBox(
            width: 160, // Ajuste para que quepan dos por fila aprox.
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
                // Aquí navegas a tu pantalla de detalle usando receta['id']
                debugPrint("Navegando a la receta: ${receta['nombre']} con ID: ${receta['id']}");
                /* Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => TuPantallaDetalle(recetaId: receta['id']!))
                ); 
                */
              },
              icon: const Icon(Icons.restaurant_menu, size: 18),
              label: Text(
                receta['nombre']!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _verde,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCategoriasGrid() {
    final cats = ["Almuerzo", "Cena", "Desayuno", "Snack", "Refrescos"];
    return Wrap(
      spacing: 8,
      children: cats.map((cat) => ActionChip(
        label: Text(cat),
        backgroundColor: Colors.white,
        onPressed: () {
          setState(() {
            _categoriaComidaElegida = cat;
            _mensajes.add({"rol": "usuario", "texto": "Categoría: $cat", "tipo": "texto"});
          });
          _cargarIngredientesPrimordiales(cat);
        },
      )).toList(),
    );
  }

  Widget _buildIngredientesGrid() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, 
              childAspectRatio: 2.2, 
              crossAxisSpacing: 8, 
              mainAxisSpacing: 8
            ),
            itemCount: _ingredientesPrimordiales.length,
            itemBuilder: (context, index) {
              final ing = _ingredientesPrimordiales[index];
              final isSel = _ingredientesSeleccionados.contains(ing);
              return FilterChip(
                label: Text(ing, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
                selected: isSel,
                selectedColor: _verde.withOpacity(0.3),
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
            },
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _ingredientesSeleccionados.isNotEmpty ? () {
              setState(() {
                _mostrarGridIngredientes = false;
                _controller.text = "Dame una recomendación de $_categoriaComidaElegida usando: ${_ingredientesSeleccionados.join(', ')}";
              });
              _enviarMensaje();
            } : null,
            icon: const Icon(Icons.restaurant),
            label: const Text("Confirmar ingredientes"),
            style: ElevatedButton.styleFrom(
              backgroundColor: _verde,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )
        ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    bool entradaBloqueada = (_mensajes.isNotEmpty && 
        (_mensajes.last["tipo"] == "reporte_btn" || _mensajes.last["tipo"] == "sugerencia_btn"));
    
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
                hintText: entradaBloqueada ? "Conversación terminada..." : "Escribe a la chef...", 
                border: InputBorder.none
              ),
              onSubmitted: (_) => _enviarMensaje(),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: entradaBloqueada ? Colors.grey : _verde), 
            onPressed: entradaBloqueada ? null : _enviarMensaje
          ),
        ],
      ),
    );
  }
}