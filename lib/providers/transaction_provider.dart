import 'package:flutter/foundation.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';

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
  TransactionType? _filterType;
  String _searchQuery = '';
  DateTime _selectedMonth = DateTime.now();

  List<TransactionModel> get allTransactions => _allTransactions;
  List<TransactionModel> get recentTransactions => _recentTransactions;
  DashboardSummary get summary => _summary;
  bool get isLoading => _isLoading;
  String? get error => _error;
  DateTime get selectedMonth => _selectedMonth;
  TransactionType? get filterType => _filterType;
  String get searchQuery => _searchQuery;

  List<TransactionModel> get filteredTransactions {
    var list = _allTransactions;
    if (_filterType != null) {
      list = list.where((t) => t.type == _filterType).toList();
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
    _setLoading(true);
    try {
      await _db.insertTransaction(tx);
      await loadAll();
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
    }
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    _setLoading(true);
    try {
      await _db.updateTransaction(tx);
      await loadAll();
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
    }
  }

  Future<void> deleteTransaction(int id) async {
    _setLoading(true);
    try {
      await _db.deleteTransaction(id);
      await loadAll();
    } catch (e) {
      _error = e.toString();
      _setLoading(false);
    }
  }

  void setFilterType(TransactionType? type) {
    _filterType = type;
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

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
