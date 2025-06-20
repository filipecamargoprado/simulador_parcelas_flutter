// lib/screens/simulacao_screen_online.dart
// ✨ VERSÃO FINAL COM LÓGICA DE SALVAR ✨

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math';
import '../services/api_service.dart';
import '../components/app_scaffold.dart';
import '../utils/theme.dart';

class SimulacaoScreenOnline extends StatefulWidget {
  final Map<String, dynamic> usuario;
  final bool isAdmin;

  const SimulacaoScreenOnline({
    super.key,
    required this.usuario,
    required this.isAdmin,
  });

  @override
  State<SimulacaoScreenOnline> createState() => _SimulacaoScreenOnlineState();
}

class _SimulacaoScreenOnlineState extends State<SimulacaoScreenOnline> {
  final margemController = TextEditingController(text: '35');
  final jurosController = TextEditingController(text: '19');
  final parcelasController = TextEditingController(text: '12');
  final precoVendaController = TextEditingController();
  final entradaPercentualController = TextEditingController(text: '20');

  Map<String, dynamic>? produtoSelecionado;
  List<Map<String, dynamic>> produtos = [];
  Map<String, dynamic>? _resultado;

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

  double arredondarDezena(double valor) {
    return (valor ~/ 10) * 10.0;
  }

  void showSnack(String mensagem, {bool isError = false}) {
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
    final juros = double.tryParse(jurosController.text) ?? 0;
    final entradaPercentual = double.tryParse(entradaPercentualController.text) ?? 0;
    var parcelas = int.tryParse(parcelasController.text) ?? 0;

    if (margem < 35 || juros < 19 || entradaPercentual < 20 || parcelas <= 0 || parcelas > 12) {
      showSnack('❌ Verifique os valores de margem, juros, entrada e parcelas.', isError: true);
      return;
    }

    final parcelasReal = tipoParcelamento == 'Quinzenal' ? parcelas * 2 : parcelas;

    final cmv = double.tryParse(produtoSelecionado!['cmv'].toString()) ?? 0;
    const campanha = 30.0;
    const custoPorBoleto = 3.5;
    const custoSaque = 3.99;
    const mensalidade = 20.0;
    double licencaAnual = (parcelasReal <= 12) ? 59.9 : 118.8;

    final custoPorBoletoTotal = custoPorBoleto * parcelasReal;
    final cmvTotal = cmv + campanha + custoSaque + licencaAnual + custoPorBoletoTotal + mensalidade;
    precoSugerido = arredondarDezena(cmvTotal / (1 - margem / 100));

    double precoVenda = double.tryParse(
        precoVendaController.text.replaceAll('R\$', '').replaceAll('.', '').replaceAll(',', '.')) ?? precoSugerido!;

    if (precoVenda < precoSugerido!) {
      precoVenda = precoSugerido!;
      showSnack('⚠️ Preço de venda ajustado para o mínimo sugerido.');
    }

    precoVendaController.text = formatarReal(precoVenda);

    final entradaValor = precoVenda * entradaPercentual / 100;
    final restante = precoVenda - entradaValor;
    final taxaJuros = juros / 100;

    double calcularParcela(double pv, int n) {
      if (n <= 0) return 0;
      double i = taxaJuros;
      // Fórmula de juros compostos para parcelas
      return (pv * i) / (1 - pow(1 + i, -n));
    }

    final valorParcela = calcularParcela(restante, parcelasReal);
    final totalPagar = valorParcela * parcelasReal;
    final valorJuros = totalPagar - restante;
    final totalVenda = entradaValor + totalPagar;
    final lucro = precoVenda - cmvTotal;
    final parcelasParaCobrirCusto = (cmvTotal > entradaValor) ? ((cmvTotal - entradaValor) / valorParcela).ceil() : 0;

    setState(() {
      _resultado = {
        'produto': '${produtoSelecionado!['marca']} - ${produtoSelecionado!['modelo']}',
        'preco_venda_final': precoVenda,
        'parcelas': parcelas,
        'juros': juros,
        'entrada': entradaPercentual,
        'margem': margem,
        'lucro': lucro,
        'cmv_base': cmv,
        'cmv_total': cmvTotal,
        'tipo_parcelamento': tipoParcelamento,
        'forma_pagamento': formaPagamento,
        'parcelas_cobrir_custo': parcelasParaCobrirCusto,
        'total_pagar': totalPagar,
        'total_venda': totalVenda,
        'salvo_por': widget.usuario['nome'] ?? 'Desconhecido',
        // Valores para exibição
        'jurosValor': valorJuros,
        'entradaValor': entradaValor,
        'valorCredito': restante,
        'valorParcela': valorParcela,
        'parcelasReal': parcelasReal,
        'precoSugerido': precoSugerido,
      };
    });
  }

