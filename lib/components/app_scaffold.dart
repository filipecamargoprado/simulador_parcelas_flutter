import 'package:flutter/material.dart';
import '../screens/login_screen.dart';
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
          children: [
            Container(
              color: AppColors.primary,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundImage: AssetImage('assets/images/logo_jufap.jpeg'),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(usuario['nome'] ?? 'Usuário',
                          style: const TextStyle(color: Colors.white)),
                      Text(usuario['email'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Simulação de Parcelas'),
              onTap: () => Navigator.pushReplacementNamed(context, '/simulacao'),
            ),
            if (isAdmin)
              ListTile(
                title: const Text('Cadastro de Produto'),
                onTap: () => Navigator.pushReplacementNamed(context, '/cadastro-produto'),
              ),
            if (isAdmin)
              ListTile(
                title: const Text('Cadastro de Usuário'),
                onTap: () => Navigator.pushReplacementNamed(context, '/cadastro-usuario'),
              ),
            ListTile(
              title: const Text('Histórico de Simulações'),
              onTap: () => Navigator.pushReplacementNamed(context, '/historico'),
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
      )
          : null,
      body: SafeArea(child: child),
    );
  }
}