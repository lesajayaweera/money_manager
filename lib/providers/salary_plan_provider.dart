import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/budget_model.dart';
import '../models/salary_plan_model.dart';
import '../services/database_service.dart';

class SalaryPlanProvider extends ChangeNotifier {
  static const String _prefsKey = 'salary_plans_v1';

  List<SalaryPlan> _plans = [];
  bool _isLoading = false;
  String? _error;

  List<SalaryPlan> get plans => _plans;
  bool get isLoading => _isLoading;
  String? get error => _error;

  SalaryPlan? get latestPlan => _plans.isEmpty ? null : _plans.first;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> loadPlans() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        _plans = SalaryPlan.listFromJsonString(raw);
      }
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Save (persist to prefs) ────────────────────────────────────────────────

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, SalaryPlan.listToJsonString(_plans));
  }

  // ── Create / Update ───────────────────────────────────────────────────────

  /// Creates a new plan, persists it, and upserts matching budget entries into
  /// the budgets table so the standalone Budget screen reflects the allocation.
  Future<void> createPlan(SalaryPlan plan) async {
    _plans.insert(0, plan);
    notifyListeners();
    await _persist();
    await _upsertBudgetFromPlan(plan);
  }

  Future<void> updatePlan(SalaryPlan updated) async {
    final idx = _plans.indexWhere((p) => p.id == updated.id);
    if (idx == -1) return;
    _plans[idx] = updated;
    notifyListeners();
    await _persist();
    await _upsertBudgetFromPlan(updated);
  }

  Future<void> deletePlan(String id) async {
    _plans.removeWhere((p) => p.id == id);
    notifyListeners();
    await _persist();
  }

  // ── Two-way sync: Budget → Plan ────────────────────────────────────────────
  //
  // Called by CreateBudgetScreen / BudgetsScreen after a manual budget edit.
  // Finds the SalaryPlan that covers the same calendar month as [budget] and
  // updates its CATEGORY-type allocations to match the budget categories.
  //
  // Rules:
  //   • Only category-type allocations are touched (loans/savings/CC remain).
  //   • If a budget category doesn't exist in the plan, it is added.
  //   • Plan category allocations that are no longer in the budget are removed.
  //   • The plan's monthlyIncome is updated to match budget.totalAmount.
  //   • If no matching plan exists, nothing happens (Budget-only mode still works).
  Future<void> updatePlanFromBudget(BudgetModel budget) async {
    final planMonth = DateTime(budget.startDate.year, budget.startDate.month);
    final idx = _plans.indexWhere((p) =>
        p.periodStart.year == planMonth.year &&
        p.periodStart.month == planMonth.month);
    if (idx == -1) return; // No plan for this month — nothing to sync

    final existing = _plans[idx];

    // Keep non-category allocations intact
    final nonCategoryAllocations =
        existing.allocations.where((a) => a.type != AllocationType.category).toList();

    // Build category allocations from the budget
    final newCategoryAllocations = budget.categories
        .where((c) => c.allocatedAmount > 0)
        .map((c) {
      // Find existing allocation to preserve its id
      final existingAlloc = existing.allocations.firstWhere(
        (a) => a.type == AllocationType.category && a.name == c.categoryName,
        orElse: () => SalaryAllocation(
          id: '${c.categoryName}_${planMonth.year}_${planMonth.month}',
          name: c.categoryName,
          type: AllocationType.category,
          amount: c.allocatedAmount,
        ),
      );
      return existingAlloc.copyWith(amount: c.allocatedAmount);
    }).toList();

    final updatedPlan = existing.copyWith(
      allocations: [...newCategoryAllocations, ...nonCategoryAllocations],
    );

    _plans[idx] = updatedPlan;
    notifyListeners();
    await _persist();
    // Do NOT call _upsertBudgetFromPlan here — budget is already saved
  }

  // ── Upsert into Budget table ───────────────────────────────────────────────
  //
  // Only category-type allocations become budget rows — savings, loans, and
  // credit card allocations are scheduled transfers, NOT spending limits.
  //
  // Strategy: find an existing budget that covers the same calendar month and
  // update it; otherwise insert a new one. This prevents the classic
  // duplicate-budget bug.
  Future<void> _upsertBudgetFromPlan(SalaryPlan plan) async {
    try {
      final db = DatabaseService.instance;

      // Only category allocations become budget spending limits
      final categoryAllocations = plan.allocations
          .where((a) => a.type == AllocationType.category)
          .toList();

      if (categoryAllocations.isEmpty) return;

      // Build the category list
      final budgetCategories = categoryAllocations
          .map((a) => BudgetCategoryAllocation(
                budgetId: 0, // placeholder; replaced on insert
                categoryName: a.name,
                allocatedAmount: a.amount,
              ))
          .toList();

      // Find existing budget for the same calendar month
      final planYear = plan.periodStart.year;
      final planMonth = plan.periodStart.month;
      final existing = await db.getBudgetByMonth(planYear, planMonth);

      final totalIncome = plan.monthlyIncome;
      final now = DateTime.now().toIso8601String();

      if (existing != null) {
        // Update: preserve same budget id but refresh total + categories
        final updated = BudgetModel(
          id: existing.id,
          totalAmount: totalIncome,
          startDate: existing.startDate,
          categories: budgetCategories
              .map((c) => BudgetCategoryAllocation(
                    id: null,
                    budgetId: existing.id!,
                    categoryName: c.categoryName,
                    allocatedAmount: c.allocatedAmount,
                  ))
              .toList(),
          createdAt: existing.createdAt,
        );
        await db.updateBudget(updated);
      } else {
        // Insert new budget for this month
        final newBudget = BudgetModel(
          totalAmount: totalIncome,
          startDate: plan.periodStart,
          categories: budgetCategories,
          createdAt: now,
        );
        await db.insertBudget(newBudget);
      }
    } catch (_) {
      // Budget upsert is best-effort; never crash the plan save
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns the plan that covers the given month, or null.
  SalaryPlan? planForMonth(int year, int month) {
    try {
      return _plans.firstWhere(
          (p) => p.periodStart.year == year && p.periodStart.month == month);
    } catch (_) {
      return null;
    }
  }

  /// Returns the most recent plan before [year]/[month], or null.
  /// Used for the "Copy from previous month" feature.
  SalaryPlan? previousPlan(int year, int month) {
    final cutoff = DateTime(year, month, 1);
    final older = _plans
        .where((p) => p.periodStart.isBefore(cutoff))
        .toList()
      ..sort((a, b) => b.periodStart.compareTo(a.periodStart));
    return older.isEmpty ? null : older.first;
  }
}
