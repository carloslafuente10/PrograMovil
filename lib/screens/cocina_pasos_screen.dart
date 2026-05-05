import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Mapa global de sustitutos
const Map<String, String> _sustitutosConfig = {
  'cebolla morada': 'Cebolla blanca',
  'cebolla roja': 'Cebolla blanca',
  'aceite de girasol': 'Manteca',
  'tortilla de maiz': 'Tortilla de harina de trigo',
  'manteca de cerdo': 'Aceite',
  'urucu': 'Pimienta dulce',
  'achlote': 'Pimienta dulce',
  'carne de res': 'Carne de pollo desmenuzado',
  'caldo de res': 'Caldo de pollo',
  'filete de carne': 'Filete de pechuga de pollo',
  'fideo corbata': 'Macarrón',
};

class CocinaPasosScreen extends StatefulWidget {
  final String recetaId;
  const CocinaPasosScreen({super.key, required this.recetaId});

  @override
  State<CocinaPasosScreen> createState() => _CocinaPasosScreenState();
}

class _CocinaPasosScreenState extends State<CocinaPasosScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<dynamic> _pasos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarPasos();
  }

  Future<void> _cargarPasos() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('steps-recetas')
          .where('receta_id', isEqualTo: widget.recetaId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        List<dynamic> pasosRaw = List.from(data['pasos_ordenados'] ?? []);
        pasosRaw.sort((a, b) => (a['orden'] ?? 0).compareTo(b['orden'] ?? 0));
        
        setState(() {
          _pasos = pasosRaw;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error cargando pasos: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.green)));
    }

    // --- CAMBIO AQUÍ: BLOQUE DE DEPURACIÓN PARA VER EL ID ---
    if (_pasos.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text("Preparación")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 60, color: Colors.orange),
                const SizedBox(height: 20),
                const Text(
                  "No se encontraron pasos", 
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                ),
                const SizedBox(height: 10),
                // Esto te mostrará el ID en la pantalla de PrograMovil
                Text(
                  "ID buscado: '${widget.recetaId}'",
                  style: const TextStyle(backgroundColor: Colors.yellow),
                ),
                const SizedBox(height: 20),
                const Text(
                  "Copia este código y ponlo en el campo 'receta_id' de tu colección 'steps-recetas' en Firebase.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    double progreso = (_currentPage + 1) / _pasos.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Preparación", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: progreso,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
            minHeight: 6,
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (int page) {
                setState(() => _currentPage = page);
              },
              itemCount: _pasos.length,
              itemBuilder: (context, index) {
                final paso = _pasos[index];
                return _buildStepCard(paso, index + 1);
              },
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStepCard(Map<String, dynamic> paso, int numeroPaso) {
  final String instruccion = paso['instruccion'] ?? "Sin instrucción";
  
  // Lógica de detección: busca si alguna clave del mapa está en la instrucción
  String? ingredienteDetectado;
  String? sustitutoSugerido;

  _sustitutosConfig.forEach((key, value) {
    if (instruccion.toLowerCase().contains(key)) {
      ingredienteDetectado = key;
      sustitutoSugerido = value;
    }
  });

  return Container(
    margin: const EdgeInsets.all(25),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(30),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 180, // Reduje un poco para dar espacio al aviso
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.green[50],
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Icon(Icons.restaurant, size: 60, color: Colors.green),
        ),
        const SizedBox(height: 20),
        Text(
          "PASO $numeroPaso",
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.green, letterSpacing: 1.5),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Text(
                  instruccion,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18, height: 1.5, color: Colors.black87),
                ),
                if (sustitutoSugerido != null) ...[
                  const SizedBox(height: 25),
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.favorite_border, color: Colors.green, size: 20),
                        const SizedBox(height: 8),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(color: Colors.brown, fontSize: 15),
                            children: [
                              const TextSpan(text: "Recuerda que si no tienes "),
                              TextSpan(
                                text: ingredienteDetectado,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple),
                              ),
                              const TextSpan(text: " puedes usar "),
                              TextSpan(
                                text: sustitutoSugerido,
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
              
  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(25, 0, 25, 40),
      child: Row(
        children: [
          if (_currentPage > 0)
            GestureDetector(
              onTap: () {
                _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Icon(Icons.arrow_back_ios_new, size: 20),
              ),
            )
          else
            const SizedBox(width: 52),
          const SizedBox(width: 15),
          Expanded(
            child: ElevatedButton(
              onPressed: () {
                if (_currentPage < _pasos.length - 1) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                } else {
                  _mostrarExito();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: Text(
                _currentPage < _pasos.length - 1 ? "Siguiente Paso" : "Finalizar",
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarExito() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("¡Excelente!"),
        content: const Text("Has terminado la receta."),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("OK"),
          )
        ],
      ),
    );
  }
}