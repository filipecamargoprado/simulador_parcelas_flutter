// 🔥 SimulacaoScreen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../services/api_service.dart';
import '../components/app_scaffold.dart';
import '../utils/theme.dart';

class SimulacaoScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final bool isAdmin;

  const SimulacaoScreen({
    super.key,
    required this.usuario,
    required this.isAdmin,
  });

  @override
  State<SimulacaoScreen> createState() => _SimulacaoScreenState();
}

double arredondarDezena(double valor) {
  return (valor ~/ 10) * 10.0;
}

class _SimulacaoScreenState extends State<SimulacaoScreen> {
  final margemController = TextEditingController(text: '35');
  final jurosController = TextEditingController(text: '19');
  final parcelasController = TextEditingController(text: '12');
  final precoVendaController = TextEditingController();
  final entradaPercentualController = TextEditingController(text: '20');

  Map<String, dynamic>? produtoSelecionado;
  List<Map<String, dynamic>> produtos = [];
  List<Widget>? resultadoWidget;

  String formaPagamento = 'Pix';
  String tipoParcelamento = 'Mensal';
  bool carregandoProdutos = true;
  double? precoSugerido;

  @override
  void initState() {
    super.initState();
    carregarProdutos();
  }

  void carregarProdutos() async {
    setState(() => carregandoProdutos = true);
    try {
      final lista = await ApiService.getProdutos();
      setState(() {
        produtos = List<Map<String, dynamic>>.from(lista);
      });
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Erro ao carregar produtos')),
      );
    } finally {
      setState(() => carregandoProdutos = false);
    }
  }

  String formatarReal(double valor) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(valor);
  }

  void showSnack(String mensagem) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensagem)),
    );
  }

  void simular() {
    if (produtoSelecionado == null) {
      showSnack('❌ Selecione um produto');
      return;
    }

    final margem = double.tryParse(margemController.text) ?? 0;
    final juros = double.tryParse(jurosController.text) ?? 0;
    final entradaPercentual = double.tryParse(entradaPercentualController.text) ?? 0;
    var parcelas = int.tryParse(parcelasController.text) ?? 0;

    // 🔥 Validações
    if (margem < 35) {
      showSnack('❌ Margem deve ser no mínimo 35%');
      return;
    }
    if (juros < 19) {
      showSnack('❌ Juros deve ser no mínimo 19%');
      return;
    }
    if (entradaPercentual < 20) {
      showSnack('❌ Entrada deve ser no mínimo 20%');
      return;
    }
    if (parcelas > 12) {
      showSnack('❌ Parcelas deve ser no máximo 12');
      return;
    }

    // 🔄 Se parcelamento é Quinzenal, dobra parcelas
    final parcelasReal = tipoParcelamento == 'Quinzenal' ? parcelas * 2 : parcelas;

    // 🧠 Dados fixos
    final cmv = double.tryParse(produtoSelecionado!['cmv'].toString()) ?? 0;
    const campanha = 30.0;
    const custoPorBoleto = 3.5;
    const custoSaque = 3.99;
    const mensalidade = 20.0;

    final custoPorBoletoTotal = custoPorBoleto * parcelasReal;

    double licencaAnual;
    if (parcelasReal <= 12) {
      licencaAnual = 59.9;
    } else if (parcelasReal <= 24) {
      licencaAnual = 118.8;
    } else {
      licencaAnual = 0; // ou outro valor, se quiser tratar acima de 24
    }

    final cmvTotal = cmv + campanha + custoSaque + licencaAnual + custoPorBoletoTotal + mensalidade;
    precoSugerido = arredondarDezena(cmvTotal / (1 - margem / 100));

    double precoVenda = double.tryParse(
        precoVendaController.text.replaceAll('.', '').replaceAll(',', '.')) ?? precoSugerido!;
    precoVenda = arredondarDezena(precoVenda);

    if (precoVenda < precoSugerido!) {
      precoVenda = precoSugerido!;
      precoVendaController.text = precoVenda.toStringAsFixed(2);
      showSnack('⚠️ Preço final deve ser maior ou igual ao preço sugerido.');
    }

    final entrada = precoVenda * entradaPercentual / 100;
    final restante = precoVenda - entrada;
    final i = juros / 100;

    double calcularParcela(double i, int n, double pv) {
      return (pv * i) / (1 - pow(1 + i, -n));
    }

    final valorParcela = calcularParcela(i, parcelasReal, restante);
    final total = valorParcela * parcelasReal;
    final valorJuros = total - restante;
    final totalVenda = entrada + total;
    final lucro = precoVenda - cmvTotal;
    final parcelasParaCobrirCusto = ((cmvTotal - entrada) / valorParcela).ceil();

    setState(() {
      precoVendaController.text = formatarReal(precoVenda);
      resultadoWidget = [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💡 Preço Sugerido: ${formatarReal(precoSugerido!)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: precoVendaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Preço Venda Final'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: simular,
                    style: AppButtonStyle.primaryButton,
                    child: const Text('Atualizar'),
                  )
                ],
              ),
              const SizedBox(height: 10),
              Text('📦 CMV Base: ${formatarReal(cmv)}'),
              Text('📦 CMV Total: ${formatarReal(cmvTotal)}'),
              Text('💵 Lucro: ${formatarReal(lucro)}'),
              Text('📈 Juros (${juros.toStringAsFixed(0)}%): ${formatarReal(valorJuros)}'),
              Text('📉 Entrada (${entradaPercentual.toStringAsFixed(0)}%): ${formatarReal(entrada)}'),
              Text('💳 Valor do Crédito: ${formatarReal(restante)}'),
              Text('🧾 Valor por parcela (${parcelasReal}x): ${formatarReal(valorParcela)}'),
              Text('🔢 Total a pagar: ${formatarReal(total)}'),
              Text('💰 Total da Venda: ${formatarReal(totalVenda)}'),
              Text('📊 Parcelas p/ Cobrir Custo: $parcelasParaCobrirCusto'),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    final dados = {
                      'produto': '${produtoSelecionado!['marca']} - ${produtoSelecionado!['modelo']}',
                      'preco_venda_final': precoVenda,
                      'parcelas': parcelas,
                      'juros': juros,
                      'entrada': entradaPercentual,
                      'margem': margem,
                      'forma_pagamento': formaPagamento,
                      'tipo_parcelamento': tipoParcelamento,
                      'cmv_base': cmv,
                      'cmv_total': cmvTotal,
                      'lucro': lucro,
                      'parcelas_cobrir_custo': parcelasParaCobrirCusto,
                      'total_pagar': total,
                      'total_venda': totalVenda,
                      'salvo_por': widget.usuario['nome'] ?? 'Desconhecido',
                    };

                    await ApiService.salvarSimulacao(dados);
                    showSnack('✅ Simulação salva com sucesso!');
                  } catch (e) {
                    showSnack('❌ Erro ao salvar: $e');
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Salvar Simulação'),
              ),
            ],
          ),
        )
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Simulação de Parcelas',
      isAdmin: widget.isAdmin,
      usuario: widget.usuario,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Simulação de Parcelas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: margemController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Margem (%)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: jurosController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Juros (%)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: entradaPercentualController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Entrada (%)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: parcelasController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Parcelas'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: formaPagamento,
                    decoration: const InputDecoration(labelText: 'Forma de Pagamento da Entrada'),
                    items: const [
                      DropdownMenuItem(value: 'Pix', child: Text('Pix')),
                      DropdownMenuItem(value: 'Dinheiro', child: Text('Dinheiro')),
                    ],
                    onChanged: (value) => setState(() => formaPagamento = value!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: tipoParcelamento,
                    decoration: const InputDecoration(labelText: 'Tipo de Parcelamento'),
                    items: const [
                      DropdownMenuItem(value: 'Mensal', child: Text('Mensal')),
                      DropdownMenuItem(value: 'Quinzenal', child: Text('Quinzenal')),
                    ],
                    onChanged: (value) => setState(() => tipoParcelamento = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: produtoSelecionado,
              decoration: const InputDecoration(labelText: 'Selecione o Produto'),
              items: produtos.map((produto) {
                return DropdownMenuItem<Map<String, dynamic>>(
                  value: produto,
                  child: Text('${produto['marca']} - ${produto['modelo']}'),
                );
              }).toList(),
              onChanged: (value) => setState(() => produtoSelecionado = value),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: simular,
              style: AppButtonStyle.primaryButton,
              child: const Text('Simular'),
            ),
            const SizedBox(height: 16),
            if (resultadoWidget != null) ...resultadoWidget!,
          ],
        ),
      ),
    );
  }
}
