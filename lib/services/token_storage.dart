import 'package:get_storage/get_storage.dart';

class TokenStorage {
  static final _box = GetStorage();

  static void salvarToken(String token) {
    _box.write('token', token);
  }

  static String? pegarToken() {
    return _box.read<String>('token');
  }

  static void removerToken() {
    _box.remove('token');
  }

  static void salvarUsuario(Map<String, dynamic> usuario) {
    _box.write('usuario', usuario);
  }

  static Map<String, dynamic>? pegarUsuario() {
    final dados = _box.read('usuario');
    if (dados != null && dados is Map) {
      return Map<String, dynamic>.from(dados);
    }
    return null;
  }

  static void removerUsuario() {
    _box.remove('usuario');
  }

  static void logout() {
    removerToken();
    removerUsuario();
  }
}
