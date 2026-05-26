import 'package:flutter/material.dart';
import '../favoritos_provider.dart';


class RecetaCardWidget extends StatelessWidget {
 final Map<String, dynamic> receta;
 final Color verde;
 final double? porcentajeMatch;


 const RecetaCardWidget({
   super.key,
   required this.receta,
   required this.verde,
   this.porcentajeMatch,
 });


 @override
 Widget build(BuildContext context) {
   final favState = FavoritosProvider.of(context);
   final String nombre = receta['nombre']?.toString() ?? '';
   final esFav = favState.esFavorito(nombre);
   final String img = receta['img']?.toString() ?? '';
   final bool esNetwork = img.startsWith('http');


   return Container(
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
     child: Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         // ── IMAGEN Y BOTÓN FAVORITO ──
         Stack(
           children: [
             ClipRRect(
               borderRadius: const BorderRadius.vertical(
                 top: Radius.circular(14),
               ),
               child: img.isNotEmpty
                   ? (esNetwork
                         ? Image.network(
                             img,
                             height: 100,
                             width: double.infinity,
                             fit: BoxFit.cover,
                             errorBuilder: (_, __, ___) => _placeholder(),
                           )
                         : Image.asset(
                             img,
                             height: 100,
                             width: double.infinity,
                             fit: BoxFit.cover,
                             errorBuilder: (_, __, ___) => _placeholder(),
                           ))
                   : _placeholder(),
             ),
             Positioned(
               top: 8,
               right: 8,
               child: GestureDetector(
                 onTap: () => favState.toggle(receta.cast<String, String>()),
                 child: Container(
                   width: 28,
                   height: 28,
                   decoration: const BoxDecoration(
                     color: Colors.white,
                     shape: BoxShape.circle,
                   ),
                   child: Icon(
                     esFav ? Icons.favorite : Icons.favorite_border,
                     size: 16,
                     color: esFav ? Colors.red : Colors.grey,
                   ),
                 ),
               ),
             ),
           ],
         ),


         // ── DETALLES Y PORCENTAJE ──
         Expanded(
           child: Padding(
             padding: const EdgeInsets.all(10),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(
                   nombre,
                   style: const TextStyle(
                     fontSize: 13,
                     fontWeight: FontWeight.w700,
                     color: Color(0xFF1A1A1A),
                   ),
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                 ),
                 Row(
                   children: [
                     Icon(
                       Icons.local_fire_department,
                       size: 12,
                       color: Colors.orange[400],
                     ),
                     const SizedBox(width: 2),
                     Text(
                       '${receta['calorias']} Cal',
                       style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                     ),
                     const SizedBox(width: 8),
                     Icon(
                       Icons.access_time,
                       size: 12,
                       color: Colors.grey[400],
                     ),
                     const SizedBox(width: 2),
                     Text(
                       '${receta['tiempo']} Min',
                       style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                     ),
                   ],
                 ),
                 // Si viene del chat, mostramos el % de coincidencia
                 // Si viene del chat, mostramos el % de coincidencia con su aclaración
                 if (porcentajeMatch != null) ...[
                   const SizedBox(height: 6),
                   // Micro-copy para aclarar de qué es el porcentaje sin romper el diseño
                   Text(
                     'COINCIDENCIA',
                     style: TextStyle(
                       fontSize: 9,
                       fontWeight: FontWeight.bold,
                       // Cambiamos el gris por tu variable verde
                       color: verde.withOpacity(0.8),
                       letterSpacing: 0.5,
                     ),
                   ),
                   const SizedBox(height: 2),
                   Row(
                     children: [
                       Expanded(
                         child: ClipRRect(
                           borderRadius: BorderRadius.circular(4),
                           child: LinearProgressIndicator(
                             value: porcentajeMatch! / 100,
                             minHeight: 5,
                             backgroundColor: verde.withOpacity(0.15),
                             valueColor: AlwaysStoppedAnimation<Color>(verde),
                           ),
                         ),
                       ),
                       const SizedBox(width: 6),
                       Text(
                         '${porcentajeMatch!.toInt()}%',
                         style: TextStyle(
                           fontSize: 11,
                           fontWeight: FontWeight.w800,
                           color: verde,
                         ),
                       ),
                     ],
                   ),
                 ],
               ],
             ),
           ),
         ),
       ],
     ),
   );
 }


 Widget _placeholder() {
   return Container(
     height: 100,
     width: double.infinity,
     color: const Color(0xFFE8E8E8),
     child: const Icon(Icons.fastfood, size: 40, color: Colors.white70),
   );
 }
}