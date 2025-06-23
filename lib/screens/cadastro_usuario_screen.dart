import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../components/app_scaffold.dart';
import '../utils/theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../utils/export_utils.dart'
  if (dart.library.html) '../utils/export_web.dart';
import 'dart:io' show File;
import 'package:bcrypt/bcrypt.dart';
import 'package:flutter/services.dart';

List<Map<String, dynamic>> processarUsuarios(dynamic rawList) {
  return List<Map<String, dynamic>>.from(rawList.whereType<Map<String, dynamic>>());
}

class CadastroUsuarioScreen extends StatefulWidget {

  final Map<String, dynamic> usuario;
  final bool isAdmin;
  final bool isSuperAdmin;

  const CadastroUsuarioScreen({
    super.key,
    required this.usuario,
    required this.isAdmin,
    required this.isSuperAdmin,
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
  bool senhaVisivel = false;

  bool carregando = true;
  bool carregandoMais = false;
  final ScrollController scrollController = ScrollController();
  int paginaAtual = 1;

  bool todosSelecionados = false;

  @override
  void initState() {
    super.initState();
    buscaController.addListener(_filtrarUsuarios);
    Future.microtask(() => carregarUsuarios());
  }

  Future<T> executarComLoading<T>(Future<T> Function() acao) async {
    bool dialogAberto = false;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          dialogAberto = true;
          return const Dialog(
            backgroundColor: Colors.transparent,
            child: Center(child: CircularProgressIndicator()),
          );
        },
      );

      final resultado = await acao();

      return resultado;
    } catch (e) {
      rethrow;
    } finally {
      if (dialogAberto && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // ✅ fecha o loading
      }
    }
  }