  // ✨ LÓGICA PARA SALVAR A SIMULAÇÃO ONLINE ✨
  Future<void> _salvarSimulacaoOnline() async {
    if (_resultado == null) {
      showSnack("Por favor, gere uma simulação antes de salvar.", isError: true);
      return;
    }
    try {
      await ApiService.salvarSimulacao(_resultado!);
      showSnack("✅ Simulação salva com sucesso!");
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
            const Text('Simulação Loja Online', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: margemController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Margem (%)'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: jurosController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Juros (%)'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: entradaPercentualController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Entrada (%)'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: parcelasController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Parcelas'))),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: formaPagamento,
                    decoration: const InputDecoration(labelText: 'Forma de Pagamento da Entrada'),
                    items: const [DropdownMenuItem(value: 'Pix', child: Text('Pix')), DropdownMenuItem(value: 'Dinheiro', child: Text('Dinheiro'))],
                    onChanged: (value) => setState(() => formaPagamento = value!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: tipoParcelamento,
                    decoration: const InputDecoration(labelText: 'Tipo de Parcelamento'),
                    items: const [DropdownMenuItem(value: 'Mensal', child: Text('Mensal')), DropdownMenuItem(value: 'Quinzenal', child: Text('Quinzenal'))],
                    onChanged: (value) => setState(() => tipoParcelamento = value!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Map<String, dynamic>>(
              value: produtoSelecionado,
              decoration: const InputDecoration(labelText: 'Selecione o Produto'),
              items: produtos.map((produto) => DropdownMenuItem<Map<String, dynamic>>(value: produto, child: Text('${produto['marca']} - ${produto['modelo']}'))).toList(),
              onChanged: (value) => setState(() => produtoSelecionado = value),
            ),
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
                    Text('💡 Preço Sugerido: ${formatarReal(_resultado!['precoSugerido'])}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: TextField(controller: precoVendaController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Preço Venda Final'))),
                        const SizedBox(width: 12),
                        ElevatedButton(onPressed: simular, style: AppButtonStyle.primaryButton, child: const Text('Atualizar'))
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('📦 CMV Base: ${formatarReal(_resultado!['cmv_base'])}'),
                    Text('📦 CMV Total: ${formatarReal(_resultado!['cmv_total'])}'),
                    Text('💵 Lucro: ${formatarReal(_resultado!['lucro'])}'),
                    Text('📈 Juros (${jurosController.text}%): ${formatarReal(_resultado!['jurosValor'])}'),
                    Text('📉 Entrada (${entradaPercentualController.text}%): ${formatarReal(_resultado!['entradaValor'])}'),
                    Text('💳 Valor do Crédito: ${formatarReal(_resultado!['valorCredito'])}'),
                    Text('🧾 Valor por parcela (${_resultado!['parcelasReal']}x): ${formatarReal(_resultado!['valorParcela'])}'),
                    Text('🔢 Total a pagar: ${formatarReal(_resultado!['total_pagar'])}'),
                    Text('💰 Total da Venda: ${formatarReal(_resultado!['total_venda'])}'),
                    Text('📊 Parcelas p/ Cobrir Custo: ${_resultado!['parcelas_cobrir_custo']}'),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _salvarSimulacaoOnline, // ✨ AÇÃO DE SALVAR IMPLEMENTADA
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