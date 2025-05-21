import 'dart:convert';
import 'dart:html' as html;
import 'package:excel/excel.dart';
import 'planilha_util_interface.dart';

class PlanilhaUtilImpl implements PlanilhaUtil {
  @override
  Future<void> gerarPlanilhaProdutos(List<Map<String, dynamic>> produtos) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Produtos']!;
    excel.delete('Sheet1');

    sheet.appendRow(<CellValue>[
      TextCellValue('marca'),
      TextCellValue('modelo'),
      TextCellValue('cmv'),
    ]);

    for (final produto in produtos) {
      sheet.appendRow(<CellValue>[
        TextCellValue(produto['marca']?.toString() ?? ''),
        TextCellValue(produto['modelo']?.toString() ?? ''),
        TextCellValue(produto['cmv']?.toString() ?? ''),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null || bytes.isEmpty) return;

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'produtos_$timestamp.xlsx';
    final base64Data = base64Encode(bytes);

    final anchor = html.AnchorElement(
      href: 'data:application/octet-stream;base64,$base64Data',
    )
      ..setAttribute('download', fileName)
      ..click();
  }

  @override
  Future<void> gerarPlanilhaUsuarios(List<Map<String, dynamic>> usuarios) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Usuarios']!;
    excel.delete('Sheet1');

    sheet.appendRow(<CellValue>[
      TextCellValue('nome'),
      TextCellValue('email'),
      TextCellValue('senha'),
    ]);

    for (final u in usuarios) {
      sheet.appendRow(<CellValue>[
        TextCellValue(u['nome']?.toString() ?? ''),
        TextCellValue(u['email']?.toString() ?? ''),
        TextCellValue(u['senha']?.toString() ?? ''),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null || bytes.isEmpty) return;

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'usuarios_$timestamp.xlsx';
    final base64Data = base64Encode(bytes);

    final anchor = html.AnchorElement(
      href: 'data:application/octet-stream;base64,$base64Data',
    )
      ..setAttribute('download', fileName)
      ..click();
  }

  @override
  Future<void> gerarPlanilhaModelo({bool isUsuario = false}) async {
    final excel = Excel.createExcel();
    final nomeAba = isUsuario ? 'Usuarios' : 'Produtos';
    final Sheet sheet = excel[nomeAba]!;
    excel.delete('Sheet1');

    if (isUsuario) {
      sheet.appendRow(<CellValue>[
        TextCellValue('nome'),
        TextCellValue('email'),
        TextCellValue('senha'),
      ]);
    } else {
      sheet.appendRow(<CellValue>[
        TextCellValue('marca'),
        TextCellValue('modelo'),
        TextCellValue('cmv'),
      ]);
    }

    final bytes = excel.save();
    if (bytes == null || bytes.isEmpty) return;

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = isUsuario ? 'modelo_usuarios_$timestamp.xlsx' : 'modelo_produtos_$timestamp.xlsx';
    final base64Data = base64Encode(bytes);

    final anchor = html.AnchorElement(
      href: 'data:application/octet-stream;base64,$base64Data',
    )
      ..setAttribute('download', fileName)
      ..click();
  }
}
