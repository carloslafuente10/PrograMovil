import 'package:cloud_firestore/cloud_firestore.dart';// Permite la conexión y consulta de datos en Firebase Firestore.

class RecipeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Método para obtener los pasos de la receta (Navegación)
  Future<List<Map<String, dynamic>>> fetchStepsForRecipe(String recipeId) async {
    try {
      // Busca el documento donde el campo receta_id coincida
      final querySnapshot = await _db
          .collection('steps-recetas')
          .where('receta_id', isEqualTo: recipeId)
          .get();

      if (querySnapshot.docs.isEmpty) return [];

      final data = querySnapshot.docs.first.data();
      final List<dynamic> stepsList = data['pasos_ordenados'] ?? [];

      return stepsList.map((s) => Map<String, dynamic>.from(s)).toList();
    } catch (e) {
      print("Error en fetchStepsForRecipe: $e");
      return [];
    }
  }

  // MÉTODO FALTANTE: Obtener sustitutos para un ingrediente
  Future<List<String>> fetchSubstitutesFor(String masterIngredientId) async {
    try {
      // Busca en la colección de ingredientes_maestros
      final doc = await _db.collection('ingredientes_maestros').doc(masterIngredientId).get();
      
      if (!doc.exists) return [];

      final data = doc.data();
      // Retorna la lista de sustitutos si existe, o una lista vacía
      return List<String>.from(data?['sustitutos'] ?? []);
    } catch (e) {
      print("Error en fetchSubstitutesFor: $e");
      return [];
    }
  }
}