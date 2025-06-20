import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final bool showDrawer;

  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.showDrawer = true,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: ApiService.usuarioLogadoNotifier,
      builder: (context, usuarioLogado, _) {

        final isAdmin = ApiService.isAdmin;
        final rotaAtual = ModalRoute.of(context)?.settings.name ?? '';
        final estaEmTelaProtegida = rotaAtual == '/cadastro-produto' || rotaAtual == '/cadastro-usuario';

        // Armazena o último status de admin localmente (evita redefinir a cada rebuild)
        bool? ultimoStatusAdmin;

        WidgetsBinding.instance.addPostFrameCallback((_) {
          final novoIsAdmin = usuarioLogado?['is_admin'] == 1;

          if (ultimoStatusAdmin != null && novoIsAdmin != ultimoStatusAdmin) {
            final mensagem = novoIsAdmin
                ? '✅ Acesso de administrador concedido'
                : '⚠️ Acesso de administrador removido';
            final cor = novoIsAdmin ? Colors.green : Colors.orange;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(mensagem),
                backgroundColor: cor,
                duration: const Duration(seconds: 3),
              ),
            );
          }

          ultimoStatusAdmin = novoIsAdmin;
        });

        // Atualiza as permissões dinâmicas do usuário
        ApiService.atualizarDadosUsuarioLogado().then((_) {
          final novoIsAdmin = ApiService.isAdmin;

          if (!novoIsAdmin && estaEmTelaProtegida && rotaAtual != '/simulacao') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('⚠️ Seu acesso de administrador foi revogado'),
                  backgroundColor: Colors.orange,
                ),
              );
              Navigator.of(context).pushNamedAndRemoveUntil('/simulacao', (route) => false);
            });
          }
        });

        final nome = usuarioLogado?['nome'] ?? 'Usuário';
        final email = usuarioLogado?['email'] ?? '';

        return Scaffold(
          appBar: AppBar(
            title: Text(title, style: const TextStyle(color: Colors.white)),
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          drawer: showDrawer
              ? Drawer(
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
                              nome,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              email,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                              ),
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
                  onTap: () {
                    final rota = ApiService.isLojaOnline ? '/simulacao-online' : '/simulacao';
                    Navigator.pushReplacementNamed(context, rota);
                  },
                ),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.shopping_cart),
                    title: const Text('Cadastro de Produto'),
                    onTap: () => Navigator.pushReplacementNamed(context, '/cadastro-produto'),
                  ),
                if (isAdmin)
                  ListTile(
                    leading: const Icon(Icons.person_add),
                    title: const Text('Cadastro de Usuário'),
                    onTap: () => Navigator.pushReplacementNamed(context, '/cadastro-usuario'),
                  ),
                ListTile(
                  leading: const Icon(Icons.history),
                  title: const Text('Histórico de Simulações'),
                  onTap: () => Navigator.pushReplacementNamed(context, '/historico'),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('Perfil'),
                  onTap: () => Navigator.pushReplacementNamed(context, '/perfil'),
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: const Text('Sair'),
                  onTap: () {
                    ApiService.logout();
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (route) => false,
                    );
                  },
                ),
              ],
            ),
          )
              : null,
          body: SafeArea(child: child),
        );
      },
    );
  }
}
