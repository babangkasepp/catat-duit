import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/utils/formatters.dart';
import '../features/transactions/models/category.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final monthTotals = ref.watch(monthTotalsProvider);
    final yearTotals = ref.watch(yearTotalsProvider);
    final byCat = ref.watch(monthExpenseByCategoryProvider);
    final cats = ref.watch(allCategoriesProvider);

    final now = DateTime.now();
    final monthLabel = '${DateRange.monthName(now.month)} ${now.year}';

    return Scaffold(
      appBar: AppBar(title: const Text('Laporan')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
        children: [
          Text(monthLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          monthTotals.when(
            data: (t) {
              final balance = t.income - t.expense;
              return Row(
                children: [
                  Expanded(child: _statCard(theme, 'Masuk', t.income, Colors.green)),
                  const SizedBox(width: 12),
                  Expanded(child: _statCard(theme, 'Keluar', t.expense, theme.colorScheme.error)),
                ],
              );
            },
            loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator())),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 16),
          monthTotals.when(
            data: (t) => _balanceLine(theme, t.income, t.expense),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),

          Text('Pengeluaran per Kategori',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          byCat.when(
            data: (data) {
              final catList = cats.value ?? const <Category>[];
              final catMap = {for (final c in catList) c.id: c};
              final entries = data.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value));
              if (entries.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('Belum ada pengeluaran bulan ini',
                          style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant)),
                    ),
                  ),
                );
              }
              final total = entries.fold<double>(0, (s, e) => s + e.value);

              return Column(
                children: [
                  AspectRatio(
                    aspectRatio: 1.4,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 50,
                        sections: [
                          for (final e in entries.take(6))
                            PieChartSectionData(
                              value: e.value,
                              color: catMap[e.key]?.colorValue ?? Colors.grey,
                              title: '${(e.value / total * 100).toStringAsFixed(0)}%',
                              radius: 60,
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  for (final e in entries) _catRow(theme, catMap[e.key], e.value, total),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),

          const SizedBox(height: 28),
          Text('Tahun Ini',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          yearTotals.when(
            data: (t) {
              final balance = t.income - t.expense;
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _yearRow(theme, 'Pemasukan', t.income, Colors.green),
                      const SizedBox(height: 8),
                      _yearRow(theme, 'Pengeluaran', t.expense, theme.colorScheme.error),
                      const Divider(),
                      _yearRow(theme, 'Saldo', balance,
                          balance >= 0 ? Colors.green.shade700 : theme.colorScheme.error,
                          bold: true),
                    ],
                  ),
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _statCard(ThemeData theme, String label, double value, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(
              Money.compact(value),
              style: theme.textTheme.titleLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _balanceLine(ThemeData theme, double income, double expense) {
    final total = income + expense;
    if (total == 0) return const SizedBox.shrink();
    final ratio = income / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Rasio Masuk vs Keluar',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                Expanded(flex: (ratio * 100).round(), child: Container(color: Colors.green)),
                Expanded(flex: ((1 - ratio) * 100).round(), child: Container(color: theme.colorScheme.error)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _catRow(ThemeData theme, Category? cat, double value, double total) {
    final pct = (value / total * 100);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (cat != null)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: cat.colorValue.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(cat.icon, style: const TextStyle(fontSize: 16)),
            )
          else
            const CircleAvatar(radius: 16, child: Icon(Icons.category, size: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat?.name ?? 'Tanpa kategori',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: pct / 100,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(cat?.colorValue ?? Colors.grey),
                  minHeight: 6,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(Money.compact(value),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700)),
              Text('${pct.toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _yearRow(ThemeData theme, String label, double value, Color color, {bool bold = false}) {
    return Row(
      children: [
        Text(label,
            style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500)),
        const Spacer(),
        Text(
          Money.format(value),
          style: theme.textTheme.bodyLarge?.copyWith(
              color: color, fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
        ),
      ],
    );
  }
}
