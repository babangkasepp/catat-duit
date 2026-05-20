import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/utils/formatters.dart';
import '../features/transactions/models/transaction.dart';
import '../features/transactions/models/category.dart';
import '../widgets/category_chip.dart';

class TransactionsScreen extends ConsumerStatefulWidget {
  const TransactionsScreen({super.key});

  @override
  ConsumerState<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends ConsumerState<TransactionsScreen> {
  String _filter = 'all'; // all | expense | income

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final txAsync = ref.watch(recentTxProvider);
    final catsAsync = ref.watch(allCategoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transaksi')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'all', label: Text('Semua')),
                ButtonSegment(value: 'expense', label: Text('Keluar')),
                ButtonSegment(value: 'income', label: Text('Masuk')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
          Expanded(
            child: txAsync.when(
              data: (list) {
                final cats = catsAsync.value ?? const <Category>[];
                final catMap = {for (final c in cats) c.id: c};
                final filtered = list.where((t) {
                  if (_filter == 'all') return true;
                  return t.type == _filter;
                }).toList();
                if (filtered.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Text(
                        'Belum ada transaksi.\nTekan tombol + untuk mulai catat.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ),
                  );
                }

                // Group by date
                final groups = <String, List<Txn>>{};
                for (final t in filtered) {
                  final key = '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
                  groups.putIfAbsent(key, () => []).add(t);
                }

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          _dateLabel(entry.value.first.date),
                          style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      Card(
                        child: Column(
                          children: [
                            for (var i = 0; i < entry.value.length; i++) ...[
                              _txTile(theme, entry.value[i], catMap[entry.value[i].categoryId]),
                              if (i < entry.value.length - 1)
                                Divider(height: 1, color: theme.colorScheme.outlineVariant),
                            ],
                          ],
                        ),
                      ),
                    ]
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _txTile(ThemeData theme, Txn t, Category? cat) {
    final isIncome = t.type == TxnType.income;
    final amountColor = isIncome ? Colors.green.shade600 : theme.colorScheme.error;
    final sign = isIncome ? '+' : '−';
    return ListTile(
      leading: cat != null
          ? CategoryChip(category: cat, size: 44)
          : CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      title: Text(
        cat?.name ?? (isIncome ? 'Pemasukan' : 'Pengeluaran'),
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: t.note != null && t.note!.isNotEmpty
          ? Text(
              t.note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant),
            )
          : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '$sign ${Money.compact(t.amount)}',
            style: theme.textTheme.titleMedium?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      onLongPress: () => _confirmDelete(t),
    );
  }

  Future<void> _confirmDelete(Txn t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: Text('${Money.format(t.amount)} ${t.note ?? ''}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(txRepoProvider).delete(t.id);
      ref.read(txRefreshProvider.notifier).state++;
    }
  }

  String _dateLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dDay = DateTime(d.year, d.month, d.day);
    final diff = today.difference(dDay).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    return '${d.day} ${DateRange.monthName(d.month)} ${d.year}';
  }
}
