// lib/screens/simulacao_screen.dart
// ✨ VERSÃO FINAL COM LÓGICA DE SALVAR IMPLEMENTADA ✨

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../services/api_service.dart';
import '../components/app_scaffold.dart';
import '../utils/theme.dart';

class _SimulacaoResultado {
  final double cmvTotal;
  final double entrada;
  final double parcela10x;
  final double parcela12x;
  final double precoSugerido;
  final Map<String, dynamic> dadosCompletosParaSalvar;

  _SimulacaoResultado({
    required this.cmvTotal,
    required this.entrada,
    required this.parcela10x,
    required this.parcela12x,
    required this.precoSugerido,
    required this.dadosCompletosParaSalvar,
  });
}

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

class _SimulacaoScreenState extends State<SimulacaoScreen> {
  final margemController = TextEditingController(text: '35');
  final entradaPercentualController = TextEditingController(text: '20');
  final precoVendaController = TextEditingController();

  Map<String, dynamic>? produtoSelecionado;
  List<Map<String, dynamic>> produtos = [];
  bool carregandoProdutos = true;
  String formaPagamento = 'Pix';

  _SimulacaoResultado? _resultado;

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
      showSnack('❌ Erro ao carregar produtos', isError: true);
    } finally {
      if (mounted) {
        setState(() => carregandoProdutos = false);
      }
    }
  }

  String formatarReal(double valor) {
    return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(valor);
  }

  double arredondarDezena(double valor) {
    return (valor ~/ 10) * 10.0;
  }

  void showSnack(String mensagem, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensagem),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
      ),
    );
  }

  void simular() {
    if (produtoSelecionado == null) {
      showSnack('❌ Selecione um produto', isError: true);
      return;
    }

    final margem = double.tryParse(margemController.text) ?? 0;
    final entradaPercentual = double.tryParse(entradaPercentualController.text) ?? 0;

    const juros = 19.0;
    const tipoParcelamento = 'Mensal';

    if (margem < 35 || entradaPercentual < 20) {
      showSnack('❌ Verifique os valores de margem e entrada.', isError: true);
      return;
    }

    final cmv = double.tryParse(produtoSelecionado!['cmv'].toString()) ?? 0;
    const campanha = 30.0;
    const custoPorBoleto = 3.5;
    const custoSaque = 3.99;
    const mensalidade = 20.0;

    final custoPorBoletoTotal = custoPorBoleto * 12;
    const licencaAnual = 59.9;
    final cmvTotal = cmv + campanha + custoSaque + licencaAnual + custoPorBoletoTotal + mensalidade;
    final precoSugerido = arredondarDezena(cmvTotal / (1 - margem / 100));

    double precoVenda = double.tryParse(
        precoVendaController.text.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.')) ?? precoSugerido;

    if (precoVenda < precoSugerido) {
      precoVenda = precoSugerido;
      showSnack('⚠️ Preço de venda ajustado para o mínimo sugerido.');
    }

    precoVendaController.text = formatarReal(precoVenda);

    final entradaValor = precoVenda * entradaPercentual / 100;
    final valorDoCredito = precoVenda - entradaValor;
    final taxaJuros = juros / 100;

    double calcularParcela(int n) {
      if (n <= 0) return 0;
      return (valorDoCredito * taxaJuros) / (1 - pow(1 + taxaJuros, -n));
    }

    final valorParcela10x = calcularParcela(10);
    final valorParcela12x = calcularParcela(12);

    final dadosParaSalvar = {
      'produto': '${produtoSelecionado!['marca']} - ${produtoSelecionado!['modelo']}',
      'preco_venda_final': precoVenda,
      'parcelas': 12,
      'juros': juros,
      'entrada': entradaPercentual,
      'margem': margem,
      'lucro': precoVenda - cmvTotal,
      'cmv_base': cmv,
      'cmv_total': cmvTotal,
      'tipo_parcelamento': tipoParcelamento,
      'forma_pagamento': formaPagamento,
      'parcelas_cobrir_custo': (cmvTotal > entradaValor) ? ((cmvTotal - entradaValor) / valorParcela12x).ceil() : 0,
      'total_pagar': valorParcela12x * 12,
      'total_venda': entradaValor + (valorParcela12x * 12),
      'salvo_por': widget.usuario['nome'] ?? 'Desconhecido',
      'valor_parcela_10x': valorParcela10x,
      'valor_parcela_12x': valorParcela12x,
    };

    setState(() {
      _resultado = _SimulacaoResultado(
        cmvTotal: cmvTotal,
        entrada: entradaValor,
        parcela10x: valorParcela10x,
        parcela12x: valorParcela12x,
        precoSugerido: precoSugerido,
        dadosCompletosParaSalvar: dadosParaSalvar,
      );
    });
  }

  // ✨ LÓGICA FINAL PARA SALVAR A SIMULAÇÃO FÍSICA ✨
  Future<void> _salvarSimulacaoFisica() async {
    if (_resultado == null) {
      showSnack("Por favor, gere uma simulação antes de salvar.", isError: true);
      return;
    }
    try {
      await ApiService.salvarSimulacao(_resultado!.dadosCompletosParaSalvar);
      showSnack("✅ Simulação salva com sucesso no histórico!");
    } catch (e) {
      showSnack("❌ Erro ao salvar simulação: ${e.toString()}", isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Simulação de Parcelas',
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Simulação Loja Física', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: TextField(controller: margemController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Margem (%)'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: entradaPercentualController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Entrada (%)'))),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(value: formaPagamento, decoration: const InputDecoration(labelText: 'Forma de Pagamento da Entrada'), items: const [DropdownMenuItem(value: 'Pix', child: Text('Pix')), DropdownMenuItem(value: 'Dinheiro', child: Text('Dinheiro'))], onChanged: (value) => setState(() => formaPagamento = value!)),
            const SizedBox(height: 16),
            DropdownButtonFormField<Map<String, dynamic>>(value: produtoSelecionado, decoration: const InputDecoration(labelText: 'Selecione o Produto'), items: produtos.map((produto) => DropdownMenuItem<Map<String, dynamic>>(value: produto, child: Text('${produto['marca']} - ${produto['modelo']}'))).toList(), onChanged: (value) => setState(() => produtoSelecionado = value)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: simular, style: AppButtonStyle.primaryButton, child: const Text('Simular')),
            const SizedBox(height: 16),

            if (_resultado != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('💡 Preço Sugerido: ${formatarReal(_resultado!.precoSugerido)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: precoVendaController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preço Venda Final'))),
                        const SizedBox(width: 12),
                        ElevatedButton(onPressed: simular, style: AppButtonStyle.primaryButton, child: const Text('Atualizar'))
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 10),
                    Text('📦 CMV Total: ${formatarReal(_resultado!.cmvTotal)}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('📉 Entrada (${entradaPercentualController.text}%): ${formatarReal(_resultado!.entrada)}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('💳 Valor por Parcela (10x): ${formatarReal(_resultado!.parcela10x)}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 8),
                    Text('💳 Valor por Parcela (12x): ${formatarReal(_resultado!.parcela12x)}', style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _salvarSimulacaoFisica, // ✨ AÇÃO FINAL DE SALVAR
                      icon: const Icon(Icons.save),
                      label: const Text('Salvar Simulação'),
                      style: AppButtonStyle.primaryButton,
                    ),
                  ],
                ),
              )
          ],
        ),
      ),
    );
  }
}