import 'dart:convert';
import 'package:get_storage/get_storage.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

class ApiService {
  static final String baseUrl = dotenv.env['API_URL'] ?? 'https://simulador.grupojufap.com.br/';
  static final _box = GetStorage();

  static String? _token;
  static final ValueNotifier<Map<String, dynamic>?> usuarioLogadoNotifier = ValueNotifier(null);

  static Map<String, dynamic>? get usuarioLogado => usuarioLogadoNotifier.value;

  static set usuarioLogado(Map<String, dynamic>? value) {
    usuarioLogadoNotifier.value = value;
    _box.write('usuario', value);
  }

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

  static bool get isAdmin {
    final u = usuarioLogadoNotifier.value;
    return u?['is_admin'] == 1 || u?['is_super_admin'] == 1;
  }

  static bool get isSuperAdmin {
    final u = usuarioLogadoNotifier.value;
    return u?['is_super_admin'] == 1;
  }

  //recarrega os dados do usuário a qualquer momento
  static Future<void> atualizarDadosUsuarioLogado() async {
    try {
      final res = await http.get(
        Uri.parse('$baseUrl/usuario-logado'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        usuarioLogado = Map<String, dynamic>.from(json.decode(res.body));
      }
    } catch (e) {
      print('Erro ao atualizar usuário logado: $e');
    }
  }

  // 🔥 Inicializa dados locais
  static Future<void> init() async {
    _token = _box.read('token');

    final usuarioLido = _box.read('usuario');
    if (usuarioLido is Map<String, dynamic>) {
      usuarioLogadoNotifier.value = Map<String, dynamic>.from(usuarioLido);
    } else {
      usuarioLogadoNotifier.value = null;
    }

    dio.options.headers['Authorization'] = _token != null ? 'Bearer $_token' : null;
    dio.interceptors.add(InterceptorsWrapper(
      onError: (DioError e, ErrorInterceptorHandler handler) async {
        if (e.response?.statusCode == 401) {
          print('⚠️ Token expirado ou inválido, forçando logout.');
          await logout();
        }
        return handler.next(e);
      },
    ));


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

      final url = Uri.parse('$baseUrl/login');
      print('📲 Enviando login para $url');
      print('📨 Email: $email | Senha: $senha');

      final res = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'senha': senha}),
      );

      print('📡 Status: ${res.statusCode}');
      print('📥 Body: ${res.body}');

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);

        if (data['token'] != null && data['usuario'] != null) {
          _token = data['token'];
          //usuarioLogadoNotifier.value = {
           //'id': data['usuario']['id'],
            //'nome': data['usuario']['nome'],
            //'email': data['usuario']['email'],
            //'is_admin': data['usuario']['is_admin'],
            //'is_super_admin': data['usuario']['is_super_admin'],
            //'precisa_alterar_senha': data['usuario']['precisa_alterar_senha'] ?? 0,
          //};
          await atualizarDadosUsuarioLogado();


          await _salvarLocal();
          dio.options.headers['Authorization'] = 'Bearer $_token';
          await atualizarDadosUsuarioLogado();
          return true;
        }
      } else {
        // Caso tenha erro (como email/senha inválido), mostrar no terminal
        print('❌ Erro ao fazer login: ${res.body}');
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
    usuarioLogadoNotifier.value = null;
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
  static Future<List<dynamic>> getUsuarios({int pagina = 1, int limite = 50}) async {
    final res = await http.get(
      Uri.parse('$baseUrl/usuarios?pagina=$pagina&limite=$limite'),
      headers: headers,
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    } else {
      throw Exception('Erro ao carregar usuários');
    }
  }

  static Future<void> salvarUsuario(Map<String, dynamic> usuario) async {
    final res = await http.post(
      Uri.parse('$baseUrl/usuarios'),
      headers: headers,
      body: jsonEncode({
        'nome': usuario['nome'],
        'email': usuario['email'],
        'senha': usuario['senha'],
        'is_admin': usuario['is_admin'],
        'is_super_admin': usuario['is_super_admin'] ?? 0,
      }),
    );
    if (res.statusCode != 201) throw Exception('Erro ao salvar usuário');
  }

  static Future<void> atualizarUsuario(int id, Map<String, dynamic> usuario) async {
    final res = await http.put(
      Uri.parse('$baseUrl/usuarios/$id'),
      headers: headers,
      body: jsonEncode({
        'nome': usuario['nome'],
        'email': usuario['email'],
        'senha': usuario['senha'], // pode ser null ou vazio
        'is_admin': usuario['is_admin'],
        'is_super_admin': usuario['is_super_admin'] ?? 0,
        'precisa_alterar_senha': usuario['precisa_alterar_senha'] ?? 0,
      }),
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