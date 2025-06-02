import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';

class ApiService {
  static final String baseUrl = dotenv.env['API_URL'] ?? 'https://simulador.grupojufap.com.br/';
  static final _box = GetStorage();

  static String? _token;
  static Map<String, dynamic>? usuarioLogado;

  static bool get isAdmin => usuarioLogado?['is_admin'] == 1;
  static bool get isLogado => _token != null && usuarioLogado != null;
  static bool get precisaAlterarSenha => usuarioLogado?['precisa_alterar_senha'] == 1;

  static final Dio dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
  );

  // 🔥 Inicializa dados locais
  static Future<void> init() async {
    _token = _box.read('token');
    usuarioLogado = _box.read('usuario');
    dio.options.headers['Authorization'] = _token != null ? 'Bearer $_token' : null;
    print('🗂️ Token carregado: $_token');
    print('👤 Usuário carregado: $usuarioLogado');
    print('🌐 API_URL: $baseUrl');
  }

  // 🔗 Headers
  static Map<String, String> get headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ✅ Teste de conexão
  static Future<void> testarConexao() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/'));
      print('🛰️ Status: ${res.statusCode}');
      print('🛰️ Body: ${res.body}');
    } catch (e) {
      print('🚫 Erro na conexão: $e');
    }
  }

  // 🔐 Login
  static Future<bool> login(String email, String senha) async {
    try {
      await logout();

      final res = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'senha': senha}),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (data['token'] != null && data['usuario'] != null) {
          _token = data['token'];
          usuarioLogado = {
            'id': data['usuario']['id'],
            'nome': data['usuario']['nome'],
            'email': data['usuario']['email'],
            'is_admin': data['usuario']['is_admin'],
            'precisa_alterar_senha': data['usuario']['precisa_alterar_senha'] ?? 0,
          };

          await _salvarLocal();
          dio.options.headers['Authorization'] = 'Bearer $_token';
          return true;
        }
      }

      return false;
    } catch (e) {
      print('🚫 Erro no login: $e');
      return false;
    }
  }

  // 🚪 Logout
  static Future<void> logout() async {
    _token = null;
    usuarioLogado = null;
    await _box.erase();
    dio.options.headers.remove('Authorization');
    print('🚪 Logout realizado com sucesso');
  }

  // 💾 Salvar no Storage
  static Future<void> _salvarLocal() async {
    await _box.write('token', _token);
    await _box.write('usuario', usuarioLogado);
  }

  // =================== PRODUTOS =====================
  static Future<List> getProdutos() async {
    final url = Uri.parse('$baseUrl/historico');
    print('🔗 URL: $url');
    print('🪪 Headers: $headers');
    final res = await http.get(Uri.parse('$baseUrl/produtos'), headers: headers);
    print('🔁 Status: ${res.statusCode}');
    print('📦 Body: ${res.body}');
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
    final url = Uri.parse('$baseUrl/historico');
    print('🔗 URL: $url');
    print('🪪 Headers: $headers');
    final res = await http.get(Uri.parse('$baseUrl/usuarios'), headers: headers);
    print('🔁 Status: ${res.statusCode}');
    print('📦 Body: ${res.body}');
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

  // 🔑 Alterar Senha
  static Future<bool> alterarSenha({
    required int id,
    required String senhaAtual,
    required String novaSenha,
  }) async {
    try {
      final response = await dio.post('/usuarios/alterar_senha', data: {
        'id': id,
        'senha_atual': senhaAtual,
        'nova_senha': novaSenha,
      });

      if (response.statusCode == 200) {
        usuarioLogado?['precisa_alterar_senha'] = 0;
        await _salvarLocal();
        return true;
      }

      return false;
    } catch (e) {
      print('Erro ao alterar senha: $e');
      return false;
    }
  }

  // =================== HISTÓRICO =====================
  static Future<List<Map<String, dynamic>>> getHistoricoSimulacoes() async {
    final url = Uri.parse('$baseUrl/historico');
    print('🔗 URL: $url');
    print('🪪 Headers: $headers');
    final res = await http.get(Uri.parse('$baseUrl/historico'), headers: headers);
    print('🔁 Status: ${res.statusCode}');
    print('📦 Body: ${res.body}');
    if (res.statusCode == 200) {
      try {
        final dados = List<Map<String, dynamic>>.from(jsonDecode(res.body));
        dados.sort((a, b) => b['id'].compareTo(a['id']));
        return dados;
      } catch (e) {
        print('Erro no decode do histórico: $e');
        throw Exception('Erro ao decodificar histórico');
      }
    }
    throw Exception('Erro ao buscar histórico');
  }

  static Future<void> salvarSimulacao(Map<String, dynamic> dados) async {
    final res = await http.post(
      Uri.parse('$baseUrl/historico'),
      headers: headers,
      body: jsonEncode(dados),
    );

    if (res.statusCode != 201) {
      String mensagemErro = 'Erro ao salvar simulação';

      try {
        final corpo = jsonDecode(res.body);
        if (corpo is Map && corpo['erro'] != null) {
          mensagemErro = corpo['erro'].toString();
        } else if (corpo['mensagem'] != null) {
          mensagemErro = corpo['mensagem'].toString();
        }
      } catch (_) {
        print('⚠️ Erro ao interpretar resposta de erro do backend');
      }

      print('❌ Backend respondeu com erro: $mensagemErro');
      throw Exception(mensagemErro);
    }
  }

  static Future<void> atualizarSimulacao(int id, Map<String, dynamic> dados) async {
    final res = await http.put(
      Uri.parse('$baseUrl/historico/$id'),
      headers: headers,
      body: jsonEncode(dados),
    );

    if (res.statusCode != 200) {
      String mensagemErro = 'Erro ao atualizar simulação';

      try {
        final corpo = jsonDecode(res.body);
        if (corpo is Map && corpo['erro'] != null) {
          mensagemErro = corpo['erro'].toString();
        } else if (corpo['mensagem'] != null) {
          mensagemErro = corpo['mensagem'].toString();
        }
      } catch (_) {
        print('⚠️ Erro ao interpretar resposta de erro do backend');
      }

      print('❌ Backend respondeu com erro: $mensagemErro');
      throw Exception(mensagemErro);
    }
  }

  static Future<void> excluirSimulacao(int id) async {
    final res = await http.delete(
      Uri.parse('$baseUrl/historico/$id'),
      headers: headers,
    );
    if (res.statusCode != 200) throw Exception('Erro ao excluir histórico');
  }

  // =================== EXPORTAÇÃO =====================
  static Future<List<Map<String, dynamic>>> exportarHistorico() async {
    final res = await http.get(Uri.parse('$baseUrl/historico'), headers: headers);
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    throw Exception('Erro ao exportar histórico');
  }

  static Future<void> importarHistorico(List<Map<String, dynamic>> dados) async {
    for (var item in dados) {
      await salvarSimulacao(item);
    }
  }
}