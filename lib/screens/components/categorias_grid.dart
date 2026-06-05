import 'package:flutter/material.dart'; // Librería de Flutter para la construcción de interfaces gráficas
// Widget que muestra las categorías de comida en forma de chips seleccionables.
class CategoriasGrid extends StatelessWidget {
  final String? categoriaComidaElegida; // Categoría actualmente seleccionada.
  final bool bloquearCategorias;  // Indica si las categorías pueden ser seleccionadas o no.
  final Color colorVerde; // Color principal utilizado para resaltar la categoría elegida.
  final Function(String cat) onCategoriaSeleccionada; // Función que se ejecuta cuando el usuario selecciona una categoría.

  const CategoriasGrid({
    super.key,
    required this.categoriaComidaElegida,
    required this.bloquearCategorias,
    required this.colorVerde,
    required this.onCategoriaSeleccionada,
  });

  @override
  Widget build(BuildContext context) {
    final cats = ["Almuerzo", "Cena", "Desayuno", "Snack", "Refrescos"];  // Lista de categorías disponibles para la clasificación de recetas.
    return Wrap(
      spacing: 8,
      children: cats.map((cat) {
        return ActionChip(
          label: Text(cat),
          backgroundColor: categoriaComidaElegida == cat  // Resalta visualmente la categoría seleccionada.
              ? colorVerde.withOpacity(0.2) 
              : Colors.white,
          onPressed: bloquearCategorias ? null : () => onCategoriaSeleccionada(cat),  // Deshabilita la selección cuando las categorías están bloqueadas.
        );
      }).toList(),
    );
  }
}