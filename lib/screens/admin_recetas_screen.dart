import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminRecetasScreen extends StatelessWidget {
  const AdminRecetasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final Color verde = const Color(0xFF2D9E73);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestionar Recetas"),
        backgroundColor: verde,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('app-recetas-completas')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No hay recetas"));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
            ),
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data() as Map<String, dynamic>;

              final recetaMap = {
                'nombre': data['nombre']?.toString() ?? '',
                'img': data['imagen']?.toString() ?? '',
                'calorias': (data['calorias'] ?? data['calorías'])?.toString() ?? '0',
              };

              return AdminRecetaCard(
                receta: recetaMap,
                docId: docs[i].id,
                verde: verde,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: verde,
        onPressed: () {
          FirebaseFirestore.instance
              .collection('app-recetas-completas')
              .add({
            'nombre': 'Nueva receta',
            'calorias': '0',
            'imagen': '',
            'tiempo': '0',
            'categoria': 'General',
          });
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class AdminRecetaCard extends StatelessWidget {
  final Map<String, String> receta;
  final String docId;
  final Color verde;

  const AdminRecetaCard({
    super.key,
    required this.receta,
    required this.docId,
    required this.verde,
  });

  @override
  Widget build(BuildContext context) {
    final String img = receta['img'] ?? '';

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Expanded(
            child: img.isNotEmpty
                ? Image.network(img, fit: BoxFit.cover)
                : Container(color: Colors.grey[300]),
          ),

          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                Text(receta['nombre'] ?? ''),

                Text("${receta['calorias']} Cal"),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [

                    // ✏️ EDITAR
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () {
                        _editarReceta(context);
                      },
                    ),

                    // 🗑 ELIMINAR
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () {
                        FirebaseFirestore.instance
                            .collection('app-recetas-completas')
                            .doc(docId)
                            .delete();
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _editarReceta(BuildContext context) {
    final nombreCtrl =
        TextEditingController(text: receta['nombre']);
    final caloriasCtrl =
        TextEditingController(text: receta['calorias']);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Editar receta"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nombreCtrl),
            TextField(controller: caloriasCtrl),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('app-recetas-completas')
                  .doc(docId)
                  .update({
                'nombre': nombreCtrl.text,
                'calorias': caloriasCtrl.text,
              });

              Navigator.pop(context);
            },
            child: const Text("Guardar"),
          ),
        ],
      ),
    );
  }
}