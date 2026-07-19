import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';

enum TransactionFilter { all, income, expense, today, thisMonth }

class DashboardSummary {
  final double totalBalance;
  final double monthlyIncome;
  final double monthlyExpenses;
  final double remainingBudget;
  final double todaySpending;

  const DashboardSummary({
    required this.totalBalance,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.remainingBudget,
    required this.todaySpending,
  });

  static const DashboardSummary zero = DashboardSummary(
    totalBalance: 0,
    monthlyIncome: 0,
    monthlyExpenses: 0,
    remainingBudget: 0,
    todaySpending: 0,
  );
}

class TransactionProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  List<TransactionModel> _allTransactions = [];
  List<TransactionModel> _recentTransactions = [];
  DashboardSummary _summary = DashboardSummary.zero;
  bool _isLoading = false;
  String? _error;

  // Filter state
  TransactionFilter _activeFilter = TransactionFilter.all;
  String _searchQuery = '';
  DateTime _selectedMonth = DateTime.now();

  List<TransactionModel> get allTransactions => _allTransactions;
  List<TransactionModel> get recentTransactions => _recentTransactions;
  DashboardSummary get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get selectedMonth => _selectedMonth;
  TransactionFilter get activeFilter => _activeFilter;
  String get searchQuery => _searchQuery;

  List<TransactionModel> get filteredTransactions {
    var list = _allTransactions;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (_activeFilter) {
      case TransactionFilter.income:
        list = list.where((t) => t.type == TransactionType.income).toList();
        break;
      case TransactionFilter.expense:
        list = list.where((t) => t.type == TransactionType.expense).toList();
        break;
      case TransactionFilter.today:
        list = list
            .where((t) =>
                DateTime(t.date.year, t.date.month, t.date.day) == today)
            .toList();
        break;
      case TransactionFilter.thisMonth:
        list = list
            .where(
                (t) => t.date.year == now.year && t.date.month == now.month)
            .toList();
        break;
      case TransactionFilter.all:
        break;
    }

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list
          .where((t) =>
              t.title.toLowerCase().contains(q) ||
              t.category.toLowerCase().contains(q) ||
              (t.note?.toLowerCase().contains(q) ?? false))
          .toList();
    }
    return list;
  }

  Future<void> loadAll() async {
    _setLoading(true);
    try {
      await Future.wait([
        _loadTransactions(),
        _loadSummary(),
      ]);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadTransactions() async {
    _allTransactions = await _db.getAllTransactions();
    _recentTransactions = _allTransactions.take(5).toList();
    notifyListeners();
  }

  Future<void> _loadSummary() async {
    final now = DateTime.now();
    final results = await Future.wait([
      _db.getTotalBalance(),
      _db.getMonthlyIncome(now.year, now.month),
      _db.getMonthlyExpenses(now.year, now.month),
      _db.getTodaySpending(),
    ]);
    _summary = DashboardSummary(
      totalBalance: results[0],
      monthlyIncome: results[1],
      monthlyExpenses: results[2],
      remainingBudget: results[1] - results[2],
      todaySpending: results[3],
    );
    notifyListeners();
  }

  Future<void> addTransaction(TransactionModel tx) async {
    try {
      await _db.insertTransaction(tx);
      await _loadTransactions();
      await _loadSummary();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    try {
      await _db.updateTransaction(tx);
      await _loadTransactions();
      await _loadSummary();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteTransaction(int id) async {
    try {
      await _db.deleteTransaction(id);
      await _loadTransactions();
      await _loadSummary();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void setFilter(TransactionFilter filter) {
    _activeFilter = filter;
    notifyListeners();
  }

  void setFilterType(TransactionType? type) {
    if (type == null) {
      _activeFilter = TransactionFilter.all;
    } else if (type == TransactionType.income) {
      _activeFilter = TransactionFilter.income;
    } else {
      _activeFilter = TransactionFilter.expense;
    }
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedMonth(DateTime month) {
    _selectedMonth = month;
    notifyListeners();
  }

  Future<List<TransactionModel>> getTransactionsByMonth(int year, int month) {
    return _db.getTransactionsByMonth(year, month);
  }

  Future<Map<String, double>> getCategoryBreakdown(
      TransactionType type, int year, int month) {
    return _db.getCategoryTotals(type, year, month);
  }

  Future<List<Map<String, dynamic>>> getLast6MonthsSummary() {
    return _db.getLast6MonthsSummary();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> clearAllData() async {
    try {
      await _db.clearAllTransactions();
      _allTransactions = [];
      _recentTransactions = [];
      _summary = DashboardSummary.zero;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}


