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

final planilhaUtil = getPlanilhaUtil();

class CadastroUsuarioScreen extends StatefulWidget {
  const CadastroUsuarioScreen({super.key});

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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: kIsWeb ? ['csv'] : ['xlsx'],
    );

    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    Uint8List? fileBytes;

    if (file.bytes != null) {
      fileBytes = file.bytes;
    } else if (file.path != null) {
      fileBytes = await File(file.path!).readAsBytes();
    }

    if (fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Não foi possível ler o arquivo selecionado.')),
      );
      return;
    }

    setState(() => _importando = true);

    try {
      int importados = 0;
      final listaAtual = await ApiService.getUsuarios();
      final usuariosExistentes = List<Map<String, dynamic>>.from(listaAtual);

      final regexEmail = RegExp(r'^[^@]+@[^@]+\.[^@]+$');

      final void Function(String emailErro) exibirErroEmail = (emailErro) {
        final texto = (emailErro.trim().isEmpty || emailErro.toLowerCase() == 'null')
            ? '[sem email]'
            : emailErro;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('⚠️ E-mail inválido: $texto')),
        );
      };

      if (kIsWeb) {
        final content = utf8.decode(fileBytes);
        final rows = const CsvToListConverter(eol: '\n').convert(content);

        final header = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
        if (!(header.contains('nome') && header.contains('email') && header.contains('senha'))) {
          throw Exception('CSV deve conter as colunas: nome, email, senha');
        }

        final nomeIndex = header.indexOf('nome');
        final emailIndex = header.indexOf('email');
        final senhaIndex = header.indexOf('senha');

        for (final row in rows.skip(1)) {
          final nome = row[nomeIndex]?.toString().trim() ?? '';
          final email = row[emailIndex]?.toString().trim() ?? '';
          final senha = row[senhaIndex]?.toString().trim() ?? '';

          if (nome.isEmpty || email.isEmpty || senha.isEmpty) continue;
          if (!regexEmail.hasMatch(email)) {
            exibirErroEmail(email);
            continue;
          }

          final existente = usuariosExistentes.firstWhere(
                (u) => u['email'].toString().toLowerCase() == email.toLowerCase(),
            orElse: () => {},
          );

          if (existente.isEmpty) {
            final novoUsuario = {'nome': nome, 'email': email, 'senha': senha, 'is_admin': 0};
            await ApiService.salvarUsuario(novoUsuario);
            importados++;
          } else {
            final mesmoNome = existente['nome'].toString().trim() == nome;
            final mesmaSenha = existente['senha'].toString().trim() == senha;
            if (!mesmoNome || !mesmaSenha) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('⚠️ Email duplicado com dados diferentes: $email')),
              );
            }
          }
        }
      } else {
        final excel = Excel.decodeBytes(fileBytes);
        if (!excel.tables.containsKey('Usuarios')) {
          throw Exception('Aba "Usuarios" não encontrada');
        }

        final sheet = excel.tables['Usuarios']!;
        final header = sheet.rows.first.map((cell) => cell?.value?.toString().toLowerCase().trim()).toList();

        final nomeIndex = header.indexOf('nome');
        final emailIndex = header.indexOf('email');
        final senhaIndex = header.indexOf('senha');

        for (final row in sheet.rows.skip(1)) {
          final nome = row[nomeIndex]?.value.toString().trim() ?? '';
          final email = row[emailIndex]?.value.toString().trim() ?? '';
          final senha = row[senhaIndex]?.value.toString().trim() ?? '';

          if (nome.isEmpty || email.isEmpty || senha.isEmpty) continue;
          if (!regexEmail.hasMatch(email)) {
            exibirErroEmail(email);
            continue;
          }

          final existente = usuariosExistentes.firstWhere(
                (u) => u['email'].toString().toLowerCase() == email.toLowerCase(),
            orElse: () => {},
          );

          if (existente.isEmpty) {
            final novoUsuario = {'nome': nome, 'email': email, 'senha': senha, 'is_admin': 0};
            await ApiService.salvarUsuario(novoUsuario);
            importados++;
          } else {
            final mesmoNome = existente['nome'].toString().trim() == nome;
            final mesmaSenha = existente['senha'].toString().trim() == senha;
            if (!mesmoNome || !mesmaSenha) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('⚠️ Email duplicado com dados diferentes: $email')),
              );
            }
          }
        }
      }

      if (importados == 0) {
        throw Exception('⚠️ Nenhum usuário novo encontrado para importar.');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Importação concluída com sucesso ($importados usuários)')),
      );
      await carregarUsuarios();
    } catch (e) {
      final erro = e.toString().contains('Nenhum usuário novo')
          ? '⚠️ Nenhum usuário novo para importar.'
          : '❌ Ocorreu um erro ao importar os usuários.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(erro)));
    } finally {
      setState(() => _importando = false);
    }
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
    nomeController.text = u['nome'];
    emailController.text = u['email'];
    senhaController.text = u['senha'];
    editingIndex = index;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Editar Usuário'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nomeController, decoration: const InputDecoration(labelText: 'Nome')),
            TextField(controller: emailController, decoration: const InputDecoration(labelText: 'Email')),
            TextField(controller: senhaController, decoration: const InputDecoration(labelText: 'Senha')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nome = nomeController.text.trim();
              final email = emailController.text.trim();
              final senha = senhaController.text.trim();

              if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('⚠️ Preencha todos os campos.')),
                );
                return;
              }

              final user = {'nome': nome, 'email': email, 'senha': senha};
              final id = u['id'];

              try {
                await ApiService.atualizarUsuario(id, user);
                Navigator.of(context).pop();
                carregarUsuarios();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('✅ Usuário atualizado com sucesso')),
                );
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('❌ Erro ao atualizar o usuário.')),
                );
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
  }

  void excluirUsuario(int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover Usuário'),
        content: const Text('Deseja realmente excluir este usuário?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final id = usuarios[index]['id'];
        final nome = usuarios[index]['nome'];
        await ApiService.excluirUsuario(id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Usuário removido: $nome')),
        );
        carregarUsuarios();
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Erro ao excluir o usuário.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6EDF9),
      body: SingleChildScrollView(
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
