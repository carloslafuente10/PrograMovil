import 'package:flutter/material.dart';

class FavoritosProvider extends InheritedWidget {

  final FavoritosState state;

  const FavoritosProvider({

    super.key,

    required this.state,

    required super.child,

  });

  static FavoritosState of(BuildContext context) {

    final provider =
        context.dependOnInheritedWidgetOfExactType<FavoritosProvider>();

    assert(provider != null);

    return provider!.state;

  }

  @override
  bool updateShouldNotify(FavoritosProvider oldWidget) {

    return true;

  }

}

class FavoritosState extends ChangeNotifier {

  final Map<String, Map<String, String>> _favoritos = {};

  List<Map<String, String>> get lista {

    return _favoritos.values.toList();

  }

  bool esFavorito(String nombre) {

    return _favoritos.containsKey(nombre);

  }

  void toggle(Map<String, String> receta) {

    final nombre = receta['nombre']!;

    if (_favoritos.containsKey(nombre)) {

      _favoritos.remove(nombre);

    } else {

      _favoritos[nombre] = receta;

    }

    notifyListeners();

  }

}