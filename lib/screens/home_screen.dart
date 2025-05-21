import 'package:flutter/material.dart';
import 'cadastro_produto_screen.dart';
import 'cadastro_usuario_screen.dart';
import 'historico_screen.dart';
import 'login_screen.dart';
import 'perfil_screen.dart';
import 'simulacao_screen.dart';

class HomeScreen extends StatefulWidget {
  final bool isAdmin;
  final Map<String, dynamic> usuario;

  const HomeScreen({super.key, required this.isAdmin, required this.usuario});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  Widget get telaAtual {
    switch (_index) {
      case 0:
        return SimulacaoScreen(usuario: widget.usuario);
      case 1:
        return const CadastroProdutoScreen();
      case 2:
        return const CadastroUsuarioScreen();
      case 3:
        return PerfilScreen(usuario: widget.usuario);
      case 4:
        return HistoricoScreen(
          isAdmin: widget.isAdmin,
          usuarioLogado: widget.usuario['nome'] ?? widget.usuario['email'],
        );
      default:
        return const SizedBox();
    }
  }

  void navigateTo(int index) {
    Navigator.pop(context);
    setState(() {
      _index = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulador Parcelas Jufap', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
        backgroundColor: const Color(0xFF005BA1),
      ),
      drawer: Drawer(
        child: ListView(
          children: [
            Container(
              color: Colors.blue,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => navigateTo(widget.isAdmin ? 3 : 1),
                        child: const CircleAvatar(
                          radius: 30,
                          backgroundImage: AssetImage('assets/images/logo_jufap.jpeg'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => navigateTo(widget.isAdmin ? 3 : 1),
                        child: Text(
                          'Perfil do Usuário',
                          style: const TextStyle(color: Colors.white, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('MENU', style: TextStyle(color: Colors.white, fontSize: 12)),
                ],
              ),
            ),
            ListTile(
              title: const Text('Simulação de Parcelas'),
              onTap: () => navigateTo(0),
            ),
            if (widget.isAdmin)
              ListTile(
                title: const Text('Cadastro de Produto'),
                onTap: () => navigateTo(1),
              ),
            if (widget.isAdmin)
              ListTile(
                title: const Text('Cadastro de Usuário'),
                onTap: () => navigateTo(2),
              ),
            ListTile(
              title: const Text('Histórico de Simulações'),
              onTap: () => navigateTo(4),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Sair'),
              onTap: () {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                );
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: telaAtual,
        ),
      ),
    );
  }
}
