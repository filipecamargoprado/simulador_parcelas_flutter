import 'package:flutter/material.dart';
import '../components/app_scaffold.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';

class PerfilScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final bool isAdmin;

  const PerfilScreen({
    super.key,
    required this.usuario,
    required this.isAdmin,
  });

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  final atualSenha = TextEditingController();
  final novaSenha1 = TextEditingController();
  final novaSenha2 = TextEditingController();
  bool mostrarSenha = false;
  bool carregando = false;

  bool erroSenhaAtual = false;
  bool erroNovaSenha = false;
  bool erroConfirmaSenha = false;

  Future<void> salvarSenha() async {
    final senhaAtual = atualSenha.text.trim();
    final nova1 = novaSenha1.text.trim();
    final nova2 = novaSenha2.text.trim();

    setState(() {
      erroSenhaAtual = senhaAtual.isEmpty;
      erroNovaSenha = nova1.isEmpty || !validaSenha(nova1);
      erroConfirmaSenha = nova2.isEmpty || nova1 != nova2;
    });

    if (erroSenhaAtual || erroNovaSenha || erroConfirmaSenha) {
      return;
    }

    setState(() => carregando = true);

    try {
      await ApiService.alterarSenha(
        id: widget.usuario['id'],
        senhaAtual: senhaAtual,
        novaSenha: nova1,
      );
      atualSenha.clear();
      novaSenha1.clear();
      novaSenha2.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Senha alterada com sucesso')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erro ao alterar senha. Verifique a senha atual.')),
      );
    } finally {
      setState(() => carregando = false);
    }
  }

  bool validaSenha(String senha) {
    final hasUppercase = senha.contains(RegExp(r'[A-Z]'));
    final hasSpecial = senha.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return senha.length >= 4 && hasUppercase && hasSpecial;
  }

  @override
  Widget build(BuildContext context) {
    final usuario = widget.usuario;

    return AppScaffold(
      title: 'Meu Perfil',
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
                Expanded(
                  child: Text(
                    'Nome: ${usuario['nome']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.email, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'E-mail: ${usuario['email']}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
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
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Senha Atual',
                errorText: erroSenhaAtual ? 'Preencha a senha atual' : null,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: novaSenha1,
              obscureText: !mostrarSenha,
              decoration: InputDecoration(
                labelText: 'Nova Senha',
                suffixIcon: IconButton(
                  icon: Icon(mostrarSenha ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => mostrarSenha = !mostrarSenha),
                ),
                errorText: erroNovaSenha
                    ? 'Mínimo 4 caracteres, 1 maiúscula e 1 caractere especial'
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: novaSenha2,
              obscureText: !mostrarSenha,
              decoration: InputDecoration(
                labelText: 'Confirmar Nova Senha',
                suffixIcon: IconButton(
                  icon: Icon(mostrarSenha ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => mostrarSenha = !mostrarSenha),
                ),
                errorText: erroConfirmaSenha ? 'As senhas não coincidem' : null,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => salvarSenha(), // 🔥 Aqui é o enter funcionando!
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: carregando ? null : salvarSenha,
              style: AppButtonStyle.primaryButton,
              icon: const Icon(Icons.save),
              label: carregando
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Text('Salvar Alterações'),
            ),
          ],
        ),
      ),
    );
  }
}
