import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DeciderScreen extends StatefulWidget {
  const DeciderScreen({super.key});

  @override
  State<DeciderScreen> createState() => _DeciderScreenState();
}

class _DeciderScreenState extends State<DeciderScreen> {
  @override
  void initState() {
    super.initState();
    _verificarLogin();
  }

  Future<void> _verificarLogin() async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (!ApiService.isLogado) {
      Navigator.pushReplacementNamed(context, '/login');
    } else if (ApiService.precisaAlterarSenha) {
      Navigator.pushReplacementNamed(context, '/alterar-senha-obrigatoria');
    } else {
      Navigator.pushReplacementNamed(context, '/simulacao');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
