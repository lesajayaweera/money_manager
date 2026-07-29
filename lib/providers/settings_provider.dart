import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colors.dart';

class SettingsProvider extends ChangeNotifier {
  static const String _keyBalanceVisible = 'balance_visible';
  static const String _keyCurrencySymbol = 'currency_symbol';
  static const String _keyNotifications = 'notifications_enabled';
  static const String _keyMonthlyBudget = 'monthly_budget';
  static const String _keyDarkMode = 'dark_mode';
  static const String _keyThemeColor = 'theme_color';

  bool _balanceVisible = true;
  String _currencySymbol = 'Rs.';
  bool _notificationsEnabled = true;
  double _monthlyBudget = 80000;
  bool _isDarkMode = false;
  Color _themeColor = const Color(0xFF6C5CE7);

  bool get balanceVisible => _balanceVisible;
  String get currencySymbol => _currencySymbol;
  bool get notificationsEnabled => _notificationsEnabled;
  double get monthlyBudget => _monthlyBudget;
  bool get isDarkMode => _isDarkMode;
  Color get themeColor => _themeColor;

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _balanceVisible = prefs.getBool(_keyBalanceVisible) ?? true;
    _currencySymbol = prefs.getString(_keyCurrencySymbol) ?? 'Rs.';
    _notificationsEnabled = prefs.getBool(_keyNotifications) ?? true;
    _monthlyBudget = prefs.getDouble(_keyMonthlyBudget) ?? 80000;
    _isDarkMode = prefs.getBool(_keyDarkMode) ?? false;

    final colorValue = prefs.getInt(_keyThemeColor);
    if (colorValue != null) {
      _themeColor = Color(colorValue);
    }
    AppColors.setSeedColor(_themeColor);

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

  Future<void> setMonthlyBudget(double budget) async {
    _monthlyBudget = budget;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyMonthlyBudget, budget);
  }

  Future<void> toggleDarkMode() async {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, _isDarkMode);
  }

  Future<void> setDarkMode(bool value) async {
    if (_isDarkMode == value) return;
    _isDarkMode = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyDarkMode, _isDarkMode);
  }

  Future<void> setThemeColor(Color color) async {
    if (_themeColor.toARGB32() == color.toARGB32()) return;
    _themeColor = color;
    AppColors.setSeedColor(color);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyThemeColor, color.toARGB32());
  }
}

