import 'package:flutter/foundation.dart';
import '../models/wallet_model.dart';
import '../services/database_service.dart';

class WalletProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;

  List<WalletModel> _wallets = [];
  bool _isLoading = false;
  String? _error;
  double _thisMonthTransfers = 0;

  List<WalletModel> get wallets => _wallets;
  bool get isLoading => _isLoading;
  String? get error => _error;
  double get thisMonthTransfers => _thisMonthTransfers;

  double get totalBalance {
    return _wallets
        .where((w) => w.includeInTotal)
        .fold(0.0, (sum, w) => sum + w.balance);
  }

  int get activeWalletCount => _wallets.length;

  Future<void> loadWallets() async {
    _setLoading(true);
    try {
      _wallets = await _db.getAllWallets();
      _thisMonthTransfers = await _db.getMonthlyTransfers();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addWallet(WalletModel wallet) async {
    try {
      final id = await _db.insertWallet(wallet);
      _wallets = [..._wallets, wallet.copyWith(id: id)];
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> updateWallet(WalletModel wallet) async {
    try {
      await _db.updateWallet(wallet);
      final idx = _wallets.indexWhere((w) => w.id == wallet.id);
      if (idx != -1) {
        final list = List<WalletModel>.from(_wallets);
        list[idx] = wallet;
        _wallets = list;
      }
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> deleteWallet(int id) async {
    try {
      await _db.deleteWallet(id);
      _wallets = _wallets.where((w) => w.id != id).toList();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<void> transferBetweenWallets({
    required int fromId,
    required int toId,
    required double amount,
    required DateTime date,
    String? note,
  }) async {
    try {
      final transfer = WalletTransfer(
        fromWalletId: fromId,
        toWalletId: toId,
        amount: amount,
        date: date,
        note: note,
        createdAt: DateTime.now(),
      );
      await _db.insertWalletTransfer(transfer);

      // Update local balances
      final list = List<WalletModel>.from(_wallets);
      final fromIdx = list.indexWhere((w) => w.id == fromId);
      final toIdx = list.indexWhere((w) => w.id == toId);
      if (fromIdx != -1) {
        list[fromIdx] = list[fromIdx].copyWith(
          balance: list[fromIdx].balance - amount,
        );
        await _db.updateWallet(list[fromIdx]);
      }
      if (toIdx != -1) {
        list[toIdx] = list[toIdx].copyWith(
          balance: list[toIdx].balance + amount,
        );
        await _db.updateWallet(list[toIdx]);
      }
      _wallets = list;
      _thisMonthTransfers = await _db.getMonthlyTransfers();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  Future<List<WalletTransfer>> getTransfersForWallet(int walletId) {
    return _db.getTransfersByWallet(walletId);
  }

  WalletModel? findById(int id) {
    try {
      return _wallets.firstWhere((w) => w.id == id);
    } catch (_) {
      return null;
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
