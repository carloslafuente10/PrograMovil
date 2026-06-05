import 'package:flutter/foundation.dart';// Proporciona herramientas para la gestión de estado mediante ChangeNotifier.
import 'recipe_service.dart';// Servicio encargado de obtener información de recetas e ingredientes desde la fuente de datos.

/// Representa un ingrediente de la receta con su ID maestro.
/// 'masterIngredientId' es la clave en 'ingredientes_maestros'.
class RecipeIngredient {
  final String masterIngredientId;
  final String displayName;
  final bool es_primordial; //nuevo vigía

  const RecipeIngredient({
    required this.masterIngredientId,
    required this.displayName,
    this.es_primordial =
        false, // Por defecto falso para no romper código antiguo
  });
}

class IngredientProgressProvider extends ChangeNotifier {
  final RecipeService _service;

  IngredientProgressProvider({RecipeService? service})
    : _service = service ?? RecipeService();

  // Ingredientes que el usuario fue marcando en pantalla
  final Set<String> _checkedIngredientIds = {};

  // Cache de sustitutos para no hacer fetches repetidos
  final Map<String, List<String>> _substitutesCache = {};

  double _progressRatio = 0.0;
  bool _isReadyToCook = false;

  double get progressRatio => _progressRatio;
  bool get isReadyToCook => _isReadyToCook;

  /// Umbral configurable. 0.8 = 80%
  static const double _readinessThreshold = 0.8;

  /// Llama esto cuando el usuario toca el checkbox de un ingrediente.
  /// [ingredientId] es el ID del ingrediente marcado (puede ser el original
  /// o un sustituto — lo que el usuario diga que tiene).
  Future<void> toggleIngredient({
    required String ingredientId,
    required List<RecipeIngredient> allRecipeIngredients,
  }) async {
    if (_checkedIngredientIds.contains(ingredientId)) {
      _checkedIngredientIds.remove(ingredientId);
    } else {
      _checkedIngredientIds.add(ingredientId);
    }

    await _recalculateProgress(allRecipeIngredients);
  }

  /// Recalcula qué porcentaje de la receta puede cubrirse con los
  /// ingredientes marcados (originales o sustitutos válidos).
  Future<void> _recalculateProgress(
    List<RecipeIngredient> allRecipeIngredients,
  ) async {
    if (allRecipeIngredients.isEmpty) {
      _progressRatio = 0.0;
      _isReadyToCook = false;
      notifyListeners();
      return;
    }

    int coveredCount = 0;

    for (final ingredient in allRecipeIngredients) {
      // Caso 1: El usuario marcó exactamente el ingrediente original
      final hasOriginal = _checkedIngredientIds.contains(
        ingredient.masterIngredientId,
      );

      if (hasOriginal) {
        coveredCount++;
        continue; // No necesitamos revisar sustitutos
      }

      // Caso 2: Verificamos si algún ingrediente marcado es sustituto válido
      final substitutes = await _getSubstitutesFor(
        ingredient.masterIngredientId,
      );

      // ¿Alguno de los IDs marcados por el usuario está en la lista de sustitutos?
      final hasValidSubstitute = substitutes.any(
        (substitute) => _checkedIngredientIds.contains(substitute),
      );

      if (hasValidSubstitute) {
        coveredCount++;
      }
    }

    // Calculamos el ratio como fracción sobre el total de ingredientes
    _progressRatio = coveredCount / allRecipeIngredients.length;

    // El botón se habilita al alcanzar o superar el umbral del 80%
    _isReadyToCook = _progressRatio >= _readinessThreshold;

    notifyListeners();
  }

  /// Obtiene sustitutos usando cache para evitar lecturas innecesarias a Firestore.
  Future<List<String>> _getSubstitutesFor(String masterIngredientId) async {
    if (_substitutesCache.containsKey(masterIngredientId)) {
      return _substitutesCache[masterIngredientId]!;
    }

    final substitutes = await _service.fetchSubstitutesFor(masterIngredientId);
    _substitutesCache[masterIngredientId] = substitutes;
    return substitutes;
  }

  /// Resetea el estado al cambiar de receta
  void reset() {
    _checkedIngredientIds.clear();
    _substitutesCache.clear();
    _progressRatio = 0.0;
    _isReadyToCook = false;
    notifyListeners();
  }
}
