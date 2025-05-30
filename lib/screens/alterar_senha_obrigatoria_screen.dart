import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

class AlterarSenhaObrigatoriaScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;

  const AlterarSenhaObrigatoriaScreen({super.key, required this.usuario});

  @override
  State<AlterarSenhaObrigatoriaScreen> createState() =>
      _AlterarSenhaObrigatoriaScreenState();
}

class _AlterarSenhaObrigatoriaScreenState
    extends State<AlterarSenhaObrigatoriaScreen> {
  final senhaAtualController = TextEditingController();
  final novaSenhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();
  bool carregando = false;
  bool mostrarSenha = false;

  bool erroSenhaAtual = false;
  bool erroNovaSenha = false;
  bool erroConfirmaSenha = false;

  bool validaSenha(String senha) {
    final hasUppercase = senha.contains(RegExp(r'[A-Z]'));
    final hasSpecial = senha.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    return senha.length >= 4 && hasUppercase && hasSpecial;
  }

  void alterarSenha() async {
    final senhaAtual = senhaAtualController.text.trim();
    final novaSenha = novaSenhaController.text.trim();
    final confirmarSenha = confirmarSenhaController.text.trim();

    setState(() {
      erroSenhaAtual = senhaAtual.isEmpty;
      erroNovaSenha = novaSenha.isEmpty || !validaSenha(novaSenha);
      erroConfirmaSenha = confirmarSenha.isEmpty || novaSenha != confirmarSenha;
    });

    if (erroSenhaAtual || erroNovaSenha || erroConfirmaSenha) {
      return;
    }

    setState(() => carregando = true);

    try {
      await ApiService.alterarSenha(
        id: widget.usuario['id'],
        senhaAtual: senhaAtual,
        novaSenha: novaSenha,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Senha alterada com sucesso')),
      );

      Navigator.pushReplacementNamed(context, '/simulacao');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erro: ${e.toString()}')),
      );
    } finally {
      setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alteração Obrigatória de Senha'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Olá ${widget.usuario['nome']},\n'
                  'Por segurança, você precisa alterar sua senha padrão.',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: senhaAtualController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Senha Atual',
                errorText: erroSenhaAtual ? 'Preencha a senha atual' : null,
              ),
            ),
            TextField(
              controller: novaSenhaController,
              obscureText: !mostrarSenha,
              decoration: InputDecoration(
                labelText: 'Nova Senha',
                suffixIcon: IconButton(
                  icon: Icon(
                      mostrarSenha ? Icons.visibility : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => mostrarSenha = !mostrarSenha),
                ),
                errorText: erroNovaSenha
                    ? 'Mínimo 4 caracteres, 1 maiúscula e 1 caractere especial'
                    : null,
              ),
            ),
            TextField(
              controller: confirmarSenhaController,
              obscureText: !mostrarSenha,
              decoration: InputDecoration(
                labelText: 'Confirmar Nova Senha',
                suffixIcon: IconButton(
                  icon: Icon(
                      mostrarSenha ? Icons.visibility : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => mostrarSenha = !mostrarSenha),
                ),
                errorText: erroConfirmaSenha ? 'As senhas não coincidem' : null,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => alterarSenha(), // 🔥 Aqui é o enter funcionando!
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: carregando ? null : alterarSenha,
              icon: const Icon(Icons.lock_reset),
              label: carregando
                  ? const Text('Salvando...')
                  : const Text('Alterar Senha'),
              style: AppButtonStyle.primaryButton,
            ),
          ],
        ),
      ),
    );
  }
}
