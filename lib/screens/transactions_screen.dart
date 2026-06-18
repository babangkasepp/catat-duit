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
      appBar: AppBar(title: const Text('Riwayat')),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('📝', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 12),
                          Text(
                            'Belum ada transaksi',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tekan tombol + untuk mulai catat',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                // Group by month, then by date
                final monthGroups = <String, List<Txn>>{};
                for (final t in filtered) {
                  final key =
                      '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
                  monthGroups.putIfAbsent(key, () => []).add(t);
                }

                // Compute cumulative balance BEFORE each month
                // We need all txns (unfiltered) for accurate carry-over
                final allSorted = List<Txn>.from(list)
                  ..sort((a, b) => a.date.compareTo(b.date));
                final monthCumulBefore = <String, double>{};
                double running = 0;
                String? prevMonth;
                for (final t in allSorted) {
                  final key =
                      '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}';
                  if (prevMonth != null && key != prevMonth) {
                    monthCumulBefore.putIfAbsent(key, () => running);
                  }
                  monthCumulBefore.putIfAbsent(key, () => running);
                  running += t.type == TxnType.income ? t.amount : -t.amount;
                  prevMonth = key;
                }

                final sortedMonthKeys = monthGroups.keys.toList()
                  ..sort((a, b) => b.compareTo(a)); // newest first

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                  itemCount: sortedMonthKeys.length,
                  itemBuilder: (context, i) {
                    final monthKey = sortedMonthKeys[i];
                    final txns = monthGroups[monthKey]!;
                    return _MonthSection(
                      monthKey: monthKey,
                      transactions: txns,
                      catMap: catMap,
                      carryOver: monthCumulBefore[monthKey] ?? 0,
                      allTransactions: list,
                      onDelete: (t) => _confirmDelete(t),
                    );
                  },
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

  Future<void> _confirmDelete(Txn t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus transaksi?'),
        content: Text('${Money.format(t.amount)} ${t.note ?? ''}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal')),
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
}

/// A collapsible month section with summary header + daily groups.
class _MonthSection extends StatelessWidget {
  final String monthKey; // "2026-06"
  final List<Txn> transactions;
  final Map<String, Category> catMap;
  final double carryOver;
  final List<Txn> allTransactions;
  final void Function(Txn) onDelete;

  const _MonthSection({
    required this.monthKey,
    required this.transactions,
    required this.catMap,
    required this.carryOver,
    required this.allTransactions,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Parse month
    final parts = monthKey.split('-');
    final year = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final monthLabel = '${DateRange.monthName(month)} $year';

    // Compute this month's totals
    double monthIncome = 0;
    double monthExpense = 0;
    for (final t in transactions) {
      if (t.type == TxnType.income) {
        monthIncome += t.amount;
      } else {
        monthExpense += t.amount;
      }
    }
    final endBalance = carryOver + monthIncome - monthExpense;

    // Group by day
    final dayGroups = <String, List<Txn>>{};
    for (final t in transactions) {
      final key =
          '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
      dayGroups.putIfAbsent(key, () => []).add(t);
    }
    final sortedDays = dayGroups.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // ─── Month header card ───
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.primaryContainer.withOpacity(0.5),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    monthLabel,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${transactions.length} transaksi',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _summaryChip(
                      theme, '↓ Masuk', monthIncome, Colors.green.shade600),
                  const SizedBox(width: 12),
                  _summaryChip(
                      theme, '↑ Keluar', monthExpense, theme.colorScheme.error),
                ],
              ),
              const SizedBox(height: 10),
              Divider(
                  height: 1,
                  color: theme.colorScheme.onPrimaryContainer.withOpacity(0.12)),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (carryOver != 0) ...[
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Saldo awal',
                              style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer
                                      .withOpacity(0.6))),
                          Text(
                            Money.compact(carryOver),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward,
                        size: 16,
                        color: theme.colorScheme.onPrimaryContainer
                            .withOpacity(0.4)),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: carryOver != 0
                          ? CrossAxisAlignment.end
                          : CrossAxisAlignment.start,
                      children: [
                        Text(
                            carryOver != 0 ? 'Saldo akhir' : 'Saldo bulan ini',
                            style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer
                                    .withOpacity(0.6))),
                        Text(
                          Money.compact(endBalance),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: endBalance >= 0
                                ? Colors.green.shade700
                                : theme.colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // ─── Daily groups ───
        for (final dayKey in sortedDays) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 12, bottom: 6),
            child: Row(
              children: [
                Text(
                  _dayLabel(dayGroups[dayKey]!.first.date),
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Divider(
                      color: theme.colorScheme.outlineVariant, height: 1),
                ),
                const SizedBox(width: 8),
                Text(
                  _dayTotal(dayGroups[dayKey]!),
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Card(
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (var i = 0; i < dayGroups[dayKey]!.length; i++) ...[
                  _TxTile(
                    txn: dayGroups[dayKey]![i],
                    category: catMap[dayGroups[dayKey]![i].categoryId],
                    onDelete: onDelete,
                  ),
                  if (i < dayGroups[dayKey]!.length - 1)
                    Divider(
                        height: 1,
                        indent: 68,
                        color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryChip(
      ThemeData theme, String label, double value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: color, fontWeight: FontWeight.w600)),
            Text(
              Money.compact(value),
              style: theme.textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
      ),
    );
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dDay = DateTime(d.year, d.month, d.day);
    final diff = today.difference(dDay).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    if (diff < 7) return '$diff hari lalu';
    return '${d.day} ${DateRange.monthName(d.month)}';
  }

  String _dayTotal(List<Txn> txns) {
    double net = 0;
    for (final t in txns) {
      net += t.type == TxnType.income ? t.amount : -t.amount;
    }
    final prefix = net >= 0 ? '+' : '';
    return '$prefix${Money.compact(net.abs())}';
  }
}

class _TxTile extends StatelessWidget {
  final Txn txn;
  final Category? category;
  final void Function(Txn) onDelete;

  const _TxTile({required this.txn, this.category, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = txn.type == TxnType.income;
    final amountColor =
        isIncome ? Colors.green.shade600 : theme.colorScheme.error;
    final sign = isIncome ? '+' : '−';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: category != null
          ? CategoryChip(category: category!, size: 42)
          : CircleAvatar(
              radius: 21,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: theme.colorScheme.onSurfaceVariant,
                size: 18,
              ),
            ),
      title: Text(
        category?.name ?? (isIncome ? 'Pemasukan' : 'Pengeluaran'),
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: txn.note != null && txn.note!.isNotEmpty
          ? Text(
              txn.note!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            )
          : null,
      trailing: Text(
        '$sign ${Money.compact(txn.amount)}',
        style: theme.textTheme.titleMedium?.copyWith(
          color: amountColor,
          fontWeight: FontWeight.w700,
        ),
      ),
      onLongPress: () => onDelete(txn),
    );
  }
}
