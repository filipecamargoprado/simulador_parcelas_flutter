import 'dart:io';
import 'package:excel/excel.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
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

    final dir = await getDownloadsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'produtos_$timestamp.xlsx';
    final file = File('${dir!.path}/$fileName')..createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    await OpenFile.open(file.path);
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

    final dir = await getDownloadsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final fileName = 'usuarios_$timestamp.xlsx';
    final file = File('${dir!.path}/$fileName')..createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    await OpenFile.open(file.path);
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

    final dir = await getDownloadsDirectory();
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final nome = isUsuario ? 'modelo_usuarios' : 'modelo_produtos';
    final fileName = '${nome}_$timestamp.xlsx';

    final file = File('${dir!.path}/$fileName')..createSync(recursive: true);
    file.writeAsBytesSync(bytes);
    await OpenFile.open(file.path);
  }
}
