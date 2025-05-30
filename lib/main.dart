import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_storage/get_storage.dart';
import 'package:simulador_parcelas_jufap/screens/decider_screen.dart';
import 'package:simulador_parcelas_jufap/screens/cadastro_produto_screen.dart';
import 'package:simulador_parcelas_jufap/screens/cadastro_usuario_screen.dart';
import 'package:simulador_parcelas_jufap/screens/historico_screen.dart';
import 'package:simulador_parcelas_jufap/screens/login_screen.dart';
import 'package:simulador_parcelas_jufap/screens/perfil_screen.dart';
import 'package:simulador_parcelas_jufap/screens/simulacao_screen.dart';
import 'package:simulador_parcelas_jufap/screens/alterar_senha_obrigatoria_screen.dart';
import 'package:simulador_parcelas_jufap/services/api_service.dart';
import 'package:simulador_parcelas_jufap/utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
  //await GetStorage().erase(); // ⚠️ Limpa todos os dados salvos (NÃO USAR EM PRODUÇÃO)
  await dotenv.load(fileName: '.env');
  await ApiService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jufap Simulador Parcelas',
      theme: appTheme,
      home: const DeciderScreen(),
      routes: {
        '/login': (_) => const LoginScreen(),
        '/simulacao': (_) => SimulacaoScreen(
          usuario: ApiService.usuarioLogado!,
          isAdmin: ApiService.isAdmin,
        ),
        '/cadastro-produto': (_) => CadastroProdutoScreen(
          usuario: ApiService.usuarioLogado!,
          isAdmin: ApiService.isAdmin,
        ),
        '/cadastro-usuario': (_) => CadastroUsuarioScreen(
          usuario: ApiService.usuarioLogado!,
          isAdmin: ApiService.isAdmin,
        ),
        '/historico': (_) => HistoricoScreen(
          usuario: ApiService.usuarioLogado!,
          isAdmin: ApiService.isAdmin,
        ),
        '/perfil': (_) => PerfilScreen(
          usuario: ApiService.usuarioLogado!,
          isAdmin: ApiService.isAdmin,
        ),
        '/alterar-senha-obrigatoria': (_) => AlterarSenhaObrigatoriaScreen(
          usuario: ApiService.usuarioLogado!,
        ),
      },
    );
  }
}
