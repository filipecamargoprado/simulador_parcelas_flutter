import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF00509D); // Azul Jufap
  static const Color secondary = Color(0xFFFFA500); // Amarelo
  static const Color background = Color(0xFFF5F5F5); // Fundo claro
  static const Color textPrimary = Color(0xFF333333); // Texto principal
  static const Color textSecondary = Color(0xFF666666); // Texto secundário
  static const Color success = Color(0xFF00C853); // Verde para sucesso
  static const Color error = Color(0xFFD32F2F); // Vermelho para erros
  static const Color card = Colors.white;
}

class AppTextStyles {
  static const TextStyle title = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 14,
    color: AppColors.textPrimary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );
}

class AppButtonStyle {
  static ButtonStyle primaryButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
    textStyle: AppTextStyles.button,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );

  static ButtonStyle secondaryButton = ElevatedButton.styleFrom(
    backgroundColor: AppColors.secondary,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
    textStyle: AppTextStyles.button,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    ),
  );
}