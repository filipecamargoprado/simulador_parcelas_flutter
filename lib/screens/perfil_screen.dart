import 'package:flutter/material.dart';
import '../components/app_scaffold.dart';
import '../utils/theme.dart';

class PerfilScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const PerfilScreen({super.key, required this.usuario});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final TextEditingController atualSenha = TextEditingController();
  final TextEditingController novaSenha1 = TextEditingController();
  final TextEditingController novaSenha2 = TextEditingController();
  bool mostrarSenha = false;

  @override
  Widget build(BuildContext context) {
    final usuario = widget.usuario;

    return AppScaffold(
      title: 'Meu Perfil',
      isAdmin: true,
      usuario: usuario,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Dados do Usuário',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('Nome: ${usuario['nome']}', style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.email, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('E-mail: ${usuario['email']}', style: const TextStyle(fontSize: 16)),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Alterar Senha',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: atualSenha,
              decoration: const InputDecoration(labelText: 'Senha Atual'),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: novaSenha1,
              decoration: InputDecoration(
                labelText: 'Nova Senha',
                suffixIcon: IconButton(
                  icon: Icon(mostrarSenha ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => mostrarSenha = !mostrarSenha),
                ),
              ),
              obscureText: !mostrarSenha,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: novaSenha2,
              decoration: InputDecoration(
                labelText: 'Confirmar Nova Senha',
                suffixIcon: IconButton(
                  icon: Icon(mostrarSenha ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => mostrarSenha = !mostrarSenha),
                ),
              ),
              obscureText: !mostrarSenha,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                if (atualSenha.text != usuario['senha']) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Senha atual incorreta.')),
                  );
                } else if (novaSenha1.text.isEmpty || novaSenha2.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Nova senha não pode estar vazia.')),
                  );
                } else if (novaSenha1.text != novaSenha2.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ As novas senhas não coincidem.')),
                  );
                } else {
                  atualSenha.clear();
                  novaSenha1.clear();
                  novaSenha2.clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Senha alterada com sucesso!')),
                  );
                }
              },
              style: AppButtonStyle.primaryButton,
              child: const Text('Salvar Alterações'),
            ),
          ],
        ),
      ),
    );
  }
}
