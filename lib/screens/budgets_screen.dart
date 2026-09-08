import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../main_scaffold.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import 'budget_category_detail_screen.dart';
import 'create_budget_screen.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetProvider>().loadBudgets();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final budgetProvider = context.watch<BudgetProvider>();
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).textTheme.titleLarge?.color ?? Colors.white;
    final textSub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final dividerColor = Theme.of(context).dividerTheme.color ?? const Color(0xFFF0F0F0);
    final budget = budgetProvider.currentBudget;
    final symbol = settings.currencySymbol;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.menu_rounded,
            color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
            size: 26,
          ),
          onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
        ),
        title: Text(
          'Budgets',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
          ),
        ),
      ),
      body: _buildBody(
        budgetProvider: budgetProvider,
        budget: budget,
        symbol: symbol,
        isDark: isDark,
        textPrimary: textPrimary,
        textSub: textSub,
        surfaceColor: surfaceColor,
        dividerColor: dividerColor,
      ),
    );
  }

  Widget _buildBody({
    required BudgetProvider budgetProvider,
    required BudgetModel? budget,
    required String symbol,
    required bool isDark,
    required Color textPrimary,
    required Color textSub,
    required Color surfaceColor,
    required Color dividerColor,
  }) {
    if (budgetProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return budget == null
        ? _NoBudgetView(isDark: isDark, textPrimary: textPrimary, textSub: textSub)
        : _HasBudgetView(
            budget: budget,
            spentAmount: budgetProvider.spentAmount,
            categorySpending: budgetProvider.categorySpending,
            symbol: symbol,
            isDark: isDark,
            textPrimary: textPrimary,
            textSub: textSub,
            surfaceColor: surfaceColor,
            dividerColor: dividerColor,
          );
  }
}

// ─── No Budget empty state ────────────────────────────────────────────────────

class _NoBudgetView extends StatelessWidget {
  final bool isDark;
  final Color textPrimary;
  final Color textSub;

  const _NoBudgetView({
    required this.isDark,
    required this.textPrimary,
    required this.textSub,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.primary,
                  size: 42,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'No Budget Set',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "You haven't created a budget yet.\nSet one to track your spending.",
                style: GoogleFonts.poppins(fontSize: 14, color: textSub),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () async {
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => const CreateBudgetScreen(),
                    ),
                  );
                  if (result == true && context.mounted) {
                    context.read<BudgetProvider>().loadBudgets();
                  }
                },
                icon: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 20),
                label: Text(
                  'Create Budget',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ],
          ),
        ));
  }
}

// ─── Has Budget view ──────────────────────────────────────────────────────────

class _HasBudgetView extends StatelessWidget {
  final BudgetModel budget;
  final double spentAmount;
  final Map<String, double> categorySpending;
  final String symbol;
  final bool isDark;
  final Color textPrimary;
  final Color textSub;
  final Color surfaceColor;
  final Color dividerColor;

  const _HasBudgetView({
    required this.budget,
    required this.spentAmount,
    required this.categorySpending,
    required this.symbol,
    required this.isDark,
    required this.textPrimary,
    required this.textSub,
    required this.surfaceColor,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    final overallPct = budget.totalAmount == 0
        ? 0.0
        : (spentAmount / budget.totalAmount).clamp(0.0, 1.0);
    final remaining =
        (budget.totalAmount - spentAmount).clamp(0.0, double.infinity);

    final limitedCats =
        budget.categories.where((c) => c.allocatedAmount > 0).toList();

    final monthYear = DateFormat('MMMM yyyy').format(budget.startDate);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      children: [
        // ── Budget Summary Card ──────────────────────────────────────────
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
              Text(
                'Budget Summary ($monthYear)',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // Circular Progress
                  SizedBox(
                    width: 130,
                    height: 130,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Transform.rotate(
                          angle: math.pi * 1.5, // Start from top
                          child: CircularProgressIndicator(
                            value: overallPct,
                            strokeWidth: 12,
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : const Color(0xFFF0F4F8),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors
                                  .expense, // The coral/orange color from the image
                            ),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                '${(overallPct * 100).toInt()}%',
                                style: GoogleFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                'of budget used',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 32),
                  // Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SummaryRow(
                          label: 'Monthly Budget',
                          amount: CurrencyFormatter.format(budget.totalAmount,
                              symbol: symbol),
                          amountColor: textPrimary,
                        ),
                        const SizedBox(height: 16),
                        _SummaryRow(
                          label: 'Total Spent',
                          amount: CurrencyFormatter.format(spentAmount,
                              symbol: symbol),
                          amountColor: AppColors.expense,
                        ),
                        const SizedBox(height: 16),
                        _SummaryRow(
                          label: 'Budget Left',
                          amount: CurrencyFormatter.format(remaining,
                              symbol: symbol),
                          amountColor: AppColors.income,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Budget by Category Card ──────────────────────────────────────
        if (limitedCats.isNotEmpty) ...[
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
                Text(
                  'Budget by Category',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                ...limitedCats.asMap().entries.map((entry) {
                  final cat = entry.value;
                  final isLast = entry.key == limitedCats.length - 1;
                  // Resolve icon/color supporting custom categories (Bug 4 fix).
                  final appCat = context
                      .watch<CategoryProvider>()
                      .findByName(cat.categoryName, CategoryType.expense);
                  final meta = appCat != null
                      ? BudgetCategoryMeta.fromAppCategory(appCat)
                      : BudgetCategoryMeta.findByName(cat.categoryName);
                  final icon = meta?.icon ?? Icons.more_horiz_rounded;
                  final color = meta?.color ?? AppColors.primary;
                  final catSpent = categorySpending[cat.categoryName] ?? 0.0;
                  final pct = cat.allocatedAmount == 0
                      ? 0.0
                      : (catSpent / cat.allocatedAmount).clamp(0.0, 1.0);

                  return Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => BudgetCategoryDetailScreen(
                              budget: budget,
                              category: cat,
                              spentAmount: catSpent,
                            ),
                          ),
                        );
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    cat.categoryName,
                                    style: GoogleFonts.poppins(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: textPrimary,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Text(
                                        '${(pct * 100).toInt()}%',
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(Icons.chevron_right_rounded,
                                          color: textSub, size: 18),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${CurrencyFormatter.format(catSpent, symbol: symbol)} / ${CurrencyFormatter.format(cat.allocatedAmount, symbol: symbol)}',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: textSub,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Stack(
                                children: [
                                  Container(
                                    height: 4,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      color: dividerColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  FractionallySizedBox(
                                    widthFactor: pct,
                                    child: Container(
                                      height: 4,
                                      decoration: BoxDecoration(
                                        color: color,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
                }),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── View Budget Insights Card ──────────────────────────────────────
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
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.spending.withOpacity(0.15)
                      : AppColors.spendingLight,
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
                      'View Budget Insights',
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'See analysis and recommendations',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: textSub,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: textSub, size: 20),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String amount;
  final Color amountColor;

  const _SummaryRow({
    required this.label,
    required this.amount,
    required this.amountColor,
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
            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          amount,
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
