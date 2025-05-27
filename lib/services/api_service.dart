import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ApiService {
  static final String baseUrl = dotenv.env['API_URL'] ?? 'https://simulador.grupojufap.com.br/';
  static final _box = GetStorage();

  static String? _token;
  static Map<String, dynamic>? usuarioLogado;
  static bool get isAdmin => usuarioLogado?['is_admin'] == 1;

  // 🔥 Inicializa os dados locais
  static Future<void> init() async {
    _token = _box.read('token');
    usuarioLogado = _box.read('usuario');

    print('🗂️ Token carregado: $_token');
    print('👤 Usuário carregado: $usuarioLogado');
  }

  // ✅ TESTE DE CONEXÃO
  static Future<void> testarConexao() async {
    try {
      print('🌐 Testando conexão com $baseUrl');
      final res = await http.get(Uri.parse('$baseUrl/'));
      print('🛰️ Status: ${res.statusCode}');
      print('🛰️ Body: ${res.body}');
    } catch (e) {
      print('🚫 Erro na conexão: $e');
    }
  }

  // 🔗 Headers com token
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // 🔐 Login
  static Future<bool> login(String email, String senha) async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'senha': senha}),
      );

      print('🔑 Response Status: ${res.statusCode}');
      print('🔑 Response Body: ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (data['token'] != null && data['usuario'] != null) {
          _token = data['token'];
          usuarioLogado = {
            'id': data['usuario']['id'],
            'nome': data['usuario']['nome'],
            'email': data['usuario']['email'],
            'is_admin': data['usuario']['is_admin'],
          };

          _box.write('token', _token);
          _box.write('usuario', usuarioLogado);

          print('✅ Login bem-sucedido. Usuário: $usuarioLogado');
          return true;
        } else {
          print('🚫 Dados inválidos no retorno do login');
          return false;
        }
      } else {
        print('🚫 Erro no login: ${res.body}');
        return false;
      }
    } catch (e) {
      print('❌ Erro na requisição de login: $e');
      return false;
    }
  }

  // 🚪 Logout
  static void logout() {
    _token = null;
    usuarioLogado = null;
    _box.remove('token');
    _box.remove('usuario');
    print('🚪 Logout realizado com sucesso');
  }

  // =================== PRODUTOS =====================
  static Future<List> getProdutos() async {
    final res = await http.get(Uri.parse('$baseUrl/produtos'), headers: headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Erro ao carregar produtos');
  }

  static Future<void> salvarProduto(Map<String, dynamic> produto) async {
    final res = await http.post(
      Uri.parse('$baseUrl/produtos'),
      headers: headers,
      body: jsonEncode(produto),
    );
    if (res.statusCode != 201) throw Exception('Erro ao salvar produto');
  }

  static Future<void> atualizarProduto(int id, Map<String, dynamic> produto) async {
    final res = await http.put(
      Uri.parse('$baseUrl/produtos/$id'),
      headers: headers,
      body: jsonEncode(produto),
    );
    if (res.statusCode != 200) throw Exception('Erro ao atualizar produto');
  }

  static Future<void> excluirProduto(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/produtos/$id'),
      headers: headers,
    );
    if (res.statusCode != 200) throw Exception('Erro ao excluir produto');
  }

  // =================== USUÁRIOS =====================
  static Future<List> getUsuarios() async {
    final res = await http.get(Uri.parse('$baseUrl/usuarios'), headers: headers);
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Erro ao carregar usuários');
  }

  static Future<void> salvarUsuario(Map<String, dynamic> usuario) async {
    final res = await http.post(
      Uri.parse('$baseUrl/usuarios'),
      headers: headers,
      body: jsonEncode(usuario),
    );
    if (res.statusCode != 201) throw Exception('Erro ao salvar usuário');
  }

  static Future<void> atualizarUsuario(int id, Map<String, dynamic> usuario) async {
    final res = await http.put(
      Uri.parse('$baseUrl/usuarios/$id'),
      headers: headers,
      body: jsonEncode(usuario),
    );
    if (res.statusCode != 200) throw Exception('Erro ao atualizar usuário');
  }

  static Future<void> excluirUsuario(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/usuarios/$id'),
      headers: headers,
    );
    if (res.statusCode != 200) throw Exception('Erro ao excluir usuário');
  }

  // =================== HISTÓRICO =====================
  static Future<List<Map<String, dynamic>>> getHistoricoSimulacoes() async {
    final res = await http.get(Uri.parse('$baseUrl/historico'), headers: headers);
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    throw Exception('Erro ao buscar histórico');
  }

  static Future<void> salvarSimulacao(Map<String, dynamic> dados) async {
    final res = await http.post(
      Uri.parse('$baseUrl/historico'),
      headers: headers,
      body: jsonEncode(dados),
    );
    if (res.statusCode != 201) throw Exception('Erro ao salvar simulação');
  }

  static Future<void> excluirSimulacao(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/historico/$id'),
      headers: headers,
    );
    if (res.statusCode != 200) throw Exception('Erro ao excluir histórico');
  }
}
