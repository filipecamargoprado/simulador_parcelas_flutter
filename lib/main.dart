import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_storage/get_storage.dart';
import 'package:simulador_parcelas_jufap/screens/login_screen.dart';
import 'package:simulador_parcelas_jufap/screens/home_screen.dart';
import 'package:simulador_parcelas_jufap/utils/theme.dart';
import 'package:simulador_parcelas_jufap/services/token_storage.dart';
import 'package:simulador_parcelas_jufap/services/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env"); // 🔐 Carrega .env
  await GetStorage.init(); // 🔥 Inicializa armazenamento local
  await ApiService.testarConexao();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final token = TokenStorage.pegarToken();
    final usuario = TokenStorage.pegarUsuario();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jufap Simulador Parcelas',
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: AppButtonStyle.primaryButton,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: AppColors.primary),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.grey),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          labelStyle: const TextStyle(color: AppColors.textSecondary),
        ),
        textTheme: const TextTheme(
          titleLarge: AppTextStyles.title,
          titleMedium: AppTextStyles.subtitle,
          bodyMedium: AppTextStyles.body,
        ),
      ),
      // 🔥 Se tem token e usuário salvo → HomeScreen | Se não → Login
      home: (token != null && usuario != null)
          ? HomeScreen(
        usuario: usuario,
        isAdmin: usuario['is_admin'] == 1,
      )
          : const LoginScreen(),
    );
  }
}
