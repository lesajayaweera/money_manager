import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _compactFormatter = NumberFormat.compact();
  static final NumberFormat _fullFormatter = NumberFormat('#,##,##0');
  static final NumberFormat _decimalFormatter = NumberFormat('#,##,##0.00');

  /// Format as "Rs. 45,000" or "Rs. 450.50" for small numbers with decimals
  static String format(double amount, {String symbol = 'Rs.'}) {
    final prefix = amount < 0 ? '-' : '';
    final absAmount = amount.abs();
    final formatted = (absAmount < 1000 && absAmount != absAmount.truncateToDouble())
        ? _decimalFormatter.format(absAmount)
        : _fullFormatter.format(absAmount);
    return '$prefix$symbol $formatted';
  }

  /// Format with sign: "+Rs. 50,000" or "-Rs. 500"
  static String formatWithSign(double amount, {String symbol = 'Rs.'}) {
    final prefix = amount >= 0 ? '+' : '-';
    final absAmount = amount.abs();
    final formatted = (absAmount < 1000 && absAmount != absAmount.truncateToDouble())
        ? _decimalFormatter.format(absAmount)
        : _fullFormatter.format(absAmount);
    return '$prefix$symbol $formatted';
  }

  /// Format compact: "Rs. 1.2L" for large numbers
  static String formatCompact(double amount, {String symbol = 'Rs.'}) {
    if (amount.abs() >= 100000) {
      final prefix = amount < 0 ? '-' : '';
      return '$prefix$symbol ${_compactFormatter.format(amount.abs())}';
    }
    return format(amount, symbol: symbol);
  }

  /// Parse "45000" from "Rs. 45,000"
  static double? parse(String text) {
    final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
    return double.tryParse(cleaned);
  }

  /// Month/Year display: "May 2024"
  static String monthYear(DateTime date) {
    return DateFormat('MMMM yyyy').format(date);
  }

  /// Day name: "Today", "Yesterday", or formatted date
  static String relativeDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    if (d == today) return 'Today';
    if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return DateFormat('d MMM yyyy').format(date);
  }

  /// Short date: "2 May 2024"
  static String shortDate(DateTime date) {
    return DateFormat('d MMM yyyy').format(date);
  }

  /// Time: "10:30 AM"
  static String time(DateTime date) {
    return DateFormat('h:mm a').format(date);
  }
}
