import 'package:flutter/material.dart';
import '../services/api_service.dart';

class DeciderScreen extends StatelessWidget {
  const DeciderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, dynamic>?>(
      valueListenable: ApiService.usuarioLogadoNotifier,
      builder: (context, usuario, _) {
        // ✨ LÓGICA DE DIRECIONAMENTO ATUALIZADA
        Future.microtask(() {
          if (!ApiService.isLogado) {
            Navigator.pushReplacementNamed(context, '/login');
          } else if (ApiService.precisaAlterarSenha) {
            Navigator.pushReplacementNamed(context, '/alterar-senha-obrigatoria');
          } else if (ApiService.isLojaOnline) {
            Navigator.pushReplacementNamed(context, '/simulacao-online');
          } else {
            Navigator.pushReplacementNamed(context, '/simulacao');
          }
        });

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        );
      },
    );
  }
}