import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/formatters.dart';
import '../features/transactions/repository/transaction_repository.dart';
import '../features/transactions/repository/category_repository.dart';

/// Data class for year-in-review stats.
class WrappedStats {
  final int year;
  final double totalIncome;
  final double totalExpense;
  final double balance;
  final int totalTransactions;
  final int daysActive;
  final String? topCategoryName;
  final String? topCategoryIcon;
  final double topCategoryAmount;
  final double avgDailyExpense;
  final String biggestExpenseNote;
  final double biggestExpenseAmount;
  final String? biggestExpenseCategoryName;
  final int monthMostActive;
  final int monthMostActiveCount;

  const WrappedStats({
    required this.year,
    required this.totalIncome,
    required this.totalExpense,
    required this.balance,
    required this.totalTransactions,
    required this.daysActive,
    required this.topCategoryName,
    required this.topCategoryIcon,
    required this.topCategoryAmount,
    required this.avgDailyExpense,
    required this.biggestExpenseNote,
    required this.biggestExpenseAmount,
    required this.biggestExpenseCategoryName,
    required this.monthMostActive,
    required this.monthMostActiveCount,
  });
}

class WrappedScreen extends ConsumerStatefulWidget {
  const WrappedScreen({super.key});

  @override
  ConsumerState<WrappedScreen> createState() => _WrappedScreenState();
}

class _WrappedScreenState extends ConsumerState<WrappedScreen> {
  WrappedStats? _stats;
  bool _loading = true;
  int _currentPage = 0;
  late PageController _pageCtrl;

