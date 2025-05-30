import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../components/app_scaffold.dart';
import '../utils/theme.dart';

class CadastroUsuarioScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final bool isAdmin;

  const CadastroUsuarioScreen({
    super.key,
    required this.usuario,
    required this.isAdmin,
  });

  @override
  State<CadastroUsuarioScreen> createState() => _CadastroUsuarioScreenState();
}

class _CadastroUsuarioScreenState extends State<CadastroUsuarioScreen> {
  final buscaController = TextEditingController();
  List usuarios = [];
  List usuariosOriginais = [];
  List<bool> selecionados = [];
  bool modoExportacao = false;
  bool todosSelecionados = false;

  @override
  void initState() {
    super.initState();
    buscaController.addListener(_filtrarUsuarios);
    Future.microtask(() => carregarUsuarios());
  }

  Future<void> carregarUsuarios() async {
    try {
      final todos = await ApiService.getUsuarios();
      setState(() {
        usuarios = todos;
        usuariosOriginais = todos;
        selecionados = List<bool>.filled(todos.length, false);
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erro ao carregar usuários.')),
      );
    }
  }

  void _filtrarUsuarios() {
    final query = buscaController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        usuarios = List.from(usuariosOriginais);
      } else {
        usuarios = usuariosOriginais.where((u) {
          final nome = u['nome'].toString().toLowerCase();
          final email = u['email'].toString().toLowerCase();
          return nome.contains(query) || email.contains(query);
        }).toList();
      }
      selecionados = List<bool>.filled(usuarios.length, false);
      todosSelecionados = false;
    });
  }

  void toggleModoExportacao() {
    setState(() {
      modoExportacao = !modoExportacao;
      selecionados = List<bool>.filled(usuarios.length, false);
      todosSelecionados = false;
    });
  }

  void toggleSelecionarTodos(bool? value) {
    setState(() {
      todosSelecionados = value ?? false;
      selecionados = List<bool>.filled(usuarios.length, todosSelecionados);
    });
  }

  Future<void> exportarSelecionados() async {
    final selecionadosIndices = selecionados
        .asMap()
        .entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selecionadosIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Nenhum usuário selecionado para exportação')),
      );
      return;
    }

    final excel = Excel.createExcel();
    const sheetName = 'Usuários';
    final sheet = excel[sheetName];

    sheet.appendRow([
      TextCellValue('Nome'),
      TextCellValue('Email'),
      TextCellValue('Admin (1=Sim, 0=Não)'),
    ]);

    for (var index in selecionadosIndices) {
      final u = usuarios[index];
      sheet.appendRow([
        TextCellValue(u['nome'] ?? ''),
        TextCellValue(u['email'] ?? ''),
        TextCellValue((u['is_admin'] == 1 || u['is_admin'] == true) ? '1' : '0'),
      ]);
    }

    // Remove abas extras
    final sheetsToRemove = excel.sheets.keys.where((name) => name != sheetName).toList();
    for (final name in sheetsToRemove) {
      excel.delete(name);
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/usuarios.xlsx');
    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Exportação concluída com sucesso')),
    );

    toggleModoExportacao();
  }

  Future<void> importarUsuarios() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result != null) {
      try {
        final fileBytes = result.files.single.bytes;
        final filePath = result.files.single.path;

        if (fileBytes == null && filePath == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Erro ao ler o arquivo')),
          );
          return;
        }

        final bytes = fileBytes ?? await File(filePath!).readAsBytes();
        final excel = Excel.decodeBytes(bytes);

        final sheet = excel.tables['Usuários'];
        if (sheet == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Aba "Usuários" não encontrada no arquivo')),
          );
          return;
        }

        int atualizados = 0;
        int inseridos = 0;
        List<String> erros = [];

        for (var row in sheet.rows.skip(1)) {
          final nome = row[0]?.value.toString().trim() ?? '';
          final email = row[1]?.value.toString().trim() ?? '';
          final adminValue = row.length > 2 ? row[2]?.value.toString().trim() : '0';
          final isAdmin = adminValue == '1';
          final senha = '123456'; // Senha padrão

          if (nome.isEmpty || email.isEmpty) {
            erros.add('Linha com dados incompletos: Nome: $nome, Email: $email');
            continue;
          }

          if (!email.contains('@') || !email.contains('.')) {
            erros.add('Email inválido: $email');
            continue;
          }

          try {
            final existente = usuariosOriginais.firstWhere(
                  (u) => u['email'].toString().toLowerCase() == email.toLowerCase(),
              orElse: () => {},
            );

            if (existente.isNotEmpty) {
              final id = existente['id'];
              await ApiService.atualizarUsuario(id, {
                'nome': nome,
                'email': email,
                'is_admin': isAdmin ? 1 : 0,
                'senha': senha,
              });
              atualizados++;
            } else {
              await ApiService.salvarUsuario({
                'nome': nome,
                'email': email,
                'is_admin': isAdmin ? 1 : 0,
                'senha': senha,
              });
              inseridos++;
            }
          } catch (e) {
            erros.add('Erro ao processar $email');
          }
        }

        await carregarUsuarios();

        String resumo = '✅ Importação concluída. '
            'Inseridos: $inseridos, Atualizados: $atualizados.';
        if (erros.isNotEmpty) {
          resumo += '\nErros:\n${erros.join('\n')}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(resumo)),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Erro ao processar o arquivo')),
        );
      }
    }
  }

  void editarUsuario(Map<String, dynamic> usuario) async {
    final nomeController = TextEditingController(text: usuario['nome']);
    final emailController = TextEditingController(text: usuario['email']);
    final senhaController = TextEditingController();
    bool isAdmin = usuario['is_admin'] == 1 || usuario['is_admin'] == true;

    bool nomeInvalido = false;
    bool emailInvalido = false;
    bool senhaInvalida = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Editar Usuário'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nomeController,
                    decoration: InputDecoration(
                      labelText: 'Nome',
                      errorText: nomeInvalido ? 'Preencha o nome' : null,
                    ),
                    onSubmitted: (_) {
                      FocusScope.of(context).nextFocus();
                    },
                  ),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      errorText: emailInvalido ? 'Email inválido' : null,
                    ),
                    onSubmitted: (_) {
                      FocusScope.of(context).nextFocus();
                    },
                  ),
                  TextField(
                    controller: senhaController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Nova Senha (opcional)',
                      errorText: senhaInvalida
                          ? 'Senha fraca (mín. 4, 1 maiúscula, 1 especial)'
                          : null,
                    ),
                    onSubmitted: (_) async {
                      final nome = nomeController.text.trim();
                      final email = emailController.text.trim();
                      final senha = senhaController.text.trim();

                      bool nomeErro = nome.isEmpty;
                      bool emailErro = !email.contains('@') || !email.contains('.com');
                      bool senhaErro = false;
                      if (senha.isNotEmpty) {
                        final hasUppercase = senha.contains(RegExp(r'[A-Z]'));
                        final hasSpecialChar = senha.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
                        senhaErro = senha.length < 4 || !hasUppercase || !hasSpecialChar;
                      }

                      setState(() {
                        nomeInvalido = nomeErro;
                        emailInvalido = emailErro;
                        senhaInvalida = senhaErro;
                      });

                      if (nomeErro || emailErro || senhaErro) {
                        return;
                      }

                      final user = {
                        'nome': nome,
                        'email': email,
                        'is_admin': isAdmin ? 1 : 0,
                      };
                      if (senha.isNotEmpty) {
                        user['senha'] = senha;
                      }

                      try {
                        final id = usuario['id'];
                        await ApiService.atualizarUsuario(id, user);
                        await carregarUsuarios();

                        if (context.mounted) {
                          Navigator.pop(context);
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Usuário atualizado com sucesso')),
                        );
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('❌ Erro ao atualizar usuário')),
                        );
                      }
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Administrador'),
                    value: isAdmin,
                    onChanged: (v) {
                      setState(() {
                        isAdmin = v ?? false;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  final nome = nomeController.text.trim();
                  final email = emailController.text.trim();
                  final senha = senhaController.text.trim();

                  bool nomeErro = nome.isEmpty;
                  bool emailErro =
                      !email.contains('@') || !email.contains('.com');

                  bool senhaErro = false;
                  if (senha.isNotEmpty) {
                    final hasUppercase = senha.contains(RegExp(r'[A-Z]'));
                    final hasSpecialChar =
                    senha.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
                    senhaErro = senha.length < 4 ||
                        !hasUppercase ||
                        !hasSpecialChar;
                  }

                  setState(() {
                    nomeInvalido = nomeErro;
                    emailInvalido = emailErro;
                    senhaInvalida = senhaErro;
                  });

                  if (nomeErro || emailErro || senhaErro) {
                    return;
                  }

                  final user = {
                    'nome': nome,
                    'email': email,
                    'is_admin': isAdmin ? 1 : 0,
                  };
                  if (senha.isNotEmpty) {
                    user['senha'] = senha;
                  }

                  try {
                    final id = usuario['id'];
                    await ApiService.atualizarUsuario(id, user);
                    await carregarUsuarios();

                    if (context.mounted) {
                      Navigator.pop(context);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('✅ Usuário atualizado com sucesso')),
                    );
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('❌ Erro ao atualizar usuário')),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void excluirUsuario(int index) async {
    final id = usuarios[index]['id'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Usuário'),
        content: const Text('Deseja realmente excluir este usuário?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.excluirUsuario(id);
        await carregarUsuarios();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Usuário excluído com sucesso')),
        );
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Erro ao excluir usuário')),
        );
      }
    }
  }

  void _criarNovoUsuario() async {
    final nomeController = TextEditingController();
    final emailController = TextEditingController();
    final senhaController = TextEditingController();
    bool isAdmin = false;

    bool nomeInvalido = false;
    bool emailInvalido = false;
    bool senhaInvalida = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Novo Usuário'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nomeController,
                    decoration: InputDecoration(
                      labelText: 'Nome',
                      errorText: nomeInvalido ? 'Preencha o nome' : null,
                    ),
                    onSubmitted: (_) {
                      FocusScope.of(context).nextFocus();
                    },
                  ),
                  TextField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      errorText: emailInvalido ? 'Email inválido' : null,
                    ),
                    onSubmitted: (_) {
                      FocusScope.of(context).nextFocus();
                    },
                  ),
                  TextField(
                    controller: senhaController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Senha',
                      errorText: senhaInvalida
                          ? 'Senha fraca (mín. 4, 1 maiúscula, 1 especial)'
                          : null,
                    ),
                    onSubmitted: (_) async {
                      final nome = nomeController.text.trim();
                      final email = emailController.text.trim();
                      final senha = senhaController.text.trim();

                      bool nomeErro = nome.isEmpty;
                      bool emailErro = !email.contains('@') || !email.contains('.com');
                      final hasUppercase = senha.contains(RegExp(r'[A-Z]'));
                      final hasSpecialChar = senha.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
                      bool senhaErro = senha.length < 4 || !hasUppercase || !hasSpecialChar;

                      setState(() {
                        nomeInvalido = nomeErro;
                        emailInvalido = emailErro;
                        senhaInvalida = senhaErro;
                      });

                      if (nomeErro || emailErro || senhaErro) {
                        return;
                      }

                      try {
                        await ApiService.salvarUsuario({
                          'nome': nome,
                          'email': email,
                          'senha': senha,
                          'is_admin': isAdmin ? 1 : 0,
                        });
                        await carregarUsuarios();

                        if (context.mounted) {
                          Navigator.pop(context);
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Usuário criado com sucesso')),
                        );
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('❌ Erro ao criar usuário')),
                        );
                      }
                    },
                  ),
                  CheckboxListTile(
                    title: const Text('Administrador'),
                    value: isAdmin,
                    onChanged: (v) {
                      setState(() {
                        isAdmin = v ?? false;
                      });
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              TextButton(
                onPressed: () async {
                  final nome = nomeController.text.trim();
                  final email = emailController.text.trim();
                  final senha = senhaController.text.trim();

                  bool nomeErro = nome.isEmpty;
                  bool emailErro =
                      !email.contains('@') || !email.contains('.com');
                  final hasUppercase = senha.contains(RegExp(r'[A-Z]'));
                  final hasSpecialChar =
                  senha.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
                  bool senhaErro = senha.length < 4 ||
                      !hasUppercase ||
                      !hasSpecialChar;

                  setState(() {
                    nomeInvalido = nomeErro;
                    emailInvalido = emailErro;
                    senhaInvalida = senhaErro;
                  });

                  if (nomeErro || emailErro || senhaErro) {
                    return;
                  }

                  try {
                    await ApiService.salvarUsuario({
                      'nome': nome,
                      'email': email,
                      'senha': senha,
                      'is_admin': isAdmin ? 1 : 0,
                    });
                    await carregarUsuarios();

                    if (context.mounted) {
                      Navigator.pop(context);
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('✅ Usuário criado com sucesso')),
                    );
                  } catch (_) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('❌ Erro ao criar usuário')),
                    );
                  }
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Cadastro de Usuário',
      isAdmin: widget.isAdmin,
      usuario: widget.usuario,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Expanded(
                  child: TextField(
                    controller: buscaController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar Usuário',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _criarNovoUsuario,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Novo Usuário'),
                  style: AppButtonStyle.primaryButton,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: importarUsuarios,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Importar'),
                  style: AppButtonStyle.primaryButton,
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: toggleModoExportacao,
                  icon: const Icon(Icons.checklist),
                  label: const Text('Selecionar Usuários'),
                  style: AppButtonStyle.primaryButton,
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: usuarios.length,
              itemBuilder: (context, index) {
                final u = usuarios[index];
                final isAdmin = u['is_admin'] == 1 || u['is_admin'] == true;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  child: ListTile(
                    leading: modoExportacao
                        ? Checkbox(
                      value: selecionados[index],
                      onChanged: (v) {
                        setState(() {
                          selecionados[index] = v ?? false;
                          todosSelecionados = selecionados.every((element) => element);
                        });
                      },
                    )
                        : null,
                    title: Text(
                      '${u['nome']} - ${u['email']}${isAdmin ? ' (Admin)' : ''}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => editarUsuario(u),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => excluirUsuario(index),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (modoExportacao)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: CheckboxListTile(
                title: const Text('Selecionar Todos'),
                value: todosSelecionados,
                onChanged: toggleSelecionarTodos,
              ),
            ),
          if (modoExportacao)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: exportarSelecionados,
                      icon: const Icon(Icons.download),
                      label: Text('Exportar (${selecionados.where((e) => e).length})'),
                      style: AppButtonStyle.primaryButton,
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (widget.isAdmin)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Excluir Usuários'),
                              content: const Text('Deseja realmente excluir os usuários selecionados?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Excluir'),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true) {
                            final indices = selecionados
                                .asMap()
                                .entries
                                .where((e) => e.value)
                                .map((e) => e.key)
                                .toList();

                            int excluidos = 0;

                            for (final i in indices) {
                              final id = usuarios[i]['id'];
                              try {
                                await ApiService.excluirUsuario(id);
                                excluidos++;
                              } catch (_) {}
                            }

                            await carregarUsuarios();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('✅ $excluidos usuário(s) excluído(s).')),
                            );

                            toggleModoExportacao();
                          }
                        },
                        icon: const Icon(Icons.delete_forever),
                        label: Text('Excluir (${selecionados.where((e) => e).length})'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ),
                  const SizedBox(width: 10),
                  ElevatedButton.icon(
                    onPressed: toggleModoExportacao,
                    icon: const Icon(Icons.close),
                    label: const Text('Cancelar'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
