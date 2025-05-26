import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final bool showDrawer;
  final bool isAdmin;
  final Map<String, dynamic> usuario;

  const AppScaffold({
    super.key,
    required this.title,
    required this.child,
    this.showDrawer = true,
    required this.isAdmin,
    required this.usuario,
  });

  @override
  Widget build(BuildContext context) {
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
                    backgroundImage:
                    AssetImage('assets/images/logo_jufap.jpeg'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          usuario['nome'] ?? 'Usuário',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          usuario['email'] ?? '',
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
              onTap: () =>
                  Navigator.pushReplacementNamed(context, '/simulacao'),
            ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.shopping_cart),
                title: const Text('Cadastro de Produto'),
                onTap: () => Navigator.pushReplacementNamed(
                    context, '/cadastro-produto'),
              ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.person_add),
                title: const Text('Cadastro de Usuário'),
                onTap: () => Navigator.pushReplacementNamed(
                    context, '/cadastro-usuario'),
              ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Histórico de Simulações'),
              onTap: () =>
                  Navigator.pushReplacementNamed(context, '/historico'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Perfil'),
              onTap: () =>
                  Navigator.pushReplacementNamed(context, '/perfil'),
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
  }
}
