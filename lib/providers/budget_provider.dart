import 'package:flutter/foundation.dart';
import '../models/budget_model.dart';
import '../services/database_service.dart';

class BudgetProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  BudgetModel? _currentBudget;
  List<BudgetModel> _allBudgets = [];
  bool _isLoading = false;

  BudgetModel? get currentBudget => _currentBudget;
  List<BudgetModel> get allBudgets => _allBudgets;
  bool get isLoading => _isLoading;

  Future<void> loadBudgets() async {
    _isLoading = true;
    notifyListeners();
    try {
      _allBudgets = await _db.getAllBudgets();
      _currentBudget = await _db.getLatestBudget();
    } catch (_) {}
    _isLoading = false;
    notifyListeners();
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
    notifyListeners();
  }
}