  @override
  void initState() {
    super.initState();
    _pageCtrl = PageController();
    _loadStats();
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    final year = DateTime.now().year;
    final txRepo = TransactionRepository();
    final catRepo = CategoryRepository();

    final start = DateTime(year, 1, 1);
    final end = DateTime(year, 12, 31, 23, 59, 59);

    final transactions = await txRepo.range(start, end);
    final totals = await txRepo.totals(start, end);
    final byCat = await txRepo.sumByCategory(start, end, 'expense');
    final allCats = await catRepo.all();
    final catMap = {for (final c in allCats) c.id: c};

    // Top expense category
    String? topCatId;
    double topCatAmount = 0;
    for (final e in byCat.entries) {
      if (e.value > topCatAmount) {
        topCatAmount = e.value;
        topCatId = e.key;
      }
    }

    // Days active
    final activeDays = <String>{};
    for (final t in transactions) {
      activeDays.add('${t.date.year}-${t.date.month}-${t.date.day}');
    }

    // Biggest single expense
    double bigAmount = 0;
    String bigNote = '-';
    String? bigCatName;
    for (final t in transactions) {
      if (t.type == 'expense' && t.amount > bigAmount) {
        bigAmount = t.amount;
        bigNote = t.note ?? '-';
        bigCatName = catMap[t.categoryId]?.name;
      }
    }

    // Month most active
    final monthCounts = <int, int>{};
    for (final t in transactions) {
      monthCounts[t.date.month] = (monthCounts[t.date.month] ?? 0) + 1;
    }
    int bestMonth = 1;
    int bestMonthCount = 0;
    for (final e in monthCounts.entries) {
      if (e.value > bestMonthCount) {
        bestMonth = e.key;
        bestMonthCount = e.value;
      }
    }

    // Average daily expense
    final daysInYear = DateTime.now()
        .difference(DateTime(year, 1, 1))
        .inDays
        .clamp(1, 366);
    final avgDaily = totals.expense / daysInYear;

    if (!mounted) return;
    setState(() {
      _stats = WrappedStats(
        year: year,
        totalIncome: totals.income,
        totalExpense: totals.expense,
        balance: totals.income - totals.expense,
        totalTransactions: transactions.length,
        daysActive: activeDays.length,
        topCategoryName: catMap[topCatId]?.name,
        topCategoryIcon: catMap[topCatId]?.icon,
        topCategoryAmount: topCatAmount,
        avgDailyExpense: avgDaily,
        biggestExpenseNote: bigNote,
        biggestExpenseAmount: bigAmount,
        biggestExpenseCategoryName: bigCatName,
        monthMostActive: bestMonth,
        monthMostActiveCount: bestMonthCount,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: Colors.deepPurple.shade900,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 16),
              Text('Menyiapkan review...',
                  style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      );
    }

    if (_stats == null || _stats!.totalTransactions == 0) {
      return Scaffold(
        backgroundColor: Colors.deepPurple.shade900,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          title: const Text('Year in Review'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('📭', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text(
                  'Belum ada data tahun ini',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mulai catat transaksi dulu,\nnanti review-nya muncul di sini!',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: Colors.white60),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final pages = _buildPages(context, _stats!);

    return Scaffold(
      backgroundColor: Colors.deepPurple.shade900,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  // Progress dots
                  Row(
                    children: List.generate(
                      pages.length,
                      (i) => Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _currentPage ? 24 : 8,
                        height: 4,
                        decoration: BoxDecoration(
                          color: i == _currentPage
                              ? Colors.white
                              : Colors.white30,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // balance close button
                ],
              ),
            ),

            // Pages
            Expanded(
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: pages,
              ),
            ),

            // Nav hint
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _currentPage < pages.length - 1
                    ? 'Swipe untuk lanjut →'
                    : '🎉 Itu dia review tahun ini!',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildPages(BuildContext context, WrappedStats s) {
    return [
      // Page 1: Intro
      _WrappedPage(
        gradient: [Colors.deepPurple.shade800, Colors.deepPurple.shade600],
        children: [
          Text(
            '${s.year}',
            style: const TextStyle(
                fontSize: 72, fontWeight: FontWeight.w900, color: Colors.white),
          ).animate().fadeIn(duration: 600.ms).scale(begin: const Offset(0.5, 0.5)),
          const SizedBox(height: 8),
          const Text(
            'Year in Review',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: Colors.white70),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 16),
          Text(
            'Lu udah catat ${s.totalTransactions} transaksi\nselama ${s.daysActive} hari aktif 💪',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, color: Colors.white60),
          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.3),
        ],
      ),

      // Page 2: Money flow
      _WrappedPage(
        gradient: [Colors.teal.shade800, Colors.teal.shade600],
        children: [
          const Text('💰', style: TextStyle(fontSize: 56))
              .animate()
              .fadeIn()
              .scale(begin: const Offset(0, 0)),
          const SizedBox(height: 12),
          const Text(
            'Aliran Uang',
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 24),
          _statRow('Masuk', Money.format(s.totalIncome), Colors.greenAccent)
              .animate()
              .fadeIn(delay: 400.ms)
              .slideX(begin: -0.3),
          const SizedBox(height: 12),
          _statRow('Keluar', Money.format(s.totalExpense), Colors.redAccent)
              .animate()
              .fadeIn(delay: 600.ms)
              .slideX(begin: 0.3),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              'Saldo: ${Money.format(s.balance)}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: s.balance >= 0 ? Colors.greenAccent : Colors.redAccent,
              ),
            ),
          ).animate().fadeIn(delay: 800.ms).scale(begin: const Offset(0.8, 0.8)),
        ],
      ),

      // Page 3: Top category
      _WrappedPage(
        gradient: [Colors.orange.shade800, Colors.orange.shade600],
        children: [
          Text(s.topCategoryIcon ?? '🏷️',
                  style: const TextStyle(fontSize: 64))
              .animate()
              .fadeIn()
              .scale(begin: const Offset(0, 0)),
          const SizedBox(height: 12),
          const Text(
            'Paling Banyak Keluar',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white70),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            s.topCategoryName ?? 'Lainnya',
            style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w900,
                color: Colors.white),
          ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),
          const SizedBox(height: 8),
          Text(
            Money.format(s.topCategoryAmount),
            style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Colors.white60),
          ).animate().fadeIn(delay: 600.ms),
        ],
      ),

      // Page 4: Biggest single expense
      _WrappedPage(
        gradient: [Colors.red.shade800, Colors.red.shade600],
        children: [
          const Text('🤯', style: TextStyle(fontSize: 56))
              .animate()
              .fadeIn()
              .shake(delay: 300.ms),
          const SizedBox(height: 12),
          const Text(
            'Pengeluaran Terbesar',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white70),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 16),
          Text(
            Money.format(s.biggestExpenseAmount),
            style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: Colors.white),
          ).animate().fadeIn(delay: 400.ms).scale(begin: const Offset(0.5, 0.5)),
          const SizedBox(height: 8),
          Text(
            '"${s.biggestExpenseNote}"',
            style: const TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: Colors.white60),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 600.ms),
          if (s.biggestExpenseCategoryName != null) ...[
            const SizedBox(height: 4),
            Text(
              s.biggestExpenseCategoryName!,
              style: const TextStyle(fontSize: 14, color: Colors.white38),
            ).animate().fadeIn(delay: 700.ms),
          ],
        ],
      ),

      // Page 5: Daily average + most active month
      _WrappedPage(
        gradient: [Colors.indigo.shade800, Colors.indigo.shade600],
        children: [
          const Text('📊', style: TextStyle(fontSize: 56))
              .animate()
              .fadeIn()
              .scale(begin: const Offset(0, 0)),
          const SizedBox(height: 12),
          const Text(
            'Rata-rata Harian',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white70),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            '${Money.format(s.avgDailyExpense)} / hari',
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white),
          ).animate().fadeIn(delay: 400.ms),
          const SizedBox(height: 32),
          const Text(
            'Bulan Paling Aktif',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white70),
          ).animate().fadeIn(delay: 600.ms),
          const SizedBox(height: 8),
          Text(
            '${DateRange.monthName(s.monthMostActive)} — ${s.monthMostActiveCount} transaksi',
            style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white),
          ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.3),
        ],
      ),

      // Page 6: Summary / closing
      _WrappedPage(
        gradient: [Colors.deepPurple.shade800, Colors.purple.shade600],
        children: [
          const Text('🎉', style: TextStyle(fontSize: 64))
              .animate()
              .fadeIn()
              .scale(begin: const Offset(0, 0)),
          const SizedBox(height: 16),
          Text(
            'Wrap Up ${s.year}',
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: Colors.white),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 20),
          _miniSummary('📝 Transaksi', '${s.totalTransactions}')
              .animate()
              .fadeIn(delay: 400.ms)
              .slideX(begin: -0.2),
          _miniSummary('📅 Hari Aktif', '${s.daysActive}')
              .animate()
              .fadeIn(delay: 500.ms)
              .slideX(begin: 0.2),
          _miniSummary('💵 Total Masuk', Money.compact(s.totalIncome))
              .animate()
              .fadeIn(delay: 600.ms)
              .slideX(begin: -0.2),
          _miniSummary('💸 Total Keluar', Money.compact(s.totalExpense))
              .animate()
              .fadeIn(delay: 700.ms)
              .slideX(begin: 0.2),
          const SizedBox(height: 20),
          Text(
            s.balance >= 0
                ? 'Cuan ${Money.compact(s.balance)} 🚀'
                : 'Minus ${Money.compact(s.balance.abs())} 😅',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: s.balance >= 0 ? Colors.greenAccent : Colors.redAccent,
            ),
          ).animate().fadeIn(delay: 900.ms).scale(begin: const Offset(0.5, 0.5)),
          const SizedBox(height: 12),
          const Text(
            'Terus catat, terus kontrol! 💪',
            style: TextStyle(fontSize: 16, color: Colors.white54),
          ).animate().fadeIn(delay: 1100.ms),
        ],
      ),
    ];
  }

  Widget _statRow(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 16, color: Colors.white54)),
          const SizedBox(width: 16),
          Text(value,
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _miniSummary(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 32),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(fontSize: 15, color: Colors.white60)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ],
      ),
    );
  }
}

class _WrappedPage extends StatelessWidget {
  final List<Color> gradient;
  final List<Widget> children;

  const _WrappedPage({required this.gradient, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}
