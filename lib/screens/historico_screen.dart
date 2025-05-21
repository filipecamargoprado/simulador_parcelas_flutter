import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';

class HistoricoScreen extends StatefulWidget {
  final bool isAdmin;
  final String usuarioLogado;
  const HistoricoScreen({super.key, required this.isAdmin, required this.usuarioLogado});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  List<Map<String, dynamic>> historico = [];
  List<Map<String, dynamic>> filtrado = [];
  final buscaController = TextEditingController();
  bool carregando = true;

  @override
  void initState() {
    super.initState();
    buscaController.addListener(_filtrar);
    Future.microtask(_carregarHistorico);
  }

  Future<void> _carregarHistorico() async {
    try {
      final dados = await ApiService.getHistoricoSimulacoes();
      setState(() {
        historico = dados;
        filtrado = dados;
        carregando = false;
      });
    } catch (_) {
      setState(() => carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erro ao carregar histórico.')),
      );
    }
  }

  void _filtrar() {
    final query = buscaController.text.toLowerCase();
    setState(() {
      filtrado = historico.where((s) => s['produto'].toLowerCase().contains(query)).toList();
    });
  }

  String formatarReal(dynamic valor) {
    final doubleValue = double.tryParse(valor.toString()) ?? 0.0;
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(doubleValue);
  }

  String formatarDataHora(String iso) {
    try {
      final dataUtc = DateTime.parse(iso);
      final dataLocal = dataUtc.toLocal();
      return DateFormat('dd/MM/yyyy HH:mm').format(dataLocal);
    } catch (_) {
      return 'Data inválida';
    }
  }

