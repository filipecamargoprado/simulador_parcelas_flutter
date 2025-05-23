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

class CadastroProdutoScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final bool isAdmin;
  const CadastroProdutoScreen({super.key, required this.usuario, required this.isAdmin});

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
    // (mantém exatamente igual)
  }

  Future<void> _carregarProdutos() async {
    try {
      final lista = await ApiService.getProdutos();
      setState(() {
        produtosFiltrados = List<Map<String, dynamic>>.from(lista);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Não foi possível carregar os produtos.')),
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
    // (mantém igual)
  }

  void excluir(int i) async {
    // (mantém igual)
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
    return AppScaffold(
      title: 'Cadastro de Produto',
      isAdmin: widget.isAdmin,
      usuario: widget.usuario,
      child: SingleChildScrollView(
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
                  style: AppButtonStyle.primaryButton,
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
