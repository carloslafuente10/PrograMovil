

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ingredient_progress_provider.dart';
import '../services/recipe_service.dart';
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
          // Barra de progreso visual
          _ProgressHeader(ratio: provider.progressRatio),

          // Lista de ingredientes con checkboxes
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

          // Botón dinámico en la parte inferior
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
              backgroundColor: colorScheme.surfaceVariant,
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

class _IngredientTile extends StatelessWidget {
  final RecipeIngredient ingredient;
  final List<RecipeIngredient> allIngredients;

  const _IngredientTile({
    required this.ingredient,
    required this.allIngredients,
  });

  @override
  Widget build(BuildContext context) {
    // Leemos sin escuchar para no reconstruir toda la lista en cada cambio
    final provider = context.read<IngredientProgressProvider>();

    return CheckboxListTile(
      title: Text(ingredient.displayName),
      value: false, // Podrías mantener estado local si lo necesitas
      onChanged: (_) async {
        await provider.toggleIngredient(
          ingredientId: ingredient.masterIngredientId,
          allRecipeIngredients: allIngredients,
        );
      },
    );
  }
}

/// Botón que cambia apariencia y texto según si se alcanzó el 80%
class _CookingButton extends StatelessWidget {
  final bool isReady;
  final String recipeId;

  const _CookingButton({required this.isReady, required this.recipeId});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: double.infinity,
          child: FilledButton.icon(
            // El botón se activa solo cuando isReady es true
            onPressed: isReady ? () => _navigateToCookingSteps(context) : null,
            icon: Icon(isReady ? Icons.restaurant : Icons.lock_outline),
            label: Text(
              isReady ? '¡A cocinar!' : 'Marca el 80% de ingredientes...',
              style: const TextStyle(fontSize: 16),
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              // Flutter maneja el color gris automáticamente cuando onPressed es null
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _navigateToCookingSteps(BuildContext context) async {
    final service = RecipeService();

    // Mostramos un indicador mientras cargamos los pasos
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final steps = await service.fetchStepsForRecipe(recipeId);

      if (!context.mounted) return;
      Navigator.of(context).pop(); // Cierra el loading

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CookingStepsScreen(steps: steps),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Cierra el loading
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al cargar los pasos. Intenta de nuevo.')),
      );
    }
  }
}