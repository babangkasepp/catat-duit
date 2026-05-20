import 'package:uuid/uuid.dart';
import '../../../core/db/database.dart';
import '../models/transaction.dart';

class TransactionRepository {
  final _db = AppDatabase.instance;
  static const _uuid = Uuid();

  Future<String> add({
    required double amount,
    required String type,
    String? categoryId,
    String? note,
    DateTime? date,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    await _db.db.insert('transactions_tbl', {
      'id': id,
      'amount': amount,
      'type': type,
      'category_id': categoryId,
      'note': note,
      'date': (date ?? now).millisecondsSinceEpoch,
      'created_at': now.millisecondsSinceEpoch,
    });
    return id;
  }

  Future<void> update(Txn txn) async {
    await _db.db.update(
      'transactions_tbl',
      txn.toMap(),
      where: 'id = ?',
      whereArgs: [txn.id],
    );
  }

  Future<void> delete(String id) async {
    await _db.db.delete('transactions_tbl', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Txn>> range(DateTime start, DateTime end) async {
    final rows = await _db.db.query(
      'transactions_tbl',
      where: 'date >= ? AND date <= ?',
      whereArgs: [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'date DESC',
    );
    return rows.map(Txn.fromMap).toList();
  }

  Future<List<Txn>> recent({int limit = 50}) async {
    final rows = await _db.db.query(
      'transactions_tbl',
      orderBy: 'date DESC',
      limit: limit,
    );
    return rows.map(Txn.fromMap).toList();
  }

  Future<Map<String, double>> sumByCategory(DateTime start, DateTime end, String type) async {
    final rows = await _db.db.rawQuery(
      'SELECT category_id, SUM(amount) as total FROM transactions_tbl '
      'WHERE date >= ? AND date <= ? AND type = ? GROUP BY category_id',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch, type],
    );
    return {
      for (final r in rows)
        (r['category_id'] as String? ?? 'unknown'): (r['total'] as num).toDouble()
    };
  }

  Future<({double income, double expense})> totals(DateTime start, DateTime end) async {
    final rows = await _db.db.rawQuery(
      'SELECT type, SUM(amount) as total FROM transactions_tbl '
      'WHERE date >= ? AND date <= ? GROUP BY type',
      [start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
    );
    double income = 0, expense = 0;
    for (final r in rows) {
      final t = r['type'] as String;
      final v = (r['total'] as num).toDouble();
      if (t == 'income') income = v;
      if (t == 'expense') expense = v;
    }
    return (income: income, expense: expense);
  }
}
