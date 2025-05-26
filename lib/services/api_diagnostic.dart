import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class ApiDiagnostic {
  static final String baseUrl = dotenv.env['API_URL'] ?? 'http://127.0.0.1:3000';

  static Future<void> testarAPI() async {
    print('🛠️ Iniciando diagnóstico da API...');
    print('🔗 Base URL: $baseUrl');

    await testarConexao();
    await testarLogin();
    await testarUsuarios();
  }

  static Future<void> testarConexao() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/'));
      print('🌐 Teste conexão / → Status: ${res.statusCode}');
      print('Resposta: ${res.body}');
    } catch (e) {
      print('🚫 Erro na conexão com / → $e');
    }
  }

  static Future<void> testarLogin() async {
    try {
      final res = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': 'filipe@jufap.com.br', // 🔥 Substitua se necessário
          'senha': '123456'               // 🔥 Substitua se necessário
        }),
      );
      print('🔑 Teste login → Status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final token = data['token'];
        print('✅ Login bem-sucedido, Token: $token');
        return token;
      } else {
        print('❌ Falha no login → ${res.body}');
      }
    } catch (e) {
      print('🚫 Erro no login → $e');
    }
  }

  static Future<void> testarUsuarios() async {
    try {
      final loginRes = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': 'filipe@jufap.com.br', // 🔥 Seu email
          'senha': '123456'               // 🔥 Sua senha
        }),
      );

      if (loginRes.statusCode == 200) {
        final data = jsonDecode(loginRes.body);
        final token = data['token'];

        final usuariosRes = await http.get(
          Uri.parse('$baseUrl/usuarios'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        print('👥 Teste /usuarios → Status: ${usuariosRes.statusCode}');
        if (usuariosRes.statusCode == 200) {
          print('✅ Usuários: ${usuariosRes.body}');
        } else {
          print('❌ Erro ao acessar /usuarios → ${usuariosRes.body}');
        }
      } else {
        print('❌ Não foi possível fazer login para testar /usuarios');
      }
    } catch (e) {
      print('🚫 Erro em /usuarios → $e');
    }
  }
}