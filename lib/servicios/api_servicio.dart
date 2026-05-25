import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static Future<List> getRecetas() async {
    final url = Uri.parse('http://10.0.2.2:3000/recetas');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Error al cargar recetas');
    }
  }
}
