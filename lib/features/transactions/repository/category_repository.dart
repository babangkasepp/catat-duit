import 'package:uuid/uuid.dart';
import '../../../core/db/database.dart';
import '../models/category.dart';

class CategoryRepository {
  final _db = AppDatabase.instance;
  static const _uuid = Uuid();

  Future<List<Category>> all({String? type}) async {
    final rows = type == null
        ? await _db.db.query('categories', orderBy: 'name ASC')
        : await _db.db.query('categories', where: 'type = ?', whereArgs: [type], orderBy: 'name ASC');
    return rows.map(Category.fromMap).toList();
  }

  Future<Category?> byId(String id) async {
    final rows = await _db.db.query('categories', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }

  Future<String> create({
    required String name,
    required String icon,
    required String color,
    required String type,
  }) async {
    final id = _uuid.v4();
    await _db.db.insert('categories', {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color,
      'type': type,
      'is_default': 0,
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
    return id;
  }
}
