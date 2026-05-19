import 'package:flutter/material.dart'; 

class CategoriasGrid extends StatelessWidget {
  final String? categoriaComidaElegida;
  final bool bloquearCategorias;
  final Color colorVerde;
  final Function(String cat) onCategoriaSeleccionada;

  const CategoriasGrid({
    super.key,
    required this.categoriaComidaElegida,
    required this.bloquearCategorias,
    required this.colorVerde,
    required this.onCategoriaSeleccionada,
  });

  @override
  Widget build(BuildContext context) {
    final cats = ["Almuerzo", "Cena", "Desayuno", "Snack", "Refrescos"];
    return Wrap(
      spacing: 8,
      children: cats.map((cat) {
        return ActionChip(
          label: Text(cat),
          backgroundColor: categoriaComidaElegida == cat 
              ? colorVerde.withOpacity(0.2) 
              : Colors.white,
          onPressed: bloquearCategorias ? null : () => onCategoriaSeleccionada(cat),
        );
      }).toList(),
    );
  }
}