// ❌ Método desativado — paginação agora é feita localmente
// Future<void> carregarMaisUsuarios() async {
//   if (carregandoMais || carregando) return;
//
//   setState(() => carregandoMais = true);
//
//   try {
//     final novaListaBruta = await ApiService.getUsuarios(pagina: paginaAtual + 1, limite: 30);
//     final novaListaConvertida = await compute(processarUsuarios, novaListaBruta);
//
//     if (novaListaConvertida.isEmpty) return;
//
//     setState(() {
//       usuarios.addAll(novaListaConvertida);
//       usuariosOriginais.addAll(novaListaConvertida);
//       selecionados.addAll(List<bool>.filled(novaListaConvertida.length, false));
//       paginaAtual++;
//     });
//   } catch (e) {
//     print('Erro carregarMaisUsuarios: $e');
//     if (mounted) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(content: Text('⚠️ Erro ao carregar mais usuários.')),
//       );
//     }
//   } finally {
//     if (mounted) setState(() => carregandoMais = false);
//   }
// }

  Future<void> carregarUsuarios() async {
    debugPrint('🔄 Chamou carregarUsuarios()');
    setState(() {
      carregando = true;
      paginaAtual = 1;
      usuarios = [];
      usuariosOriginais = [];
      selecionados = [];
    });

    try {
      // ⏱️ Timeout de segurança: 10 segundos
      final listaCompleta = await ApiService.getUsuarios().timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Tempo de resposta excedido (10s)'),
      );

      final listaConvertida = List<Map<String, dynamic>>.from(listaCompleta);

      setState(() {
        usuarios = List<Map<String, dynamic>>.from(listaConvertida)
          ..sort((a, b) =>
              a['nome'].toString().toLowerCase().compareTo(
                  b['nome'].toString().toLowerCase()));

        usuariosOriginais = List<Map<String, dynamic>>.from(usuarios);
        selecionados = List<bool>.filled(usuarios.length, false);
      });
    } catch (e) {
      print('❌ Erro ao carregar usuários: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('❌ Erro ao carregar usuários: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => carregando = false);
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
        const SnackBar(
            content: Text('⚠️ Nenhum usuário selecionado para exportação')),
      );
      return;
    }

    await executarComLoading(() async {
      final excel = Excel.createExcel();
      const sheetName = 'Usuários';
      final sheet = excel[sheetName];

      sheet.appendRow([
        TextCellValue('Nome'),
        TextCellValue('Email'),
        TextCellValue('Admin (1=Sim, 0=Não)'),
      ]);

      // Remove abas extras (como "Sheet1")
      final sheetsToRemove = excel.sheets.keys.where((name) =>
      name != sheetName).toList();
      for (final name in sheetsToRemove) {
        excel.delete(name);
      }

      for (var index in selecionadosIndices) {
        final u = usuarios[index];
        sheet.appendRow([
          TextCellValue(u['nome'] ?? ''),
          TextCellValue(u['email'] ?? ''),
          TextCellValue(
              (u['is_admin'] == 1 || u['is_admin'] == true) ? '1' : '0'),
        ]);
      }

      final bytes = excel.encode();
      if (bytes == null) return;

      await exportarArquivo(bytes, 'usuarios.xlsx');
    });

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Exportação concluída com sucesso')),
      );
    }

    toggleModoExportacao();
  }

  Future<void> importarUsuarios() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
    );

    if (result == null) return;

    final fileBytes = result.files.single.bytes;
    final filePath = result.files.single.path;

    if (fileBytes == null && filePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erro ao ler o arquivo')),
      );
      return;
    }

    int atualizados = 0;
    int inseridos = 0;
    List<String> erros = [];

    await executarComLoading(() async {
      final bytes = kIsWeb
          ? fileBytes!
          : fileBytes ?? await File(filePath!).readAsBytes();
      final excel = Excel.decodeBytes(bytes);

      final sheet = excel.tables['Usuários'];
      if (sheet == null) {
        throw Exception('Aba "Usuários" não encontrada no arquivo');
      }

      final mapaUsuariosPorEmail = {
        for (var u in usuariosOriginais)
          u['email'].toString().toLowerCase(): u
      };

      List<Future<void>> tarefas = [];

      for (var row in sheet.rows.skip(1)) {
        if (row.every((cell) =>
        cell == null || cell.value
            .toString()
            .trim()
            .isEmpty)) {
          continue;
        }

        final nome = row[0]?.value.toString().trim() ?? '';
        final email = row[1]?.value.toString().trim().toLowerCase() ?? '';
        final adminValue = row.length > 2
            ? row[2]?.value.toString().trim()
            : '0';
        final isAdmin = adminValue == '1';

        if (nome.isEmpty || email.isEmpty) {
          erros.add('Linha com dados incompletos: Nome: $nome, Email: $email');
          continue;
        }

        if (!email.contains('@') || !email.contains('.')) {
          erros.add('Email inválido: $email');
          continue;
        }

        final existente = mapaUsuariosPorEmail[email];
        final senhaCriptografada = BCrypt.hashpw('123456', BCrypt.gensalt());

        if (existente != null) {
          final id = existente['id'];
          tarefas.add(
            ApiService.atualizarUsuario(id, {
              'nome': nome,
              'email': email,
              'is_admin': isAdmin ? 1 : 0,
              'senha': senhaCriptografada,
            }).then((_) {
              atualizados++;
            }).catchError((_) {
              erros.add('Erro ao atualizar $email');
            }),
          );
        } else {
          tarefas.add(
            ApiService.salvarUsuario({
              'nome': nome,
              'email': email,
              'is_admin': isAdmin ? 1 : 0,
              'senha': senhaCriptografada,
            }).then((_) {
              inseridos++;
            }).catchError((_) {
              erros.add('Erro ao criar $email');
            }),
          );
        }
      }

      await Future.wait(tarefas);
    });

    // ✅ carregar após o loading
    await carregarUsuarios();

    String resumo = '✅ Importação finalizada.\nInseridos: $inseridos\nAtualizados: $atualizados';
    if (erros.isNotEmpty) {
      resumo += '\n⚠️ Erros:\n${erros.join('\n')}';
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) =>
            KeyboardListener(
              focusNode: FocusNode()
                ..requestFocus(),
              onKeyEvent: (event) {
                if (event.logicalKey == LogicalKeyboardKey.enter ||
                    event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                  Navigator.pop(context);
                }
              },
              child: AlertDialog(
                title: const Text('Resumo da Importação'),
                content: SingleChildScrollView(child: Text(resumo)),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fechar'),
                  ),
                ],
              ),
            ),
      );
    }
  }

  void editarUsuario(Map<String, dynamic> usuario) async {
    final nomeController = TextEditingController(text: usuario['nome']);
    final emailController = TextEditingController(text: usuario['email']);
    final senhaController = TextEditingController();

    bool nomeInvalido = false;
    bool emailInvalido = false;
    bool senhaInvalida = false;

    bool isAdmin = usuario['is_admin'] == 1 || usuario['is_admin'] == true;
    bool isSuperAdmin = usuario['is_super_admin'] == 1 || usuario['is_super_admin'] == true;
    bool isLojaOnline = usuario['loja_online'] == 1 || usuario['loja_online'] == true;

    Future<void> salvar() async {
      final nome = nomeController.text.trim();
      final email = emailController.text.trim();
      final senha = senhaController.text.trim();

      bool nomeErro = nome.isEmpty;
      bool emailErro = !email.contains('@') || !email.contains('.com');

      bool senhaErro = false;
      if (senha.isNotEmpty) {
        final hasUppercase = senha.contains(RegExp(r'[A-Z]'));
        final hasSpecialChar = senha.contains(
            RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
        senhaErro = senha.length < 4 || !hasUppercase || !hasSpecialChar;
      }

      if (nomeErro || emailErro || senhaErro) {
        setState(() {
          nomeInvalido = nomeErro;
          emailInvalido = emailErro;
          senhaInvalida = senhaErro;
        });
        return;
      }

      final user = {
        'nome': nome,
        'email': email,
        'is_admin': isAdmin ? 1 : 0,
        'is_super_admin': isSuperAdmin ? 1 : 0,
      };

      if (senha.isNotEmpty) {
        user['senha'] = senha;
        user['precisa_alterar_senha'] = 1;
      }

      print('📤 Enviando atualização: $user');

      try {
        await executarComLoading(() async {
          final id = usuario['id'];
          print('🧪 Atualizando usuário ID: ${usuario['id']} com dados: $user');
          await ApiService.atualizarUsuario(id, user);
          await carregarUsuarios();

          if (ApiService.usuarioLogadoNotifier.value?['id'].toString() ==
              id.toString()) {
            await ApiService.atualizarDadosUsuarioLogado();
            ApiService.usuarioLogado = Map<String, dynamic>.from(ApiService.usuarioLogado ?? {});

            if (context.mounted) {
              final rotaAtual = ModalRoute
                  .of(context)
                  ?.settings
                  .name ?? '/simulacao';
              Navigator.of(context).pushReplacementNamed(rotaAtual);
            }
          }
        });

        if (context.mounted) Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Usuário atualizado com sucesso')),
        );
      } catch (e) {
        print('❌ Erro ao atualizar: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Erro ao atualizar usuário')),
        );
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          KeyboardListener(
            focusNode: FocusNode()
              ..requestFocus(),
            onKeyEvent: (event) {
              if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                salvar();
              }
            },
            child: StatefulBuilder(
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
                        ),
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            errorText: emailInvalido ? 'Email inválido' : null,
                          ),
                        ),
                        TextField(
                          controller: senhaController,
                          obscureText: !senhaVisivel,
                          decoration: InputDecoration(
                            labelText: 'Nova Senha (opcional)',
                            errorText: senhaInvalida
                                ? 'Senha fraca (mín. 4, 1 maiúscula, 1 especial)'
                                : null,
                            suffixIcon: IconButton(
                              icon: Icon(
                                senhaVisivel ? Icons.visibility : Icons
                                    .visibility_off,
                              ),
                              onPressed: () =>
                                  setState(() {
                                    senhaVisivel = !senhaVisivel;
                                  }),
                            ),
                          ),
                        ),
                        if (ApiService.isSuperAdmin)
                          CheckboxListTile(
                            title: const Text('Administrador'),
                            value: isAdmin,
                            onChanged: (v) =>
                                setState(() {
                                  isAdmin = v ?? false;
                                }),
                          ),
                        if (ApiService.isSuperAdmin)
                          CheckboxListTile(
                            title: const Text('Super Admin'),
                            value: isSuperAdmin,
                            onChanged: (v) =>
                                setState(() {
                                  isSuperAdmin = v ?? false;
                                }),
                          ),
                        if (ApiService.isSuperAdmin)
                          CheckboxListTile(
                            title: const Text('Loja Online'),
                            value: isLojaOnline,
                            onChanged: (v) => setState(() { isLojaOnline = v ?? false; }),
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
                      onPressed: salvar,
                      child: const Text('Salvar'),
                    ),
                  ],
                );
              },
            ),
          ),
    );
  }

  void excluirUsuario(int index) async {
    if (!ApiService.isSuperAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('⚠️ Apenas Super Admin pode excluir usuários.')),
      );
      return;
    }

    final id = usuarios[index]['id'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) =>
          AlertDialog(
            title: const Text('Excluir Usuário'),
            content: const Text('Deseja realmente excluir este usuário?'),
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
      try {
        await executarComLoading(() async {
          await ApiService.excluirUsuario(id);
          await carregarUsuarios();
        });

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
    bool isSuperAdmin = false;
    bool isLojaOnline = false;

    bool nomeInvalido = false;
    bool emailInvalido = false;
    bool senhaInvalida = false;

    Future<void> salvar() async {
      final nome = nomeController.text.trim();
      final email = emailController.text.trim();
      final senha = senhaController.text.trim();

      bool nomeErro = nome.isEmpty;
      bool emailErro = !email.contains('@') || !email.contains('.com');
      final hasUppercase = senha.contains(RegExp(r'[A-Z]'));
      final hasSpecialChar = senha.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
      bool senhaErro = senha.length < 4 || !hasUppercase || !hasSpecialChar;

      if (nomeErro || emailErro || senhaErro) {
        setState(() {
          nomeInvalido = nomeErro;
          emailInvalido = emailErro;
          senhaInvalida = senhaErro;
        });
        return;
      }

      try {
        await executarComLoading(() async {
          await ApiService.salvarUsuario({
            'nome': nome,
            'email': email,
            'senha': senha,
            'is_admin': isAdmin ? 1 : 0,
            'is_super_admin': isSuperAdmin ? 1 : 0,
            'loja_online': isLojaOnline ? 1 : 0,
          });
          await carregarUsuarios();
        });

        if (context.mounted) Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Usuário criado com sucesso')),
        );
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Erro ao criar usuário')),
        );
      }
    }

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          KeyboardListener(
            focusNode: FocusNode()
              ..requestFocus(),
            onKeyEvent: (event) {
              if (event.logicalKey == LogicalKeyboardKey.enter ||
                  event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                salvar();
              }
            },
            child: StatefulBuilder(
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
                          onSubmitted: (_) =>
                              FocusScope
                                  .of(context)
                                  .nextFocus(),
                        ),
                        TextField(
                          controller: emailController,
                          decoration: InputDecoration(
                            labelText: 'Email',
                            errorText: emailInvalido ? 'Email inválido' : null,
                          ),
                          onSubmitted: (_) =>
                              FocusScope
                                  .of(context)
                                  .nextFocus(),
                        ),
                        TextField(
                          controller: senhaController,
                          obscureText: !senhaVisivel,
                          decoration: InputDecoration(
                            labelText: 'Senha',
                            errorText: senhaInvalida
                                ? 'Senha fraca (mín. 4, 1 maiúscula, 1 especial)'
                                : null,
                            suffixIcon: IconButton(
                              icon: Icon(
                                senhaVisivel ? Icons.visibility : Icons
                                    .visibility_off,
                              ),
                              onPressed: () {
                                setState(() {
                                  senhaVisivel = !senhaVisivel;
                                });
                              },
                            ),
                          ),
                        ),
                        if (ApiService.isSuperAdmin)
                          CheckboxListTile(
                            title: const Text('Administrador'),
                            value: isAdmin,
                            onChanged: (v) =>
                                setState(() {
                                  isAdmin = v ?? false;
                                }),
                          ),
                        if (ApiService.isSuperAdmin)
                          CheckboxListTile(
                            title: const Text('Super Admin'),
                            value: isSuperAdmin,
                            onChanged: (v) =>
                                setState(() {
                                  isSuperAdmin = v ?? false;
                                }),
                          ),
                        if (ApiService.isSuperAdmin)
                          CheckboxListTile(
                            title: const Text('Loja Online'),
                            value: isLojaOnline,
                            onChanged: (v) => setState(() { isLojaOnline = v ?? false; }),
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
                      onPressed: salvar,
                      child: const Text('Salvar'),
                    ),
                  ],
                );
              },
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: ApiService.usuarioLogadoNotifier,
      builder: (context, usuario, _) {
        final bool temPermissao = usuario?['is_admin'] == 1 ||
            usuario?['is_super_admin'] == 1;

        // ✅ Se perdeu permissão, redireciona imediatamente
        if (!temPermissao) {
          Future.microtask(() {
            if (ModalRoute
                .of(context)
                ?.isCurrent == true) {
              Navigator.of(context).pushReplacementNamed('/simulacao');
            }
          });
          return const SizedBox();
        }

        const int itensPorPagina = 10;
        final int totalPaginas = (usuarios.length / itensPorPagina).ceil();
        final int indiceInicio = (paginaAtual - 1) * itensPorPagina;
        final int indiceFim = (indiceInicio + itensPorPagina).clamp(
            0, usuarios.length);

        final usuariosPaginados = usuarios.sublist(indiceInicio, indiceFim);

        return AppScaffold(
          title: 'Cadastro de Usuário',
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 16),
                child: Column(
                  children: [
                    Row(
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
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _criarNovoUsuario,
                          icon: const Icon(Icons.person_add),
                          label: const Text('Novo Usuário'),
                          style: AppButtonStyle.primaryButton,
                        ),
                        ElevatedButton.icon(
                          onPressed: importarUsuarios,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Importar'),
                          style: AppButtonStyle.primaryButton,
                        ),
                        ElevatedButton.icon(
                          onPressed: toggleModoExportacao,
                          icon: const Icon(Icons.checklist),
                          label: const Text('Selecionar Usuários'),
                          style: AppButtonStyle.primaryButton,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: carregando
                    ? const Center(child: CircularProgressIndicator())
                    : usuarios.isEmpty
                    ? const Center(child: Text('Nenhum usuário encontrado'))
                    : ListView.builder(
                  itemCount: usuariosPaginados.length,
                  itemBuilder: (context, index) {
                    final u = usuariosPaginados[index];
                    final isSuperAdmin = u['is_super_admin'] == 1;
                    final isAdmin = u['is_admin'] == 1 || u['is_admin'] == true;
                    final isLojaOnline = u['loja_online'] == 1 || u['loja_online'] == true;
                    final globalIndex = indiceInicio + index;


                    List<String> statusParts = [];
                    if (isSuperAdmin) statusParts.add('Super Admin');
                    else if (isAdmin) statusParts.add('Admin');

                    if (isLojaOnline) statusParts.add('Loja Online');
                    else statusParts.add('Loja Física');

                    String status = statusParts.isNotEmpty ? ' (${statusParts.join(', ')})' : '';

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius
                          .circular(10)),
                      child: ListTile(
                        leading: modoExportacao
                            ? Checkbox(
                          value: selecionados[globalIndex],
                          onChanged: (v) {
                            setState(() {
                              selecionados[globalIndex] = v ?? false;
                              todosSelecionados = selecionados.every((e) => e);
                            });
                          },
                        )
                            : null,
                        title: Text(
                          '${u['nome']} - ${u['email']}$status',
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
                              onPressed: () => excluirUsuario(globalIndex),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (usuarios.length > itensPorPagina)
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left),
                            onPressed: paginaAtual > 1
                                ? () => setState(() => paginaAtual--)
                                : null,
                          ),
                          Text('Página $paginaAtual de $totalPaginas'),
                          IconButton(
                            icon: const Icon(Icons.chevron_right),
                            onPressed: paginaAtual < totalPaginas
                                ? () => setState(() => paginaAtual++)
                                : null,
                          ),
                        ],
                      ),
                      Text('Total: ${usuarios.length} registros'),
                    ],
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
                      ElevatedButton.icon(
                        onPressed: exportarSelecionados,
                        icon: const Icon(Icons.download),
                        label: Text('Exportar (${selecionados
                            .where((e) => e)
                            .length})'),
                        style: AppButtonStyle.primaryButton,
                      ),
                      if ((ApiService.usuarioLogadoNotifier
                          .value?['is_admin'] == 1) ||
                          (ApiService.usuarioLogadoNotifier
                              .value?['is_super_admin'] == 1))
                        ElevatedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) =>
                                  AlertDialog(
                                    title: const Text('Excluir Usuários'),
                                    content: const Text(
                                        'Deseja realmente excluir os usuários selecionados?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancelar'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Excluir'),
                                      ),
                                    ],
                                  ),
                            );

                            if (confirm == true) {
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (_) =>
                                const Dialog(
                                  backgroundColor: Colors.transparent,
                                  child: Center(
                                      child: CircularProgressIndicator()),
                                ),
                              );

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
                              Navigator.pop(context); // Fecha o loading

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(
                                    '✅ $excluidos usuário(s) excluído(s).')),
                              );

                              toggleModoExportacao();
                            }
                          },
                          icon: const Icon(Icons.delete_forever),
                          label: Text('Excluir (${selecionados
                              .where((e) => e)
                              .length})'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                        ),
                      ElevatedButton.icon(
                        onPressed: toggleModoExportacao,
                        icon: const Icon(Icons.close),
                        label: const Text('Cancelar'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}