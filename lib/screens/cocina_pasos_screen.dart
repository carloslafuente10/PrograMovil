import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
      List<dynamic> pasosEncontrados = [];

      final docSnapshot = await FirebaseFirestore.instance
          .collection('steps-recetas')
          .doc(widget.recetaId)
          .get();

      if (docSnapshot.exists) {
        final data = docSnapshot.data()!;
        pasosEncontrados = List.from(data['pasos_ordenados'] ?? []);
      }

      if (pasosEncontrados.isEmpty) {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('steps-recetas')
            .where('receta_id', isEqualTo: widget.recetaId)
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          final data = querySnapshot.docs.first.data();
          pasosEncontrados = List.from(data['pasos_ordenados'] ?? []);
        }
      }

      if (pasosEncontrados.isEmpty) {
        final personalDoc = await FirebaseFirestore.instance
            .collection('recetas_personales')
            .doc(widget.recetaId)
            .get();
        if (personalDoc.exists) {
          final data = personalDoc.data()!;
          pasosEncontrados = data['pasos'] as List? ?? [];
        }
      }

      if (pasosEncontrados.isEmpty) {
        final catalogoDoc = await FirebaseFirestore.instance
            .collection('app-recetas-completas')
            .doc(widget.recetaId)
            .get();
        if (catalogoDoc.exists) {
          final data = catalogoDoc.data()!;
          pasosEncontrados = List.from(data['pasos_ordenados'] ?? []);
        }
      }

      pasosEncontrados.sort((a, b) => (a['orden'] ?? 0).compareTo(b['orden'] ?? 0));

      setState(() {
        _pasos = pasosEncontrados;
        _isLoading = false;
      });
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2D9E73))),
      );
    }

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
                const Text("No se encontraron pasos",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 10),
                Text("ID buscado: '${widget.recetaId}'",
                    style: const TextStyle(backgroundColor: Colors.yellow)),
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
        title: const Text("Preparación",
            style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
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
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2D9E73)),
            minHeight: 6,
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (int page) => setState(() => _currentPage = page),
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

    String? ingredienteDetectado;
    String? sustitutoSugerido;

    _sustitutosConfig.forEach((key, value) {
      if (instruccion.toLowerCase().contains(key)) {
        ingredienteDetectado = key;
        sustitutoSugerido = value;
      }
    });

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "PASO $numeroPaso",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D9E73),
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  instruccion,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 19,
                    height: 1.65,
                    color: Colors.black87,
                  ),
                ),
                if (sustitutoSugerido != null) ...[
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF9E7),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFFFE082)),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.favorite_border,
                            color: Color(0xFF2D9E73), size: 20),
                        const SizedBox(height: 8),
                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                                color: Colors.brown, fontSize: 14),
                            children: [
                              const TextSpan(text: "Recuerda que si no tienes "),
                              TextSpan(
                                text: ingredienteDetectado,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple),
                              ),
                              const TextSpan(text: " puedes usar "),
                              TextSpan(
                                text: sustitutoSugerido,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2D9E73)),
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
      ),
    );
  }

  Widget _buildBottomBar() {
    final bool esUltimoPaso = _currentPage >= _pasos.length - 1;
    const Color verde = Color(0xFF2D9E73);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: _currentPage > 0
                  ? OutlinedButton.icon(
                      onPressed: () {
                        _pageController.previousPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      icon: const Icon(Icons.chevron_left_rounded, color: verde),
                      label: const Text("Paso Anterior",
                          style: TextStyle(
                              color: verde, fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: verde),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            if (_currentPage > 0) const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  if (!esUltimoPaso) {
                    _pageController.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  } else {
                    _mostrarExito();
                  }
                },
                icon: Icon(
                  esUltimoPaso
                      ? Icons.check_circle_rounded
                      : Icons.chevron_right_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  esUltimoPaso ? "Finalizar" : "Siguiente Paso",
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: verde,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _mostrarExito() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("¡Excelente!",
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text("Has completado todos los pasos de la receta. ¡Buen provecho!"),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2D9E73),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("¡Listo!", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}