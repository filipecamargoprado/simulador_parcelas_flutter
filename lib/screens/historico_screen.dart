import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import '../services/api_service.dart';
import '../components/app_scaffold.dart';
import '../utils/theme.dart';
import 'dart:math';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

class _HistoricoScreenState extends State<HistoricoScreen> {
  List<Map<String, dynamic>> historico = [];
  List<Map<String, dynamic>> filtrado = [];
  final buscaController = TextEditingController();
  bool carregando = true;
  bool modoExportacao = false;
  bool todosSelecionados = false;
  List<bool> selecionados = [];

  @override
  void initState() {
    super.initState();
    buscaController.addListener(_filtrar);
    Future.microtask(_carregarHistorico);
  }

  Future<T> executarComLoading<T>(Future<T> Function() acao) async {
    bool dialogAberto = false;
    try {
      showDialog(context: context, barrierDismissible: false, builder: (_) {
        dialogAberto = true;
        return const Dialog(backgroundColor: Colors.transparent, child: Center(child: CircularProgressIndicator()));
      });
      return await acao();
    } finally {
      if (dialogAberto && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _carregarHistorico() async {
    try {
      if (!mounted) return;
      setState(() => carregando = true);
      final dados = await ApiService.getHistoricoSimulacoes();
      if (!mounted) return;

      setState(() {
        historico = dados;
        filtrado = dados;
        selecionados = List<bool>.filled(dados.length, false);
        modoExportacao = false;
        carregando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => carregando = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erro ao carregar histórico: $e')));
    }
  }

  void _filtrar() {
    final query = buscaController.text.toLowerCase();
    setState(() {
      filtrado = historico.where((s) {
        return (s['produto']?.toString().toLowerCase() ?? '').contains(query) ||
            (s['salvo_por']?.toString().toLowerCase() ?? '').contains(query);
      }).toList();
      selecionados = List<bool>.filled(filtrado.length, false);
      todosSelecionados = false;
    });
  }

  String formatarReal(dynamic valor) {
    if (valor == null) return 'N/A';
    final doubleValue = double.tryParse(valor.toString());
    if (doubleValue == null) return 'N/A';
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(doubleValue);
  }

  String formatarDataHora(String? iso) {
    if (iso == null) return 'Data inválida';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return 'Data inválida';
    }
  }

  void editar(Map<String, dynamic> simulacao) async {
    bool isRegistroFisico = simulacao['valor_parcela_10x'] != null;

    final cmvTotal = double.tryParse(simulacao['cmv_total'].toString()) ?? 0.0;

    final precoController = TextEditingController(text: simulacao['preco_venda_final'].toString());
    final parcelasController = TextEditingController(text: simulacao['parcelas'].toString());
    final jurosController = TextEditingController(text: simulacao['juros'].toString());
    final entradaController = TextEditingController(text: simulacao['entrada'].toString());
    final margemController = TextEditingController(text: simulacao['margem'].toString());

    String tipoParcelamento = simulacao['tipo_parcelamento'] ?? 'Mensal';
    String formaPagamento = simulacao['forma_pagamento'] ?? 'Pix';

    // Variável para controlar a mensagem de erro dentro do dialog
    String? errorMessage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (context, setStateInDialog) {
              return AlertDialog(
                title: Text('Editar Simulação ${isRegistroFisico ? "Física" : "Online"}'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ✨ EXIBIÇÃO DA MENSAGEM DE ERRO DENTRO DO DIALOG ✨
                      if (errorMessage != null) ...[
                        Text(errorMessage!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 10),
                      ],
                      TextField(controller: precoController, decoration: const InputDecoration(labelText: 'Preço Venda Final'), keyboardType: TextInputType.number),
                      if (!isRegistroFisico) ...[
                        TextField(controller: margemController, decoration: const InputDecoration(labelText: 'Margem (%)'), keyboardType: TextInputType.number),
                        TextField(controller: parcelasController, decoration: const InputDecoration(labelText: 'Parcelas'), keyboardType: TextInputType.number),
                        TextField(controller: jurosController, decoration: const InputDecoration(labelText: 'Juros (%)'), keyboardType: TextInputType.number),
                        TextField(controller: entradaController, decoration: const InputDecoration(labelText: 'Entrada (%)'), keyboardType: TextInputType.number),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: formaPagamento,
                          decoration: const InputDecoration(labelText: 'Forma de Pagamento da Entrada'),
                          items: ['Pix', 'Dinheiro'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setStateInDialog(() => formaPagamento = v!),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: tipoParcelamento,
                          decoration: const InputDecoration(labelText: 'Tipo de Parcelamento'),
                          items: ['Mensal', 'Quinzenal'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (v) => setStateInDialog(() => tipoParcelamento = v!),
                        ),
                      ]
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                  TextButton(
                    onPressed: () async {
                      final precoVenda = double.tryParse(precoController.text) ?? 0.0;
                      final margem = double.tryParse(margemController.text) ?? 0.0;

                      final precoSugerido = (cmvTotal / (1 - (35 / 100))).floorToDouble();

                      // ✨ LÓGICA DE VALIDAÇÃO AJUSTADA PARA ATUALIZAR O ESTADO DO DIALOG ✨
                      if (precoVenda < precoSugerido) {
                        setStateInDialog(() => errorMessage = 'Preço final deve ser ≥ ${formatarReal(precoSugerido)}');
                        return;
                      }
                      if (!isRegistroFisico) {
                        final parcelas = int.tryParse(parcelasController.text) ?? 0;
                        final juros = double.tryParse(jurosController.text) ?? 0.0;
                        final entrada = double.tryParse(entradaController.text) ?? 0.0;

                        if (margem < 35) { setStateInDialog(() => errorMessage = 'Margem deve ser no mínimo 35%'); return; }
                        if (juros < 19) { setStateInDialog(() => errorMessage = 'Juros deve ser no mínimo 19%'); return; }
                        if (entrada < 20) { setStateInDialog(() => errorMessage = 'Entrada deve ser no mínimo 20%'); return; }
                        if (parcelas > 12 || parcelas <= 0) { setStateInDialog(() => errorMessage = 'Parcelas deve ser entre 1 e 12'); return; }
                      }

                      // Se passar por todas as validações, limpa a mensagem de erro
                      setStateInDialog(() => errorMessage = null);

                      final novosDados = {
                        'preco_venda_final': precoVenda,
                        'parcelas': int.tryParse(parcelasController.text) ?? simulacao['parcelas'],
                        'juros': double.tryParse(jurosController.text) ?? simulacao['juros'],
                        'entrada': double.tryParse(entradaController.text) ?? simulacao['entrada'],
                        'margem': margem,
                        'tipo_parcelamento': tipoParcelamento,
                        'forma_pagamento': formaPagamento,
                      };

                      Navigator.pop(context);
                      await executarComLoading(() async {
                        try {
                          await ApiService.atualizarSimulacao(simulacao['id'], novosDados);
                          await _carregarHistorico();
                          if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Simulação atualizada com sucesso!'), backgroundColor: Colors.green));
                        } catch(e) {
                          if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Erro ao atualizar: $e'), backgroundColor: Colors.red));
                        }
                      });
                    },
                    child: const Text('Salvar'),
                  ),
                ],
              );
            }
        );
      },
    );
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
      await executarComLoading(() async {
        try {
          await ApiService.excluirSimulacao(id);
          await _carregarHistorico();
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('✅ Histórico excluído com sucesso.')));
        } catch (_) {
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Erro ao excluir histórico.')));
        }
      });
    }
  }

  // ✨ MÉTODO EXPORTAR SELECIONADOS IMPLEMENTADO ✨
  Future<void> exportarSelecionados() async {
    final itensSelecionados = <Map<String, dynamic>>[];
    for (int i = 0; i < filtrado.length; i++) {
      if (selecionados.length > i && selecionados[i]) {
        itensSelecionados.add(filtrado[i]);
      }
    }

    if (itensSelecionados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhuma simulação selecionada para exportar.')));
      return;
    }

    await executarComLoading(() async {
      final excel = Excel.createExcel();
      final Sheet sheet = excel['Historico'];
      excel.delete('Sheet1');

      final headers = <String>['Produto', 'Preço Final', 'Criado Por', 'Data', 'Tipo de Loja'];
      bool temFisico = itensSelecionados.any((s) => s['valor_parcela_10x'] != null);
      bool temOnline = itensSelecionados.any((s) => s['valor_parcela_10x'] == null);

      if (temFisico) headers.addAll(['Parcela 10x', 'Parcela 12x']);
      if (temOnline) headers.addAll(['Lucro', 'Total Venda', 'Num Parcelas']);

      sheet.appendRow(headers.map((item) => TextCellValue(item)).toList());

      for (final s in itensSelecionados) {
        bool isRegistroFisico = s['valor_parcela_10x'] != null;

        final row = <CellValue>[
          TextCellValue(s['produto'] ?? ''),
          TextCellValue(formatarReal(s['preco_venda_final'])),
          TextCellValue(s['salvo_por'] ?? ''),
          TextCellValue(formatarDataHora(s['data_hora'])),
          TextCellValue(isRegistroFisico ? 'Física' : 'Online'),
        ];

        if (temFisico) {
          row.add(isRegistroFisico ? TextCellValue(formatarReal(s['valor_parcela_10x'])) : TextCellValue(''));
          row.add(isRegistroFisico ? TextCellValue(formatarReal(s['valor_parcela_12x'])) : TextCellValue(''));
        }
        if (temOnline) {
          row.add(!isRegistroFisico ? TextCellValue(formatarReal(s['lucro'])) : TextCellValue(''));
          row.add(!isRegistroFisico ? TextCellValue(formatarReal(s['total_venda'])) : TextCellValue(''));
          row.add(!isRegistroFisico ? TextCellValue(s['parcelas']?.toString() ?? '') : TextCellValue(''));
        }
        sheet.appendRow(row);
      }

      final bytes = excel.save();
      if (bytes != null) {
        final directory = await getApplicationDocumentsDirectory();
        final path = '${directory.path}/historico_simulacoes_${DateTime.now().millisecondsSinceEpoch}.xlsx';
        final file = File(path);
        await file.writeAsBytes(bytes, flush: true);
        await OpenFile.open(path);
      }
    });
  }

  // ✨ MÉTODO EXCLUIR SELECIONADOS IMPLEMENTADO ✨
  Future<void> excluirSelecionados() async {
    final idsParaExcluir = <int>[];
    for (int i = 0; i < filtrado.length; i++) {
      if (selecionados.length > i && selecionados[i]) {
        idsParaExcluir.add(filtrado[i]['id'] as int);
      }
    }
    if (idsParaExcluir.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nenhum item selecionado.')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Excluir Selecionados'),
        content: Text('Deseja realmente excluir os ${idsParaExcluir.length} itens selecionados?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
        ],
      ),
    );

    if (confirm == true) {
      await executarComLoading(() async {
        try {
          for (final id in idsParaExcluir) {
            await ApiService.excluirSimulacao(id);
          }
          await _carregarHistorico();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('✅ ${idsParaExcluir.length} itens excluídos.')));
        } catch (_) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('❌ Erro ao excluir itens.')));
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // O método build permanece o mesmo da resposta anterior, pois sua estrutura já está correta.
    return AppScaffold(
      title: 'Histórico de Simulações',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(child: TextField(controller: buscaController, decoration: const InputDecoration(labelText: 'Buscar simulação', prefixIcon: Icon(Icons.search), border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => setState(() {
                    modoExportacao = !modoExportacao;
                    selecionados = List<bool>.filled(filtrado.length, false);
                    todosSelecionados = false;
                  }),
                  icon: const Icon(Icons.checklist),
                  label: Text(modoExportacao ? 'Cancelar' : 'Selecionar'),
                  style: AppButtonStyle.primaryButton,
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _carregarHistorico,
              child: carregando
                  ? const Center(child: CircularProgressIndicator())
                  : filtrado.isEmpty
                  ? Center(child: Text('Nenhuma simulação encontrada.', style: Theme.of(context).textTheme.titleMedium))
                  : ListView.builder(
                itemCount: filtrado.length,
                itemBuilder: (context, index) {
                  final s = filtrado[index];
                  bool isRegistroFisico = s['valor_parcela_10x'] != null;

                  final precoVendaFinal = double.tryParse(s['preco_venda_final'].toString()) ?? 0.0;
                  final entradaPercent = double.tryParse(s['entrada'].toString()) ?? 0.0;

                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (modoExportacao)
                                Padding(
                                  padding: const EdgeInsets.only(right: 8.0, top: 8.0),
                                  child: Checkbox(
                                    value: selecionados.length > index ? selecionados[index] : false,
                                    onChanged: (v) => setState(() => selecionados[index] = v ?? false),
                                  ),
                                ),
                              Expanded(
                                child: Text('📱 ${s['produto'] ?? 'Produto não informado'}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                              if (!modoExportacao && ApiService.isAdmin)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(icon: const Icon(Icons.edit), onPressed: () => editar(s)),
                                    IconButton(icon: const Icon(Icons.delete), onPressed: () => excluir(s['id'])),
                                  ],
                                ),
                            ],
                          ),
                          const Divider(height: 20),

                          if (isRegistroFisico) ...[
                            Text('💰 Preço Final: ${formatarReal(precoVendaFinal)}'),
                            Text('📦 CMV Total: ${formatarReal(s['cmv_total'])}'),
                            Text('📉 Entrada (${entradaPercent.toStringAsFixed(0)}%): ${formatarReal(precoVendaFinal * (entradaPercent / 100))}'),
                            const SizedBox(height: 8),
                            Text('💳 Valor por Parcela (10x): ${formatarReal(s['valor_parcela_10x'])}'),
                            Text('💳 Valor por Parcela (12x): ${formatarReal(s['valor_parcela_12x'])}'),
                          ] else ...[
                            Text('💰 Preço Final: ${formatarReal(s['preco_venda_final'])}'),
                            Text('📦 CMV Base: ${formatarReal(s['cmv_base'])}'),
                            Text('📦 CMV Total: ${formatarReal(s['cmv_total'])}'),
                            Text('💵 Lucro: ${formatarReal(s['lucro'])}'),
                            Text('📈 Juros (${s['juros']}%): ${formatarReal(s['total_venda'] - precoVendaFinal)}'),
                            Text('📉 Entrada (${entradaPercent.toStringAsFixed(0)}%): ${formatarReal(precoVendaFinal * (entradaPercent / 100))}'),
                            Text('💳 Valor do Crédito: ${formatarReal(precoVendaFinal * (1 - (entradaPercent / 100)))}'),
                            Text('🧾 Valor por parcela (${s['parcelas']}x): ${formatarReal((double.tryParse(s['total_pagar'].toString()) ?? 0.0) / (int.tryParse(s['parcelas'].toString()) ?? 1))}'),
                            Text('📆 Parcelamento: ${s['parcelas']}x ${s['tipo_parcelamento']}'),
                            Text('🏦 Forma de Pagamento da Entrada: ${s['forma_pagamento']}'),
                            Text('🔢 Total a pagar: ${formatarReal(s['total_pagar'])}'),
                            Text('💰 Total da Venda: ${formatarReal(s['total_venda'])}'),
                            Text('📊 Parcelas p/ Cobrir Custo: ${s['parcelas_cobrir_custo']}'),
                          ],

                          const Divider(height: 20),
                          Text('📅 Criado em: ${formatarDataHora(s['data_hora'])}'),
                          if (s['salvo_por'] != null) Text('👤 Criado por: ${s['salvo_por']}'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          if (modoExportacao)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CheckboxListTile(
                    title: const Text('Selecionar Todos'),
                    value: todosSelecionados,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) => setState(() {
                      todosSelecionados = v ?? false;
                      for (int i = 0; i < selecionados.length; i++) {
                        selecionados[i] = todosSelecionados;
                      }
                    }),
                  ),
                  Text('${selecionados.where((e) => e).length} selecionado(s)'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(icon: const Icon(Icons.download), label: const Text('Exportar'), onPressed: exportarSelecionados),
                      if(ApiService.isAdmin)
                        ElevatedButton.icon(icon: const Icon(Icons.delete_forever), label: const Text('Excluir'), onPressed: excluirSelecionados, style: AppButtonStyle.dangerButton),
                      ElevatedButton.icon(onPressed: ()=> setState(()=> modoExportacao = false), icon: const Icon(Icons.close), label: const Text("Cancelar"), style: ElevatedButton.styleFrom(backgroundColor: Colors.orange))
                    ],
                  )
                ],
              ),
            )
        ],
      ),
    );
  }
}