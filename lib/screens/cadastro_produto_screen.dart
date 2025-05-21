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

class CadastroProdutoScreen extends StatefulWidget {
  const CadastroProdutoScreen({super.key});
  @override
  State<CadastroProdutoScreen> createState() => _CadastroProdutoScreenState();
}

class _CadastroProdutoScreenState extends State<CadastroProdutoScreen> {
  final marcaController = TextEditingController();
  final modeloController = TextEditingController();
  final cmvController = TextEditingController();
  final buscaController = TextEditingController();
  bool _importando = false;

  int? editIndex;
  List<Map<String, dynamic>> produtosFiltrados = [];

  @override
  void initState() {
    super.initState();
    buscaController.addListener(_filtrarProdutos);
    Future.microtask(() => _carregarProdutos());
  }

  Future<void> importarProdutos() async {
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
      int atualizados = 0;
      int inseridos = 0;

      final listaAtual = await ApiService.getProdutos();
      final produtosExistentes = List<Map<String, dynamic>>.from(listaAtual);

      if (kIsWeb) {
        final content = utf8.decode(fileBytes);
        final rows = const CsvToListConverter(eol: '\n').convert(content);

        final header = rows.first.map((e) => e.toString().toLowerCase().trim()).toList();
        if (!(header.contains('marca') && header.contains('modelo') && header.contains('cmv'))) {
          throw Exception('CSV deve conter as colunas: marca, modelo, cmv');
        }

        final marcaIndex = header.indexOf('marca');
        final modeloIndex = header.indexOf('modelo');
        final cmvIndex = header.indexOf('cmv');

        for (final row in rows.skip(1)) {
          final marca = row[marcaIndex]?.toString().trim() ?? '';
          final modelo = row[modeloIndex]?.toString().trim() ?? '';
          final cmv = row[cmvIndex]?.toString().trim() ?? '';

          if (marca.isEmpty || modelo.isEmpty || cmv.isEmpty) continue;

          final existente = produtosExistentes.firstWhere(
                (p) => p['marca'].toString().toLowerCase() == marca.toLowerCase() &&
                p['modelo'].toString().toLowerCase() == modelo.toLowerCase(),
            orElse: () => {},
          );

          if (existente.isNotEmpty) {
            await ApiService.atualizarProduto(existente['id'], {'marca': marca, 'modelo': modelo, 'cmv': cmv});
            atualizados++;
          } else {
            await ApiService.salvarProduto({'marca': marca, 'modelo': modelo, 'cmv': cmv});
            inseridos++;
          }
        }
      } else {
        final excel = Excel.decodeBytes(fileBytes);

        if (!excel.tables.containsKey('Produtos')) {
          throw Exception('Aba "Produtos" não encontrada');
        }

        final sheet = excel.tables['Produtos']!;
        final header = sheet.rows.first.map((cell) => cell?.value?.toString().toLowerCase().trim()).toList();

        final marcaIndex = header.indexOf('marca');
        final modeloIndex = header.indexOf('modelo');
        final cmvIndex = header.indexOf('cmv');

        for (final row in sheet.rows.skip(1)) {
          final marca = row[marcaIndex]?.value.toString().trim() ?? '';
          final modelo = row[modeloIndex]?.value.toString().trim() ?? '';
          final cmv = row[cmvIndex]?.value.toString().trim() ?? '';

          if (marca.isEmpty || modelo.isEmpty || cmv.isEmpty) continue;

          final existente = produtosExistentes.firstWhere(
                (p) => p['marca'].toString().toLowerCase() == marca.toLowerCase() &&
                p['modelo'].toString().toLowerCase() == modelo.toLowerCase(),
            orElse: () => {},
          );

          if (existente.isNotEmpty) {
            await ApiService.atualizarProduto(existente['id'], {'marca': marca, 'modelo': modelo, 'cmv': cmv});
            atualizados++;
          } else {
            await ApiService.salvarProduto({'marca': marca, 'modelo': modelo, 'cmv': cmv});
            inseridos++;
          }
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ $atualizados atualizados, $inseridos inseridos com sucesso.')),
      );
      await _carregarProdutos();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Ocorreu um erro ao importar os produtos.')),
      );
    } finally {
      setState(() => _importando = false);
    }
  }

  Future<void> _carregarProdutos() async {
    try {
      final lista = await ApiService.getProdutos();
      setState(() {
        produtosFiltrados = List<Map<String, dynamic>>.from(lista);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Não foi possível carregar os produtos. Verifique sua conexão.')),
      );
    }
  }

  void _filtrarProdutos() async {
    final query = buscaController.text.toLowerCase();
    final todos = List<Map<String, dynamic>>.from(await ApiService.getProdutos());

    setState(() {
      produtosFiltrados = todos.where((p) =>
      p['marca'].toLowerCase().contains(query) ||
          p['modelo'].toLowerCase().contains(query)
      ).toList();
    });
  }

  void salvar() async {
    final marca = marcaController.text.trim();
    final modelo = modeloController.text.trim();
    final cmv = cmvController.text.trim();

    if (marca.isEmpty || modelo.isEmpty || cmv.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Preencha todos os campos para salvar.')),
      );
      return;
    }

    final produto = {'marca': marca, 'modelo': modelo, 'cmv': cmv};
    final nomeProduto = '$marca - $modelo';

    try {
      if (editIndex != null) {
        final id = produtosFiltrados[editIndex!]['id'];
        await ApiService.atualizarProduto(id, produto);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Produto atualizado: $nomeProduto')));
      } else {
        await ApiService.salvarProduto(produto);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ Produto salvo: $nomeProduto')));
      }

      marcaController.clear();
      modeloController.clear();
      cmvController.clear();
      editIndex = null;
      _carregarProdutos();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erro ao salvar o produto.')),
      );
    }
  }

  void editarProduto(int index, Map p) {
    marcaController.text = p['marca'];
    modeloController.text = p['modelo'];
    cmvController.text = p['cmv'];
    editIndex = index;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Editar Produto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: marcaController,
                decoration: const InputDecoration(labelText: 'Marca'),
              ),
              TextField(
                controller: modeloController,
                decoration: const InputDecoration(labelText: 'Modelo'),
              ),
              TextField(
                controller: cmvController,
                decoration: const InputDecoration(labelText: 'CMV'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                marcaController.clear();
                modeloController.clear();
                cmvController.clear();
                editIndex = null;
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                salvar();
                Navigator.of(context).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void excluir(int i) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remover Produto'),
        content: const Text('Deseja realmente excluir este produto?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final id = produtosFiltrados[i]['id'];
        await ApiService.excluirProduto(id);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Produto excluído.')));
        _carregarProdutos();
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Erro ao excluir o produto.')));
      }
    }
  }

  @override
  void dispose() {
    marcaController.dispose();
    modeloController.dispose();
    cmvController.dispose();
    buscaController.dispose();
    super.dispose();
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
                'Cadastro de Produto',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: marcaController,
                decoration: const InputDecoration(labelText: 'Marca'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: modeloController,
                decoration: const InputDecoration(labelText: 'Modelo'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: cmvController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'CMV'),
              ),
              const SizedBox(height: 12),
              Center(
                child: ElevatedButton(
                  onPressed: salvar,
                  child: const Text('Salvar Produto'),
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: buscaController,
                decoration: const InputDecoration(
                  labelText: 'Buscar Produto',
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
                    label: const Text('Importar Produtos'),
                    onPressed: importarProdutos,
                  ),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Exportar Produtos'),
                    onPressed: () async {
                      try {
                        await planilhaUtil.gerarPlanilhaProdutos(produtosFiltrados);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('✅ Planilha gerada com sucesso.')),
                        );
                      } catch (_) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('❌ Erro ao gerar planilha.')),
                        );
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text('Produtos Cadastrados', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: produtosFiltrados.length,
                itemBuilder: (context, index) {
                  final p = produtosFiltrados[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 1,
                    child: ListTile(
                      title: Text('${p['marca']} - ${p['modelo']}'),
                      subtitle: Text('CMV: R\$ ${p['cmv']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(icon: const Icon(Icons.edit), onPressed: () => editarProduto(index, p)),
                          IconButton(icon: const Icon(Icons.delete), onPressed: () => excluir(index)),
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
