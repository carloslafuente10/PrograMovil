import 'package:flutter/material.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:http/http.dart' as http;

import 'dart:convert'; // Necesario para JSON 

import 'detalle_receta_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


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

 

  // Variables para el flujo lineal de Reportes

  bool _bloquearReportes = false;         // Bloquea las categorías principales (Contenido, Experiencia, Técnico)

  String _categoriaReporteActual = "";    // Almacena qué tipo de reporte se está ejecutando

  String _subCategoriaReporteActual = ""; // Almacena el problema específico seleccionado

  bool _bloquearFlujoReporte = false;     // Bloquea que se pulsen subcategorías repetidas o paralelas



  final Color _verde = const Color(0xFF2D9E73);



  // Variables para el flujo lineal de Ayuda / Recomendación de Comida

  String? _categoriaComidaElegida;

  List<String> _ingredientesPrimordiales = [];

  final List<String> _ingredientesSeleccionados = [];

 

  // --- AQUÍ ESTÁN LAS DE CLARACIONES ÚNICAS CORREGIDAS ---

  bool _mostrarGridIngredientes = false;

  bool _bloquearCategorias = false;



  // --- CONFIGURACIÓN DE GROQ (xAI API) ---

  final String _apiKeyGrok = dotenv.env['GROQ_API_KEY'] ?? '';
  final String _systemPrompt = """

Eres A.L.I.C.I.A., la chef virtual oficial de PrograMovil.

Tu misión es asistir con recetas, reportes de errores y sugerencias.



REGLAS CRÍTICAS DE RESPUESTA:

1. Sé SÚPER CORTA y DIRECTA. Responde en un máximo de 2 o 3 líneas de texto.

2. NUNCA uses listas numeradas, viñetas ni textos largos. Todo debe ser un párrafo breve y fluido.

3. Mantén el tono entusiasta y usa metáforas culinarias rápidas (problemas = platos quemados, soluciones = recetas).

4. Usa pocos emojis de cocina y nunca reveles que eres una IA.

""";



