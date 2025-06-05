import 'package:flutter/material.dart';
import '../services/api_service.dart';

class ProtegidoPorAdmin extends StatelessWidget {
  final Widget child;

  const ProtegidoPorAdmin({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!ApiService.isAdmin) {
      Future.microtask(() {
        Navigator.of(context).pushReplacementNamed('/simulacao');
      });
      return const SizedBox.shrink();
    }

    return child;
  }
}
