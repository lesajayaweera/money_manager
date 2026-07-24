import 'package:flutter/foundation.dart';
import '../models/goal_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../services/database_service.dart';

class GoalProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  List<GoalModel> _goals = [];
  bool _isLoading = false;
  String? _error;

  List<GoalModel> get goals => _goals;
  bool get isLoading => _isLoading;
  String? get error => _error;

  int get activeGoalCount => _goals.where((g) => !g.isCompleted).length;

  double get totalSaved => _goals.fold(0.0, (s, g) => s + g.savedAmount);

  Future<void> loadGoals() async {
    _setLoading(true);
    try {
      _goals = await _db.getAllGoals();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addGoal(GoalModel goal) async {
    try {
      final id = await _db.insertGoal(goal);
      _goals.insert(0, goal.copyWith(id: id));
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateGoal(GoalModel goal) async {
    try {
      await _db.updateGoal(goal);
      final index = _goals.indexWhere((g) => g.id == goal.id);
      if (index != -1) {
        _goals[index] = goal;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteGoal(int id) async {
    try {
      await _db.deleteGoal(id);
      _goals.removeWhere((g) => g.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Adds savings to a goal AND creates an expense transaction so the
  /// amount is properly deducted from the overall balance.
  /// If [walletName] is provided, also deducts from that wallet's balance.
  Future<void> addSavings(
    GoalSavingsEntry entry, {
    String goalName = 'Goal',
    String? walletName,
  }) async {
    try {
      // 1. Record the goal savings entry
      await _db.addGoalSavings(entry);

      // 2. Create an expense transaction to deduct from balance
      final tx = TransactionModel(
        title: 'Savings – $goalName',
        amount: entry.amount,
        type: TransactionType.expense,
        category: 'Goals',
        date: entry.date,
        note: entry.note ?? 'Added to goal: $goalName',
        walletName: walletName ?? '',
      );
      await _db.insertTransaction(tx);

      // 3. Deduct from the chosen wallet balance if specified
      if (walletName != null && walletName.isNotEmpty) {
        final wallets = await _db.getAllWallets();
        final wallet = wallets.where((w) => w.name == walletName).toList();
        if (wallet.isNotEmpty) {
          final w = wallet.first;
          final updated = WalletModel(
            id: w.id,
            name: w.name,
            type: w.type,
            balance: w.balance - entry.amount,
            iconCodePoint: w.iconCodePoint,
            colorValue: w.colorValue,
            note: w.note,
            includeInTotal: w.includeInTotal,
            status: w.status,
            createdAt: w.createdAt,
          );
          await _db.updateWallet(updated);
        }
      }

      // 4. Refresh goals from DB to get updated saved_amount
      final updatedGoals = await _db.getAllGoals();
      _goals = updatedGoals;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<List<GoalSavingsEntry>> getSavingsHistory(int goalId) {
    return _db.getGoalSavings(goalId);
  }

  Future<void> clearAllData() async {
    try {
      await _db.clearAllGoals();
      _goals = [];
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
