import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _keyBalanceVisible = 'balance_visible';
  static const String _keyCurrencySymbol = 'currency_symbol';
  static const String _keyNotifications = 'notifications_enabled';

  bool _balanceVisible = true;
  String _currencySymbol = 'Rs.';
  bool _notificationsEnabled = true;

  bool get balanceVisible => _balanceVisible;
  String get currencySymbol => _currencySymbol;
  bool get notificationsEnabled => _notificationsEnabled;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _balanceVisible = prefs.getBool(_keyBalanceVisible) ?? true;
    _currencySymbol = prefs.getString(_keyCurrencySymbol) ?? 'Rs.';
    _notificationsEnabled = prefs.getBool(_keyNotifications) ?? true;
    notifyListeners();
  }

  Future<void> toggleBalanceVisibility() async {
    _balanceVisible = !_balanceVisible;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBalanceVisible, _balanceVisible);
  }

  Future<void> setCurrencySymbol(String symbol) async {
    _currencySymbol = symbol;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCurrencySymbol, symbol);
  }

  Future<void> toggleNotifications() async {
    _notificationsEnabled = !_notificationsEnabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyNotifications, _notificationsEnabled);
  }
}
