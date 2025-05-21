import 'package:flutter/material.dart';

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

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text('Meu Perfil', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Nome: ${usuario['nome']}'),
                    Text('E-mail: ${usuario['email']}'),
                    const SizedBox(height: 20),
                    const Text('Alterar Senha', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              TextField(controller: atualSenha, decoration: const InputDecoration(labelText: 'Senha Atual'), obscureText: true),
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
                    // Aqui você pode chamar o método de atualização da senha se desejar
                    atualSenha.clear();
                    novaSenha1.clear();
                    novaSenha2.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Senha alterada com sucesso!')),
                    );
                  }
                },
                child: const Text('Salvar Alterações'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
