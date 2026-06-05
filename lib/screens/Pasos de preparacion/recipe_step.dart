class RecipeStep {// Modelo que representa un paso individual dentro de una receta.
  final int order;
  final String instruction;

  const RecipeStep({
    required this.order,
    required this.instruction,
  });

  /// Convierte un Map (proveniente de Firestore) en un RecipeStep.
  /// El campo 'orden' puede venir como int o como String, así que lo normalizamos.
  factory RecipeStep.fromMap(Map<String, dynamic> map) {
    return RecipeStep(
      order: (map['orden'] as num).toInt(),
      instruction: map['instruccion'] as String,
    );
  }

  /// Parsea el documento de Firestore completo que contiene el array 'pasos_ordenados'.
  /// Retorna la lista ya ordenada por el campo 'orden'.
  static List<RecipeStep> listFromFirestoreDoc(Map<String, dynamic> docData) {
    final rawSteps = docData['pasos_ordenados'] as List<dynamic>? ?? [];

    final steps = rawSteps
        .map((item) => RecipeStep.fromMap(item as Map<String, dynamic>))
        .toList();

    // Ordenamos aquí para no depender del orden de inserción en Firestore
    steps.sort((a, b) => a.order.compareTo(b.order));

    return steps;
  }
}