import 'package:flutter/material.dart';// Librería de Flutter para la construcción de interfaces gráficas
import 'package:cloud_firestore/cloud_firestore.dart';// Permite la conexión y consulta de datos en Firebase Firestore.
// Pantalla de administración de categorías de recetas, donde se pueden agregar, editar o eliminar categorías.
class AdminCategoriasScreen extends StatelessWidget {
  const AdminCategoriasScreen({super.key});

  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
  static const Color _fondo = Color(0xFFF5F6FA);

  @override
  // Construye la interfaz de la pantalla de administración de categorías, mostrando una lista de categorías existentes y un botón para agregar nuevas categorías.
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _fondo,
      appBar: AppBar(
        backgroundColor: _verde,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Categorías',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: _verde,
            child: Container(
              decoration: const BoxDecoration(
                color: _fondo,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('app-Categorías')
                    .snapshots(),
                builder: (context, snapshot) {
                  final count = snapshot.data?.docs.length ?? 0;
                  return Row(
                    children: [
                      const Icon(
                        Icons.grid_view_rounded,
                        color: _verde,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$count categorías registradas',
                        style: const TextStyle(
                          color: _verde,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('app-Categorías')
                  .orderBy('nombre')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: _verde),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.category_outlined,
                          size: 56,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No hay categorías aún',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Toca + para agregar la primera',
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 80),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    return _CategoriaCard(
                      nombre: data['nombre']?.toString() ?? '',
                      docId: docs[i].id,
                      index: i,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: _verde,
        elevation: 4,
        onPressed: () => _mostrarDialogo(context, null, null),
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
        label: const Text(
          'Nueva categoría',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
// Función que muestra un diálogo para agregar o editar una categoría, dependiendo de si se proporciona un ID de documento existente.
  static void _mostrarDialogo(
    BuildContext context,
    String? docId,
    String? nombreActual,
  ) {
    const Color verde = Color(0xFF2D9E73);
    final ctrl = TextEditingController(text: nombreActual ?? '');
    final esEdicion = docId != null;
// Construye un diálogo que permite al usuario ingresar el nombre de una categoría, con opciones para cancelar o guardar los cambios, y maneja la lógica de actualización o creación en Firebase Firestore.
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          esEdicion ? 'Editar categoría' : 'Nueva categoría',
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: 'Nombre',
            prefixIcon: const Icon(Icons.label_rounded, color: verde, size: 20),
            filled: true,
            fillColor: const Color(0xFFF5F6FA),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: verde, width: 1.5),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              final nombre = ctrl.text.trim();
              if (nombre.isEmpty) return;
              if (esEdicion) {
                FirebaseFirestore.instance
                    .collection('app-Categorías')
                    .doc(docId)
                    .update({'nombre': nombre});
              } else {
                FirebaseFirestore.instance.collection('app-Categorías').add({
                  'nombre': nombre,
                });
              }
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: verde,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              esEdicion ? 'Guardar' : 'Agregar',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// Widget que representa una tarjeta individual de categoría, mostrando su nombre y opciones para editar o eliminar la categoría.
class _CategoriaCard extends StatelessWidget {
  final String nombre;
  final String docId;
  final int index;

  static const Color _verde = Color(0xFF2D9E73);
  static const Color _verdeClaro = Color(0xFFE8F7F1);
// Lista de iconos predefinidos para representar visualmente las categorías, asignados de forma cíclica según el índice de la categoría.
  static const List<IconData> _iconos = [
    Icons.breakfast_dining_rounded,
    Icons.lunch_dining_rounded,
    Icons.dinner_dining_rounded,
    Icons.local_cafe_rounded,
    Icons.fastfood_rounded,
    Icons.set_meal_rounded,
    Icons.cake_rounded,
    Icons.soup_kitchen_rounded,
  ];
// Constructor que inicializa los campos necesarios para representar una categoría, incluyendo su nombre, ID de documento en Firestore y su índice para la asignación de iconos.
  const _CategoriaCard({
    required this.nombre,
    required this.docId,
    required this.index,
  });

  @override
  // Construye la tarjeta visual de la categoría, mostrando su nombre, un icono representativo y botones para editar o eliminar la categoría, con estilos personalizados para cada acción.
  Widget build(BuildContext context) {
    final icono = _iconos[index % _iconos.length];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () =>
            AdminCategoriasScreen._mostrarDialogo(context, docId, nombre),
        splashColor: _verdeClaro,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _verdeClaro,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: _verde, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => AdminCategoriasScreen._mostrarDialogo(
                  context,
                  docId,
                  nombre,
                ),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: _verdeClaro,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: _verde,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _confirmarEliminar(context),
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(
                    Icons.delete_rounded,
                    color: Color(0xFFE53935),
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
// Función que muestra un diálogo de confirmación antes de eliminar una categoría, asegurando que el usuario confirme su intención de eliminar la categoría seleccionada.
  void _confirmarEliminar(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Eliminar categoría',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text('¿Eliminar la categoría "$nombre"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('app-Categorías')
                  .doc(docId)
                  .delete();
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
