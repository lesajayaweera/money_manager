import 'package:flutter/foundation.dart';
import '../models/lend_borrow_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
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
      .where((e) => e.effectiveStatus != LendBorrowStatus.paid)
      .fold(0.0, (s, e) => s + (e.amount - e.accumulatedAmount).clamp(0.0, double.infinity));

  double get totalToPay => borrowedEntries
      .where((e) => e.effectiveStatus != LendBorrowStatus.paid)
      .fold(0.0, (s, e) => s + (e.amount - e.accumulatedAmount).clamp(0.0, double.infinity));

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
  /// If accumulatedAmount > 0, it also records the partial settlement immediately.
  Future<void> addEntry(LendBorrowModel entry) async {
    try {
      // 1. Insert the entry first (without transactionId yet)
      final entryId = await _db.insertLendBorrow(entry);

      // 2. Create the mirror transaction
      final tx = TransactionModel(
        title: entry.isLent
            ? 'Lent to ${entry.personName}'
            : 'Borrowed from ${entry.personName}',
        amount: entry.amount,
        type: entry.isLent ? TransactionType.expense : TransactionType.income,
        category: entry.isLent ? 'Lent' : 'Borrowed',
        date: entry.date,
        note: entry.note,
        walletName: entry.walletName ?? '',
        lendBorrowId: entryId,
      );
      final txId = await _db.insertTransaction(tx);

      // 3. Link transaction back to the lend/borrow entry
      final linked = entry.copyWith(id: entryId, transactionId: txId);
      await _db.updateLendBorrow(linked);
      _entries.insert(0, linked);

      // 4. Update wallet balance for the initial amount
      if (entry.walletName != null && entry.walletName!.isNotEmpty) {
        await _adjustWalletBalance(
          entry.walletName!,
          entry.amount,
          deduct: entry.isLent,
        );
      }

      // 5. If there is an accumulated amount, record it as a repayment immediately
      if (entry.accumulatedAmount > 0) {
        await _recordRepayment(linked, entry.accumulatedAmount, 'Initial repayment');
      }

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Updates an existing lend/borrow entry.
  /// Handles changes to both total amount and accumulated amount.
  Future<void> updateEntry(LendBorrowModel entry) async {
    try {
      final existing = _entries.firstWhere(
        (e) => e.id == entry.id,
        orElse: () => entry,
      );

      final amountChanged = existing.amount != entry.amount;
      final accumulatedDiff = entry.accumulatedAmount - existing.accumulatedAmount;

      // 1. Update the DB record
      await _db.updateLendBorrow(entry);
      final index = _entries.indexWhere((e) => e.id == entry.id);
      if (index != -1) {
        _entries[index] = entry;
        notifyListeners();
      }

      // 2. If total amount changed, update the original mirror transaction
      if (amountChanged && existing.transactionId != null) {
        final oldTx = TransactionModel(
          id: existing.transactionId,
          title: entry.isLent
              ? 'Lent to ${entry.personName}'
              : 'Borrowed from ${entry.personName}',
          amount: entry.amount,
          type: entry.isLent ? TransactionType.expense : TransactionType.income,
          category: entry.isLent ? 'Lent' : 'Borrowed',
          date: entry.date,
          note: entry.note,
          walletName: entry.walletName ?? '',
          lendBorrowId: entry.id,
        );
        await _db.updateTransaction(oldTx);

        // Fix wallet balance for the total amount difference
        if (entry.walletName != null && entry.walletName!.isNotEmpty) {
          final diff = entry.amount - existing.amount;
          if (diff != 0) {
            await _adjustWalletBalance(
              entry.walletName!,
              diff.abs(),
              deduct: entry.isLent ? diff > 0 : diff < 0,
            );
          }
        }
      }

      // 3. If accumulated amount changed, record a new partial settlement transaction
      if (accumulatedDiff != 0) {
        await _recordRepayment(
          entry,
          accumulatedDiff.abs(),
          accumulatedDiff > 0 ? 'Repayment update' : 'Repayment reversal',
          isReversal: accumulatedDiff < 0,
        );
      }
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> _recordRepayment(LendBorrowModel entry, double amount, String note, {bool isReversal = false}) async {
    // If it's a normal repayment:
    // Lent -> getting back -> income
    // Borrowed -> paying back -> expense
    // If it's a reversal (accumulatedAmount decreased), do the opposite.
    final bool isIncome = entry.isLent ? !isReversal : isReversal;

    final tx = TransactionModel(
      title: entry.isLent
          ? (isReversal ? 'Reversed repayment from ${entry.personName}' : 'Received from ${entry.personName}')
          : (isReversal ? 'Reversed repayment to ${entry.personName}' : 'Repaid to ${entry.personName}'),
      amount: amount,
      type: isIncome ? TransactionType.income : TransactionType.expense,
      category: entry.isLent ? 'Lent' : 'Borrowed',
      date: DateTime.now(),
      note: note,
      walletName: entry.walletName ?? '',
      lendBorrowId: entry.id,
    );
    await _db.insertTransaction(tx);

    // Wallet balance
    if (entry.walletName != null && entry.walletName!.isNotEmpty) {
      await _adjustWalletBalance(
        entry.walletName!,
        amount,
        deduct: !isIncome, // if it's expense, deduct. if income, credit.
      );
    }
  }

  /// Adds a new repayment to the entry.
  Future<void> addRepayment(int entryId, double amount, {String? walletName, String? note}) async {
    try {
      final entry = _entries.firstWhere((e) => e.id == entryId);
      final newAccumulated = entry.accumulatedAmount + amount;
      
      final updatedEntry = entry.copyWith(
        accumulatedAmount: newAccumulated,
        // Override wallet name if provided during repayment
        walletName: walletName ?? entry.walletName,
      );
      
      await updateEntry(updatedEntry);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// Deletes an entry AND its linked mirror + all settlement transactions.
  /// Reverses the wallet balance completely.
  Future<void> deleteEntry(int id) async {
    try {
      final entry = _entries.firstWhere((e) => e.id == id);

      // 1. Delete all linked transactions (the original + all partial repayments)
      await _db.deleteTransactionsByLendBorrowId(id);

      // 2. Reverse net wallet balance
      // Net amount deducted from wallet originally = entry.amount (deducted if lent) - entry.accumulatedAmount (credited if lent)
      if (entry.walletName != null && entry.walletName!.isNotEmpty) {
        final netImpact = entry.amount - entry.accumulatedAmount;
        if (netImpact > 0) {
          // E.g. Lent 5000, Accumulated 2000. Net impact = 3000 deducted. We need to credit back 3000.
          await _adjustWalletBalance(
            entry.walletName!,
            netImpact,
            deduct: !entry.isLent, // reverse of original
          );
        } else if (netImpact < 0) {
          // E.g. Lent 5000, Accumulated 6000. Net impact = -1000 deducted (so 1000 credited). We need to deduct 1000.
          await _adjustWalletBalance(
            entry.walletName!,
            netImpact.abs(),
            deduct: entry.isLent,
          );
        }
      }

      // 3. Delete the lend/borrow entry
      await _db.deleteLendBorrow(id);
      _entries.removeWhere((e) => e.id == id);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> clearAllData() async {
    try {
      await _db.clearAllLendBorrows();
      _entries = [];
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ─── Private Helpers ──────────────────────────────────────────────────────

  Future<void> _adjustWalletBalance(
    String walletName,
    double amount, {
    required bool deduct,
  }) async {
    final wallets = await _db.getAllWallets();
    final matches = wallets.where((w) => w.name == walletName).toList();
    if (matches.isEmpty) return;
    final w = matches.first;
    final updated = WalletModel(
      id: w.id,
      name: w.name,
      type: w.type,
      balance: deduct ? w.balance - amount : w.balance + amount,
      iconCodePoint: w.iconCodePoint,
      colorValue: w.colorValue,
      note: w.note,
      includeInTotal: w.includeInTotal,
      status: w.status,
      createdAt: w.createdAt,
    );
    await _db.updateWallet(updated);
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
