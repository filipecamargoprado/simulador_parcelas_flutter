import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/planilha_util.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import '../utils/theme.dart';
import '../components/app_scaffold.dart';

final planilhaUtil = getPlanilhaUtil();

class CadastroUsuarioScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final bool isAdmin;
  const CadastroUsuarioScreen({super.key, required this.usuario, required this.isAdmin});

  @override
  State<CadastroUsuarioScreen> createState() => _CadastroUsuarioScreenState();
}

class _CadastroUsuarioScreenState extends State<CadastroUsuarioScreen> {
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  final buscaController = TextEditingController();
  bool _importando = false;
  List usuarios = [];
  int? editingIndex;

  @override
  void initState() {
    super.initState();
    buscaController.addListener(_filtrarUsuarios);
    Future.microtask(() => carregarUsuarios());
  }

  Future<void> importarUsuarios() async {
    // (mantém igual como no seu código atual)
  }

  Future<void> carregarUsuarios({String filtro = ''}) async {
    try {
      final todos = await ApiService.getUsuarios();
      setState(() {
        usuarios = filtro.isEmpty
            ? todos
            : todos.where((u) =>
        u['nome'].toString().toLowerCase().contains(filtro.toLowerCase()) ||
            u['email'].toString().toLowerCase().contains(filtro.toLowerCase()))
            .toList();
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Não foi possível carregar os usuários.')),
      );
    }
  }

  void _filtrarUsuarios() {
    carregarUsuarios(filtro: buscaController.text);
  }

  void salvarUsuario() async {
    final nome = nomeController.text.trim();
    final email = emailController.text.trim();
    final senha = senhaController.text.trim();

    if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Preencha todos os campos para salvar.')),
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ E-mail inválido. Verifique o formato.')),
      );
      return;
    }

    if (senha.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ A senha deve ter ao menos 4 caracteres.')),
      );
      return;
    }

    final user = {'nome': nome, 'email': email, 'senha': senha};

    try {
      if (editingIndex != null) {
        final id = usuarios[editingIndex!]['id'];
        await ApiService.atualizarUsuario(id, user);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Usuário atualizado: $nome')),
        );
      } else {
        await ApiService.salvarUsuario(user);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Usuário salvo: $nome')),
        );
      }

      nomeController.clear();
      emailController.clear();
      senhaController.clear();
      editingIndex = null;
      carregarUsuarios();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erro ao salvar o usuário.')),
      );
    }
  }

  void editarUsuario(int index, Map u) {
    // (mantém igual)
  }

  void excluirUsuario(int index) async {
    // (mantém igual)
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Cadastro de Usuário',
      isAdmin: widget.isAdmin,
      usuario: widget.usuario,
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cadastro de Usuário',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nomeController,
                decoration: const InputDecoration(labelText: 'Nome'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: senhaController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Senha'),
              ),
              const SizedBox(height: 12),
              Center(
                child: ElevatedButton(
                  onPressed: salvarUsuario,
                  style: AppButtonStyle.primaryButton,
                  child: const Text('Salvar Usuário'),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: buscaController,
                decoration: const InputDecoration(
                  labelText: 'Buscar Usuário',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Importar Usuários'),
                    onPressed: importarUsuarios,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Exportar Usuários'),
                    onPressed: () async {
                      try {
                        final todos = List<Map<String, dynamic>>.from(usuarios);
                        await planilhaUtil.gerarPlanilhaUsuarios(todos);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Planilha de usuários gerada com sucesso')),
                        );
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('❌ Erro ao gerar a planilha de usuários')),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Usuários Cadastrados', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: usuarios.length,
                itemBuilder: (context, index) {
                  final u = usuarios[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 1,
                    child: ListTile(
                      title: Text('${u['nome']} - ${u['email']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => editarUsuario(index, u)),
                          IconButton(icon: const Icon(Icons.delete), onPressed: () => excluirUsuario(index)),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
