import 'package:flutter/material.dart';

class IngredientesGrid extends StatelessWidget {
  final List<String> ingredientesPrimordiales;
  final List<String> ingredientesSeleccionados;
  final Color colorVerde;
  final Function(String ing, bool isSelected) onIngredienteToggle;
  final VoidCallback onConfirmar;

  const IngredientesGrid({
    super.key,
    required this.ingredientesPrimordiales,
    required this.ingredientesSeleccionados,
    required this.colorVerde,
    required this.onIngredienteToggle,
    required this.onConfirmar,
  });

  @override
  Widget build(BuildContext context) {
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
              mainAxisSpacing: 8,
            ),
            itemCount: ingredientesPrimordiales.length,
            itemBuilder: (context, index) {
              final ing = ingredientesPrimordiales[index];
              final isSel = ingredientesSeleccionados.contains(ing);
              return FilterChip(
                label: Text(
                  ing, 
                  style: const TextStyle(fontSize: 11), 
                  overflow: TextOverflow.ellipsis,
                ),
                selected: isSel,
                selectedColor: colorVerde.withOpacity(0.3),
                onSelected: (val) => onIngredienteToggle(ing, val),
              );
            },
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: ingredientesSeleccionados.isNotEmpty ? onConfirmar : null,
            icon: const Icon(Icons.restaurant),
            label: const Text("Confirmar ingredientes"),
            style: ElevatedButton.styleFrom(
              backgroundColor: colorVerde,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )
        ],
      ),
    );
  }
}