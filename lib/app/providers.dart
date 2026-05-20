import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/transactions/repository/transaction_repository.dart';
import '../features/transactions/repository/category_repository.dart';
import '../features/transactions/models/transaction.dart';
import '../features/transactions/models/category.dart';
import '../features/budget/budget_repository.dart';
import '../features/budget/budget_model.dart';
import '../core/utils/formatters.dart';

final txRepoProvider = Provider<TransactionRepository>((_) => TransactionRepository());
final categoryRepoProvider = Provider<CategoryRepository>((_) => CategoryRepository());
final budgetRepoProvider = Provider<BudgetRepository>((_) => BudgetRepository());

/// Bumped whenever any transaction is added/edited/deleted to invalidate caches.
final txRefreshProvider = StateProvider<int>((_) => 0);

final allCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  return ref.read(categoryRepoProvider).all();
});

final expenseCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  return ref.read(categoryRepoProvider).all(type: 'expense');
});

final incomeCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  return ref.read(categoryRepoProvider).all(type: 'income');
});

final categoryByIdProvider = FutureProvider.family<Category?, String>((ref, id) async {
  return ref.read(categoryRepoProvider).byId(id);
});

final recentTxProvider = FutureProvider<List<Txn>>((ref) async {
  ref.watch(txRefreshProvider);
  return ref.read(txRepoProvider).recent(limit: 100);
});

final todayTotalsProvider = FutureProvider<({double income, double expense})>((ref) async {
  ref.watch(txRefreshProvider);
  final (start, end) = DateRange.today();
  return ref.read(txRepoProvider).totals(start, end);
});

final monthTotalsProvider = FutureProvider<({double income, double expense})>((ref) async {
  ref.watch(txRefreshProvider);
  final (start, end) = DateRange.thisMonth();
  return ref.read(txRepoProvider).totals(start, end);
});

final monthExpenseByCategoryProvider = FutureProvider<Map<String, double>>((ref) async {
  ref.watch(txRefreshProvider);
  final (start, end) = DateRange.thisMonth();
  return ref.read(txRepoProvider).sumByCategory(start, end, 'expense');
});

final yearTotalsProvider = FutureProvider<({double income, double expense})>((ref) async {
  ref.watch(txRefreshProvider);
  final (start, end) = DateRange.thisYear();
  return ref.read(txRepoProvider).totals(start, end);
});

final budgetsProvider = FutureProvider<List<Budget>>((ref) async {
  ref.watch(txRefreshProvider);
  return ref.read(budgetRepoProvider).all();
});
