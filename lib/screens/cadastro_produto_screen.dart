import 'dart:io';
import 'package:flutter/material.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../services/api_service.dart';
import '../components/app_scaffold.dart';
import '../utils/theme.dart';
import 'package:flutter/foundation.dart';

List<Map<String, dynamic>> processarProdutos(dynamic rawList) {
  return List<Map<String, dynamic>>.from(rawList.whereType<Map<String, dynamic>>());
}

class CadastroProdutoScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final bool isAdmin;

  const CadastroProdutoScreen({
    super.key,
    required this.usuario,
    required this.isAdmin,
  });

  @override
  State<CadastroProdutoScreen> createState() => _CadastroProdutoScreenState();
}

class _CadastroProdutoScreenState extends State<CadastroProdutoScreen> {
  final marcaController = TextEditingController();
  final modeloController = TextEditingController();
  final cmvController = TextEditingController();
  final buscaController = TextEditingController();

  int? editIndex;
  List<Map<String, dynamic>> produtos = [];
  List<Map<String, dynamic>> produtosOriginais = [];
  List<bool> selecionados = [];
  bool modoExportacao = false;
  bool todosSelecionados = false;

  bool carregando = true;

  final ScrollController scrollController = ScrollController();
  int paginaAtual = 1;
  bool carregandoMais = false;

  @override
  void initState() {
    super.initState();
    buscaController.addListener(_filtrarProdutos);
    scrollController.addListener(() {
      if (scrollController.position.pixels >= scrollController.position.maxScrollExtent - 100) {
        carregarMaisProdutos();
      }
    });
    Future.microtask(carregarProdutos);
  }

