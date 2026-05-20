import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/providers.dart';
import '../core/utils/formatters.dart';
import '../features/budget/budget_model.dart';
import '../features/transactions/models/category.dart';

class BudgetScreen extends ConsumerWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final budgets = ref.watch(budgetsProvider);
    final cats = ref.watch(expenseCategoriesProvider);
    final byCat = ref.watch(monthExpenseByCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Bulanan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showSetBudget(context, ref),
          ),
        ],
      ),
      body: budgets.when(
        data: (list) {
          if (list.isEmpty) {
            return _emptyState(theme, () => _showSetBudget(context, ref));
          }
          final catList = cats.value ?? const <Category>[];
          final catMap = {for (final c in catList) c.id: c};
          final spentMap = byCat.value ?? const <String, double>{};

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            children: [
              for (final b in list)
                _budgetCard(context, ref, theme, b, catMap[b.categoryId], spentMap[b.categoryId] ?? 0),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _emptyState(ThemeData theme, VoidCallback onAdd) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🎯', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 12),
            Text('Belum ada budget',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'Set budget per kategori biar lu bisa\nkontrol pengeluaran bulanan.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Budget'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _budgetCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    Budget b,
    Category? cat,
    double spent,
  ) {
    final pct = b.amount == 0 ? 0.0 : (spent / b.amount).clamp(0.0, 1.5);
    final pctInt = (pct * 100).round();
    final over = pct >= 1.0;
    final warn = pct >= 0.8;
    final color = over
        ? theme.colorScheme.error
        : warn
            ? Colors.orange
            : (cat?.colorValue ?? theme.colorScheme.primary);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onLongPress: () => _confirmDelete(context, ref, b),
        onTap: () => _showSetBudget(context, ref, existing: b),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                if (cat != null)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: cat.colorValue.withOpacity(0.18),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(cat.icon, style: const TextStyle(fontSize: 20)),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(cat?.name ?? 'Kategori dihapus',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700)),
                      Text(
                        '${Money.compact(spent)} / ${Money.compact(b.amount)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$pctInt%',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: color, fontWeight: FontWeight.w800),
                ),
              ]),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: pct.clamp(0.0, 1.0),
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 10,
                ),
              ),
              if (over) ...[
                const SizedBox(height: 8),
                Row(children: [
                  Icon(Icons.warning_amber_rounded, color: theme.colorScheme.error, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Lewat budget ${Money.compact(spent - b.amount)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.error),
                    ),
                  ),
                ]),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, Budget b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus budget?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(budgetRepoProvider).delete(b.id);
      ref.read(txRefreshProvider.notifier).state++;
    }
  }

  Future<void> _showSetBudget(BuildContext context, WidgetRef ref, {Budget? existing}) async {
    final cats = await ref.read(categoryRepoProvider).all(type: 'expense');
    if (!context.mounted) return;
    String? selectedId = existing?.categoryId ?? cats.first.id;
    final amountCtrl = TextEditingController(
      text: existing != null ? existing.amount.toStringAsFixed(0) : '',
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: StatefulBuilder(
            builder: (ctx, setSt) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(existing != null ? 'Edit Budget' : 'Set Budget Baru',
                      style: Theme.of(ctx).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 16),
                  Text('Kategori', style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in cats)
                        ChoiceChip(
                          label: Text('${c.icon} ${c.name}'),
                          selected: selectedId == c.id,
                          onSelected: (_) => setSt(() => selectedId = c.id),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text('Nominal Per Bulan', style: Theme.of(ctx).textTheme.labelLarge),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(prefixText: 'Rp '),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () async {
                      final a = double.tryParse(amountCtrl.text);
                      if (a == null || a <= 0 || selectedId == null) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Cek lagi data-nya')));
                        return;
                      }
                      await ref.read(budgetRepoProvider).upsert(
                          categoryId: selectedId!, amount: a);
                      ref.read(txRefreshProvider.notifier).state++;
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                    child: const Text('Simpan'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}