  void excluir(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Registro'),
        content: const Text('Deseja realmente excluir este histórico?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.excluirSimulacao(id);
        _carregarHistorico();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Histórico excluído com sucesso.')),
        );
      } catch (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Erro ao excluir histórico.')),
        );
      }
    }
  }

  Future<void> _exportarExcel(List<Map<String, dynamic>> dados, {bool unico = false, String? nomeArquivo}) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Simulação']!;
    excel.delete('Sheet1');

    // Cabeçalho
    sheet.appendRow(<CellValue>[
      TextCellValue('Produto'),
      TextCellValue('Preço Final'),
      TextCellValue('CMV Base'),
      TextCellValue('CMV Total'),
      TextCellValue('Lucro'),
      TextCellValue('Entrada (%)'),
      TextCellValue('Parcelas'),
      TextCellValue('Tipo Parcelamento'),
      TextCellValue('Forma Pagamento'),
      TextCellValue('Total a Pagar'),
      TextCellValue('Parcelas p/ Custo'),
      TextCellValue('Criado em'),
      TextCellValue('Criado por'),
    ]);

    // Dados
    for (final item in dados) {
      sheet.appendRow(<CellValue>[
        TextCellValue(item['produto']?.toString() ?? ''),
        DoubleCellValue(double.tryParse(item['preco_venda_final']?.toString() ?? '0') ?? 0),
        DoubleCellValue(double.tryParse(item['cmv_base']?.toString() ?? '0') ?? 0),
        DoubleCellValue(double.tryParse(item['cmv_total']?.toString() ?? '0') ?? 0),
        DoubleCellValue(double.tryParse(item['lucro']?.toString() ?? '0') ?? 0),
        DoubleCellValue(double.tryParse(item['entrada']?.toString() ?? '0') ?? 0),
        IntCellValue(int.tryParse(item['parcelas']?.toString() ?? '0') ?? 0),
        TextCellValue(item['tipo_parcelamento']?.toString() ?? ''),
        TextCellValue(item['forma_pagamento']?.toString() ?? ''),
        DoubleCellValue(double.tryParse(item['total_pagar']?.toString() ?? '0') ?? 0),
        IntCellValue(int.tryParse(item['parcelas_cobrir_custo']?.toString() ?? '0') ?? 0),
        TextCellValue(formatarDataHora(item['data_hora']?.toString() ?? '')),
        TextCellValue(item['salvo_por']?.toString() ?? ''),
      ]);
    }

    final fileBytes = excel.save();
    if (fileBytes == null || fileBytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erro ao gerar arquivo Excel.')),
      );
      return;
    }

    if (kIsWeb) {
      final content = base64Encode(fileBytes);
      final anchor = html.AnchorElement(
        href: 'data:application/octet-stream;base64,$content',
      )..setAttribute('download', '${nomeArquivo ?? "simulacao_geral"}.xlsx')
        ..click();
    } else {
      final dir = await getDownloadsDirectory();
      final path = '${dir!.path}/${nomeArquivo ?? "simulacao_geral"}.xlsx';
      final file = File(path)..createSync(recursive: true);
      file.writeAsBytesSync(fileBytes);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Arquivo salvo em: $path')),
      );
    }
  }

  void _editarSimulacao(Map<String, dynamic> simulacao) {
    final nomeController = TextEditingController(text: simulacao['produto'] ?? '');
    final precoVendaController = TextEditingController(text: simulacao['preco_venda_final'].toString());
    final entradaController = TextEditingController(text: simulacao['entrada'].toString());
    final parcelasController = TextEditingController(text: simulacao['parcelas'].toString());
    final margemController = TextEditingController(text: simulacao['margem']?.toString() ?? '35');
    final jurosController = TextEditingController(text: simulacao['juros'].toString());
    String formaPagamento = simulacao['forma_pagamento'] ?? 'Pix';
    String tipoParcelamento = simulacao['tipo_parcelamento'] ?? 'Mensal';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Editar Simulação'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nomeController,
                  decoration: const InputDecoration(labelText: 'Nome do Produto'),
                ),
                TextField(
                  controller: precoVendaController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Preço de Venda Final'),
                ),
                TextField(
                  controller: entradaController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Entrada (%)'),
                ),
                TextField(
                  controller: parcelasController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Parcelas'),
                ),
                TextField(
                  controller: margemController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Margem (%)'),
                ),
                TextField(
                  controller: jurosController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Juros (%)'),
                ),
                DropdownButtonFormField<String>(
                  value: formaPagamento,
                  decoration: const InputDecoration(labelText: 'Forma de Pagamento'),
                  items: const [
                    DropdownMenuItem(value: 'Pix', child: Text('Pix')),
                    DropdownMenuItem(value: 'Dinheiro', child: Text('Dinheiro')),
                  ],
                  onChanged: (value) => formaPagamento = value!,
                ),
                DropdownButtonFormField<String>(
                  value: tipoParcelamento,
                  decoration: const InputDecoration(labelText: 'Tipo de Parcelamento'),
                  items: const [
                    DropdownMenuItem(value: 'Mensal', child: Text('Mensal')),
                    DropdownMenuItem(value: 'Quinzenal', child: Text('Quinzenal')),
                  ],
                  onChanged: (value) => tipoParcelamento = value!,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Salvar'),
              onPressed: () async {
                final double margem = double.tryParse(margemController.text) ?? 0;
                final double juros = double.tryParse(jurosController.text) ?? 0;
                final double entrada = double.tryParse(entradaController.text) ?? 0;
                final int parcelas = int.tryParse(parcelasController.text) ?? 1;
                final double precoVenda = double.tryParse(precoVendaController.text) ?? 0;

                final double cmv = double.tryParse(simulacao['cmv_base'].toString()) ?? 0;
                final campanha = 30.0;
                final custoPorBoleto = 3.5;
                final custoSaque = 3.99;
                final licencaAnual = 59.9;
                final mensalidade = 5.0;
                final parcelasReais = tipoParcelamento == 'Quinzenal' ? parcelas * 2 : parcelas;
                final custoPorBoletoTotal = custoPorBoleto * parcelasReais;
                final cmvTotal = cmv + campanha + custoSaque + licencaAnual + custoPorBoletoTotal + mensalidade;
                final precoSugerido = cmvTotal / (1 - margem / 100);

                final List<String> avisos = [];
                if (margem < 35) avisos.add('⚠️ Margem deve ser maior ou igual a 35%');
                if (juros < 19) avisos.add('⚠️ Juros deve ser maior ou igual a 19%');
                if (entrada < 20) avisos.add('⚠️ Entrada deve ser maior ou igual a 20%');
                if (parcelas > 12) avisos.add('⚠️ Parcelas devem ser menor ou igual a 12');
                if (precoVenda < precoSugerido) {
                  avisos.add('⚠️ Preço final deve ser maior ou igual ao preço de venda sugerido (${precoSugerido.toStringAsFixed(2)})');
                }

                if (avisos.isNotEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: avisos.map((e) => Text(e)).toList(),
                      ),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                  return;
                }

                final atualizado = {
                  'produto': nomeController.text.trim(),
                  'preco_venda_final': precoVenda,
                  'entrada': entrada,
                  'parcelas': parcelas,
                  'margem': margem,
                  'juros': juros,
                  'forma_pagamento': formaPagamento,
                  'tipo_parcelamento': tipoParcelamento,
                  'cmv_base': simulacao['cmv_base'],
                  'cmv_total': simulacao['cmv_total'],
                  'lucro': simulacao['lucro'],
                  'total_pagar': simulacao['total_pagar'],
                  'parcelas_cobrir_custo': simulacao['parcelas_cobrir_custo'],
                  'salvo_por': simulacao['salvo_por'],
                };

                try {
                  await ApiService.atualizarSimulacao(simulacao['id'], atualizado);
                  Navigator.of(context).pop();
                  _carregarHistorico();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Simulação atualizada com sucesso!')),
                  );
                } catch (_) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Erro ao atualizar simulação')),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6EDF9),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            width: double.infinity,
            color: Colors.white,
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              runAlignment: WrapAlignment.center,
              children: [
                const Text(
                  'Histórico de Simulações',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                ElevatedButton.icon(
                  onPressed: () => _exportarExcel(filtrado),
                  icon: const Icon(Icons.download),
                  label: const Text('Exportar Todos'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: buscaController,
              decoration: const InputDecoration(
                labelText: 'Buscar simulação',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(
            child: carregando
                ? const Center(child: CircularProgressIndicator())
                : filtrado.isEmpty
                ? const Center(child: Text('Nenhuma simulação encontrada.'))
                : ListView.builder(
              itemCount: filtrado.length,
              itemBuilder: (context, index) {
                final s = filtrado[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                '📱 ${s['produto']}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Wrap(
                              spacing: 4,
                              children: [
                                if (widget.isAdmin)
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _editarSimulacao(s),
                                  ),
                                if (widget.isAdmin)
                                  IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => excluir(s['id']),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.download),
                                  onPressed: () =>
                                      _exportarExcel([s], nomeArquivo: 'simulacao_${s['id']}'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('💰 Preço Final: ${formatarReal(s['preco_venda_final'])}'),
                        Text('📦 CMV Base: ${formatarReal(s['cmv_base'])}'),
                        Text('📦 CMV Total: ${formatarReal(s['cmv_total'])}'),
                        Text('💵 Lucro: ${formatarReal(s['lucro'])}'),
                        Text('Entrada: ${s['entrada']}%'),
                        Text('Parcelamento: ${s['parcelas']}x ${s['tipo_parcelamento']}'),
                        Text('Forma de Pagamento: ${s['forma_pagamento']}'),
                        Text('📈 Total a pagar: ${formatarReal(s['total_pagar'])}'),
                        Text('📊 Parcelas para cobrir o custo: ${s['parcelas_cobrir_custo']}'),
                        Text('📅 Criado em: ${formatarDataHora(s['data_hora'])}'),
                        if (s['salvo_por'] != null)
                          Text('👤 Criado por: ${s['salvo_por']}'),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
