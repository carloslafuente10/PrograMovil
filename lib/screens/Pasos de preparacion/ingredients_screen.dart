import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ingredient_progress_provider.dart';
import 'recipe_service.dart';
import 'cooking_steps_screen.dart';

class IngredientsScreen extends StatelessWidget {
  final String recipeId;
  final String recipeTitle;
  final List<RecipeIngredient> ingredients;

  const IngredientsScreen({
    super.key,
    required this.recipeId,
    required this.recipeTitle,
    required this.ingredients,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => IngredientProgressProvider(),
      child: _IngredientsBody(
        recipeId: recipeId,
        recipeTitle: recipeTitle,
        ingredients: ingredients,
      ),
    );
  }
}

class _IngredientsBody extends StatelessWidget {
  final String recipeId;
  final String recipeTitle;
  final List<RecipeIngredient> ingredients;

  const _IngredientsBody({
    required this.recipeId,
    required this.recipeTitle,
    required this.ingredients,
  });

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<IngredientProgressProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(recipeTitle)),
      body: Column(
        children: [
          _ProgressHeader(ratio: provider.progressRatio),
          Expanded(
            child: ListView.builder(
              itemCount: ingredients.length,
              itemBuilder: (context, index) {
                final ingredient = ingredients[index];
                return _IngredientTile(
                  ingredient: ingredient,
                  allIngredients: ingredients,
                );
              },
            ),
          ),
          _CookingButton(
            isReady: provider.isReadyToCook,
            recipeId: recipeId,
          ),
        ],
      ),
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  final double ratio;
  const _ProgressHeader({required this.ratio});

  @override
  Widget build(BuildContext context) {
    final percent = (ratio * 100).round();
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tienes el $percent% de los ingredientes',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 12,
              backgroundColor: colorScheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(
                ratio >= 0.8 ? Colors.green : colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientTile extends StatefulWidget {
  final RecipeIngredient ingredient;
  final List<RecipeIngredient> allIngredients;

  const _IngredientTile({
    required this.ingredient,
    required this.allIngredients,
    super.key,
  });

  @override
  State<_IngredientTile> createState() => _IngredientTileState();
}

class _IngredientTileState extends State<_IngredientTile> {
  bool _isDone = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<IngredientProgressProvider>();

    return CheckboxListTile(
      title: Text(widget.ingredient.displayName),
      value: _isDone,
      onChanged: (bool? value) async {
        setState(() {
          _isDone = value ?? false;
        });
        await provider.toggleIngredient(
          ingredientId: widget.ingredient.masterIngredientId,
          allRecipeIngredients: widget.allIngredients,
        );
      },
    );
  }
}

class _CookingButton extends StatelessWidget {
  final bool isReady;
  final String recipeId;

  const _CookingButton({
    required this.isReady,
    required this.recipeId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isReady)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF3BAE7C),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              "¡A cocinar! 👨‍🍳",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isReady ? () => _navigateToSteps(context) : null,
                icon: const Icon(Icons.play_arrow),
                label: const Text("Empezar a cocinar"),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3BAE7C),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _navigateToSteps(BuildContext context) async {
    // 1. Verificación inmediata en consola
    print("--- INICIANDO NAVEGACIÓN ---");
    print("Buscando pasos para el ID exacto: '$recipeId'");

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final service = RecipeService();
      final steps = await service.fetchStepsForRecipe(recipeId);
      
      print("Resultado de Firestore: ${steps.length} documentos encontrados.");

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Quitar loading

      if (steps.isEmpty) {
        // Alerta visual de que no hay datos
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Error de Datos"),
            content: Text("No se encontraron pasos para la receta: '$recipeId'. Revisa que el nombre en Firestore coincida exactamente."),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => CookingStepsScreen(steps: steps)),
        );
      }
    } catch (e) {
      print("ERROR CRÍTICO: $e");
      if (context.mounted) Navigator.of(context).pop();
    }
  }