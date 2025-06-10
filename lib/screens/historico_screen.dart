import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import '../components/app_scaffold.dart';
import '../utils/theme.dart';
import 'package:open_file/open_file.dart';

class HistoricoScreen extends StatefulWidget {
  const HistoricoScreen({super.key});

  @override
  State<HistoricoScreen> createState() => _HistoricoScreenState();
}

double arredondarPraBaixo(double valor) {
  return (valor / 10).floor() * 10;
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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) {
          dialogAberto = true;
          return const Dialog(
            backgroundColor: Colors.transparent,
            child: Center(child: CircularProgressIndicator()),
          );
        },
      );
      return await acao();
    } finally {
      if (dialogAberto && context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
    }
  }

  Future<void> _carregarHistorico() async {
    try {
      final dados = await ApiService.getHistoricoSimulacoes();
      dados.sort((a, b) {
        final dataA = DateTime.tryParse(a['data_hora'].toString()) ?? DateTime(2000);
        final dataB = DateTime.tryParse(b['data_hora'].toString()) ?? DateTime(2000);
        return dataB.compareTo(dataA);
      });
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
      filtrado = historico.where((s) {
        return s['produto'].toString().toLowerCase().contains(query) ||
            s['forma_pagamento'].toString().toLowerCase().contains(query);
      }).toList();
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
      await executarComLoading(() async {
        try {
          await ApiService.excluirSimulacao(id);
          await _carregarHistorico();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Histórico excluído com sucesso.')),
          );
        } catch (_) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ Erro ao excluir histórico.')),
          );
        }
      });
    }
  }

  void editar(Map<String, dynamic> simulacao) async {
    final precoController = TextEditingController(text: simulacao['preco_venda_final'].toString());
    final parcelasController = TextEditingController(text: simulacao['parcelas'].toString());
    final jurosController = TextEditingController(text: simulacao['juros'].toString());
    final margemController = TextEditingController(text: simulacao['margem']?.toString() ?? '35');
    final entradaController = TextEditingController(text: simulacao['entrada'].toString());

    String tipoParcelamento = simulacao['tipo_parcelamento'] ?? 'Mensal';
    String formaPagamento = simulacao['forma_pagamento'] ?? 'Pix';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Editar Simulação'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: precoController,
                decoration: const InputDecoration(labelText: 'Preço Venda Final'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: parcelasController,
                decoration: const InputDecoration(labelText: 'Parcelas'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: jurosController,
                decoration: const InputDecoration(labelText: 'Juros (%)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: margemController,
                decoration: const InputDecoration(labelText: 'Margem (%)'),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: entradaController,
                decoration: const InputDecoration(labelText: 'Entrada (%)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                value: formaPagamento,
                decoration: const InputDecoration(labelText: 'Forma de Pagamento da Entrada'),
                items: ['Pix', 'Dinheiro']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => formaPagamento = v!,
              ),
              DropdownButtonFormField<String>(
                value: tipoParcelamento,
                decoration: const InputDecoration(labelText: 'Tipo de Parcelamento'),
                items: ['Mensal', 'Semanal', 'Quinzenal']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => tipoParcelamento = v!,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              final cmvTotal = double.tryParse(simulacao['cmv_total'].toString()) ?? 0;
              final precoVenda = double.tryParse(precoController.text) ?? 0;
              final parcelas = int.tryParse(parcelasController.text) ?? 0;
              final juros = double.tryParse(jurosController.text) ?? 0;
              final margem = double.tryParse(margemController.text) ?? 0;
              final entrada = double.tryParse(entradaController.text) ?? 0;

              final precoSugerido = arredondarPraBaixo(cmvTotal / (1 - (margem / 100)));

              if (margem < 35) {
                Navigator.pop(context, false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('❌ Margem deve ser no mínimo 35%')),
                );
                return;
              }

              if (juros < 19) {
                Navigator.pop(context, false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('❌ Juros deve ser no mínimo 19%')),
                );
                return;
              }

              if (entrada < 20) {
                Navigator.pop(context, false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('❌ Entrada deve ser no mínimo 20%')),
                );
                return;
              }

              if (parcelas > 12) {
                Navigator.pop(context, false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('❌ Parcelas deve ser no máximo 12')),
                );
                return;
              }

              if (precoVenda < precoSugerido) {
                Navigator.pop(context, false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('⚠️ Preço final deve ser maior ou igual ao preço sugerido: R\$ ${precoSugerido.toStringAsFixed(2)}')),
                );
                return;
              }

              await executarComLoading(() async {
                try {
                  final id = simulacao['id'];
                  final novosDados = {
                    'preco_venda_final': precoVenda,
                    'parcelas': parcelas,
                    'juros': juros,
                    'margem': margem,
                    'entrada': entrada,
                    'forma_pagamento': formaPagamento,
                    'tipo_parcelamento': tipoParcelamento,
                    'cmv_base': simulacao['cmv_base'],
                    'cmv_total': simulacao['cmv_total'],
                  };
                  await ApiService.atualizarSimulacao(id, novosDados);
                  Navigator.pop(context, true);
                  await _carregarHistorico();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('✅ Simulação atualizada')),
                  );
                } catch (_) {
                  Navigator.pop(context, false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('❌ Erro ao atualizar simulação')),
                  );
                }
              });
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
  }

  Future<void> exportarSelecionados() async {
    final selecionadosIndices = selecionados
        .asMap()
        .entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    if (selecionadosIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Nenhuma simulação selecionada')),
      );
      return;
    }

    final excel = Excel.createExcel();
    final sheet = excel['Simulações'];
    excel.delete('Sheet1');

    // Cabeçalho
    sheet.appendRow([
      TextCellValue('Produto'),
      TextCellValue('Preço Final'),
      TextCellValue('Parcelas'),
      TextCellValue('Juros (%)'),
      TextCellValue('Valor Juros'),
      TextCellValue('Margem (%)'),
      TextCellValue('Entrada (%)'),
      TextCellValue('Valor da Entrada'),
      TextCellValue('Valor do Crédito'),
      TextCellValue('Forma Pagamento'),
      TextCellValue('Parcelamento'),
      TextCellValue('Total a Pagar'),
      TextCellValue('Total da Venda'),
      TextCellValue('Lucro'),
      TextCellValue('CMV Base'),
      TextCellValue('CMV Total'),
      TextCellValue('Parcelas Cobrir Custo'),
      TextCellValue('Data'),
      TextCellValue('Salvo Por'),
    ]);

    for (var i in selecionadosIndices) {
      final h = filtrado[i];
      final preco = double.tryParse(h['preco_venda_final'].toString()) ?? 0;
      final entradaPercent = double.tryParse(h['entrada'].toString()) ?? 0;
      final entradaValor = preco * (entradaPercent / 100);
      final jurosPercent = double.tryParse(h['juros'].toString()) ?? 0;
      final totalPagar = double.tryParse(h['total_pagar'].toString()) ?? 0;
      final totalVenda = entradaValor + totalPagar;
      final valorJuros = totalVenda - preco;
      final valorCredito = preco - entradaValor;

      sheet.appendRow([
        TextCellValue(h['produto'] ?? ''),
        TextCellValue(preco.toStringAsFixed(2)),
        TextCellValue(h['parcelas'].toString()),
        TextCellValue(jurosPercent.toStringAsFixed(0)),
        TextCellValue(valorJuros.toStringAsFixed(2)),
        TextCellValue(h['margem'].toString()),
        TextCellValue(entradaPercent.toStringAsFixed(0)),
        TextCellValue(entradaValor.toStringAsFixed(2)),
        TextCellValue(valorCredito.toStringAsFixed(2)),
        TextCellValue(h['forma_pagamento'] ?? ''),
        TextCellValue(h['tipo_parcelamento'] ?? ''),
        TextCellValue(totalPagar.toStringAsFixed(2)),
        TextCellValue(totalVenda.toStringAsFixed(2)),
        TextCellValue(h['lucro'].toString()),
        TextCellValue(h['cmv_base'].toString()),
        TextCellValue(h['cmv_total'].toString()),
        TextCellValue(h['parcelas_cobrir_custo'].toString()),
        TextCellValue(formatarDataHora(h['data_hora'].toString())),
        TextCellValue(h['salvo_por'] ?? ''),
      ]);
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/simulacoes_selecionadas.xlsx');
    await file.writeAsBytes(excel.encode()!);
    await OpenFile.open(file.path);
    setState(() => modoExportacao = false);
  }

  Future<void> excluirSelecionados() async {
    final indices = selecionados
        .asMap()
        .entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    await executarComLoading(() async {
      int excluidos = 0;
      for (final i in indices) {
        final id = filtrado[i]['id'];
        if (id == null || id is! int) {
          print('⚠️ ID inválido: $id');
          continue;
        }

        try {
          await ApiService.excluirSimulacao(id);
          excluidos++;
        } catch (e) {
          print('❌ Erro ao excluir ID $id: $e');
        }
      }

      await _carregarHistorico();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ $excluidos simulação(ões) excluída(s).')),
      );

      setState(() => modoExportacao = false);
    });
  }


  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Histórico de Simulações',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: buscaController,
                    decoration: const InputDecoration(
                      labelText: 'Buscar simulação',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      modoExportacao = !modoExportacao;
                      selecionados = List<bool>.filled(filtrado.length, false);
                      todosSelecionados = false;
                    });
                  },
                  icon: const Icon(Icons.checklist),
                  label: Text(modoExportacao ? 'Selecionar Simulações' : 'Selecionar Simulações'),
                  style: AppButtonStyle.primaryButton,
                ),
              ],
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
                final preco = double.tryParse(s['preco_venda_final'].toString()) ?? 0;
                final entrada = double.tryParse(s['entrada'].toString()) ?? 0;
                final juros = double.tryParse(s['juros'].toString()) ?? 0;
                final totalPagar = double.tryParse(s['total_pagar'].toString()) ?? 0;
                final totalVenda = double.tryParse(s['total_venda'].toString()) ?? 0;
                final lucro = double.tryParse(s['lucro'].toString()) ?? 0;
                final cmvBase = double.tryParse(s['cmv_base'].toString()) ?? 0;
                final cmvTotal = double.tryParse(s['cmv_total'].toString()) ?? 0;
                final credito = preco - (preco * (entrada / 100));
                final entradaValor = preco * (entrada / 100);
                final valorJuros = totalVenda - preco;
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
                              child: Row(
                                children: [
                                  if (modoExportacao)
                                    Checkbox(
                                      value: selecionados[index],
                                      onChanged: (v) {
                                        setState(() {
                                          selecionados[index] = v ?? false;
                                          todosSelecionados = selecionados.every((el) => el);
                                        });
                                      },
                                    ),
                                  Expanded(
                                    child: Text(
                                      '📱 ${s['produto']}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!modoExportacao)
                              Row(
                                children: [
                                  if (ApiService.isAdmin)
                                    IconButton(
                                      icon: const Icon(Icons.edit),
                                      onPressed: () => editar(s),
                                    ),
                                  if (ApiService.isAdmin)
                                    IconButton(
                                      icon: const Icon(Icons.delete),
                                      onPressed: () => excluir(s['id']),
                                    ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('💰 Preço Final: ${formatarReal(preco)}'),
                        Text('📦 CMV Base: ${formatarReal(cmvBase)}'),
                        Text('📦 CMV Total: ${formatarReal(cmvTotal)}'),
                        Text('💵 Lucro: ${formatarReal(lucro)}'),
                        Text('📈 Juros (${juros.toStringAsFixed(0)}%): ${formatarReal(valorJuros)}'),
                        Text('📉 Entrada (${entrada.toStringAsFixed(0)}%): ${formatarReal(entradaValor)}'),
                        Text('💳 Valor do Crédito: ${formatarReal(credito)}'),
                        Text('🧾 Valor por parcela (${s['parcelas']}x): ${formatarReal(totalPagar / (int.tryParse(s['parcelas'].toString()) ?? 1))}'),
                        Text('📆 Parcelamento: ${s['parcelas']}x ${s['tipo_parcelamento']}'),
                        Text('🏦 Forma de Pagamento da Entrada: ${s['forma_pagamento']}'),
                        Text('🔢 Total a pagar: ${formatarReal(totalPagar)}'),
                        Text('💰 Total da Venda: ${formatarReal(totalVenda)}'),
                        Text('📊 Parcelas p/ Cobrir Custo: ${s['parcelas_cobrir_custo']}'),
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
          if (modoExportacao) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CheckboxListTile(
                    title: const Text('Selecionar Todos'),
                    value: todosSelecionados,
                    onChanged: (v) {
                      setState(() {
                        todosSelecionados = v ?? false;
                        selecionados = List<bool>.filled(filtrado.length, todosSelecionados);
                      });
                    },
                  ),
                  Center(
                    child: Text(
                      'Selecionados: ${selecionados.where((e) => e).length}',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      ElevatedButton.icon(
                          onPressed: () async {
                            final selecionadosIndices = selecionados
                                .asMap()
                                .entries
                                .where((e) => e.value)
                                .map((e) => e.key)
                                .toList();
                            if (selecionadosIndices.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('⚠️ Nenhuma simulação selecionada')),
                              );
                              return;
                            }
                            await executarComLoading(() async {
                              await exportarSelecionados();
                            });
                          },
                          icon: const Icon(Icons.download),
                          label: Text('Exportar (${selecionados.where((e) => e).length})'),
                          style: AppButtonStyle.primaryButton,
                        ),
                      const SizedBox(width: 10),
                      if (ApiService.isAdmin) // ✅ Só mostra para admins
                        ElevatedButton.icon(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Excluir Selecionados'),
                                content: const Text('Tem certeza que deseja excluir as simulações selecionadas?'),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                  TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Excluir')),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await executarComLoading(() async {
                                await excluirSelecionados();
                              });
                            }
                          },
                          icon: const Icon(Icons.delete_forever),
                          label: Text('Excluir (${selecionados.where((e) => e).length})'),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() => modoExportacao = false);
                        },
                        icon: const Icon(Icons.close),
                        label: const Text('Cancelar'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
