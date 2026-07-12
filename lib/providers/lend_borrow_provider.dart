import 'package:flutter/foundation.dart';
import '../models/lend_borrow_model.dart';
import '../services/database_service.dart';

class LendBorrowProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  List<LendBorrowModel> _entries = [];
  bool _isLoading = false;
  String? _error;

  List<LendBorrowModel> get entries => _entries;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<LendBorrowModel> get lentEntries =>
      _entries.where((e) => e.isLent).toList();

  List<LendBorrowModel> get borrowedEntries =>
      _entries.where((e) => e.isBorrowed).toList();

  double get totalToReceive => lentEntries
      .where((e) => e.status != LendBorrowStatus.paid)
      .fold(0.0, (s, e) => s + e.amount);

  double get totalToPay => borrowedEntries
      .where((e) => e.status != LendBorrowStatus.paid)
      .fold(0.0, (s, e) => s + e.amount);

  Future<void> loadEntries() async {
    _setLoading(true);
    try {
      _entries = await _db.getAllLendBorrow();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addEntry(LendBorrowModel entry) async {
    try {
      final id = await _db.insertLendBorrow(entry);
      _entries.insert(0, entry.copyWith(id: id));
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateEntry(LendBorrowModel entry) async {
    try {
      await _db.updateLendBorrow(entry);
      final index = _entries.indexWhere((e) => e.id == entry.id);
      if (index != -1) {
        _entries[index] = entry;
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteEntry(int id) async {
    try {
      await _db.deleteLendBorrow(id);
      _entries.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
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
