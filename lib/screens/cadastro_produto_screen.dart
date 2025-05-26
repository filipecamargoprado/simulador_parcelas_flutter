import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../components/app_scaffold.dart';
import '../utils/theme.dart';

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

  @override
  void initState() {
    super.initState();
    buscaController.addListener(_filtrarProdutos);
    Future.microtask(_carregarProdutos);
  }

  Future<void> _carregarProdutos() async {
    try {
      final lista = await ApiService.getProdutos();
      setState(() {
        produtos = List<Map<String, dynamic>>.from(lista);
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erro ao carregar produtos')),
      );
    }
  }

  void _filtrarProdutos() {
    final query = buscaController.text.toLowerCase();
    setState(() {
      produtos = produtos.where((p) {
        final nome = '${p['marca']} ${p['modelo']}'.toLowerCase();
        return nome.contains(query);
      }).toList();
    });
  }

  void salvar() async {
    final marca = marcaController.text.trim();
    final modelo = modeloController.text.trim();
    final cmv = cmvController.text.trim();

    if (marca.isEmpty || modelo.isEmpty || cmv.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Preencha todos os campos')),
      );
      return;
    }

    final produto = {'marca': marca, 'modelo': modelo, 'cmv': cmv};

    try {
      if (editIndex != null) {
        final id = produtos[editIndex!]['id'];
        await ApiService.atualizarProduto(id, produto);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Produto atualizado com sucesso')),
        );
      } else {
        await ApiService.salvarProduto(produto);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Produto salvo com sucesso')),
        );
      }

      marcaController.clear();
      modeloController.clear();
      cmvController.clear();
      editIndex = null;
      _carregarProdutos();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erro ao salvar produto')),
      );
    }
  }

  void editar(int index) {
    final produto = produtos[index];
    setState(() {
      marcaController.text = produto['marca'];
      modeloController.text = produto['modelo'];
      cmvController.text = produto['cmv'].toString();
      editIndex = index;
    });
  }

  void excluir(int index) async {
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
        _carregarProdutos();
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Cadastro de Produto',
      usuario: widget.usuario,
      isAdmin: widget.isAdmin,
      child: SingleChildScrollView(
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
            const Text('Produtos Cadastrados', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: produtos.length,
              itemBuilder: (context, index) {
                final p = produtos[index];
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
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => editar(index)),
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
    );
  }
}
