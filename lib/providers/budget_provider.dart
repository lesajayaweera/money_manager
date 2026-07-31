import 'package:flutter/foundation.dart';
import '../models/budget_model.dart';
import '../services/database_service.dart';

class BudgetProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  BudgetModel? _currentBudget;
  List<BudgetModel> _allBudgets = [];
  bool _isLoading = false;

  /// Total real spending for the current budget's month.
  /// Only real expenses count — income, lend/borrow-linked transactions,
  /// and Lent/Borrowed category transactions are excluded.
  double _spentAmount = 0;

  /// Per-category real spending for the current budget's month.
  /// Keys match category names in [BudgetCategoryAllocation].
  Map<String, double> _categorySpending = {};

  BudgetModel? get currentBudget => _currentBudget;
  List<BudgetModel> get allBudgets => _allBudgets;
  bool get isLoading => _isLoading;

  /// Actual money spent this budget month (spending limit progress).
  double get spentAmount => _spentAmount;

  /// Per-category actual spending this budget month.
  Map<String, double> get categorySpending => _categorySpending;

  /// Remaining budget = limit - actual spending. Returns 0 if no budget set.
  double get remainingAmount =>
      _currentBudget == null ? 0 : (_currentBudget!.totalAmount - _spentAmount).clamp(0, double.infinity);

  Future<void> loadBudgets() async {
    _isLoading = true;
    notifyListeners();
    try {
      _allBudgets = await _db.getAllBudgets();
      _currentBudget = await _db.getLatestBudget();
      await _loadSpending();
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  /// Loads actual spending figures for the current budget's month.
  Future<void> _loadSpending() async {
    final budget = _currentBudget;
    if (budget == null) {
      _spentAmount = 0;
      _categorySpending = {};
      return;
    }
    final year = budget.startDate.year;
    final month = budget.startDate.month;
    _spentAmount = await _db.getBudgetSpending(year, month);
    _categorySpending = await _db.getBudgetCategorySpending(year, month);
  }

  Future<void> saveBudget(BudgetModel budget) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _db.insertBudget(budget);
      await loadBudgets();
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateBudget(BudgetModel budget) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _db.updateBudget(budget);
      await loadBudgets();
    } catch (_) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteBudget(int id) async {
    await _db.deleteBudget(id);
    await loadBudgets();
  }

  Future<void> clearAllData() async {
    await _db.clearAllBudgets();
    _currentBudget = null;
    _allBudgets = [];
    _spentAmount = 0;
    _categorySpending = {};
    notifyListeners();
  }
}
