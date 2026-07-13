import 'package:flutter/foundation.dart';
import '../models/lend_borrow_model.dart';
import '../models/transaction_model.dart';
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

  /// Adds a lend/borrow entry and records the matching transaction:
  /// • Lent money  → expense (money left your pocket)
  /// • Borrowed    → income  (money came into your pocket)
  Future<void> addEntry(LendBorrowModel entry) async {
    try {
      final id = await _db.insertLendBorrow(entry);
      _entries.insert(0, entry.copyWith(id: id));

      // Mirror as a transaction for balance impact
      final tx = TransactionModel(
        title: entry.isLent
            ? 'Lent to ${entry.personName}'
            : 'Borrowed from ${entry.personName}',
        amount: entry.amount,
        type: entry.isLent ? TransactionType.expense : TransactionType.income,
        category: entry.isLent ? 'Lent' : 'Borrowed',
        date: entry.date,
        note: entry.note,
      );
      await _db.insertTransaction(tx);

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Updates an existing lend/borrow entry.
  /// If the status is being changed TO paid (settled), records the reverse
  /// transaction:
  /// • Lent + now paid → income  (money came back)
  /// • Borrowed + now paid → expense (money went back)
  Future<void> updateEntry(LendBorrowModel entry) async {
    try {
      final existing = _entries.firstWhere(
        (e) => e.id == entry.id,
        orElse: () => entry,
      );

      await _db.updateLendBorrow(entry);
      final index = _entries.indexWhere((e) => e.id == entry.id);
      if (index != -1) {
        _entries[index] = entry;
        notifyListeners();
      }

      // If status just became "paid", record the settlement transaction
      final wasNotPaid = existing.status != LendBorrowStatus.paid;
      final isNowPaid = entry.status == LendBorrowStatus.paid;
      if (wasNotPaid && isNowPaid) {
        final tx = TransactionModel(
          title: entry.isLent
              ? 'Received from ${entry.personName}'
              : 'Repaid to ${entry.personName}',
          amount: entry.amount,
          // Lent was expense when created → getting back = income
          // Borrowed was income when created → paying back = expense
          type: entry.isLent ? TransactionType.income : TransactionType.expense,
          category: entry.isLent ? 'Lent' : 'Borrowed',
          date: DateTime.now(),
          note: 'Settlement of ${entry.isLent ? "lent" : "borrowed"} amount',
        );
        await _db.insertTransaction(tx);
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
