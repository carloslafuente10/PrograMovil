import 'package:flutter/material.dart';
import 'favoritos_provider.dart';
import 'detalle_receta_screen.dart';

class FavoritosScreen extends StatelessWidget {
  const FavoritosScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final favState = FavoritosProvider.of(context);
    final lista = favState.lista;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F5),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 4),
              child: Text(
                'Mis Favoritos',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 16),
              child: Text(
                lista.isEmpty
                    ? 'Aún no tienes recetas guardadas'
                    : '${lista.length} receta${lista.length == 1 ? '' : 's'} guardada${lista.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ),
            Expanded(
              child: lista.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 64,
                            color: Colors.grey[300],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Marca el ❤️ en cualquier receta\npara guardarla aquí',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: lista.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final r = lista[i];
                        return _FavoritoTile(receta: r, favState: favState);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritoTile extends StatelessWidget {
  final Map<String, dynamic> receta;
  final FavoritosState favState;
  const _FavoritoTile({required this.receta, required this.favState});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DetalleRecetaScreen(nombreReceta: receta['nombre']!),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Imagen
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(14),
              ),
              child: (receta['img'] ?? '').isNotEmpty
                  ? Image.network(
                      receta['img']!,
                      width: 90,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _placeholder(),
                    )
                  : _placeholder(),
            ),

            // Datos
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      receta['nombre'] ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          size: 13,
                          color: Colors.orange[400],
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${receta['calorias'] ?? ''} Cal',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.access_time,
                          size: 13,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${receta['tiempo'] ?? ''} Min',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    if ((receta['categoria'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2D9E73).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          receta['categoria'],
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF2D9E73),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // ✅ Basurero en lugar del corazón
            Padding(
              padding: const EdgeInsets.only(right: 14),
              child: GestureDetector(
                onTap: () => _confirmarEliminar(context),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Diálogo de confirmación antes de eliminar
  void _confirmarEliminar(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          '¿Eliminar favorito?',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '¿Quieres quitar "${receta['nombre']}" de tus favoritos?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: Colors.grey[600])),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              favState.toggle(receta);
            },
            child: const Text(
              'Eliminar',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
    width: 90,
    height: 80,
    color: const Color(0xFFE8E8E8),
    child: const Icon(Icons.fastfood, size: 32, color: Colors.white70),
  );
}
