import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import 'transaction_history_screen.dart';

class BudgetCategoryDetailScreen extends StatelessWidget {
  final BudgetModel budget;
  final BudgetCategoryAllocation category;
  final double spentAmount;

  const BudgetCategoryDetailScreen({
    super.key,
    required this.budget,
    required this.category,
    required this.spentAmount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        Theme.of(context).textTheme.titleLarge?.color ?? Colors.white;
    final textSub =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final dividerColor =
        Theme.of(context).dividerTheme.color ?? const Color(0xFFF0F0F0);
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    final symbol = context.watch<SettingsProvider>().currencySymbol;

    // Resolve icon/color: try CategoryProvider first (supports custom categories),
    // then fall back to the hardcoded BudgetCategoryMeta defaults (Bug 4 fix).
    final categoryProvider = context.watch<CategoryProvider>();
    final appCat = categoryProvider.findByName(
        category.categoryName, CategoryType.expense);
    final meta = appCat != null
        ? BudgetCategoryMeta.fromAppCategory(appCat)
        : BudgetCategoryMeta.findByName(category.categoryName);
    final icon = meta?.icon ?? Icons.more_horiz_rounded;
    final color = meta?.color ?? AppColors.primary;
    final monthYear = DateFormat('MMMM yyyy').format(budget.startDate);

    final pct = category.allocatedAmount == 0
        ? 0.0
        : (spentAmount / category.allocatedAmount).clamp(0.0, 1.0);
    final isOver = spentAmount > category.allocatedAmount;
    final leftAmount = (category.allocatedAmount - spentAmount)
        .clamp(0.0, double.infinity);

    // Get transactions for this category in this month
    final allTx = context.watch<TransactionProvider>().allTransactions;
    final categoryTx = allTx.where((t) {
      return t.type == TransactionType.expense &&
          t.category == category.categoryName &&
          t.date.year == budget.startDate.year &&
          t.date.month == budget.startDate.month;
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    final recentTx = categoryTx.take(5).toList();

    return Scaffold(
      backgroundColor: scaffoldColor,
      appBar: AppBar(
        backgroundColor: scaffoldColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Budget Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.more_horiz_rounded, color: textPrimary),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // ── Header ───────────────────────────────────────────────
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.categoryName,
                    style: GoogleFonts.poppins(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    monthYear,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: textSub,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ── Budget Progress Card ────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: dividerColor.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Budget Progress',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      '${(pct * 100).toInt()}%',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Stack(
                  children: [
                    Container(
                      height: 12,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: dividerColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: pct,
                      child: Container(
                        height: 12,
                        decoration: BoxDecoration(
                          color: color, // The image shows orange, which matches category color for Food
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _AmountItem(
                      label: 'Budget',
                      amount: category.allocatedAmount,
                      amountColor: AppColors.primary,
                      symbol: symbol,
                      textSub: textSub,
                    ),
                    _AmountItem(
                      label: 'Spent',
                      amount: spentAmount,
                      amountColor: AppColors.expense,
                      symbol: symbol,
                      textSub: textSub,
                    ),
                    _AmountItem(
                      label: 'Left',
                      amount: leftAmount,
                      amountColor: AppColors.income,
                      symbol: symbol,
                      textSub: textSub,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Recent Transactions Card ────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: dividerColor.withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Transactions',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        // TODO: Navigate to history filtered by category
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const TransactionHistoryScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'See All',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF6C5CE7), // AppColors.primary
                        ),
                      ),
                    ),
                  ],
                ),
                if (recentTx.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  ...recentTx.asMap().entries.map((entry) {
                    final tx = entry.value;
                    final isLast = entry.key == recentTx.length - 1;
                    return Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                      child: _TransactionItem(
                        transaction: tx,
                        symbol: symbol,
                        textPrimary: textPrimary,
                        textSub: textSub,
                      ),
                    );
                  }).toList(),
                ] else ...[
                  const SizedBox(height: 32),
                  Center(
                    child: Text(
                      'No recent transactions',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: textSub,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Budget Tips Card ────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: dividerColor.withOpacity(0.5)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.spending.withOpacity(0.15) : AppColors.spendingLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lightbulb_outline_rounded,
                      color: AppColors.spending, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Budget Tips',
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isOver
                            ? 'You have exceeded your ${category.categoryName} budget.'
                            : 'You are doing good! You have ${CurrencyFormatter.format(leftAmount, symbol: symbol)} left in your ${category.categoryName} budget.',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: textSub,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: textSub, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _AmountItem extends StatelessWidget {
  final String label;
  final double amount;
  final Color amountColor;
  final String symbol;
  final Color textSub;

  const _AmountItem({
    required this.label,
    required this.amount,
    required this.amountColor,
    required this.symbol,
    required this.textSub,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: textSub,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.format(amount, symbol: symbol),
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: amountColor,
          ),
        ),
      ],
    );
  }
}

class _TransactionItem extends StatelessWidget {
  final TransactionModel transaction;
  final String symbol;
  final Color textPrimary;
  final Color textSub;

  const _TransactionItem({
    required this.transaction,
    required this.symbol,
    required this.textPrimary,
    required this.textSub,
  });

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final txDate = DateTime(date.year, date.month, date.day);

    if (txDate == today) return 'Today';
    if (txDate == yesterday) return 'Yesterday';
    return DateFormat('d MMM').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final appCat = categoryProvider.findByName(
        transaction.category, CategoryType.expense);
    final meta = appCat != null
        ? BudgetCategoryMeta.fromAppCategory(appCat)
        : BudgetCategoryMeta.findByName(transaction.category);
    final icon = meta?.icon ?? Icons.more_horiz_rounded;
    final color = meta?.color ?? AppColors.primary;
    final isExpense = transaction.type == TransactionType.expense;

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.title,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${_formatDate(transaction.date)} • ${transaction.walletName ?? 'Cash'}',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: textSub,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${isExpense ? '-' : '+'}${CurrencyFormatter.format(transaction.amount, symbol: symbol)}',
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isExpense ? AppColors.expense : AppColors.income,
          ),
        ),
      ],
    );
  }
}
