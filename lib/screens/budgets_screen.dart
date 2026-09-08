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
import '../providers/salary_plan_provider.dart';
import '../providers/settings_provider.dart';
import 'budget_category_detail_screen.dart';
import 'create_budget_screen.dart';
import 'monthly_plan_screen.dart';

class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetProvider>().loadBudgets();
    });
  }

  // ── Month navigation ────────────────────────────────────────────────────────

  void _goToPreviousMonth() {
    final current = context.read<BudgetProvider>().selectedMonth;
    final prev = DateTime(current.year, current.month - 1, 1);
    context.read<BudgetProvider>().setSelectedMonth(prev);
  }

  void _goToNextMonth() {
    final current = context.read<BudgetProvider>().selectedMonth;
    final next = DateTime(current.year, current.month + 1, 1);
    context.read<BudgetProvider>().setSelectedMonth(next);
  }

  // ── Open create / edit ──────────────────────────────────────────────────────

  Future<void> _openCreateOrEdit({BudgetModel? existing}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CreateBudgetScreen(existing: existing),
      ),
    );
    if (result == true && mounted) {
      // Reload budgets and also sync the salary plan for this month
      await context.read<BudgetProvider>().loadBudgets();
      if (mounted) {
        final bp = context.read<BudgetProvider>();
        final budget = bp.currentBudget;
        if (budget != null) {
          await context
              .read<SalaryPlanProvider>()
              .updatePlanFromBudget(budget);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final budgetProvider = context.watch<BudgetProvider>();
    final settings = context.watch<SettingsProvider>();
    final planProvider = context.watch<SalaryPlanProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        Theme.of(context).textTheme.titleLarge?.color ?? Colors.white;
    final textSub =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final dividerColor =
        Theme.of(context).dividerTheme.color ?? const Color(0xFFF0F0F0);
    final budget = budgetProvider.currentBudget;
    final symbol = settings.currencySymbol;
    final selectedMonth = budgetProvider.selectedMonth;

    // Is there a salary plan for the selected month?
    final plan = planProvider.planForMonth(
        selectedMonth.year, selectedMonth.month);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      floatingActionButton: _buildFab(budget),
      body: _buildBody(
        budgetProvider: budgetProvider,
        budget: budget,
        plan: plan,
        symbol: symbol,
        isDark: isDark,
        textPrimary: textPrimary,
        textSub: textSub,
        surfaceColor: surfaceColor,
        dividerColor: dividerColor,
        selectedMonth: selectedMonth,
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    final budgetProvider = context.watch<BudgetProvider>();
    final selectedMonth = budgetProvider.selectedMonth;
    final now = DateTime.now();
    final isCurrentMonth =
        selectedMonth.year == now.year && selectedMonth.month == now.month;

    return AppBar(
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
      actions: [
        // Month navigation
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.chevron_left_rounded,
                  color: Theme.of(context).textTheme.bodySmall?.color),
              onPressed: _goToPreviousMonth,
              padding: EdgeInsets.zero,
            ),
            GestureDetector(
              onTap: isCurrentMonth ? null : () {
                context.read<BudgetProvider>().setSelectedMonth(DateTime.now());
              },
              child: Text(
                DateFormat('MMM yyyy').format(selectedMonth),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isCurrentMonth
                      ? AppColors.primary
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.chevron_right_rounded,
                  color: Theme.of(context).textTheme.bodySmall?.color),
              onPressed: _goToNextMonth,
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildFab(BudgetModel? budget) {
    return FloatingActionButton(
      onPressed: () => _openCreateOrEdit(existing: budget),
      backgroundColor: AppColors.primary,
      elevation: 4,
      child: Icon(
        budget == null ? Icons.add_rounded : Icons.edit_rounded,
        color: Colors.white,
        size: 26,
      ),
    );
  }

  Widget _buildBody({
    required BudgetProvider budgetProvider,
    required BudgetModel? budget,
    required dynamic plan,
    required String symbol,
    required bool isDark,
    required Color textPrimary,
    required Color textSub,
    required Color surfaceColor,
    required Color dividerColor,
    required DateTime selectedMonth,
  }) {
    if (budgetProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return budget == null
        ? _NoBudgetView(
            isDark: isDark,
            textPrimary: textPrimary,
            textSub: textSub,
            hasPlan: plan != null,
            onCreateBudget: () => _openCreateOrEdit(),
            onOpenPlan: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MonthlyPlanScreen()),
            ),
          )
        : _HasBudgetView(
            budget: budget,
            spentAmount: budgetProvider.spentAmount,
            categorySpending: budgetProvider.categorySpending,
            isOverBudget: budgetProvider.isOverBudget,
            overBudgetAmount: budgetProvider.overBudgetAmount,
            symbol: symbol,
            isDark: isDark,
            textPrimary: textPrimary,
            textSub: textSub,
            surfaceColor: surfaceColor,
            dividerColor: dividerColor,
            hasPlan: plan != null,
            onOpenPlan: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MonthlyPlanScreen()),
            ),
            onEdit: () => _openCreateOrEdit(existing: budget),
          );
  }
}

// ─── No Budget empty state ────────────────────────────────────────────────────

class _NoBudgetView extends StatelessWidget {
  final bool isDark;
  final Color textPrimary;
  final Color textSub;
  final bool hasPlan;
  final VoidCallback onCreateBudget;
  final VoidCallback onOpenPlan;

  const _NoBudgetView({
    required this.isDark,
    required this.textPrimary,
    required this.textSub,
    required this.hasPlan,
    required this.onCreateBudget,
    required this.onOpenPlan,
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
              onPressed: onCreateBudget,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
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
            if (hasPlan) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onOpenPlan,
                icon: Icon(Icons.calendar_month_rounded,
                    color: AppColors.primary, size: 16),
                label: Text(
                  'View Monthly Plan',
                  style: GoogleFonts.poppins(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Has Budget view ──────────────────────────────────────────────────────────

class _HasBudgetView extends StatelessWidget {
  final BudgetModel budget;
  final double spentAmount;
  final Map<String, double> categorySpending;
  final bool isOverBudget;
  final double overBudgetAmount;
  final String symbol;
  final bool isDark;
  final Color textPrimary;
  final Color textSub;
  final Color surfaceColor;
  final Color dividerColor;
  final bool hasPlan;
  final VoidCallback onOpenPlan;
  final VoidCallback onEdit;

  const _HasBudgetView({
    required this.budget,
    required this.spentAmount,
    required this.categorySpending,
    required this.isOverBudget,
    required this.overBudgetAmount,
    required this.symbol,
    required this.isDark,
    required this.textPrimary,
    required this.textSub,
    required this.surfaceColor,
    required this.dividerColor,
    required this.hasPlan,
    required this.onOpenPlan,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final overallPct = budget.totalAmount == 0
        ? 0.0
        : (spentAmount / budget.totalAmount).clamp(0.0, 1.0);
    final remaining = budget.totalAmount - spentAmount;

    final limitedCats =
        budget.categories.where((c) => c.allocatedAmount > 0).toList();

    final monthYear = DateFormat('MMMM yyyy').format(budget.startDate);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 110),
      children: [
        // ── Monthly Plan link banner ─────────────────────────────────────
        if (hasPlan) ...[
          _PlanLinkBanner(
            isDark: isDark,
            textPrimary: textPrimary,
            onTap: onOpenPlan,
          ),
          const SizedBox(height: 16),
        ],

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Budget Summary',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  Text(
                    monthYear,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: textSub,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  // Circular Progress
                  SizedBox(
                    width: 120,
                    height: 120,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Transform.rotate(
                          angle: math.pi * 1.5,
                          child: CircularProgressIndicator(
                            value: overallPct,
                            strokeWidth: 11,
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : const Color(0xFFF0F4F8),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              isOverBudget
                                  ? AppColors.expense
                                  : AppColors.expense,
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
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: isOverBudget
                                      ? AppColors.expense
                                      : textPrimary,
                                  height: 1.1,
                                ),
                              ),
                              Text(
                                'used',
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: textSub,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 28),
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
                        const SizedBox(height: 14),
                        _SummaryRow(
                          label: 'Total Spent',
                          amount: CurrencyFormatter.format(spentAmount,
                              symbol: symbol),
                          amountColor: AppColors.expense,
                        ),
                        const SizedBox(height: 14),
                        if (isOverBudget)
                          _SummaryRow(
                            label: 'Over Budget',
                            amount: CurrencyFormatter.format(overBudgetAmount,
                                symbol: symbol),
                            amountColor: AppColors.expense,
                            isWarning: true,
                          )
                        else
                          _SummaryRow(
                            label: 'Budget Left',
                            amount: CurrencyFormatter.format(
                                remaining.clamp(0, double.infinity),
                                symbol: symbol),
                            amountColor: AppColors.income,
                          ),
                      ],
                    ),
                  ),
                ],
              ),

              // Over-budget warning bar
              if (isOverBudget) ...[
                const SizedBox(height: 16),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.expense.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.expense.withOpacity(0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: AppColors.expense, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          "You've spent ${CurrencyFormatter.format(overBudgetAmount, symbol: symbol)} more than your budget.",
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: AppColors.expense,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
                  final appCat = context
                      .watch<CategoryProvider>()
                      .findByName(cat.categoryName, CategoryType.expense);
                  final meta = appCat != null
                      ? BudgetCategoryMeta.fromAppCategory(appCat)
                      : BudgetCategoryMeta.findByName(cat.categoryName);
                  final icon = meta?.icon ?? Icons.more_horiz_rounded;
                  final color = meta?.color ?? AppColors.primary;
                  final catSpent = categorySpending[cat.categoryName] ?? 0.0;
                  final catOver = catSpent > cat.allocatedAmount;
                  final pct = cat.allocatedAmount == 0
                      ? 0.0
                      : (catSpent / cat.allocatedAmount).clamp(0.0, 1.0);
                  final catRemaining =
                      (cat.allocatedAmount - catSpent);

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
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                            child:
                                Icon(icon, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        cat.categoryName,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: textPrimary,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Row(
                                      children: [
                                        if (catOver)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.expense
                                                  .withOpacity(0.12),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'Over',
                                              style: GoogleFonts.poppins(
                                                fontSize: 9,
                                                fontWeight: FontWeight.w700,
                                                color: AppColors.expense,
                                              ),
                                            ),
                                          )
                                        else
                                          Text(
                                            '${(pct * 100).toInt()}%',
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w700,
                                              color: textPrimary,
                                            ),
                                          ),
                                        const SizedBox(width: 6),
                                        Icon(Icons.chevron_right_rounded,
                                            color: textSub, size: 18),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      '${CurrencyFormatter.format(catSpent, symbol: symbol)} spent',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: catOver
                                            ? AppColors.expense
                                            : textSub,
                                        fontWeight: catOver
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                    Text(
                                      catOver
                                          ? '${CurrencyFormatter.format(catRemaining.abs(), symbol: symbol)} over'
                                          : '${CurrencyFormatter.format(catRemaining, symbol: symbol)} left',
                                      style: GoogleFonts.poppins(
                                        fontSize: 11,
                                        color: catOver
                                            ? AppColors.expense
                                            : AppColors.income,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Stack(
                                  children: [
                                    Container(
                                      height: 5,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.darkDivider
                                            : dividerColor,
                                        borderRadius:
                                            BorderRadius.circular(4),
                                      ),
                                    ),
                                    FractionallySizedBox(
                                      widthFactor: pct,
                                      child: Container(
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: catOver
                                              ? AppColors.expense
                                              : color,
                                          borderRadius:
                                              BorderRadius.circular(4),
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

        // ── Insights card ───────────────────────────────────────────────
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

// ─── Plan Link Banner ─────────────────────────────────────────────────────────

class _PlanLinkBanner extends StatelessWidget {
  final bool isDark;
  final Color textPrimary;
  final VoidCallback onTap;

  const _PlanLinkBanner({
    required this.isDark,
    required this.textPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkPrimarySurface
              : AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: AppColors.primary.withOpacity(isDark ? 0.25 : 0.15)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                color: AppColors.primary, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Monthly Plan active for this period',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary,
                ),
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                color: AppColors.primary, size: 13),
          ],
        ),
      ),
    );
  }
}

// ─── Summary Row ──────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final String label;
  final String amount;
  final Color amountColor;
  final bool isWarning;

  const _SummaryRow({
    required this.label,
    required this.amount,
    required this.amountColor,
    this.isWarning = false,
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
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: amountColor,
          ),
        ),
      ],
    );
  }
}
