class TxnType {
  static const expense = 'expense';
  static const income = 'income';
}

class Txn {
  final String id;
  final double amount;
  final String type;
  final String? categoryId;
  final String? note;
  final DateTime date;
  final DateTime createdAt;

  const Txn({
    required this.id,
    required this.amount,
    required this.type,
    required this.categoryId,
    required this.note,
    required this.date,
    required this.createdAt,
  });

  factory Txn.fromMap(Map<String, dynamic> m) => Txn(
        id: m['id'] as String,
        amount: (m['amount'] as num).toDouble(),
        type: m['type'] as String,
        categoryId: m['category_id'] as String?,
        note: m['note'] as String?,
        date: DateTime.fromMillisecondsSinceEpoch(m['date'] as int),
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'type': type,
        'category_id': categoryId,
        'note': note,
        'date': date.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
      };
}
