import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_storage/get_storage.dart';
import 'package:simulador_parcelas_jufap/screens/cadastro_produto_screen.dart';
import 'package:simulador_parcelas_jufap/screens/cadastro_usuario_screen.dart';
import 'package:simulador_parcelas_jufap/screens/historico_screen.dart';
import 'package:simulador_parcelas_jufap/screens/login_screen.dart';
import 'package:simulador_parcelas_jufap/screens/perfil_screen.dart';
import 'package:simulador_parcelas_jufap/screens/simulacao_screen.dart';
import 'package:simulador_parcelas_jufap/services/api_service.dart';
import 'package:simulador_parcelas_jufap/utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await GetStorage.init();
  await ApiService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final usuario = ApiService.usuarioLogado;
    final isAdmin = ApiService.isAdmin;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jufap Simulador Parcelas',
      theme: appTheme,
      initialRoute: usuario == null ? '/login' : '/simulacao',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/simulacao': (_) => SimulacaoScreen(usuario: usuario!, isAdmin: isAdmin),
        '/cadastro-produto': (_) => CadastroProdutoScreen(usuario: usuario!, isAdmin: isAdmin),
        '/cadastro-usuario': (_) => CadastroUsuarioScreen(usuario: usuario!, isAdmin: isAdmin),
        '/historico': (_) => HistoricoScreen(usuario: usuario!, isAdmin: isAdmin),
        '/perfil': (_) => PerfilScreen(usuario: usuario!, isAdmin: isAdmin),
      },
    );
  }
}
