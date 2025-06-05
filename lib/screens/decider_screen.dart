import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DeciderScreen extends StatelessWidget {
  const DeciderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: ApiService.usuarioLogadoNotifier,
      builder: (context, usuario, _) {
        // Aguarda carregar
        if (usuario == null && !ApiService.isLogado) {
          Future.microtask(() {
            Navigator.pushReplacementNamed(context, '/login');
          });
        } else if (ApiService.precisaAlterarSenha) {
          Future.microtask(() {
            Navigator.pushReplacementNamed(context, '/alterar-senha-obrigatoria');
          });
        } else {
          Future.microtask(() {
            Navigator.pushReplacementNamed(context, '/simulacao');
          });
        }

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}