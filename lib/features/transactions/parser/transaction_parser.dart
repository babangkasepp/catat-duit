import '../../../core/db/database.dart';
import '../models/transaction.dart';
import 'amount_parser.dart';

class ParseResult {
  final double amount;
  final String type; // expense | income
  final String? categoryId;
  final String? note;
  final double confidence;

  const ParseResult({
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.note,
    required this.confidence,
  });
}

class TransactionParser {
  static const _incomeMarkers = [
    'gaji', 'gajian', 'salary', 'bonus', 'thr', 'dapet', 'dapat',
    'masuk', 'cuan', 'profit', 'dividen', 'honor',
    'fee', 'komisi', 'kiriman', 'dikirim', 'dikasih'
  ];

  static Future<ParseResult?> parse(String input) async {
    final amount = AmountParser.parse(input);
    if (amount == null || amount <= 0) return null;

    final stripped = AmountParser.stripAmount(input);
    final lower = input.toLowerCase();

    final isIncome = lower.startsWith('+') || _incomeMarkers.any((m) => lower.contains(m));
    final type = isIncome ? TxnType.income : TxnType.expense;

    final categoryMatch = await _matchCategory(stripped, type);

    return ParseResult(
      amount: amount,
      type: type,
      categoryId: categoryMatch?.$1,
      note: stripped.isEmpty ? null : stripped,
      confidence: categoryMatch?.$2 ?? 0.4,
    );
  }

  static Future<(String, double)?> _matchCategory(String text, String type) async {
    if (text.isEmpty) return null;
    final db = AppDatabase.instance.db;
    final tokens = text.split(RegExp(r'\s+')).where((t) => t.length >= 2).toList();
    if (tokens.isEmpty) return null;

    // Direct keyword match
    for (final token in tokens) {
      final rows = await db.rawQuery(
        'SELECT k.category_id FROM keywords k '
        'JOIN categories c ON c.id = k.category_id '
        'WHERE k.keyword = ? AND c.type = ? LIMIT 1',
        [token, type],
      );
      if (rows.isNotEmpty) {
        return (rows.first['category_id'] as String, 0.95);
      }
    }

    // Partial / contains
    for (final token in tokens) {
      final rows = await db.rawQuery(
        'SELECT k.category_id FROM keywords k '
        'JOIN categories c ON c.id = k.category_id '
        "WHERE (k.keyword LIKE ? OR ? LIKE '%' || k.keyword || '%') AND c.type = ? LIMIT 1",
        ['%$token%', token, type],
      );
      if (rows.isNotEmpty) {
        return (rows.first['category_id'] as String, 0.75);
      }
    }

    final fallback = type == TxnType.income ? 'lainnya_masuk' : 'lainnya_keluar';
    return (fallback, 0.3);
  }
}
