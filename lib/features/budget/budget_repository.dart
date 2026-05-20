import 'package:uuid/uuid.dart';
import '../../core/db/database.dart';
import 'budget_model.dart';

class BudgetRepository {
  final _db = AppDatabase.instance;
  static const _uuid = Uuid();

  Future<List<Budget>> all() async {
    final rows = await _db.db.query('budgets', orderBy: 'created_at DESC');
    return rows.map(Budget.fromMap).toList();
  }

  Future<Budget?> byCategory(String categoryId) async {
    final rows = await _db.db.query(
      'budgets',
      where: 'category_id = ? AND period = ?',
      whereArgs: [categoryId, 'monthly'],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Budget.fromMap(rows.first);
  }

  Future<void> upsert({required String categoryId, required double amount}) async {
    final existing = await byCategory(categoryId);
    if (existing == null) {
      await _db.db.insert('budgets', {
        'id': _uuid.v4(),
        'category_id': categoryId,
        'amount': amount,
        'period': 'monthly',
        'created_at': DateTime.now().millisecondsSinceEpoch,
      });
    } else {
      await _db.db.update(
        'budgets',
        {'amount': amount},
        where: 'id = ?',
        whereArgs: [existing.id],
      );
    }
  }

  Future<void> delete(String id) async {
    await _db.db.delete('budgets', where: 'id = ?', whereArgs: [id]);
  }
}