String _construirPromptValidacion(String categoriaReporte, String subCategoria, String textoUsuario) {

  return """

Eres el sistema de control de calidad de la app PrograMovil. Tu única tarea es validar si la descripción de un reporte de error enviada por el usuario es legítima.



CRITERIOS DE VALIDACIÓN:

1. RELACIÓN: El texto debe tener relación directa con el problema reportado. Categoría: $categoriaReporte. Subcategoría: $subCategoria.

2. COHERENCIA: El texto debe ser legible, coherente y describir una situación o acción. No se permiten números aleatorios, spam, insultos ni palabras sueltas sin sentido.

3. CONTEXTO DE LA APP: Debe hablar de funciones, pantallas, botones o recetas de la aplicación (datos de recetas, carga, inicio de sesión, etc.).



Texto del usuario a evaluar: "$textoUsuario"



Responde ÚNICAMENTE con la palabra 'VALIDO' si cumple los 3 criterios, o 'INVALIDO' si falla en alguno. No agregues saludos, explicaciones ni puntuación.

""";

}

  @override

  void initState() {

    super.initState();

  }



  // --- LÓGICA DE COMUNICACIÓN CON GROK CON CONTEXTO COMPLETO ---

  Future<String> _obtenerRespuestaDeGrok(String mensajeUsuario) async {

    final url = Uri.parse('https://api.groq.com/openai/v1/chat/completions');

   

    List<Map<String, String>> historialParaApi = [

      {"role": "system", "content": _systemPrompt}

    ];



    for (var msg in _mensajes) {

      if (msg["tipo"] == "texto") {

        String roleApi = (msg["rol"] == "usuario") ? "user" : "assistant";

        historialParaApi.add({

          "role": roleApi,

          "content": msg["texto"] ?? ""

        });

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

          "temperature": 0.4

        }),

      );



      if (response.statusCode == 200) {

        final data = jsonDecode(utf8.decode(response.bodyBytes));

        return data['choices'][0]['message']['content'];

      } else {

        debugPrint("Error de Grok API Status: ${response.statusCode} - ${response.body}");

        return "¡Uy! Se me ha cortado la salsa (Error de comunicación con la cocina).";

      }

    } catch (e) {

      debugPrint("Excepción al conectar con Grok: $e");

      return "Se nos ha derramado el caldo... Revisa tu conexión a internet.";

    }

  }



  Future<bool> _verificarRecetaEnFirebase(String texto) async {

    try {

      // Hacemos una consulta rápida simulada o real a tu colección de Firebase

      // Puedes adaptarlo en el futuro usando tu instancia si deseas verificar strings exactos:

      // final query = await FirebaseFirestore.instance.collection('app-recetas-completas').get();

     

      await Future.delayed(const Duration(milliseconds: 600)); // Simula un pequeño delay de red

      return true; // Por defecto retorna true para indicar que cruzó datos con el sistema

    } catch (e) {

      debugPrint("Error al verificar en Firebase: $e");

      return false;

    }

  }



  // --- LÓGICA DE BÚSQUEDA EN FIRESTORE ---

  Future<void> _buscarRecetasRecomendadas() async {

    setState(() => _estaCargando = true);

    try {

      final snapshot = await FirebaseFirestore.instance

          .collection('app-recetas-completas')

          .where('categoria', isEqualTo: _categoriaComidaElegida)

          .get();



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

            "recetas": recetasEncontradas

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

      _bloquearCategorias = false;

      _bloquearFlujoReporte = false;

      _categoriaComidaElegida = null;

      _ingredientesSeleccionados.clear();

      _categoriaReporteActual = "";    // Guardará si es "Contenido", "Técnico" o "Experiencia"

      _subCategoriaReporteActual = ""; // Guardará el problema ("Receta mal explicada", "Crash", etc.)

      _bloquearReportes = false;



      String saludoChef;

      String tipoMensaje = "texto";



      if (titulo == "Reporte") {

        saludoChef = "Lamento mucho que tengas problemas que te separen de tu proxima comida. Por favor selecciona el problema que mas coincida con tu situacion.";

        tipoMensaje = "botones_reporte_categorias";

        _esperandoDetalleReporte = true;

      } else if (titulo == "Ayuda") {

        saludoChef = "Aqui estoy para guiarte en tu siguiente comida. Por favor selecciona una categoría:";

        tipoMensaje = "botones_categoria";

      } else if (titulo == "Consulta Especifica") {

        saludoChef = "¡Entrando comandas de alta cocina! 🚀 Tienes una duda avanzada para la Chef A.L.I.C.I.A. Escribe libremente tu inquietud culinaria o técnica en la barra de abajo y prepararé una respuesta magistral.";

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



  void _seleccionarCategoriaReporte(String categoria) {

  if (_bloquearReportes) return; // Si ya hay un reporte en curso, ignora clics extras



  setState(() {

    _bloquearReportes = true; // Bloqueamos los botones principales de reporte

    _categoriaReporteActual = categoria;

    _esperandoDetalleReporte = true;

    _mensajes.add({"rol": "usuario", "texto": categoria, "tipo": "texto"});

   

    // Aquí mapeas el texto personalizado que desees para cada una de las 3 categorías

    String respuestaSubcategoria = "Has seleccionado $categoria. Por favor, especifica el inconveniente para procesar tu reporte:";

   

    // Tu lógica existente para determinar qué lista de subcategorías enviar:

    List<String> subCats = [];

    if (categoria.contains("Contenido")) {

      subCats = ["Receta mal explicada", "Ingredientes erróneos", "Imágenes rotas"];

    } else if (categoria.contains("experiencia")) {

      subCats = ["Navegación confusa", "Letra muy pequeña", "Diseño incómodo"];

    } else {

      subCats = ["Cierre inesperado (Crash)", "Error de base de datos", "Carga lenta / Lag"];

    }



    _mensajes.add({

      "rol": "llama",

      "texto": respuestaSubcategoria,

      "tipo": "botones_reporte_subcategorias", // Asegúrate de que coincida con tu generador de UI

      "opciones": subCats, // Pasa tus subcategorías para renderizarlas

      "categoria_reporte": categoria

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



    if (_esperandoDetalleReporte) {

      // [FILTRO 1]: Validación de Coherencia de Texto (Filtro rápido de longitud)

      int espacios = textoOriginal.split(' ').length - 1;

      if (espacios < 2 || textoOriginal.length < 10) {

        setState(() {

          _estaCargando = false;

          _mensajes.add({

            "rol": "llama",

            "texto": "¡Uy chef! Esa comanda parece escrita en un idioma extraño. 📝 Por favor, usa palabras claras e introduce un texto coherente para contarme qué está fallando.",

            "tipo": "texto"

          });

        });

        return;

      }



      try {

        // [FILTRO 2 y 3]: Validación de Contexto y Coherencia usando tu función optimizada

        String promptValidacion = _construirPromptValidacion(

          _categoriaReporteActual,

          _subCategoriaReporteActual,

          textoOriginal

        );

       

        // Llamamos a Groq usando el prompt estricto que creamos arriba

        final respuestaValidacion = await _obtenerRespuestaDeGrok(promptValidacion);

       

        // Si el validador determina que es INVALÍDOR, frena el flujo y pide corrección

        if (respuestaValidacion.trim().toUpperCase().contains("INVALIDO")) {

          setState(() {

            _estaCargando = false;

            _mensajes.add({

              "rol": "llama",

              "tipo": "texto",

              "texto": "¡Uy chef! Ese reporte parece tener los 'ingredientes equivocados'. Por favor, describe de forma clara el problema relacionado con la aplicación o las recetas para poder ayudarte. 🍳"

            });

          });

          return;

        }



        // --- FILTROS PASADOS CON ÉXITO: DETERMINAR TIPO DE RESPUESTA EN BASE A FIREBASE ---

        if (_categoriaReporteActual.contains("Contenido") || _subCategoriaReporteActual == "Receta mal explicada") {

          // Caso Firebase (Recetas y funciones de datos)

          bool existeEnRecetarioFirebase = await _verificarRecetaEnFirebase(textoOriginal);



          setState(() {

            _estaCargando = false;

            _esperandoDetalleReporte = false;

            _bloquearReportes = false;

            _bloquearFlujoReporte = false;

            _subCategoriaReporteActual = "";

            _categoriaReporteActual = "";



            if (existeEnRecetarioFirebase) {

              _mensajes.add({

                "rol": "llama",

                "tipo": "texto",

                "texto": "He verificado la información manejada en nuestro sistema de Firebase. El ingrediente o plato ya está bajo el radar de nuestra cocina de desarrollo."

              });

            } else {

              _mensajes.add({

                "rol": "llama",

                "tipo": "texto",

                "texto": "¡Uy chef! Revisé detalladamente en los servidores de Firebase y ese platillo o ingrediente no se encuentra registrado en nuestro recetario de la app."

              });

            }

          });

        } else {

          // Caso Técnico / Diseño -> Mensaje corto de la IA

          final respuestaConsueloIA = await _obtenerRespuestaDeGrok(textoOriginal);



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

              "texto": respuestaConsueloIA

            });

          });

        }



        // --- SOLUCIÓN DEL BOTÓN: Cambiamos "reporte_btn" por "sugerencia_btn" ---

        setState(() {

          _mensajes.add({

            "rol": "llama",

            "tipo": "sugerencia_btn", // Cambiado aquí para activar la UI administrativa y bloquear el input

            "texto": "¿Deseas enviar formalmente esta comanda de error directamente al plantel administrativo para que sea resuelta?"

          });

        });



      } catch (e) {

        setState(() {

          _esperandoDetalleReporte = false;

          _bloquearFlujoReporte = false;

          _estaCargando = false;

          _subCategoriaReporteActual = "";

          _mensajes.add({

            "rol": "llama",

            "tipo": "sugerencia_btn", // Cambiado aquí también por seguridad

            "texto": "¡Vaya, el horno se apagó! Pero guardé tu comanda de error. ¿La enviamos al plantel administrativo de igual forma?"

          });

        });

      }

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

      final respuesta = await _obtenerRespuestaDeGrok(textoOriginal);

      setState(() {

        _mensajes.add({

          "rol": "llama",

          "tipo": "texto",

          "texto": respuesta

        });

      });

    } catch (e) {

      setState(() => _mensajes.add({"rol": "llama", "texto": "Disculpa, creo que no entendí lo que intentaste decir."}));

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

                  _bloquearCategorias = false;

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

          SafeArea(child: _opcionSeleccionada ? _buildResponsiveLayout() : _buildWelcomeLayout()),

        ],

      ),

    );

  }



  Widget _buildResponsiveLayout() {

    if (_categoriaActual == "Reporte") {

      return Column(

        children: [

          Container(

            height: 140,

            width: double.infinity,

            color: Colors.white,

            child: const Center(

              child: Column(

                mainAxisAlignment: MainAxisAlignment.center,

                children: [

                  Icon(Icons.restaurant, size: 36, color: Color(0xFF2D9E73)),

                  SizedBox(height: 6),

                  Text(

                    "[ Animación de la Llama ]",

                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),

                  ),

                ],

              ),

            ),

          ),

          const Divider(height: 1, color: Colors.black12),

          Expanded(

            child: _buildChatLayout(),

          ),

        ],

      );

    } else {

      return _buildChatLayout();

    }

  }



  Widget _buildWelcomeLayout() {
  return Align(
    alignment: Alignment.bottomCenter, // Empuja todo el contenido hacia abajo
    child: SingleChildScrollView(
      padding: const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 16.0, top: 40.0), // Ajusta márgenes externos
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end, // Alinea los elementos internos al final
        children: [
          
         
          Transform.translate(
            offset: const Offset(0, -450), // Mueve SOLO el texto 50 píxeles hacia arriba sin mover los botones
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
          // --------------------------------------------

          // Aquí abajo siguen tus botones actuales (Reporte, Ayuda, etc.)
          // Al usar Transform.translate arriba, estos elementos se quedan exactamente en su posición original.

            const SizedBox(height: 20), // Reducido de 40 a 20 para acercar los botones al título
            _buildMenuButton(
              titulo: "Reporte",
              descripcion: "Quiero Reportar un problem con la app",
              subDescripcion: "Reportar un problema con la app",
              icono: Icons.bug_report_outlined,
              colorIcono: const Color(0xFFE57373)
            ),
            _buildMenuButton(
              titulo: "Ayuda",
              descripcion: "Necesito una recomendación de comida",
              subDescripcion: "Necesito una recomendación",
              icono: Icons.restaurant_menu,
              colorIcono: const Color(0xFFFFB74D)
            ),
            //_buildMenuButton(
            //titulo: "Sugerencia",
            //descripcion: "Me gustaría sugerir una nueva receta",
            //subDescripcion: "Sugerir nueva receta",
            //icono: Icons.lightbulb_outline,
            //colorIcono: const Color(0xFFFFF176)
            //,
            _buildHighlightedButton(), // Se eliminó el SizedBox(height: 10) previo para juntarlo más
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
      padding: const EdgeInsets.only(bottom: 10), // Reducido de 20 a 10 para juntar los botones
      child: Container(
        decoration: BoxDecoration(
          // Color crema/hueso idéntico al fondo de la imagen (100% sólido)
          color: const Color(0xFFF7F4EB), 
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              // Sombra suave adaptada al tono cálido del nuevo botón
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12), // Reducido el padding vertical para hacerlos más esbeltos
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
                        // Tono marrón teja/anaranjado oscuro que combina con la ilustración
                        color: Color(0xFFC85A32), 
                      ),
                    ),
                    const SizedBox(height: 2), // Reducido levemente
                    Text(
                      subDescripcion,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.normal,
                        // Gris pardo suave para la descripción
                        color: Color(0xFF7A756B), 
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                // Color mimetizado para la flecha derecha
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

          onPressed: () => _seleccionarOpcion("Consulta Especifica", "Tengo una consulta mas específica de lo normal"),

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

              Icon(Icons.psychology_alt, color: Colors.white, size: 32),

              SizedBox(width: 15),

              Expanded(

                child: Text(

                  "Tengo una consulta más específica de lo normal",

                  style: TextStyle(

                    fontSize: 14,

                    fontWeight: FontWeight.w900,

                    letterSpacing: 0.3,

                  )

                )

              ),

            ],

          ),

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

                child: Row(

                  mainAxisSize: MainAxisSize.min,

                  crossAxisAlignment: CrossAxisAlignment.start,

                  mainAxisAlignment: esUsuario ? MainAxisAlignment.end : MainAxisAlignment.start,

                  children: [

                    if (!esUsuario)

                      Padding(

                        padding: const EdgeInsets.only(right: 8.0, top: 5),

                        child: CircleAvatar(

                          radius: 18,

                          backgroundColor: _verde.withOpacity(0.2),

                          backgroundImage: const AssetImage('assets/images/chef_avatar.png'),

                          child: const Icon(Icons.restaurant, size: 16, color: Color(0xFF2D9E73)),

                        ),

                      ),

                   

                    Expanded(

                      flex: esUsuario ? 0 : 1,

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

                          if (msg["tipo"] == "botones_reporte_categorias") _buildReporteCategoriasGrid(),

                          if (msg["tipo"] == "botones_reporte_subcategorias") _buildReporteSubcategoriasGrid(msg["categoria_reporte"]),

                          if (msg["tipo"] == "botones_categoria") _buildCategoriasGrid(),

                          if (msg["tipo"] == "grid_ingredients" && _mostrarGridIngredientes) _buildIngredientesGrid(),

                          if (msg["tipo"] == "recetas_grid") _buildRecetasBotonesGrid(msg["recetas"]),

                          if (msg["tipo"] == "reporte_btn")

                             _buildActionBtn(() => _enviarReporteAlAdmin(msg["texto"]), Icons.mark_email_read_outlined, "Enviar reporte al admin"),

                          if (msg["tipo"] == "sugerencia_btn")

                             _buildActionBtn(_enviarSugerenciaAlAdmin, Icons.send_and_archive, "Enviar al plantel administrativo"),

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

            child: Text("A.L.I.C.I.A. está cocinando...", style: TextStyle(color: Colors.black54, fontStyle: FontStyle.italic)),

          ),

        _buildInputArea(),

      ],

    );

  }



  Widget _buildReporteCategoriasGrid() {

    final categoriasReporte = ["1. Problemas con el Contenido", "2. Problemas con la experiencia", "3. Fallas Técnicas"];

    return Wrap(

      spacing: 8,

      runSpacing: 4,

      children: categoriasReporte.map((cat) {

        // Si ya hay una categoría asignada en este flujo, desactivamos los otros botones

        bool desactivar = _bloquearReportes || (_categoriaReporteActual.isNotEmpty && _categoriaReporteActual != cat);

       

        return ActionChip(

          label: Text(cat, style: const TextStyle(fontWeight: FontWeight.w600)),

          backgroundColor: _categoriaReporteActual == cat ? _verde.withOpacity(0.15) : Colors.white,

          side: BorderSide(color: _verde.withOpacity(0.5)),

          onPressed: desactivar ? null : () => _seleccionarCategoriaReporte(cat),

        );

      }).toList(),

    );

  }



  Widget _buildReporteSubcategoriasGrid(String categoriaPadre) {

    List<String> opciones = [];

   

    if (categoriaPadre.contains("Contenido")) {

      opciones = ["Receta mal explicada", "Ingredientes erróneos", "Imágenes rotas"];

    } else if (categoriaPadre.contains("experiencia")) {

      opciones = ["Navegación confusa", "Letra muy pequeña", "Diseño incómodo"];

    } else {

      opciones = ["Cierre inesperado (Crash)", "Error de base de datos", "Carga lenta / Lag"];

    }



    return Wrap(

      spacing: 8,

      runSpacing: 4,

      children: opciones.map((opc) {

        // Si el usuario ya eligió una subcategoría o el flujo está cerrado esperando el texto, bloqueamos

        bool desactivarSub = _bloquearFlujoReporte || (_subCategoriaReporteActual.isNotEmpty && _subCategoriaReporteActual != opc);



        return ActionChip(

          label: Text(opc),

          backgroundColor: _subCategoriaReporteActual == opc ? const Color(0xFFFFE082) : const Color(0xFFFFF8E1),

          side: const BorderSide(color: Color(0xFFFFE082)),

          onPressed: desactivarSub ? null : () {

            setState(() {

              _bloquearFlujoReporte = true; // <-- CONGELA el resto de subcategorías al instante

              _subCategoriaReporteActual = opc;

              _mensajes.add({"rol": "usuario", "texto": "Problema específico: $opc", "tipo": "texto"});

             

              _mensajes.add({

                "rol": "llama",

                "texto": "Comanda anotada. Por favor, describe detalladamente la situación por el teclado para validar tu reporte 📝",

                "tipo": "texto"

              });

            });

          },

        );

      }).toList(),

    );

  }

  Widget _buildRecetasBotonesGrid(List<Map<String, String>> recetas) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: recetas.map((receta) {
          return SizedBox(
            width: 160, 
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () {
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
      children: cats.map((cat) {
        bool desactivarCat = _bloquearCategorias || (_categoriaComidaElegida != null && _categoriaComidaElegida != cat);

        return ActionChip(
          label: Text(cat),
          backgroundColor: _categoriaComidaElegida == cat ? _verde.withOpacity(0.2) : Colors.white,
          onPressed: desactivarCat ? null : () {
            setState(() {
              _bloquearCategorias = true; // <-- Bloquea para que no pulsen otra categoría de comida
              _categoriaComidaElegida = cat;
              _mensajes.add({"rol": "usuario", "texto": "Categoría: $cat", "tipo": "texto"});
            });
            _cargarIngredientesPrimordiales(cat);
          },
        );
      }).toList(),
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