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
import 'package:simulador_parcelas_jufap/screens/simulacao_screen_online.dart';
import 'package:simulador_parcelas_jufap/services/api_service.dart';
import 'package:simulador_parcelas_jufap/components/protegido_por_admin.dart';
import 'package:simulador_parcelas_jufap/utils/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();
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
        '/cadastro-produto': (_) => ProtegidoPorAdmin(
          child: CadastroProdutoScreen(
            usuario: ApiService.usuarioLogado!,
            isAdmin: ApiService.isAdmin,
          ),
        ),
        '/cadastro-usuario': (_) => ProtegidoPorAdmin(
          child: CadastroUsuarioScreen(
            usuario: ApiService.usuarioLogado!,
            isAdmin: ApiService.isAdmin,
            isSuperAdmin : ApiService.isSuperAdmin,
          ),
        ),
        '/historico': (_) => const HistoricoScreen(),
        '/perfil': (_) => PerfilScreen(
          usuario: ApiService.usuarioLogado!,
          isAdmin: ApiService.isAdmin,
        ),
        '/simulacao-online': (_) => SimulacaoScreenOnline(
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
