import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../models/transaction_model.dart';

enum InsightSeverity { info, warning, good, bad }

class FinancialInsight {
  final String title;
  final String description;
  final InsightSeverity severity;
  final IconData _icon;

  const FinancialInsight({
    required this.title,
    required this.description,
    required this.severity,
    required IconData icon,
  }) : _icon = icon;

  IconData get icon => _icon;

  static final Map<InsightSeverity, Color> severityColors = {
    InsightSeverity.info: AppColors.primary,
    InsightSeverity.warning: AppColors.spending,
    InsightSeverity.good: AppColors.income,
    InsightSeverity.bad: const Color(0xFFE17055),
  };
}

class InsightsService {
  /// Generates a list of financial insights from the user's transactions.
  ///
  /// Uses the current month as the primary reference period and compares
  /// against the previous 3 months to detect patterns.
  static List<FinancialInsight> generateInsights(
    List<TransactionModel> allTransactions,
    Map<String, double> categorySpending,
    double? monthlyBudget,
  ) {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final currentMonthEnd = DateTime(now.year, now.month + 1, 1);

    final List<FinancialInsight> insights = [];

    final currentMonthTxs = allTransactions
        .where((t) =>
            t.date.isAfter(
                currentMonthStart.subtract(const Duration(milliseconds: 1))) &&
            t.date.isBefore(currentMonthEnd))
        .toList();

    final currentExpenses = currentMonthTxs
        .where((t) => t.type == TransactionType.expense)
        .toList();
    final currentIncome =
        currentMonthTxs.where((t) => t.type == TransactionType.income).toList();

    final currentExpenseTotal =
        currentExpenses.fold<double>(0, (sum, t) => sum + t.amount);
    final currentIncomeTotal =
        currentIncome.fold<double>(0, (sum, t) => sum + t.amount);

    final Map<String, double> catTotals = {};
    for (final tx in currentExpenses) {
      catTotals[tx.category] = (catTotals[tx.category] ?? 0) + tx.amount;
    }

    // ── Insight 1: Top category this month ─────────────────────────────────
    if (catTotals.isNotEmpty) {
      final sorted = catTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sorted.first;
      final pct = (top.value / currentExpenseTotal * 100).round();
      insights.add(FinancialInsight(
        title: 'Top Spending Category',
        description:
            '${top.key} is your biggest expense this month at '
            '$pct% of total spending (${_fmt(top.value)}).',
        severity: pct > 40 ? InsightSeverity.warning : InsightSeverity.info,
        icon: Icons.insights_rounded,
      ));
    }

    // ── Insight 2: Spending spike detection ────────────────────────────────
    final prevThreeMonths = DateTime(now.year, now.month - 3, 1);
    final prevTxs = allTransactions
        .where((t) =>
            t.type == TransactionType.expense &&
            t.date.isAfter(
                prevThreeMonths.subtract(const Duration(milliseconds: 1))) &&
            t.date.isBefore(currentMonthStart))
        .toList();

    if (prevTxs.isNotEmpty) {
      final Map<String, double> prevCatTotals = {};
      for (final tx in prevTxs) {
        prevCatTotals[tx.category] = (prevCatTotals[tx.category] ?? 0) + tx.amount;
      }

      for (final entry in catTotals.entries) {
        final prevTotal = prevCatTotals[entry.key] ?? 0;
        final prevMonthlyAvg = prevTotal / 3;
        if (prevMonthlyAvg > 0 && entry.value > prevMonthlyAvg * 2) {
          insights.add(FinancialInsight(
            title: 'Unusual Spending Spike',
            description:
                'Spending on ${entry.key} is ${_fmt(entry.value - prevMonthlyAvg)} '
                'above your 3-month average. Consider whether this is expected.',
            severity: InsightSeverity.warning,
            icon: Icons.trending_up_rounded,
          ));
        }
      }
    }

    // ── Insight 3: Savings trend ───────────────────────────────────────────
    final monthSavings = currentIncomeTotal - currentExpenseTotal;
    if (currentIncomeTotal > 0 || currentExpenseTotal > 0) {
      if (monthSavings > 0) {
        final savingsRate = currentIncomeTotal > 0
            ? (monthSavings / currentIncomeTotal * 100).round()
            : 100;
        insights.add(FinancialInsight(
          title: 'Positive Savings Rate',
          description:
              'You saved ${_fmt(monthSavings)} this month, a $savingsRate% '
              'savings rate. Keep it up!',
          severity: InsightSeverity.good,
          icon: Icons.savings_rounded,
        ));
      } else if (monthSavings < 0) {
        final over = _fmt(monthSavings.abs());
        insights.add(FinancialInsight(
          title: 'Overspending Detected',
          description:
              'You spent ${_fmt(currentExpenseTotal)} but earned only '
              '${_fmt(currentIncomeTotal)} — a deficit of $over this month.',
          severity: InsightSeverity.bad,
          icon: Icons.warning_amber_rounded,
        ));
      }
    }

    // ── Insight 4: Budget adherence ────────────────────────────────────────
    if (monthlyBudget != null && monthlyBudget > 0) {
      final pctUsed = (currentExpenseTotal / monthlyBudget * 100).round();
      if (pctUsed > 100) {
        final over = _fmt(currentExpenseTotal - monthlyBudget);
        insights.add(FinancialInsight(
          title: 'Over Budget',
          description:
              'You\'re $over over your ${_fmt(monthlyBudget)} budget '
              '($pctUsed% used).',
          severity: InsightSeverity.bad,
          icon: Icons.speed_rounded,
        ));
      } else if (pctUsed > 80) {
        insights.add(FinancialInsight(
          title: 'Approaching Budget Limit',
          description:
              'You\'ve used $pctUsed% of your ${_fmt(monthlyBudget)} budget. '
              'Slowing down on discretionary spending is advised.',
          severity: InsightSeverity.warning,
          icon: Icons.speed_rounded,
        ));
      } else {
        insights.add(FinancialInsight(
          title: 'Within Budget',
          description:
              'You\'ve used $pctUsed% of your ${_fmt(monthlyBudget)} budget. '
              'You\'re on track.',
          severity: InsightSeverity.good,
          icon: Icons.check_circle_rounded,
        ));
      }
    }

    // ── Insight 5: Daily average spending ──────────────────────────────────
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final daysElapsed = now.day;
    if (currentExpenseTotal > 0 && daysElapsed > 0) {
      final dailyAvg = currentExpenseTotal / daysElapsed;
      final projected = dailyAvg * daysInMonth;
      insights.add(FinancialInsight(
        title: 'Daily Spending Average',
        description:
            'You\'re spending ${_fmt(dailyAvg)} per day on average. '
            'Projected month-end total: ${_fmt(projected)}.',
        severity: InsightSeverity.info,
        icon: Icons.calendar_month_rounded,
      ));
    }

    // ── Insight 6: No-spend days ───────────────────────────────────────────
    final spendDates = currentExpenses
        .map((t) => '${t.date.year}-${t.date.month}-${t.date.day}')
        .toSet();
    int noSpendDays = 0;
    for (int d = 1; d <= now.day; d++) {
      final key = '${now.year}-${now.month}-$d';
      if (!spendDates.contains(key)) noSpendDays++;
    }
    if (noSpendDays > 0 && currentExpenses.isNotEmpty) {
      insights.add(FinancialInsight(
        title: 'No-Spend Days',
        description:
            'You had $noSpendDays day${noSpendDays == 1 ? '' : 's'} with no '
            'expenses so far this month.',
        severity: InsightSeverity.good,
        icon: Icons.event_available_rounded,
      ));
    }

    // ── Insight 7: Wallet concentration ────────────────────────────────────
    final walletTotals = <String, double>{};
    for (final tx in currentExpenses) {
      walletTotals[tx.walletName] =
          (walletTotals[tx.walletName] ?? 0) + tx.amount;
    }
    if (walletTotals.isNotEmpty && currentExpenseTotal > 0) {
      final sortedWallets = walletTotals.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topWallet = sortedWallets.first;
      final walletPct = (topWallet.value / currentExpenseTotal * 100).round();
      if (walletPct > 50) {
        insights.add(FinancialInsight(
          title: 'Wallet Concentration',
          description:
              '$walletPct% of your spending ($_fmt(topWallet.value)) goes '
              'through ${topWallet.key}. Consider spreading expenses.',
          severity: InsightSeverity.info,
          icon: Icons.account_balance_wallet_rounded,
        ));
      }
    }

    // ── Insight 8: Category composition ────────────────────────────────────
    if (catTotals.isNotEmpty) {
      final distinctCats = catTotals.length;
      if (distinctCats <= 2 && currentExpenseTotal > 0) {
        insights.add(FinancialInsight(
          title: 'Concentrated Spending',
          description:
              'Only $distinctCats categor${distinctCats == 1 ? 'y' : 'ies'} '
              'account for all of this month\'s spending. A more diverse '
              'expense mix may help balance your budget.',
          severity: InsightSeverity.warning,
          icon: Icons.pie_chart_rounded,
        ));
      }
    }

    insights.sort((a, b) {
      const order = [
        InsightSeverity.bad,
        InsightSeverity.warning,
        InsightSeverity.good,
        InsightSeverity.info,
      ];
      return order.indexOf(a.severity).compareTo(order.indexOf(b.severity));
    });

    return insights;
  }

  static String _fmt(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K';
    }
    return value.toStringAsFixed(0);
  }
}