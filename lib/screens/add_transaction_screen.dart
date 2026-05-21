import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/providers.dart';
import '../core/utils/formatters.dart';
import '../features/transactions/models/category.dart';
import '../features/transactions/models/transaction.dart';
import '../features/transactions/parser/transaction_parser.dart';
import '../widgets/category_chip.dart';
import 'scan_receipt_screen.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  const AddTransactionScreen({super.key});

  @override
  ConsumerState<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  final _quickCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  String _type = TxnType.expense;
  String? _selectedCategoryId;
  DateTime _date = DateTime.now();
  bool _saving = false;
  String? _smartHint;

  @override
  void dispose() {
    _quickCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _onQuickChanged(String value) async {
    if (value.trim().isEmpty) {
      setState(() => _smartHint = null);
      return;
    }
    final result = await TransactionParser.parse(value);
    if (!mounted) return;
    if (result == null) {
      setState(() => _smartHint = null);
      return;
    }
    setState(() {
      _amountCtrl.text = result.amount.toStringAsFixed(0);
      _type = result.type;
      _selectedCategoryId = result.categoryId;
      _noteCtrl.text = result.note ?? '';
      _smartHint = result.confidence >= 0.9
          ? '✨ Auto-deteksi: ${result.type == TxnType.income ? 'Pemasukan' : 'Pengeluaran'} ${Money.compact(result.amount)}'
          : '🔍 Coba deteksi: ${Money.compact(result.amount)}, cek kategori dulu';
    });
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^\d]'), ''));
    if (amount == null || amount <= 0) {
      _toast('Nominal belum valid');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(txRepoProvider).add(
            amount: amount,
            type: _type,
            categoryId: _selectedCategoryId,
            note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
            date: _date,
          );
      ref.read(txRefreshProvider.notifier).state++;
      if (!mounted) return;
      _toast('Tersimpan ✅');
      context.pop();
    } catch (e) {
      _toast('Gagal simpan: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _scanReceipt() async {
    final result = await Navigator.of(context).push<ScanReceiptResult>(
      MaterialPageRoute(builder: (_) => const ScanReceiptScreen()),
    );
    if (result == null || !mounted) return;

    setState(() {
      _type = TxnType.expense;
      if (result.amount != null) {
        _amountCtrl.text = result.amount!.toStringAsFixed(0);
      }
      if (result.merchant != null) {
        _noteCtrl.text = result.merchant!;
        _quickCtrl.text = result.merchant!;
      }
      if (result.date != null) {
        _date = result.date!;
      }
      _smartHint = '📸 Dari struk: ${[
        if (result.amount != null) Money.compact(result.amount!),
        if (result.merchant != null) result.merchant,
      ].join(' · ')}';
    });

    // Trigger category auto-detect using the merchant text
    if (result.merchant != null && result.merchant!.isNotEmpty) {
      final parsed = await TransactionParser.parse(result.merchant!);
      if (!mounted || parsed == null) return;
      setState(() {
        if (parsed.categoryId != null) {
          _selectedCategoryId = parsed.categoryId;
        }
      });
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cats = _type == TxnType.expense
        ? ref.watch(expenseCategoriesProvider)
        : ref.watch(incomeCategoriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catat Transaksi'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Scan Struk',
            icon: const Icon(Icons.document_scanner_outlined),
            onPressed: _saving ? null : _scanReceipt,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Quick input
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.auto_awesome, color: theme.colorScheme.primary, size: 20),
                  const SizedBox(width: 8),
                  Text('Quick Input',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 4),
                Text(
                  'Coba ketik: "50rb kopi" atau "gajian 8jt"',
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _quickCtrl,
                  decoration: const InputDecoration(
                    hintText: 'ketik bebas...',
                    prefixIcon: Icon(Icons.bolt),
                  ),
                  onChanged: _onQuickChanged,
                  textInputAction: TextInputAction.done,
                ),
                if (_smartHint != null) ...[
                  const SizedBox(height: 8),
                  Text(_smartHint!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: theme.colorScheme.primary)),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Type toggle
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: TxnType.expense,
                label: Text('Pengeluaran'),
                icon: Icon(Icons.arrow_upward),
              ),
              ButtonSegment(
                value: TxnType.income,
                label: Text('Pemasukan'),
                icon: Icon(Icons.arrow_downward),
              ),
            ],
            selected: {_type},
            onSelectionChanged: (s) {
              setState(() {
                _type = s.first;
                _selectedCategoryId = null;
              });
            },
          ),
          const SizedBox(height: 20),

          Text('Nominal', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _amountCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            decoration: const InputDecoration(
              prefixText: 'Rp ',
              hintText: '0',
            ),
          ),
          const SizedBox(height: 20),

          Text('Kategori', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          cats.when(
            data: (list) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in list)
                  CategoryTile(
                    category: c,
                    selected: _selectedCategoryId == c.id,
                    onTap: () => setState(() => _selectedCategoryId = c.id),
                  ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
          const SizedBox(height: 20),

          Text('Catatan (opsional)', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _noteCtrl,
            decoration: const InputDecoration(hintText: 'Misal: kopi di kantor'),
            maxLines: 2,
          ),
          const SizedBox(height: 20),

          Text('Tanggal', style: theme.textTheme.labelLarge),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: Text('${_date.day}/${_date.month}/${_date.year}'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 32),

          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check),
            label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
