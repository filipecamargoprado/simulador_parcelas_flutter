abstract class PlanilhaUtil {
  Future<void> gerarPlanilhaModelo({bool isUsuario = false});
  Future<void> gerarPlanilhaProdutos(List<Map<String, dynamic>> produtos);
  Future<void> gerarPlanilhaUsuarios(List<Map<String, dynamic>> usuarios);
}