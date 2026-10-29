import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database_helper.dart';
import '../notification_service.dart';
import 'add_sale_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;
  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  final db = DatabaseHelper();
  List<Sale> _sales = [];
  bool _loading = true;

  String _fmt(DateTime d) => DateFormat('dd/MM/yyyy HH:mm').format(d);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final sales = await db.getSalesByCustomer(widget.customer.id);
    setState(() {
      _sales = sales;
      _loading = false;
    });
  }

  Future<void> _addAbono(Sale sale) async {
    final amtCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Abono a ${sale.item}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amtCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monto del abono',
                prefixText: '\$ ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A1B9A)),
            onPressed: () async {
              final amount = double.tryParse(amtCtrl.text) ?? 0;
              if (amount <= 0) return;
              final now = DateTime.now();
              await db.insertPayment(Payment(
                id: '${sale.id}_p${DateTime.now().millisecondsSinceEpoch}',
                saleId: sale.id,
                amount: amount,
                paidAt: now.toIso8601String(),
                note: noteCtrl.text.trim().isEmpty ? null : noteCtrl.text.trim(),
              ));
              await NotificationService().scheduleCollectionReminder(
                customerName: widget.customer.name,
                fromDate: now,
              );
              if (mounted) Navigator.pop(context);
              _load();
            },
            child: const Text('Guardar abono'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSale(Sale sale) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Eliminar venta'),
        content: const Text('¿Seguro que quieres eliminar esta venta y sus abonos?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Sí', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await db.deleteSale(sale.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.name),
        backgroundColor: const Color(0xFF6A1B9A),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {},
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  width: double.infinity,
                  color: const Color(0xFF6A1B9A).withValues(alpha: 0.1),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.customer.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold)),
                      if (widget.customer.phone.isNotEmpty)
                        Text('Tel: ${widget.customer.phone}'),
                      const SizedBox(height: 8),
                      FutureBuilder<double>(
                        future: db.getCustomerDebt(widget.customer.id),
                        builder: (ctx, snap) {
                          final debt = snap.data ?? 0;
                          return Text(
                            'Saldo total a cobrar: \$${debt.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: debt > 0 ? Colors.red.shade700 : Colors.green.shade700,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Cartera - Ventas',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
                if (_sales.isEmpty)
                  const Expanded(
                    child: Center(
                      child: Text('Aun no hay ventas para esta clienta.'),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _sales.length,
                      itemBuilder: (ctx, i) {
                        final s = _sales[i];
                        return FutureBuilder<List<Payment>>(
                          future: db.getPaymentsBySale(s.id),
                          builder: (ctx, snap) {
                            final paid = snap.data
                                    ?.fold(0.0, (sum, p) => sum + p.amount) ??
                                0.0;
                            final balance = s.totalAmount - paid;
                            final created = DateTime.tryParse(s.createdAt);
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 6),
                              child: ListTile(
                                leading: s.photoPath != null &&
                                        File(s.photoPath!).existsSync()
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.file(
                                          File(s.photoPath!),
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const CircleAvatar(
                                        child: Icon(Icons.shopping_bag)),
                                title: Text(s.item,
                                    style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'Total: \$${s.totalAmount.toStringAsFixed(2)}  |  Abonado: \$${paid.toStringAsFixed(2)}'),
                                    Text(
                                        'Saldo: \$${balance.toStringAsFixed(2)}  |  ${created != null ? _fmt(created) : s.createdAt}'),
                                  ],
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.add_circle,
                                          color: Color(0xFF6A1B9A)),
                                      onPressed: () => _addAbono(s),
                                      tooltip: 'Registrar abono',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          color: Colors.red),
                                      onPressed: () => _deleteSale(s),
                                    ),
                                  ],
                                ),
                                onTap: () => _showHistory(s),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6A1B9A),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddSaleScreen(customer: widget.customer),
            ),
          );
          if (result == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva venta'),
      ),
    );
  }

  void _showHistory(Sale sale) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historial - ${sale.item}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            FutureBuilder<List<Payment>>(
              future: db.getPaymentsBySale(sale.id),
              builder: (ctx, snap) {
                final pays = snap.data ?? [];
                if (pays.isEmpty) {
                  return const Center(
                      child: Text('Sin abonos registrados aun.'));
                }
                return SizedBox(
                  height: 300,
                  child: ListView.builder(
                    itemCount: pays.length,
                    itemBuilder: (c2, i) {
                      final p = pays[i];
                      final d = DateTime.tryParse(p.paidAt);
                      return ListTile(
                        leading: const Icon(Icons.payment),
                        title: Text('\$${p.amount.toStringAsFixed(2)}'),
                        subtitle: Text(d != null ? _fmt(d) : p.paidAt),
                        trailing: p.note != null ? Text(p.note!) : null,
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.add_circle),
                label: const Text('Registrar nuevo abono'),
                onPressed: () {
                  Navigator.pop(context);
                  _addAbono(sale);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
