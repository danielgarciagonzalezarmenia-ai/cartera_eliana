import 'package:flutter/material.dart';
import '../database_helper.dart';
import 'add_customer_screen.dart';
import 'customer_detail_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final db = DatabaseHelper();
  List<Customer> _customers = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final list = await db.getCustomers();
    setState(() {
      _customers = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Clientas'),
        centerTitle: true,
        backgroundColor: const Color(0xFF6A1B9A),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _customers.isEmpty
              ? const Center(
                  child: Text(
                    'Aun no hay clientas.\nPresiona "+" para agregar una.',
                    textAlign: TextAlign.center,
                  ),
                )
              : ListView.builder(
                  itemCount: _customers.length,
                  itemBuilder: (ctx, i) {
                    final c = _customers[i];
                    return FutureBuilder<double>(
                      future: db.getCustomerDebt(c.id),
                      builder: (ctx, snap) {
                        final debt = snap.data ?? 0;
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(
                            c.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (c.phone.isNotEmpty)
                                Text('Tel: ${c.phone}'),
                              Text(
                                'Debe: \$${debt.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: debt > 0 ? Colors.red.shade700 : Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerDetailScreen(customer: c),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6A1B9A),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddCustomerScreen()),
          );
          if (result == true) _load();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Nueva clienta'),
      ),
    );
  }
}
