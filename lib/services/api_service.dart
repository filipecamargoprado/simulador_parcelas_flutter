import 'dart:convert';
import 'dart:developer';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Serviço responsável por se comunicar com a API da Jufap.
class ApiService {
  // 🔗 Links para ambientes locais e produção
  static const String _mobileUrl = 'http://10.0.2.2:3000';
  static const String _webUrl = 'http://localhost:3000';
  static const String _desktopUrl = 'http://127.0.0.1:3000';
  static const String _productionUrl = 'https://apijufap-production.up.railway.app';

  /// 🧠 Define se vai rodar local ou produção
  static bool isProduction = true; // true = Railway | false = Local

  /// 🔗 Retorna a URL base da API
  static String get baseUrl {
    if (isProduction) return _productionUrl;
    if (kIsWeb) return _webUrl;
    if (Platform.isAndroid) return _mobileUrl;
    return _desktopUrl;
  }

  // =============================================================
  // ======================= PRODUTOS ============================
  // =============================================================

  static Future<List> getProdutos() async {
    final res = await http.get(Uri.parse('$baseUrl/produtos'));
    log('📡 GET /produtos → ${res.statusCode}');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Erro ao carregar produtos: ${res.body}');
  }

  static Future<void> salvarProduto(Map<String, dynamic> produto) async {
    log('🔄 POST /produtos: $produto');
    final res = await http.post(
      Uri.parse('$baseUrl/produtos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(produto),
    );
    log('📥 Resposta salvarProduto: ${res.statusCode} → ${res.body}');
    if (res.statusCode != 201) {
      throw Exception('Erro ao salvar produto: ${res.body}');
    }
  }

  static Future<void> atualizarProduto(int id, Map<String, dynamic> produto) async {
    log('✏️ PUT /produtos/$id: $produto');
    final res = await http.put(
      Uri.parse('$baseUrl/produtos/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(produto),
    );
    log('📥 Resposta atualizarProduto: ${res.statusCode} → ${res.body}');
    if (res.statusCode != 200) {
      throw Exception('Erro ao atualizar produto: ${res.body}');
    }
  }

  static Future<void> excluirProduto(int id) async {
    log('🗑 DELETE /produtos/$id');
    final res = await http.delete(Uri.parse('$baseUrl/produtos/$id'));
    log('📥 Resposta excluirProduto: ${res.statusCode} → ${res.body}');
    if (res.statusCode != 200) {
      throw Exception('Erro ao excluir produto: ${res.body}');
    }
  }

  // =============================================================
  // ======================= USUÁRIOS ============================
  // =============================================================

  static Future<List> getUsuarios() async {
    final res = await http.get(Uri.parse('$baseUrl/usuarios'));
    log('📡 GET /usuarios → ${res.statusCode}');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Erro ao carregar usuários: ${res.body}');
  }

  static Future<void> salvarUsuario(Map<String, dynamic> usuario) async {
    log('🔄 POST /usuarios: $usuario');
    final res = await http.post(
      Uri.parse('$baseUrl/usuarios'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(usuario),
    );
    log('📥 Resposta salvarUsuario: ${res.statusCode} → ${res.body}');
    if (res.statusCode != 201) {
      throw Exception('Erro ao salvar usuário: ${res.body}');
    }
  }

  static Future<void> atualizarUsuario(int id, Map<String, dynamic> usuario) async {
    log('✏️ PUT /usuarios/$id: $usuario');
    final res = await http.put(
      Uri.parse('$baseUrl/usuarios/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(usuario),
    );
    log('📥 Resposta atualizarUsuario: ${res.statusCode} → ${res.body}');
    if (res.statusCode != 200) {
      throw Exception('Erro ao atualizar usuário: ${res.body}');
    }
  }

  static Future<void> excluirUsuario(int id) async {
    log('🗑 DELETE /usuarios/$id');
    final res = await http.delete(Uri.parse('$baseUrl/usuarios/$id'));
    log('📥 Resposta excluirUsuario: ${res.statusCode} → ${res.body}');
    if (res.statusCode != 200) {
      throw Exception('Erro ao excluir usuário: ${res.body}');
    }
  }

  static Future<bool> login(String email, String senha) async {
    log('🔐 POST /login → email: $email');
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'senha': senha}),
    );
    log('📥 Resposta login: ${res.statusCode} → ${res.body}');
    return res.statusCode == 200;
  }

  // =============================================================
  // ================== HISTÓRICO DE SIMULAÇÕES ==================
  // =============================================================

  static Future<void> salvarSimulacao(Map<String, dynamic> dados) async {
    log('🔄 POST /historico: $dados');
    final res = await http.post(
      Uri.parse('$baseUrl/historico'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dados),
    );
    log('📥 Resposta salvarSimulacao: ${res.statusCode} → ${res.body}');
    if (res.statusCode != 201) {
      throw Exception('Erro ao salvar simulação: ${res.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> getHistoricoSimulacoes() async {
    final res = await http.get(Uri.parse('$baseUrl/historico'));
    log('📡 GET /historico → ${res.statusCode}');
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    throw Exception('Erro ao buscar histórico: ${res.body}');
  }

  static Future<void> excluirSimulacao(int id) async {
    log('🗑 DELETE /historico/$id');
    final res = await http.delete(Uri.parse('$baseUrl/historico/$id'));
    log('📥 Resposta excluirSimulacao: ${res.statusCode} → ${res.body}');
    if (res.statusCode != 200) {
      throw Exception('Erro ao excluir histórico: ${res.body}');
    }
  }

  static Future<void> atualizarSimulacao(int id, Map<String, dynamic> dados) async {
    log('✏️ PUT /historico/$id: $dados');
    final res = await http.put(
      Uri.parse('$baseUrl/historico/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(dados),
    );
    log('📥 Resposta atualizarSimulacao: ${res.statusCode} → ${res.body}');
    if (res.statusCode != 200) {
      throw Exception('Erro ao atualizar histórico: ${res.body}');
    }
  }
}