  Future<void> carregarMaisProdutos() async {
    if (carregandoMais || carregando) return;

    setState(() => carregandoMais = true);

    try {
      final novaListaBruta = await ApiService.getProdutos();
      final novaListaConvertida = await compute(processarProdutos, novaListaBruta);

      setState(() {
        produtos.addAll(novaListaConvertida);
        produtosOriginais.addAll(novaListaConvertida);
        selecionados.addAll(List<bool>.filled(novaListaConvertida.length, false));
        paginaAtual++;
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Erro ao carregar mais produtos.')),
      );
    } finally {
      setState(() => carregandoMais = false);
    }
  }

  Future<void> carregarProdutos() async {
    setState(() => carregando = true);

    try {
      final listaBruta = await ApiService.getProdutos();
      final listaProcessada = await compute(processarProdutos, listaBruta);

      setState(() {
        produtos = listaProcessada;
        produtosOriginais = List<Map<String, dynamic>>.from(listaProcessada);
        selecionados = List<bool>.filled(produtos.length, false);
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erro ao carregar produtos.')),
      );
    } finally {
      setState(() => carregando = false);
    }
  }

  void _filtrarProdutos() {
    final query = buscaController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        produtos = List.from(produtosOriginais);
      } else {
        produtos = produtosOriginais.where((p) {
          final marca = p['marca'].toString().toLowerCase();
          final modelo = p['modelo'].toString().toLowerCase();
          return marca.contains(query) || modelo.contains(query);
        }).toList();
      }
      selecionados = List<bool>.filled(produtos.length, false);
      todosSelecionados = false;
    });
  }

  Future<void> salvarProduto(
      BuildContext context,
      bool isEdit,
      Map<String, dynamic> produto,
      TextEditingController marcaController,
      TextEditingController modeloController,
      TextEditingController cmvController,
      void Function(void Function()) setState,
      ) async {
    final marca = marcaController.text.trim();
    final modelo = modeloController.text.trim();
    final cmvStr = cmvController.text.trim();
    final cmv = double.tryParse(cmvStr);

    // ✅ Validação já deve ter sido feita no popup (não precisa repetir aqui)
    // Apenas monta os dados e salva
    final dados = {
      'marca': marca,
      'modelo': modelo,
      'cmv': cmv,
    };

    try {
      if (isEdit) {
        final id = produto['id'];
        await ApiService.atualizarProduto(id, dados);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Produto atualizado com sucesso')),
        );
      } else {
        await ApiService.salvarProduto(dados);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Produto criado com sucesso')),
        );
      }

      await carregarProdutos();

      if (context.mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erro ao salvar produto')),
      );
    }
  }

  void abrirPopupProduto({
    required Map<String, dynamic> produto,
    required bool isEdit,
  }) async {
    final marcaController = TextEditingController(text: produto['marca'] ?? '');
    final modeloController = TextEditingController(text: produto['modelo'] ?? '');
    final cmvController = TextEditingController(text: produto['cmv']?.toString() ?? '');

    bool marcaInvalida = false;
    bool modeloInvalido = false;
    bool cmvInvalido = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text(isEdit ? 'Editar Produto' : 'Novo Produto'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: marcaController,
                    decoration: InputDecoration(
                      labelText: 'Marca',
                      errorText: marcaInvalida ? 'Preencha a marca' : null,
                    ),
                    onSubmitted: (_) {
                      FocusScope.of(context).nextFocus();
                    },
                  ),
                  TextField(
                    controller: modeloController,
                    decoration: InputDecoration(
                      labelText: 'Modelo',
                      errorText: modeloInvalido ? 'Preencha o modelo' : null,
                    ),
                    onSubmitted: (_) {
                      FocusScope.of(context).nextFocus();
                    },
                  ),
                  TextField(
                    controller: cmvController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'CMV',
                      errorText: cmvInvalido ? 'Informe um CMV válido' : null,
                    ),
                    onSubmitted: (_) async {
                      final marca = marcaController.text.trim();
                      final modelo = modeloController.text.trim();
                      final cmvStr = cmvController.text.trim();
                      final cmv = double.tryParse(cmvStr);

                      final marcaErro = marca.isEmpty;
                      final modeloErro = modelo.isEmpty;
                      final cmvErro = cmv == null;

                      setState(() {
                        marcaInvalida = marcaErro;
                        modeloInvalido = modeloErro;
                        cmvInvalido = cmvErro;
                      });

                      if (marcaErro || modeloErro || cmvErro) {
                        return;
                      }

                      await salvarProduto(
                        context,
                        isEdit,
                        produto,
                        marcaController,
                        modeloController,
                        cmvController,
                        setState,
                      );
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
                  final marca = marcaController.text.trim();
                  final modelo = modeloController.text.trim();
                  final cmvStr = cmvController.text.trim();
                  final cmv = double.tryParse(cmvStr);

                  final marcaErro = marca.isEmpty;
                  final modeloErro = modelo.isEmpty;
                  final cmvErro = cmv == null;

                  setState(() {
                    marcaInvalida = marcaErro;
                    modeloInvalido = modeloErro;
                    cmvInvalido = cmvErro;
                  });

                  if (marcaErro || modeloErro || cmvErro) {
                    return;
                  }

                  await salvarProduto(
                    context,
                    isEdit,
                    produto,
                    marcaController,
                    modeloController,
                    cmvController,
                    setState,
                  );
                },
                child: const Text('Salvar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void criarNovoProduto() {
    abrirPopupProduto(
      produto: {},
      isEdit: false,
    );
  }

  void editarProduto(Map<String, dynamic> produto) {
    abrirPopupProduto(
      produto: produto,
      isEdit: true,
    );
  }

  void excluirProduto(int index) async {
    final id = produtos[index]['id'];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Produto'),
        content: const Text('Deseja realmente excluir este produto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.excluirProduto(id);
        await carregarProdutos();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Produto excluído com sucesso')),
        );
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Erro ao excluir produto')),
        );
      }
    }
  }

  void toggleModoExportacao() {
    setState(() {
      modoExportacao = !modoExportacao;
      selecionados = List<bool>.filled(produtos.length, false);
      todosSelecionados = false;
    });
  }

  void toggleSelecionarTodos(bool? value) {
    setState(() {
      todosSelecionados = value ?? false;
      selecionados = List<bool>.filled(produtos.length, todosSelecionados);
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
        const SnackBar(content: Text('⚠️ Nenhum produto selecionado para exportação')),
      );
      return;
    }

    final excel = Excel.createExcel();
    const sheetName = 'Produtos';
    final sheet = excel[sheetName];

    sheet.appendRow([
      TextCellValue('Marca'),
      TextCellValue('Modelo'),
      TextCellValue('CMV'),
    ]);

    for (var index in selecionadosIndices) {
      final p = produtos[index];
      sheet.appendRow([
        TextCellValue(p['marca'] ?? ''),
        TextCellValue(p['modelo'] ?? ''),
        TextCellValue(p['cmv'].toString()),
      ]);
    }

    // Remove abas extras
    final sheetsToRemove = excel.sheets.keys.where((name) => name != sheetName).toList();
    for (final name in sheetsToRemove) {
      excel.delete(name);
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/produtos.xlsx');
    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Exportação concluída com sucesso')),
    );

    toggleModoExportacao();
  }

  Future<void> importarProdutos() async {
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

        final sheet = excel.tables['Produtos'];
        if (sheet == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Aba "Produtos" não encontrada no arquivo')),
          );
          return;
        }

        int atualizados = 0;
        int inseridos = 0;
        List<String> erros = [];

        for (var row in sheet.rows.skip(1)) {
          final marca = row[0]?.value.toString().trim() ?? '';
          final modelo = row[1]?.value.toString().trim() ?? '';
          final cmvStr = row[2]?.value.toString().trim() ?? '';

          if (marca.isEmpty || modelo.isEmpty || cmvStr.isEmpty) {
            erros.add('Linha incompleta -> Marca: $marca, Modelo: $modelo, CMV: $cmvStr');
            continue;
          }

          final cmv = double.tryParse(cmvStr);
          if (cmv == null) {
            erros.add('CMV inválido no modelo $modelo');
            continue;
          }

          try {
            final existente = produtosOriginais.firstWhere(
                  (p) => p['modelo'].toString().toLowerCase() == modelo.toLowerCase(),
              orElse: () => {},
            );

            if (existente.isNotEmpty) {
              final id = existente['id'];
              await ApiService.atualizarProduto(id, {
                'marca': marca,
                'modelo': modelo,
                'cmv': cmv,
              });
              atualizados++;
            } else {
              await ApiService.salvarProduto({
                'marca': marca,
                'modelo': modelo,
                'cmv': cmv,
              });
              inseridos++;
            }
          } catch (e) {
            erros.add('Erro ao processar modelo $modelo');
          }
        }

        await carregarProdutos();

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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Cadastro de Produto',
      isAdmin: widget.isAdmin,
      usuario: widget.usuario,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: buscaController,
                        decoration: const InputDecoration(
                          labelText: 'Buscar Produto',
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
                      onPressed: criarNovoProduto,
                      icon: const Icon(Icons.add),
                      label: const Text('Novo Produto'),
                      style: AppButtonStyle.primaryButton,
                    ),
                    ElevatedButton.icon(
                      onPressed: importarProdutos,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Importar'),
                      style: AppButtonStyle.primaryButton,
                    ),
                    ElevatedButton.icon(
                      onPressed: toggleModoExportacao,
                      icon: const Icon(Icons.checklist),
                      label: const Text('Selecionar Produtos'),
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
                : ListView.builder(
              controller: scrollController,
              itemCount: produtos.length + (carregandoMais ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == produtos.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final p = produtos[index];

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
                          todosSelecionados = selecionados.every((e) => e);
                        });
                      },
                    )
                        : null,
                    title: Text('${p['marca']} - ${p['modelo']}'),
                    subtitle: Text('CMV: R\$ ${p['cmv']}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit),
                          onPressed: () => editarProduto(p),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () => excluirProduto(index),
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
                    ElevatedButton.icon(
                      onPressed: exportarSelecionados,
                      icon: const Icon(Icons.download),
                      label: Text('Exportar (${selecionados.where((e) => e).length})'),
                      style: AppButtonStyle.primaryButton,
                    ),
                  const SizedBox(width: 10),
                  if (widget.isAdmin) // ✅ Apenas admins podem excluir
                      ElevatedButton.icon(
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Excluir Produtos'),
                              content: const Text('Deseja realmente excluir os produtos selecionados?'),
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
                              final id = produtos[i]['id'];
                              try {
                                await ApiService.excluirProduto(id);
                                excluidos++;
                              } catch (_) {}
                            }

                            await carregarProdutos();

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('✅ $excluidos produto(s) excluído(s).')),
                            );

                            toggleModoExportacao();
                          }
                        },
                        icon: const Icon(Icons.delete_forever),
                        label: Text('Excluir (${selecionados.where((e) => e).length})'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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
