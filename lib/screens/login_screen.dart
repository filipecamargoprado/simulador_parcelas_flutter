// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';

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
      final sucesso = await ApiService.login(email, senha);

      // Garante que o widget ainda está montado antes de navegar
      if (sucesso && mounted) {
        // Redireciona para o Decider, que centraliza a lógica de qual tela mostrar
        Navigator.pushReplacementNamed(context, '/');
      } else {
        if(mounted){
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ E-mail ou senha inválidos')),
          );
        }
      }
    } catch (e) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erro ao conectar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (O resto do seu método build continua igual)
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