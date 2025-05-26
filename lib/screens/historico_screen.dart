import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api_service.dart';
import '../components/app_scaffold.dart';
import '../utils/theme.dart';

class HistoricoScreen extends StatefulWidget {
  final bool isAdmin;
  final Map<String, dynamic> usuario;

  const HistoricoScreen({super.key, required this.isAdmin, required this.usuario});

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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Histórico de Simulações',
      isAdmin: widget.isAdmin,
      usuario: widget.usuario,
      child: Column(
        children: [
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
                            if (widget.isAdmin)
                              IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => excluir(s['id']),
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
        ],
      ),
    );
  }
}
