import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  Database? _db;
  Database get db {
    final database = _db;
    if (database == null) {
      throw StateError('Database belum di-init. Panggil AppDatabase.instance.init() dulu.');
    }
    return database;
  }

  Future<void> init() async {
    if (_db != null) return;
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'catat_duit.db');
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: _onCreate,
    );
    await _seedCategories();
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('CREATE TABLE categories ('
        'id TEXT PRIMARY KEY, '
        'name TEXT NOT NULL, '
        'icon TEXT NOT NULL, '
        'color TEXT NOT NULL, '
        'type TEXT NOT NULL, '
        'is_default INTEGER NOT NULL DEFAULT 0, '
        'created_at INTEGER NOT NULL'
        ')');

    await db.execute('CREATE TABLE keywords ('
        'id INTEGER PRIMARY KEY AUTOINCREMENT, '
        'category_id TEXT NOT NULL, '
        'keyword TEXT NOT NULL, '
        'FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE'
        ')');

    await db.execute('CREATE TABLE transactions_tbl ('
        'id TEXT PRIMARY KEY, '
        'amount REAL NOT NULL, '
        'type TEXT NOT NULL, '
        'category_id TEXT, '
        'note TEXT, '
        'date INTEGER NOT NULL, '
        'created_at INTEGER NOT NULL, '
        'FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE SET NULL'
        ')');

    await db.execute('CREATE TABLE budgets ('
        'id TEXT PRIMARY KEY, '
        'category_id TEXT NOT NULL, '
        'amount REAL NOT NULL, '
        'period TEXT NOT NULL, '
        'created_at INTEGER NOT NULL, '
        'FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE'
        ')');

    await db.execute('CREATE INDEX idx_tx_date ON transactions_tbl(date)');
    await db.execute('CREATE INDEX idx_tx_category ON transactions_tbl(category_id)');
    await db.execute('CREATE INDEX idx_kw_keyword ON keywords(keyword)');
  }

  Future<void> _seedCategories() async {
    final database = _db!;
    final count = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM categories'),
    );
    if ((count ?? 0) > 0) return;

    final raw = await rootBundle.loadString('assets/keywords.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final cats = (data['categories'] as List).cast<Map<String, dynamic>>();
    final now = DateTime.now().millisecondsSinceEpoch;

    final batch = database.batch();
    for (final c in cats) {
      batch.insert('categories', {
        'id': c['id'],
        'name': c['name'],
        'icon': c['icon'],
        'color': c['color'],
        'type': c['type'],
        'is_default': 1,
        'created_at': now,
      });
      for (final kw in (c['keywords'] as List)) {
        batch.insert('keywords', {
          'category_id': c['id'],
          'keyword': (kw as String).toLowerCase().trim(),
        });
      }
    }
    await batch.commit(noResult: true);
  }
}
