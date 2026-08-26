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

  // ── Upsert into Budget table ───────────────────────────────────────────────
  //
  // Only category-type allocations become budget rows — savings, loans, and
  // credit card allocations are scheduled transfers, NOT spending limits.
  //
  // Strategy: insert a fresh budget for this plan's period. The existing
  // BudgetProvider.saveBudget uses insertBudget which calls insert with
  // ConflictAlgorithm.replace on the budgets table — that is fine for the
  // top-level row. The categories use a per-budget delete + re-insert cycle
  // inside updateBudget which is also safe.
  //
  // To avoid the classic duplicate-budget bug, we look for an existing budget
  // that covers the same calendar month and update it; otherwise we insert.
  Future<void> _upsertBudgetFromPlan(SalaryPlan plan) async {
    try {
      final db = DatabaseService.instance;
      final allBudgets = await db.getAllBudgets();

      // Only category allocations become budget spending limits
      final categoryAllocations = plan.allocations
          .where((a) => a.type == AllocationType.category)
          .toList();

      if (categoryAllocations.isEmpty) return;

      // Build the BudgetModel
      final budgetCategories = categoryAllocations
          .map((a) => BudgetCategoryAllocation(
                budgetId: 0, // placeholder; will be replaced on insert
                categoryName: a.name,
                allocatedAmount: a.amount,
              ))
          .toList();

      // Find an existing budget for the same calendar month
      final planMonth = DateTime(plan.periodStart.year, plan.periodStart.month);
      BudgetModel? existing;
      for (final b in allBudgets) {
        final bMonth = DateTime(b.startDate.year, b.startDate.month);
        if (bMonth == planMonth) {
          existing = b;
          break;
        }
      }

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
                    budgetId: existing!.id!,
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
}
