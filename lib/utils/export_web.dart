import 'dart:html' as html;
// TODO: Migrar para 'package:web' quando dart:html for removido de vez.

Future<void> salvarEExportarArquivo(String nomeArquivo, List<int> bytes) async {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", nomeArquivo)
    ..click();
  html.Url.revokeObjectUrl(url);
}