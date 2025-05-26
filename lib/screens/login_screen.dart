import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  bool carregando = false;

  void fazerLogin() async {
    final email = emailController.text.trim();
    final senha = senhaController.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Preencha e-mail e senha')),
      );
      return;
    }

    setState(() => carregando = true);

    try {
      final usuarios = await ApiService.getUsuarios();
      final usuarioEncontrado = usuarios.firstWhere(
            (u) => u['email'] == email && u['senha'] == senha,
        orElse: () => null,
      );

      if (usuarioEncontrado != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => HomeScreen(
              usuario: usuarioEncontrado,
              isAdmin: usuarioEncontrado['is_admin'] == 1,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Usuário ou senha inválidos')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erro ao conectar com o servidor')),
      );
    } finally {
      setState(() => carregando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6F0F8),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          width: 400,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 10),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/logo_jufap.jpeg', height: 80),
              const SizedBox(height: 20),
              const Text(
                'Login',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'E-mail'),
                textInputAction: TextInputAction.next,
              ),
              TextField(
                controller: senhaController,
                decoration: const InputDecoration(labelText: 'Senha'),
                obscureText: true,
                onSubmitted: (_) => fazerLogin(),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: carregando ? null : fazerLogin,
                style: AppButtonStyle.primaryButton,
                child: carregando
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text('Entrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
