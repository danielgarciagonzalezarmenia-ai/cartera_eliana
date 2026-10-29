import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../database_helper.dart';
import '../notification_service.dart';

class AddSaleScreen extends StatefulWidget {
  final Customer customer;
  const AddSaleScreen({super.key, required this.customer});

  @override
  State<AddSaleScreen> createState() => _AddSaleScreenState();
}

class _AddSaleScreenState extends State<AddSaleScreen> {
  final _itemCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _paidCtrl = TextEditingController(text: '0');
  final _noteCtrl = TextEditingController();
  final _picker = ImagePicker();
  final db = DatabaseHelper();
  File? _photo;

  @override
  void dispose() {
    _itemCtrl.dispose();
    _priceCtrl.dispose();
    _paidCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _takePhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
      maxWidth: 1024,
    );
    if (picked != null) {
      setState(() => _photo = File(picked.path));
    }
  }

  Future<void> _save() async {
    final item = _itemCtrl.text.trim();
    final price = double.tryParse(_priceCtrl.text) ?? 0;
    final paid = double.tryParse(_paidCtrl.text) ?? 0;

    if (item.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingresa el articulo y un precio valido')),
      );
      return;
    }

    final now = DateTime.now();
    final saleId = now.millisecondsSinceEpoch.toString();
    await db.insertSale(Sale(
      id: saleId,
      customerId: widget.customer.id,
      item: item,
      photoPath: _photo?.path,
      totalAmount: price,
      createdAt: now.toIso8601String(),
    ));

    if (paid > 0) {
      await db.insertPayment(Payment(
        id: '${saleId}_p1',
        saleId: saleId,
        amount: paid,
        paidAt: now.toIso8601String(),
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      ));
    }

    await NotificationService().scheduleCollectionReminder(
      customerName: widget.customer.name,
      fromDate: now,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Venta guardada. Recordatorio programado en 15 dias a las 8:00 AM.'),
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Venta - ${widget.customer.name}'),
        backgroundColor: const Color(0xFF6A1B9A),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(
              controller: _itemCtrl,
              decoration: const InputDecoration(
                labelText: 'Articulo (ej. anillo)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_bag),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _priceCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Precio total',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 110,
                  child: TextField(
                    controller: _paidCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Abono inicial',
                      border: OutlineInputBorder(),
                      prefixText: '\$ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Nota (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Foto del articulo'),
                    onPressed: _takePhoto,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6A1B9A),
                    ),
                  ),
                ),
                if (_photo != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: Image.file(_photo!, width: 80, height: 80, fit: BoxFit.cover),
                  ),
              ],
            ),
            if (_photo != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Foto: ${_photo!.path.split('/').last}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            const SizedBox(height: 26),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6A1B9A),
                ),
                onPressed: _save,
                child: const Text('Guardar venta y abono', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
