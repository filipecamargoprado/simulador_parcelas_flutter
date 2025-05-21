import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import 'dart:math';

class SimulacaoScreen extends StatefulWidget {
  final Map<String, dynamic> usuario;
  const SimulacaoScreen({super.key, required this.usuario});

  @override
  State<SimulacaoScreen> createState() => _SimulacaoScreenState();
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
        const SnackBar(content: Text('Erro ao carregar produtos')),
      );
    } finally {
      setState(() => carregandoProdutos = false);
    }
  }

  String formatarReal(double valor) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(valor);
  }

  void simular() {
    if (produtoSelecionado == null) return;

    final cmv = double.tryParse(produtoSelecionado!['cmv'].toString()) ?? 0;
    final campanha = 30.0;
    final custoPorBoleto = 3.5;
    final custoSaque = 3.99;
    final licencaAnual = 59.9;
    final mensalidade = 5.0;

    final parcelas = int.tryParse(parcelasController.text) ?? 12;
    final margem = double.tryParse(margemController.text) ?? 0;
    final juros = double.tryParse(jurosController.text) ?? 0;
    final entradaPercentual = double.tryParse(entradaPercentualController.text) ?? 0;

    if (tipoParcelamento == 'Quinzenal') {
      parcelasController.text = (parcelas * 2).toString();
    }

    if (margem < 35 || juros < 19 || entradaPercentual < 20 || parcelas > 12) {
      final List<String> avisos = [];

      if (margem < 35) avisos.add('⚠️ Margem deve ser maior ou igual a 35%');
      if (juros < 19) avisos.add('⚠️ Juros devem ser maior ou igual a 19%');
      if (entradaPercentual < 20) avisos.add('⚠️ Entrada deve ser maior ou igual a 20%');
      if (parcelas > 12) avisos.add('⚠️ Parcelas devem ser menor ou igual a 12');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: avisos.map((e) => Text(e)).toList(),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    final custoPorBoletoTotal = custoPorBoleto * parcelas;
    final cmvTotal = cmv + campanha + custoSaque + licencaAnual + custoPorBoletoTotal + mensalidade;
    precoSugerido = cmvTotal / (1 - margem / 100);

    double precoVenda = double.tryParse(precoVendaController.text.replaceAll('.', '').replaceAll(',', '.')) ?? precoSugerido!;

    if (precoVenda < precoSugerido!) {
      precoVenda = precoSugerido!;
      precoVendaController.text = precoVenda.toStringAsFixed(2);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ O preço de venda final deve ser maior ou igual ao preço sugerido.')),
      );
    }

    final entrada = precoVenda * entradaPercentual / 100;
    final restante = precoVenda - entrada;
    final i = juros / 100;

    double calcularParcela(double i, int n, double pv) {
      return (pv * i) / (1 - pow(1 + i, -n));
    }

    final valorParcela = calcularParcela(i, parcelas, restante);
    final total = valorParcela * parcelas;
    final lucro = precoVenda - cmvTotal;
    final parcelasParaCobrirCusto = (cmvTotal / valorParcela).ceil();

    setState(() {
      precoVendaController.text = formatarReal(precoVenda);
      resultadoWidget = [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('💡 Preço de Venda Sugerido: ${formatarReal(precoSugerido!)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Preço de Venda Final'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: precoVendaController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: simular,
                    child: const Text('Atualizar'),
                  )
                ],
              ),
              const SizedBox(height: 10),
              Text('📦 CMV Base: ${formatarReal(cmv)}'),
              Text('📦 CMV Total: ${formatarReal(cmvTotal)}'),
              Text('💵 Lucro: ${formatarReal(lucro)}'),
              Text('Entrada (${entradaPercentual.toStringAsFixed(0)}%): ${formatarReal(entrada)}'),
              Text('Financiado: ${formatarReal(restante)}'),
              const SizedBox(height: 10),
              Text('📊 Parcelas com Juros (${parcelas}x): ${formatarReal(valorParcela)}'),
              Text('🔢 Total a pagar: ${formatarReal(total)}'),
              Text('📈 Parcelas para cobrir o custo: $parcelasParaCobrirCusto'),
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
                      'lucro': lucro,
                      'cmv_base': cmv,
                      'cmv_total': cmvTotal,
                      'tipo_parcelamento': tipoParcelamento,
                      'forma_pagamento': formaPagamento,
                      'parcelas_cobrir_custo': parcelasParaCobrirCusto,
                      'total_pagar': total,
                      'salvo_por': widget.usuario['nome'] ?? widget.usuario['email'],
                    };

                    await ApiService.salvarSimulacao(dados);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ Simulação salva com sucesso!')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('❌ Erro ao salvar simulação: $e')),
                    );
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Salvar simulação venda'),
              ),
            ],
          ),
        )
      ];
    });
  }

  @override
  void dispose() {
    margemController.dispose();
    jurosController.dispose();
    parcelasController.dispose();
    precoVendaController.dispose();
    entradaPercentualController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments;
    if (args != null && args is Map && produtoSelecionado == null) {
      precoVendaController.text = args['preco_venda_final']?.toString() ?? '';
      parcelasController.text = args['parcelas']?.toString() ?? '12';
      jurosController.text = args['juros']?.toString() ?? '19';
      entradaPercentualController.text = args['entrada']?.toString() ?? '20';
      formaPagamento = args['forma_pagamento'] ?? 'Pix';
      tipoParcelamento = args['tipo_parcelamento'] ?? 'Mensal';

      final nomeProduto = args['produto']?.toString();
      if (nomeProduto != null && produtos.isNotEmpty) {
        final encontrado = produtos.firstWhere(
              (p) => '${p['marca']} - ${p['modelo']}' == nomeProduto,
          orElse: () => {},
        );
        if (encontrado.isNotEmpty) {
          produtoSelecionado = encontrado;
        }
      }
    }

    return SingleChildScrollView(
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
                  onChanged: (value) {
                    setState(() => formaPagamento = value!);
                  },
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
                  onChanged: (value) {
                    setState(() => tipoParcelamento = value!);
                  },
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
            onChanged: (value) {
              setState(() => produtoSelecionado = value);
            },
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: simular, child: const Text('Simular')),
          const SizedBox(height: 16),
          if (resultadoWidget != null) ...resultadoWidget!,
        ],
      ),
    );
  }
}
