import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../core/utils/formatters.dart';
import '../features/transactions/models/category.dart';
import '../features/transactions/models/transaction.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final monthTotals = ref.watch(monthTotalsProvider);
    final todayTotals = ref.watch(todayTotalsProvider);
    final recent = ref.watch(recentTxProvider);
    final cats = ref.watch(allCategoriesProvider);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async {
          ref.read(txRefreshProvider.notifier).state++;
          await Future.delayed(const Duration(milliseconds: 300));
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            _greeting(theme),
            const SizedBox(height: 20),
            _balanceCard(theme, monthTotals),
            const SizedBox(height: 16),
            _todayCard(theme, todayTotals),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Transaksi Terbaru',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/transactions'),
                  child: const Text('Lihat semua'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            recent.when(
              data: (list) {
                if (list.isEmpty) {
                  return _emptyState(context);
                }
                final catList = cats.value ?? const <Category>[];
                final catMap = {for (final c in catList) c.id: c};
                return Column(
                  children: [
                    for (final t in list.take(8))
                      _TxRow(txn: t, category: catMap[t.categoryId])
                          .animate()
                          .fadeIn(duration: 200.ms),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _greeting(ThemeData theme) {
    final hour = DateTime.now().hour;
    final greet = hour < 11
        ? 'Selamat pagi'
        : hour < 15
            ? 'Selamat siang'
            : hour < 18
                ? 'Selamat sore'
                : 'Selamat malam';
    return Text(
      '$greet 👋',
      style: theme.textTheme.headlineSmall
          ?.copyWith(fontWeight: FontWeight.w800),
    );
  }

  Widget _balanceCard(
      ThemeData theme, AsyncValue<({double income, double expense})> totals) {
    return totals.when(
      data: (t) {
        final balance = t.income - t.expense;
        final isPositive = balance >= 0;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary,
                theme.colorScheme.primary.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saldo Bulan Ini',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: Colors.white.withOpacity(0.85))),
              const SizedBox(height: 6),
              Text(
                Money.format(balance),
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                      child: _miniStat('Masuk', t.income, Icons.arrow_downward,
                          Colors.greenAccent)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _miniStat('Keluar', t.expense, Icons.arrow_upward,
                          Colors.redAccent)),
                ],
              ),
              if (!isPositive) ...[
                const SizedBox(height: 8),
                Row(children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.amber, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Pengeluaran lebih besar dari pemasukan',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: Colors.white.withOpacity(0.9)),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        );
      },
      loading: () => const SizedBox(
          height: 160, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => Card(
          child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: $e'))),
    );
  }

  Widget _miniStat(String label, double value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
                Text(
                  Money.compact(value),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _todayCard(
      ThemeData theme, AsyncValue<({double income, double expense})> totals) {
    return totals.when(
      data: (t) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.today, color: theme.colorScheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Hari ini',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                    Text(
                      'Keluar ${Money.compact(t.expense)} • Masuk ${Money.compact(t.income)}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        child: Column(
          children: [
            const Text('💸', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            Text(
              'Belum ada transaksi',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Mulai catat pengeluaran lu hari ini.\nKetik aja "50rb kopi" — gampang banget.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/add'),
              icon: const Icon(Icons.add),
              label: const Text('Catat Sekarang'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  final Txn txn;
  final Category? category;
  const _TxRow({required this.txn, this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = txn.type == TxnType.income;
    final amountColor =
        isIncome ? Colors.green.shade600 : theme.colorScheme.error;
    final sign = isIncome ? '+' : '−';

    final leadingWidget = category == null
        ? CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              size: 18,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          )
        : Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: category!.colorValue.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(category!.icon, style: const TextStyle(fontSize: 20)),
          );

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: leadingWidget,
      title: Text(
        category?.name ?? (isIncome ? 'Pemasukan' : 'Pengeluaran'),
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        '${txn.note ?? '-'} • ${_formatDate(txn.date)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      trailing: Text(
        '$sign ${Money.compact(txn.amount)}',
        style: theme.textTheme.titleMedium?.copyWith(
          color: amountColor,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dDay = DateTime(d.year, d.month, d.day);
    final diff = today.difference(dDay).inDays;
    if (diff == 0) return 'Hari ini';
    if (diff == 1) return 'Kemarin';
    if (diff < 7) return '$diff hari lalu';
    return '${d.day}/${d.month}/${d.year}';
  }
}
