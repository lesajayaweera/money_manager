import 'package:flutter/foundation.dart';
import '../models/budget_model.dart';
import '../services/database_service.dart';

class BudgetProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  BudgetModel? _currentBudget;
  List<BudgetModel> _allBudgets = [];
  bool _isLoading = false;

  /// The calendar month currently being viewed in the Budget screen.
  DateTime _selectedMonth =
      DateTime(DateTime.now().year, DateTime.now().month, 1);

  /// Total real spending for [_selectedMonth].
  double _spentAmount = 0;

  /// Per-category real spending for [_selectedMonth].
  Map<String, double> _categorySpending = {};

  // ── Public getters ──────────────────────────────────────────────────────────

  BudgetModel? get currentBudget => _currentBudget;
  List<BudgetModel> get allBudgets => _allBudgets;
  bool get isLoading => _isLoading;
  DateTime get selectedMonth => _selectedMonth;

  /// Actual money spent in [_selectedMonth] (for the viewed budget).
  double get spentAmount => _spentAmount;

  /// Per-category actual spending in [_selectedMonth].
  Map<String, double> get categorySpending => _categorySpending;

  /// Remaining = limit − actual; never goes below 0 here — callers can show
  /// "over by X" when spentAmount > currentBudget.totalAmount.
  double get remainingAmount =>
      _currentBudget == null ? 0 : (_currentBudget!.totalAmount - _spentAmount);

  /// True when the user has spent more than their budget limit.
  bool get isOverBudget =>
      _currentBudget != null && _spentAmount > _currentBudget!.totalAmount;

  /// How much over budget (positive = overspent).
  double get overBudgetAmount => isOverBudget
      ? _spentAmount - _currentBudget!.totalAmount
      : 0;

  // ── Month navigation ────────────────────────────────────────────────────────

  Future<void> setSelectedMonth(DateTime month) async {
    _selectedMonth = DateTime(month.year, month.month, 1);
    await _loadBudgetForMonth();
  }

  // ── Load ────────────────────────────────────────────────────────────────────

  Future<void> loadBudgets() async {
    _isLoading = true;
    notifyListeners();
    try {
      _allBudgets = await _db.getAllBudgets();
      await _loadBudgetForMonth();
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadBudgetForMonth() async {
    _currentBudget = await _db.getBudgetByMonth(
        _selectedMonth.year, _selectedMonth.month);
    await _loadSpending();
    notifyListeners();
  }

  /// Loads actual spending figures for [_selectedMonth].
  Future<void> _loadSpending() async {
    final budget = _currentBudget;
    if (budget == null) {
      _spentAmount = 0;
      _categorySpending = {};
      return;
    }
    _spentAmount =
        await _db.getBudgetSpendingForMonth(_selectedMonth.year, _selectedMonth.month);
    _categorySpending =
        await _db.getBudgetCategorySpendingForMonth(_selectedMonth.year, _selectedMonth.month);
  }

  // ── Save / Update ───────────────────────────────────────────────────────────

  /// Saves a budget, preventing duplicates for the same calendar month.
  ///
  /// If a budget already exists for the budget's start_date month, it is
  /// updated in-place rather than creating a second record.
  Future<void> saveBudget(BudgetModel budget) async {
    _isLoading = true;
    notifyListeners();
    try {
      final existing = await _db.getBudgetByMonth(
          budget.startDate.year, budget.startDate.month);
      if (existing != null) {
        // Update: preserve same id, refresh total + categories
        final updated = BudgetModel(
          id: existing.id,
          totalAmount: budget.totalAmount,
          startDate: existing.startDate,
          categories: budget.categories
              .map((c) => BudgetCategoryAllocation(
                    id: null,
                    budgetId: existing.id!,
                    categoryName: c.categoryName,
                    allocatedAmount: c.allocatedAmount,
                  ))
              .toList(),
          createdAt: existing.createdAt,
        );
        await _db.updateBudget(updated);
      } else {
        await _db.insertBudget(budget);
      }
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

  /// Called by BudgetsScreen / CreateBudgetScreen after a budget is edited
  /// directly, so the caller can also trigger a SalaryPlan sync. Returns
  /// the saved/updated BudgetModel for use in the sync.
  Future<BudgetModel?> getBudgetForMonth(int year, int month) async {
    return _db.getBudgetByMonth(year, month);
  }

  Future<void> clearAllData() async {
    await _db.clearAllBudgets();
    _currentBudget = null;
    _allBudgets = [];
    _spentAmount = 0;
    _categorySpending = {};
    notifyListeners();
  }

  /// Reloads spending figures without a full budget reload — lightweight
  /// refresh after a transaction is added/edited/deleted.
  Future<void> refreshSpending() async {
    await _loadSpending();
    notifyListeners();
  }
}
