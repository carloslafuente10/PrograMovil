import 'package:flutter/material.dart';
import 'favoritos_provider.dart';
import 'detalle_receta_screen.dart';

class FavoritosScreen extends StatelessWidget {
  const FavoritosScreen({super.key});

  static const Color _verde = Color(0xFF2D9E73);

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
            // Encabezado
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 24, 20, 4),
              child: Text(
                'Mis Favoritos',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 16),
              child: Text(
                lista.isEmpty ? 'Aún no tienes recetas guardadas' : '${lista.length} receta${lista.length == 1 ? '' : 's'} guardada${lista.length == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
            ),

            // Lista o estado vacío
            Expanded(
              child: lista.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.favorite_border, size: 64, color: Colors.grey[300]),
                          const SizedBox(height: 12),
                          Text('Marca el ❤️ en cualquier receta\npara guardarla aquí',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey[400], fontSize: 14, height: 1.6)),
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
  final Map<String, String> receta;
  final FavoritosState favState;
  const _FavoritoTile({required this.receta, required this.favState});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetalleRecetaScreen(nombreReceta: receta['nombre']!)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            // Imagen
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(14)),
              child: Image.asset(
                receta['img']!,
                width: 90, height: 80, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 90, height: 80, color: const Color(0xFFE8E8E8),
                  child: const Icon(Icons.fastfood, size: 32, color: Colors.white70),
                ),
              ),
            ),
            // Datos
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(receta['nombre']!,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.local_fire_department, size: 13, color: Colors.orange[400]),
                        const SizedBox(width: 3),
                        Text('${receta['calorias']} Cal', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                        const SizedBox(width: 12),
                        Icon(Icons.access_time, size: 13, color: Colors.grey[400]),
                        const SizedBox(width: 3),
                        Text('${receta['tiempo']} Min', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D9E73).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(receta['categoria'] ?? '',
                          style: const TextStyle(fontSize: 10, color: Color(0xFF2D9E73), fontWeight: FontWeight.w500)),
                    ),
                  ],
                ),
              ),
            ),
            // Botón quitar favorito
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: GestureDetector(
                onTap: () => favState.toggle(receta),
                child: const Icon(Icons.favorite, color: Colors.red, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}