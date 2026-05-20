class Budget {
  final String id;
  final String categoryId;
  final double amount;
  final String period; // 'monthly'
  final DateTime createdAt;

  const Budget({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.period,
    required this.createdAt,
  });

  factory Budget.fromMap(Map<String, dynamic> m) => Budget(
        id: m['id'] as String,
        categoryId: m['category_id'] as String,
        amount: (m['amount'] as num).toDouble(),
        period: m['period'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
      );
}
