import 'package:flutter/material.dart';
import 'cadastro_produto_screen.dart';
import 'cadastro_usuario_screen.dart';
import 'historico_screen.dart';
import 'login_screen.dart';
import 'perfil_screen.dart';
import 'simulacao_screen.dart';
import '../utils/theme.dart';

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
        return SimulacaoScreen(
          usuario: widget.usuario,
          isAdmin: widget.isAdmin,
        );
      case 1:
        return CadastroProdutoScreen(
          usuario: widget.usuario,
          isAdmin: widget.isAdmin,
        );
      case 2:
        return CadastroUsuarioScreen(
          usuario: widget.usuario,
          isAdmin: widget.isAdmin,
        );
      case 3:
        return PerfilScreen(
          usuario: widget.usuario,
          isAdmin: widget.isAdmin,
        );
      case 4:
        return HistoricoScreen(
          usuario: widget.usuario,
          isAdmin: widget.isAdmin,
        );
      default:
        return SimulacaoScreen(
          usuario: widget.usuario,
          isAdmin: widget.isAdmin,
        );
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
        title: const Text('Simulador Parcelas Jufap'),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: AppColors.primary,
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage('assets/images/logo_jufap.jpeg'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.usuario['nome'] ?? 'Usuário',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          widget.usuario['email'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.calculate),
              title: const Text('Simulação de Parcelas'),
              onTap: () => navigateTo(0),
            ),
            if (widget.isAdmin)
              ListTile(
                leading: const Icon(Icons.shopping_cart),
                title: const Text('Cadastro de Produto'),
                onTap: () => navigateTo(1),
              ),
            if (widget.isAdmin)
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('Cadastro de Usuário'),
                onTap: () => navigateTo(2),
              ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Histórico de Simulações'),
              onTap: () => navigateTo(4),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Perfil'),
              onTap: () => navigateTo(3),
            ),
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
