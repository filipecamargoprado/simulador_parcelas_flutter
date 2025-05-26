import 'package:flutter/material.dart';
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
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  final buscaController = TextEditingController();

  List usuarios = [];
  List usuariosOriginais = [];
  int? editingIndex;

  @override
  void initState() {
    super.initState();
    buscaController.addListener(_filtrarUsuarios);
    Future.microtask(() => carregarUsuarios());
  }

  Future<void> carregarUsuarios({String filtro = ''}) async {
    try {
      final todos = await ApiService.getUsuarios();
      setState(() {
        usuarios = todos;
        usuariosOriginais = todos;
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
    });
  }

  void salvarUsuario() async {
    final nome = nomeController.text.trim();
    final email = emailController.text.trim();
    final senha = senhaController.text.trim();

    if (nome.isEmpty || email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Preencha todos os campos')),
      );
      return;
    }

    if (!email.contains('@') || !email.contains('.')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ E-mail inválido')),
      );
      return;
    }

    if (senha.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ A senha deve ter no mínimo 4 caracteres')),
      );
      return;
    }

    final user = {'nome': nome, 'email': email, 'senha': senha};

    try {
      if (editingIndex != null) {
        final id = usuarios[editingIndex!]['id'];
        await ApiService.atualizarUsuario(id, user);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Usuário atualizado com sucesso')),
        );
      } else {
        await ApiService.salvarUsuario(user);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Usuário salvo com sucesso')),
        );
      }

      nomeController.clear();
      emailController.clear();
      senhaController.clear();
      editingIndex = null;
      carregarUsuarios();
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erro ao salvar usuário')),
      );
    }
  }

  void editarUsuario(int index) {
    final u = usuarios[index];
    setState(() {
      nomeController.text = u['nome'];
      emailController.text = u['email'];
      senhaController.clear();
      editingIndex = index;
    });
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
        carregarUsuarios();
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Cadastro de Usuário',
      isAdmin: widget.isAdmin,
      usuario: widget.usuario,
      child: SingleChildScrollView(
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
                        IconButton(icon: const Icon(Icons.edit), onPressed: () => editarUsuario(index)),
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
    );
  }
}
