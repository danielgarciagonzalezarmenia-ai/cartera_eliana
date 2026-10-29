import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class Customer {
  final String id;
  String name;
  String phone;
  final String createdAt;

  Customer({
    required this.id,
    required this.name,
    this.phone = '',
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'phone': phone,
        'created_at': createdAt,
      };

  factory Customer.fromMap(Map<String, dynamic> m) => Customer(
        id: m['id'] as String,
        name: m['name'] as String,
        phone: m['phone'] as String? ?? '',
        createdAt: m['created_at'] as String,
      );
}

class Sale {
  final String id;
  final String customerId;
  String item;
  String? photoPath;
  double totalAmount;
  final String createdAt;

  Sale({
    required this.id,
    required this.customerId,
    required this.item,
    this.photoPath,
    required this.totalAmount,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'customer_id': customerId,
        'item': item,
        'photo_path': photoPath,
        'total_amount': totalAmount,
        'created_at': createdAt,
      };

  factory Sale.fromMap(Map<String, dynamic> m) => Sale(
        id: m['id'] as String,
        customerId: m['customer_id'] as String,
        item: m['item'] as String,
        photoPath: m['photo_path'] as String?,
        totalAmount: (m['total_amount'] as num).toDouble(),
        createdAt: m['created_at'] as String,
      );
}

class Payment {
  final String id;
  final String saleId;
  double amount;
  final String paidAt;
  String? note;

  Payment({
    required this.id,
    required this.saleId,
    required this.amount,
    required this.paidAt,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'sale_id': saleId,
        'amount': amount,
        'paid_at': paidAt,
        'note': note,
      };

  factory Payment.fromMap(Map<String, dynamic> m) => Payment(
        id: m['id'] as String,
        saleId: m['sale_id'] as String,
        amount: (m['amount'] as num).toDouble(),
        paidAt: m['paid_at'] as String,
        note: m['note'] as String?,
      );
}

class DatabaseHelper {
  static Database? _db;

  static const _dbName = 'cartera_eliana.db';
  static const _version = 1;

  Future<Database> get db async => _db ??= await _init();

  Future<Database> _init() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, _dbName);
    return await openDatabase(
      path,
      version: _version,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE customers(
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            phone TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE sales(
            id TEXT PRIMARY KEY,
            customer_id TEXT NOT NULL,
            item TEXT NOT NULL,
            photo_path TEXT,
            total_amount REAL NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            FOREIGN KEY(customer_id) REFERENCES customers(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE payments(
            id TEXT PRIMARY KEY,
            sale_id TEXT NOT NULL,
            amount REAL NOT NULL DEFAULT 0,
            paid_at TEXT NOT NULL,
            note TEXT,
            FOREIGN KEY(sale_id) REFERENCES sales(id)
          )
        ''');
      },
    );
  }

  Future<void> insertCustomer(Customer c) async {
    final d = await db;
    await d.insert('customers', c.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Customer>> getCustomers() async {
    final d = await db;
    final maps = await d.query('customers', orderBy: 'created_at DESC');
    return maps.map(Customer.fromMap).toList();
  }

  Future<int> updateCustomer(Customer c) async {
    final d = await db;
    return await d.update(
      'customers',
      c.toMap(),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  Future<int> deleteCustomer(String id) async {
    final d = await db;
    return await d.delete('customers', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertSale(Sale s) async {
    final d = await db;
    await d.insert('sales', s.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Sale>> getSalesByCustomer(String customerId) async {
    final d = await db;
    final maps = await d.query(
      'sales',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );
    return maps.map(Sale.fromMap).toList();
  }

  Future<int> updateSale(Sale s) async {
    final d = await db;
    return await d.update(
      'sales',
      s.toMap(),
      where: 'id = ?',
      whereArgs: [s.id],
    );
  }

  Future<int> deleteSale(String id) async {
    final d = await db;
    return await d.delete('sales', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> insertPayment(Payment p) async {
    final d = await db;
    await d.insert('payments', p.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Payment>> getPaymentsBySale(String saleId) async {
    final d = await db;
    final maps = await d.query(
      'payments',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'paid_at DESC',
    );
    return maps.map(Payment.fromMap).toList();
  }

  Future<double> getCustomerDebt(String customerId) async {
    final d = await db;
    final salesRes = await d.rawQuery(
      'SELECT COALESCE(SUM(total_amount),0) AS total FROM sales WHERE customer_id = ?',
      [customerId],
    );
    final totalSales = (salesRes.first['total'] as num).toDouble();

    final payRes = await d.rawQuery(
      'SELECT COALESCE(SUM(amount),0) AS paid FROM payments p JOIN sales s ON p.sale_id = s.id WHERE s.customer_id = ?',
      [customerId],
    );
    final totalPaid = (payRes.first['paid'] as num).toDouble();

    return totalSales - totalPaid;
  }

  Future<void> close() async {
    final d = await db;
    await d.close();
    _db = null;
  }
}
