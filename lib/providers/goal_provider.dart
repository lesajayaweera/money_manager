import 'package:flutter/foundation.dart';
import '../models/goal_model.dart';
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

  Future<void> addSavings(GoalSavingsEntry entry) async {
    try {
      await _db.addGoalSavings(entry);
      // Refresh the specific goal from DB to get updated saved_amount
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

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
