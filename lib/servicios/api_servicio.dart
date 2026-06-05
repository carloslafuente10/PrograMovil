import 'dart:convert';// Permite convertir datos JSON a objetos Dart y viceversa.
import 'package:http/http.dart' as http;// Librería para realizar solicitudes HTTP a servicios o APIs externas.
// Servicio encargado de obtener recetas desde la API.
class ApiService {
  static Future<List> getRecetas() async {
    final url = Uri.parse('http://10.0.2.2:3000/recetas');

    final response = await http.get(url);
  // Genera una excepción cuando la API no responde correctamente.
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al cargar recetas');
    }
  }
}