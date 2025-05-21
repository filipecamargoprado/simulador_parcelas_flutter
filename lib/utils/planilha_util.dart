import 'package:flutter/foundation.dart' show kIsWeb;
import 'planilha_util_interface.dart';

// Importa a implementação correta com base na plataforma
import 'planilha_util_io.dart'
if (dart.library.html) 'planilha_util_web.dart';

/// Retorna a implementação de PlanilhaUtil correta para a plataforma (web ou IO)
PlanilhaUtil getPlanilhaUtil() => PlanilhaUtilImpl();