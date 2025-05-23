import 'dart:convert';
import 'dart:developer';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static final String baseUrl = dotenv.env['API_URL'] ?? 'https://grupojufap.com.br';

  static Map<String, String> get headers => {'Content-Type': 'application/json'};

  // ======================= PRODUTOS ============================
  static Future<List> getProdutos() async {
    final res = await http.get(Uri.parse('$baseUrl/produtos'), headers: headers);
    log('📡 GET /produtos → ${res.statusCode}');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Erro ao carregar produtos: ${res.body}');
  }

  static Future<void> salvarProduto(Map<String, dynamic> produto) async {
    log('🔄 POST /produtos: $produto');
    final res = await http.post(
      Uri.parse('$baseUrl/produtos'),
      headers: headers,
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
      headers: headers,
      body: jsonEncode(produto),
    );
    log('📥 Resposta atualizarProduto: ${res.statusCode} → ${res.body}');
    if (res.statusCode != 200) {
      throw Exception('Erro ao atualizar produto: ${res.body}');
    }
  }

  static Future<void> excluirProduto(int id) async {
    log('🗑 DELETE /produtos/$id');
    final res = await http.delete(Uri.parse('$baseUrl/produtos/$id'), headers: headers);
    log('📥 Resposta excluirProduto: ${res.statusCode} → ${res.body}');
    if (res.statusCode != 200) {
      throw Exception('Erro ao excluir produto: ${res.body}');
    }
  }

  // ======================= USUÁRIOS ============================
  static Future<List> getUsuarios() async {
    final res = await http.get(Uri.parse('$baseUrl/usuarios'), headers: headers);
    log('📡 GET /usuarios → ${res.statusCode}');
    if (res.statusCode == 200) return jsonDecode(res.body);
    throw Exception('Erro ao carregar usuários: ${res.body}');
  }

  static Future<void> salvarUsuario(Map<String, dynamic> usuario) async {
    log('🔄 POST /usuarios: $usuario');
    final res = await http.post(
      Uri.parse('$baseUrl/usuarios'),
      headers: headers,
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
      headers: headers,
      body: jsonEncode(usuario),
    );
    log('📥 Resposta atualizarUsuario: ${res.statusCode} → ${res.body}');
    if (res.statusCode != 200) {
      throw Exception('Erro ao atualizar usuário: ${res.body}');
    }
  }

  static Future<void> excluirUsuario(int id) async {
    log('🗑 DELETE /usuarios/$id');
    final res = await http.delete(Uri.parse('$baseUrl/usuarios/$id'), headers: headers);
    log('📥 Resposta excluirUsuario: ${res.statusCode} → ${res.body}');
    if (res.statusCode != 200) {
      throw Exception('Erro ao excluir usuário: ${res.body}');
    }
  }

  static Future<bool> login(String email, String senha) async {
    log('🔐 POST /login → email: $email');
    final res = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: headers,
      body: jsonEncode({'email': email, 'senha': senha}),
    );
    log('📥 Resposta login: ${res.statusCode} → ${res.body}');
    return res.statusCode == 200;
  }

  // ================== HISTÓRICO DE SIMULAÇÕES ==================
  static Future<void> salvarSimulacao(Map<String, dynamic> dados) async {
    log('🔄 POST /historico: $dados');
    final res = await http.post(
      Uri.parse('$baseUrl/historico'),
      headers: headers,
      body: jsonEncode(dados),
    );
    log('📥 Resposta salvarSimulacao: ${res.statusCode} → ${res.body}');
    if (res.statusCode != 201) {
      throw Exception('Erro ao salvar simulação: ${res.body}');
    }
  }

  static Future<List<Map<String, dynamic>>> getHistoricoSimulacoes() async {
    final res = await http.get(Uri.parse('$baseUrl/historico'), headers: headers);
    log('📡 GET /historico → ${res.statusCode}');
    if (res.statusCode == 200) {
      return List<Map<String, dynamic>>.from(jsonDecode(res.body));
    }
    throw Exception('Erro ao buscar histórico: ${res.body}');
  }

  static Future<void> excluirSimulacao(int id) async {
    log('🗑 DELETE /historico/$id');
    final res = await http.delete(Uri.parse('$baseUrl/historico/$id'), headers: headers);
    log('📥 Resposta excluirSimulacao: ${res.statusCode} → ${res.body}');
    if (res.statusCode != 200) {
      throw Exception('Erro ao excluir histórico: ${res.body}');
    }
  }

  static Future<void> atualizarSimulacao(int id, Map<String, dynamic> dados) async {
    log('✏️ PUT /historico/$id: $dados');
    final res = await http.put(
      Uri.parse('$baseUrl/historico/$id'),
      headers: headers,
      body: jsonEncode(dados),
    );
    log('📥 Resposta atualizarSimulacao: ${res.statusCode} → ${res.body}');
    if (res.statusCode != 200) {
      throw Exception('Erro ao atualizar histórico: ${res.body}');
    }
  }
}