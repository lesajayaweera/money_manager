import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/transaction_model.dart';
import 'database_service.dart';

/// Lets non-widget code (providers) show a snack bar anywhere in the app.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Warns the user when an expense pushes their spending past the budget's
/// alert point or past the limit, for the whole budget or the expense's
/// category. Works for every way an expense is added (manual, quick add, SMS).
class BudgetAlertService {
  BudgetAlertService._();

  /// Spending snapshot taken before an expense is saved.
  static Future<BudgetSpendSnapshot?> snapshot(TransactionModel tx) async {
    if (!tx.isExpense) return null;
    final db = DatabaseService.instance;
    final total = await db.getBudgetSpending(tx.date.year, tx.date.month);
    final cats =
        await db.getBudgetCategorySpending(tx.date.year, tx.date.month);
    return BudgetSpendSnapshot(total, cats[tx.category] ?? 0);
  }

  /// Compares spending after the expense with [before] and shows a warning
  /// when a threshold was crossed. Never throws.
  static Future<void> checkAfter(
      TransactionModel tx, BudgetSpendSnapshot? before) async {
    if (before == null) return;
    try {
      final db = DatabaseService.instance;
      final budget =
          await db.getEffectiveBudget(tx.date.year, tx.date.month);
      if (budget == null || budget.totalAmount <= 0) return;

      final total = await db.getBudgetSpending(tx.date.year, tx.date.month);
      final cats =
          await db.getBudgetCategorySpending(tx.date.year, tx.date.month);
      final catNow = cats[tx.category] ?? 0;

      String? message;
      var severe = false;

      // Overall budget first, then the category's own limit.
      if (_crossed(before.total, total, budget.totalAmount)) {
        message =
            "You've gone over your monthly budget by ${_fmt(total - budget.totalAmount)}.";
        severe = true;
      } else if (_crossed(before.total, total, budget.alertAmount)) {
        message =
            "Heads up: you've used ${(total / budget.totalAmount * 100).floor()}% of your monthly budget. "
            '${_fmt(budget.totalAmount - total)} left.';
      } else {
        final limit = budget.categories
            .where((c) => c.categoryName == tx.category)
            .fold<double>(0, (s, c) => s + c.allocatedAmount);
        if (limit > 0) {
          if (_crossed(before.category, catNow, limit)) {
            message =
                '${tx.category} is over its limit by ${_fmt(catNow - limit)}.';
            severe = true;
          } else if (_crossed(before.category, catNow,
              limit * budget.alertPercent / 100)) {
            message =
                "${tx.category}: you've used ${(catNow / limit * 100).floor()}% of its limit. "
                '${_fmt(limit - catNow)} left.';
          }
        }
      }

      if (message == null) return;
      rootMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                severe
                    ? Icons.error_outline_rounded
                    : Icons.notifications_active_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(message,
                    style: GoogleFonts.poppins(fontSize: 13)),
              ),
            ],
          ),
          backgroundColor: severe ? AppColors.expense : AppColors.spending,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (_) {
      // Alerts are best-effort; never break saving a transaction.
    }
  }

  static bool _crossed(double before, double after, double line) =>
      line > 0 && before < line && after >= line;

  static String _fmt(double v) => CurrencyFormatter.format(v.abs());
}

class BudgetSpendSnapshot {
  final double total;
  final double category;
  const BudgetSpendSnapshot(this.total, this.category);
}
