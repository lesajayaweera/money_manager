import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import '../main_scaffold.dart';
import 'budget_category_detail_screen.dart';
import 'create_budget_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with AutomaticKeepAliveClientMixin, SingleTickerProviderStateMixin {
  @override
  bool get wantKeepAlive => true;

  late TabController _tabController;
  int _touchedPieIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
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
          'Reports',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color:
                Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.darkSurface2
                    : const Color(0xFFEEECFD),
                borderRadius: BorderRadius.circular(22),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(22),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor:
                    Theme.of(context).textTheme.bodyMedium?.color ??
                        Colors.white,
                dividerColor: Colors.transparent,
                labelStyle: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w500),
                tabs: [
                  const Tab(text: 'Overview'),
                  const Tab(text: 'Categories'),
                  const Tab(text: 'Daily'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _OverviewTab(
                  touchedIndex: _touchedPieIndex,
                  onPieTouch: (i) => setState(() => _touchedPieIndex = i),
                ),
                const _CategoriesTab(),
                const _DailyTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Overview Tab ─────────────────────────────────────────────────────────────

enum ReportPeriod { daily, monthly, annually, custom }

class _OverviewTab extends StatefulWidget {
  final int touchedIndex;
  final ValueChanged<int> onPieTouch;

  const _OverviewTab({required this.touchedIndex, required this.onPieTouch});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  ReportPeriod _selectedPeriod = ReportPeriod.monthly;
  DateTimeRange? _customDateRange;
  int _touchedIncomePieIndex = -1;
  int _touchedWalletPieIndex = -1;

  List<TransactionModel> _getFilteredTransactions(
      List<TransactionModel> allTxs) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (_selectedPeriod) {
      case ReportPeriod.daily:
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
        break;
      case ReportPeriod.monthly:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 1);
        break;
      case ReportPeriod.annually:
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year + 1, 1, 1);
        break;
      case ReportPeriod.custom:
        if (_customDateRange != null) {
          start = _customDateRange!.start;
          end = _customDateRange!.end.add(const Duration(days: 1));
        } else {
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 1);
        }
        break;
    }

    return allTxs.where((t) {
      return (t.date.isAfter(start.subtract(const Duration(milliseconds: 1))) ||
              t.date.isAtSameMomentAs(start)) &&
          t.date.isBefore(end);
    }).toList();
  }

  Map<String, double> _getCategoryBreakdown(
      List<TransactionModel> txs, TransactionType type) {
    final Map<String, double> breakdown = {};
    for (final tx in txs) {
      if (tx.type == type) {
        breakdown[tx.category] = (breakdown[tx.category] ?? 0) + tx.amount;
      }
    }
    final sortedEntries = breakdown.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sortedEntries);
  }

  Future<void> _selectCustomDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _customDateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface:
                  Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedPeriod = ReportPeriod.custom;
      });
    } else if (_selectedPeriod == ReportPeriod.custom &&
        _customDateRange == null) {
      // Revert if cancelled and no range was selected
      setState(() {
        _selectedPeriod = ReportPeriod.monthly;
      });
    }
  }

  String _getPeriodLabel() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case ReportPeriod.daily:
        return DateFormat('dd MMM yyyy').format(now);
      case ReportPeriod.monthly:
        return DateFormat('MMMM yyyy').format(now);
      case ReportPeriod.annually:
        return DateFormat('yyyy').format(now);
      case ReportPeriod.custom:
        if (_customDateRange != null) {
          final start = DateFormat('dd MMM').format(_customDateRange!.start);
          final end = DateFormat('dd MMM yyyy').format(_customDateRange!.end);
          return '$start - $end';
        }
        return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final settings = context.watch<SettingsProvider>();
    final walletProvider = context.watch<WalletProvider>();

    final filteredTxs = _getFilteredTransactions(provider.allTransactions);

    double totalIncome = 0;
    double totalExpense = 0;
    for (final tx in filteredTxs) {
      if (tx.isIncome) totalIncome += tx.amount;
      if (tx.isExpense) totalExpense += tx.amount;
    }

    final expenseBreakdown =
        _getCategoryBreakdown(filteredTxs, TransactionType.expense);
    final incomeBreakdown =
        _getCategoryBreakdown(filteredTxs, TransactionType.income);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Period Selector
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Report Period',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color ??
                        Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _PeriodChip(
                        label: 'Daily',
                        isSelected: _selectedPeriod == ReportPeriod.daily,
                        onTap: () => setState(
                            () => _selectedPeriod = ReportPeriod.daily),
                      ),
                      const SizedBox(width: 8),
                      _PeriodChip(
                        label: 'Monthly',
                        isSelected: _selectedPeriod == ReportPeriod.monthly,
                        onTap: () => setState(
                            () => _selectedPeriod = ReportPeriod.monthly),
                      ),
                      const SizedBox(width: 8),
                      _PeriodChip(
                        label: 'Annually',
                        isSelected: _selectedPeriod == ReportPeriod.annually,
                        onTap: () => setState(
                            () => _selectedPeriod = ReportPeriod.annually),
                      ),
                      const SizedBox(width: 8),
                      _PeriodChip(
                        label: 'Custom',
                        isSelected: _selectedPeriod == ReportPeriod.custom,
                        onTap: _selectCustomDateRange,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Income vs Expense bar chart
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Income vs Expense (${_getPeriodLabel()})',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color ??
                        Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                _SimpleBarChart(
                  income: totalIncome,
                  expenses: totalExpense,
                  currencySymbol: settings.currencySymbol,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Spending Overview bar chart
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Spending Overview',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color ??
                        Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 200,
                  child: _SpendingOverTimeChart(
                    txs: filteredTxs,
                    period: _selectedPeriod,
                    customDateRange: _customDateRange,
                    currencySymbol: settings.currencySymbol,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Cash Flow line chart
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cash Flow',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color ??
                        Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Income vs Expenses over time',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color ??
                        Colors.grey,
                  ),
                ),
                const SizedBox(height: 16),
                // Legend
                Row(
                  children: [
                    Container(
                        width: 12,
                        height: 3,
                        decoration: BoxDecoration(
                            color: AppColors.income,
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Text('Income',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.income,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 16),
                    Container(
                        width: 12,
                        height: 3,
                        decoration: BoxDecoration(
                            color: AppColors.expense,
                            borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    Text('Expenses',
                        style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: AppColors.expense,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: _CashFlowChart(
                    txs: filteredTxs,
                    period: _selectedPeriod,
                    customDateRange: _customDateRange,
                    currencySymbol: settings.currencySymbol,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category-wise expenses pie chart
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category-wise Expenses',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color ??
                        Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                if (expenseBreakdown.isEmpty)
                  SizedBox(
                    height: 80,
                    child: Center(
                      child: Text(
                        'No expenses in this period',
                        style: GoogleFonts.poppins(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color ??
                                    Colors.white),
                      ),
                    ),
                  )
                else
                  _PieSection(
                    data: expenseBreakdown,
                    touchedIndex: widget.touchedIndex,
                    onTouch: widget.onPieTouch,
                    currencySymbol: settings.currencySymbol,
                    total: totalExpense,
                    isExpense: true,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Category-wise income pie chart
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category-wise Income',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color ??
                        Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                if (incomeBreakdown.isEmpty)
                  SizedBox(
                    height: 80,
                    child: Center(
                      child: Text(
                        'No income in this period',
                        style: GoogleFonts.poppins(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color ??
                                    Colors.white),
                      ),
                    ),
                  )
                else
                  _PieSection(
                    data: incomeBreakdown,
                    touchedIndex: _touchedIncomePieIndex,
                    onTouch: (i) => setState(() => _touchedIncomePieIndex = i),
                    currencySymbol: settings.currencySymbol,
                    total: totalIncome,
                    isExpense: false,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Wallet-wise balance pie chart
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wallet-wise Balance',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color ??
                        Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                if (walletProvider.wallets.isEmpty)
                  SizedBox(
                    height: 80,
                    child: Center(
                      child: Text(
                        'No wallets found',
                        style: GoogleFonts.poppins(
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color ??
                                    Colors.white),
                      ),
                    ),
                  )
                else
                  _WalletPieSection(
                    wallets: walletProvider.wallets,
                    touchedIndex: _touchedWalletPieIndex,
                    onTouch: (i) => setState(() => _touchedWalletPieIndex = i),
                    currencySymbol: settings.currencySymbol,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurface2
                  : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected
                ? Colors.white
                : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─── Simple Bar Chart (custom, matches design exactly) ─────────────────────

class _SimpleBarChart extends StatelessWidget {
  final double income;
  final double expenses;
  final String currencySymbol;

  const _SimpleBarChart({
    required this.income,
    required this.expenses,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = math.max(income, expenses);
    final safeMax = maxVal == 0 ? 1.0 : maxVal;
    // Reserve 30px at top for value labels, 160px for bars, 36px for x-labels
    const labelAreaHeight = 30.0;
    const chartHeight = 150.0;
    const barWidth = 60.0;

    // Y-axis steps
    final step = (maxVal / 3).ceilToDouble();
    final y3 = step * 3;
    final y2 = step * 2;
    final y1 = step;

    return SizedBox(
      height: labelAreaHeight + chartHeight + 36,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Y-axis labels – aligned to bar area only (offset by labelAreaHeight)
          Padding(
            padding: const EdgeInsets.only(top: labelAreaHeight),
            child: SizedBox(
              width: 44,
              height: chartHeight,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _yLabel(context, y3),
                  _yLabel(context, y2),
                  _yLabel(context, y1),
                  _yLabel(context, 0),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Chart area
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Label area: fixed height so bars never push labels up
                SizedBox(
                  height: labelAreaHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      SizedBox(
                        width: barWidth,
                        child: Text(
                          CurrencyFormatter.format(income,
                              symbol: currencySymbol),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.income,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(
                        width: barWidth,
                        child: Text(
                          CurrencyFormatter.format(expenses,
                              symbol: currencySymbol),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppColors.expense,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Bar area
                SizedBox(
                  height: chartHeight,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Bar(
                        value: income,
                        maxValue: safeMax,
                        totalHeight: chartHeight,
                        barWidth: barWidth,
                        color: AppColors.income,
                      ),
                      _Bar(
                        value: expenses,
                        maxValue: safeMax,
                        totalHeight: chartHeight,
                        barWidth: barWidth,
                        color: AppColors.expense,
                      ),
                    ],
                  ),
                ),
                // X-axis labels
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    SizedBox(
                      width: barWidth,
                      child: Center(
                        child: Text(
                          'Income',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color ??
                                    Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: barWidth,
                      child: Center(
                        child: Text(
                          'Expenses',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color ??
                                    Colors.white,
                          ),
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
    );
  }

  Widget _yLabel(BuildContext context, double value) {
    String label;
    if (value >= 1000) {
      label = '${(value / 1000).round()}K';
    } else {
      label = value.toInt().toString();
    }
    return Text(
      label,
      style: GoogleFonts.poppins(
          fontSize: 10,
          color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white),
    );
  }
}

class _Bar extends StatelessWidget {
  final double value;
  final double maxValue;
  final double totalHeight;
  final double barWidth;
  final Color color;

  const _Bar({
    required this.value,
    required this.maxValue,
    required this.totalHeight,
    required this.barWidth,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final barHeight = (value / maxValue) * totalHeight;
    return SizedBox(
      width: barWidth,
      // Bar only — label is in the dedicated label area above
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeOutCubic,
        width: barWidth,
        height: math.max(barHeight, value > 0 ? 4 : 0),
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
        ),
      ),
    );
  }
}

// ─── Spending Over Time Chart ──────────────────────────────────────────────────

class _SpendingOverTimeChart extends StatelessWidget {
  final List<TransactionModel> txs;
  final ReportPeriod period;
  final DateTimeRange? customDateRange;
  final String currencySymbol;

  const _SpendingOverTimeChart({
    super.key,
    required this.txs,
    required this.period,
    this.customDateRange,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    // Group transactions
    final Map<int, double> grouped = {};
    int minKey = 0;
    int maxKey = 0;

    final now = DateTime.now();

    if (period == ReportPeriod.daily) {
      minKey = 0;
      maxKey = 23;
      for (var tx in txs) {
        if (tx.isExpense) {
          grouped[tx.date.hour] = (grouped[tx.date.hour] ?? 0) + tx.amount;
        }
      }
    } else if (period == ReportPeriod.monthly) {
      minKey = 1;
      maxKey = DateUtils.getDaysInMonth(now.year, now.month);
      for (var tx in txs) {
        if (tx.isExpense) {
          grouped[tx.date.day] = (grouped[tx.date.day] ?? 0) + tx.amount;
        }
      }
    } else if (period == ReportPeriod.annually) {
      minKey = 1;
      maxKey = 12;
      for (var tx in txs) {
        if (tx.isExpense) {
          grouped[tx.date.month] = (grouped[tx.date.month] ?? 0) + tx.amount;
        }
      }
    } else if (period == ReportPeriod.custom) {
      if (customDateRange != null) {
        final days =
            customDateRange!.end.difference(customDateRange!.start).inDays;
        if (days <= 31) {
          minKey = 0;
          maxKey = days;
          for (var tx in txs) {
            if (tx.isExpense) {
              final dayDiff = tx.date.difference(customDateRange!.start).inDays;
              grouped[dayDiff] = (grouped[dayDiff] ?? 0) + tx.amount;
            }
          }
        } else {
          minKey = 0;
          maxKey =
              (customDateRange!.end.year - customDateRange!.start.year) * 12 +
                  customDateRange!.end.month -
                  customDateRange!.start.month;
          for (var tx in txs) {
            if (tx.isExpense) {
              final monthDiff =
                  (tx.date.year - customDateRange!.start.year) * 12 +
                      tx.date.month -
                      customDateRange!.start.month;
              grouped[monthDiff] = (grouped[monthDiff] ?? 0) + tx.amount;
            }
          }
        }
      }
    }

    double maxY = 0;
    for (var val in grouped.values) {
      if (val > maxY) maxY = val;
    }
    if (maxY == 0) maxY = 100;

    double xInterval = 1;
    if (maxKey - minKey > 15) {
      xInterval = ((maxKey - minKey) / 5).ceilToDouble();
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY * 1.2,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF333333)
                : Colors.white,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                CurrencyFormatter.format(rod.toY, symbol: currencySymbol),
                GoogleFonts.poppins(
                  color: AppColors.expense,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                final intVal = value.toInt();

                if (maxKey - minKey > 15) {
                  if (intVal != minKey &&
                      intVal != maxKey &&
                      (intVal - minKey) % xInterval.toInt() != 0) {
                    return const SizedBox.shrink();
                  }
                }

                String text = '';
                if (period == ReportPeriod.daily) {
                  text = '$intVal:00';
                } else if (period == ReportPeriod.monthly) {
                  text = '$intVal';
                } else if (period == ReportPeriod.annually) {
                  const months = [
                    'Jan',
                    'Feb',
                    'Mar',
                    'Apr',
                    'May',
                    'Jun',
                    'Jul',
                    'Aug',
                    'Sep',
                    'Oct',
                    'Nov',
                    'Dec'
                  ];
                  if (intVal >= 1 && intVal <= 12) {
                    text = months[intVal - 1];
                  }
                } else if (period == ReportPeriod.custom &&
                    customDateRange != null) {
                  final days = customDateRange!.end
                      .difference(customDateRange!.start)
                      .inDays;
                  if (days <= 31) {
                    final d =
                        customDateRange!.start.add(Duration(days: intVal));
                    text = '${d.day}/${d.month}';
                  } else {
                    final m = customDateRange!.start.month + intVal;
                    final monthIndex = (m - 1) % 12;
                    const months = [
                      'Jan',
                      'Feb',
                      'Mar',
                      'Apr',
                      'May',
                      'Jun',
                      'Jul',
                      'Aug',
                      'Sep',
                      'Oct',
                      'Nov',
                      'Dec'
                    ];
                    text = months[monthIndex];
                  }
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    text,
                    style: GoogleFonts.poppins(
                      color: Theme.of(context).textTheme.bodySmall?.color ??
                          Colors.white,
                      fontSize: 10,
                    ),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value == maxY * 1.2 || value == 0)
                  return const SizedBox.shrink();
                String label;
                if (value >= 1000) {
                  label =
                      '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K';
                } else {
                  label = value.toInt().toString();
                }
                return Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).textTheme.bodySmall?.color ??
                        Colors.white,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.right,
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4 == 0 ? 1 : maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(maxKey - minKey + 1, (index) {
          final key = minKey + index;
          final val = grouped[key] ?? 0.0;
          return BarChartGroupData(
            x: key,
            barRods: [
              BarChartRodData(
                toY: val,
                color: AppColors.expense,
                width: maxKey - minKey > 20 ? 4 : 12,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(4)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxY * 1.2,
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.05),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ─── Cash Flow Line Chart ────────────────────────────────────────────────────

class _CashFlowChart extends StatelessWidget {
  final List<TransactionModel> txs;
  final ReportPeriod period;
  final DateTimeRange? customDateRange;
  final String currencySymbol;

  const _CashFlowChart({
    super.key,
    required this.txs,
    required this.period,
    this.customDateRange,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final Map<int, double> incomeGrouped = {};
    final Map<int, double> expenseGrouped = {};
    int minKey = 0;
    int maxKey = 0;

    final now = DateTime.now();

    if (period == ReportPeriod.daily) {
      minKey = 0;
      maxKey = 23;
      for (var tx in txs) {
        if (tx.isExpense) {
          expenseGrouped[tx.date.hour] =
              (expenseGrouped[tx.date.hour] ?? 0) + tx.amount;
        } else {
          incomeGrouped[tx.date.hour] =
              (incomeGrouped[tx.date.hour] ?? 0) + tx.amount;
        }
      }
    } else if (period == ReportPeriod.monthly) {
      minKey = 1;
      maxKey = DateUtils.getDaysInMonth(now.year, now.month);
      for (var tx in txs) {
        if (tx.isExpense) {
          expenseGrouped[tx.date.day] =
              (expenseGrouped[tx.date.day] ?? 0) + tx.amount;
        } else {
          incomeGrouped[tx.date.day] =
              (incomeGrouped[tx.date.day] ?? 0) + tx.amount;
        }
      }
    } else if (period == ReportPeriod.annually) {
      minKey = 1;
      maxKey = 12;
      for (var tx in txs) {
        if (tx.isExpense) {
          expenseGrouped[tx.date.month] =
              (expenseGrouped[tx.date.month] ?? 0) + tx.amount;
        } else {
          incomeGrouped[tx.date.month] =
              (incomeGrouped[tx.date.month] ?? 0) + tx.amount;
        }
      }
    } else if (period == ReportPeriod.custom && customDateRange != null) {
      final days =
          customDateRange!.end.difference(customDateRange!.start).inDays;
      if (days <= 31) {
        minKey = 0;
        maxKey = days;
        for (var tx in txs) {
          final dayDiff = tx.date.difference(customDateRange!.start).inDays;
          if (tx.isExpense) {
            expenseGrouped[dayDiff] =
                (expenseGrouped[dayDiff] ?? 0) + tx.amount;
          } else {
            incomeGrouped[dayDiff] = (incomeGrouped[dayDiff] ?? 0) + tx.amount;
          }
        }
      } else {
        minKey = 0;
        maxKey =
            (customDateRange!.end.year - customDateRange!.start.year) * 12 +
                customDateRange!.end.month -
                customDateRange!.start.month;
        for (var tx in txs) {
          final monthDiff = (tx.date.year - customDateRange!.start.year) * 12 +
              tx.date.month -
              customDateRange!.start.month;
          if (tx.isExpense) {
            expenseGrouped[monthDiff] =
                (expenseGrouped[monthDiff] ?? 0) + tx.amount;
          } else {
            incomeGrouped[monthDiff] =
                (incomeGrouped[monthDiff] ?? 0) + tx.amount;
          }
        }
      }
    }

    // Build spots
    final incomeSpots = <FlSpot>[];
    final expenseSpots = <FlSpot>[];
    for (int i = minKey; i <= maxKey; i++) {
      incomeSpots.add(FlSpot(i.toDouble(), incomeGrouped[i] ?? 0));
      expenseSpots.add(FlSpot(i.toDouble(), expenseGrouped[i] ?? 0));
    }

    double maxY = 0;
    for (var s in [...incomeSpots, ...expenseSpots]) {
      if (s.y > maxY) maxY = s.y;
    }
    if (maxY == 0) maxY = 100;

    double xInterval = 1;
    if (maxKey - minKey > 15) {
      xInterval = ((maxKey - minKey) / 5).ceilToDouble();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY * 1.25,
        minX: minKey.toDouble(),
        maxX: maxKey.toDouble(),
        clipData: const FlClipData.all(),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: isDark ? const Color(0xFF333355) : Colors.white,
            getTooltipItems: (spots) {
              return spots.map((s) {
                final isIncome = s.barIndex == 0;
                return LineTooltipItem(
                  '${isIncome ? "In" : "Out"}: ${CurrencyFormatter.format(s.y, symbol: currencySymbol)}',
                  GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isIncome ? AppColors.income : AppColors.expense,
                  ),
                );
              }).toList();
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: xInterval,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final intVal = value.toInt();
                if (maxKey - minKey > 15) {
                  if (intVal != minKey &&
                      intVal != maxKey &&
                      (intVal - minKey) % xInterval.toInt() != 0) {
                    return const SizedBox.shrink();
                  }
                }
                String text = '';
                if (period == ReportPeriod.daily) {
                  text = '$intVal:00';
                } else if (period == ReportPeriod.monthly) {
                  text = '$intVal';
                } else if (period == ReportPeriod.annually) {
                  const months = [
                    'Jan',
                    'Feb',
                    'Mar',
                    'Apr',
                    'May',
                    'Jun',
                    'Jul',
                    'Aug',
                    'Sep',
                    'Oct',
                    'Nov',
                    'Dec'
                  ];
                  if (intVal >= 1 && intVal <= 12) text = months[intVal - 1];
                } else if (period == ReportPeriod.custom &&
                    customDateRange != null) {
                  final days = customDateRange!.end
                      .difference(customDateRange!.start)
                      .inDays;
                  if (days <= 31) {
                    final d =
                        customDateRange!.start.add(Duration(days: intVal));
                    text = '${d.day}/${d.month}';
                  } else {
                    final m = customDateRange!.start.month + intVal;
                    const months = [
                      'Jan',
                      'Feb',
                      'Mar',
                      'Apr',
                      'May',
                      'Jun',
                      'Jul',
                      'Aug',
                      'Sep',
                      'Oct',
                      'Nov',
                      'Dec'
                    ];
                    text = months[(m - 1) % 12];
                  }
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    text,
                    style: GoogleFonts.poppins(
                      color: Theme.of(context).textTheme.bodySmall?.color ??
                          Colors.grey,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (value, meta) {
                if (value == maxY * 1.25 || value == 0)
                  return const SizedBox.shrink();
                final label = value >= 1000
                    ? '${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}K'
                    : value.toInt().toString();
                return Text(
                  label,
                  style: GoogleFonts.poppins(
                    color: Theme.of(context).textTheme.bodySmall?.color ??
                        Colors.grey,
                    fontSize: 10,
                  ),
                  textAlign: TextAlign.right,
                );
              },
            ),
          ),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4 == 0 ? 1 : maxY / 4,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          // Income line
          LineChartBarData(
            spots: incomeSpots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: AppColors.income,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: spot.y > 0 ? 3 : 0,
                color: AppColors.income,
                strokeWidth: 1.5,
                strokeColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.income.withValues(alpha: 0.08),
            ),
          ),
          // Expense line
          LineChartBarData(
            spots: expenseSpots,
            isCurved: true,
            curveSmoothness: 0.35,
            color: AppColors.expense,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: spot.y > 0 ? 3 : 0,
                color: AppColors.expense,
                strokeWidth: 1.5,
                strokeColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: AppColors.expense.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Wallet Pie Section ───────────────────────────────────────────────────────

class _WalletPieSection extends StatelessWidget {
  final List<WalletModel> wallets;
  final int touchedIndex;
  final ValueChanged<int> onTouch;
  final String currencySymbol;

  const _WalletPieSection({
    super.key,
    required this.wallets,
    required this.touchedIndex,
    required this.onTouch,
    required this.currencySymbol,
  });

  static const List<Color> _walletColors = [
    Color(0xFF0984E3), // Blue
    Color(0xFF00B894), // Green
    Color(0xFF6C5CE7), // Indigo
    Color(0xFFFDAA3D), // Orange
    Color(0xFFE84393), // Pink
    Color(0xFF00CEC9), // Teal
    Color(0xFFFF7675), // Red
    Color(0xFFFDCB6E), // Yellow
    Color(0xFFE17055), // Burnt Orange
    Color(0xFFA29BFE), // Light Purple
  ];

  @override
  Widget build(BuildContext context) {
    final activeWallets = wallets.where((w) => w.includeInTotal).toList();
    final total = activeWallets.fold(0.0, (s, w) => s + w.balance);

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < activeWallets.length; i++) {
      final isTouched = i == touchedIndex;
      final color = _walletColors[i % _walletColors.length];
      sections.add(PieChartSectionData(
        value: activeWallets[i].balance < 0 ? 0 : activeWallets[i].balance,
        title: '',
        color: color,
        radius: isTouched ? 85 : 80,
      ));
    }

    return Column(
      children: [
        if (activeWallets.isNotEmpty) ...[
          // Donut
          SizedBox(
            width: 180,
            height: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 0,
                    sectionsSpace: 2,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        if (response?.touchedSection != null) {
                          onTouch(
                              response!.touchedSection!.touchedSectionIndex);
                        } else {
                          onTouch(-1);
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        // Legend
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: activeWallets.asMap().entries.map((entry) {
            final i = entry.key;
            final wallet = entry.value;
            final color = _walletColors[i % _walletColors.length];
            final pct = total == 0
                ? 0
                : (wallet.balance < 0 ? 0 : wallet.balance) / total * 100;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      wallet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.titleLarge?.color ??
                            Colors.white,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      CurrencyFormatter.format(wallet.balance,
                          symbol: currencySymbol),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyMedium?.color ??
                            Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${pct.toStringAsFixed(0)}%)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyMedium?.color ??
                          Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Divider(
            height: 1,
            color: Theme.of(context).dividerTheme.color ??
                const Color(0xFFF0F0F0)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Total Balance',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color ??
                      Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                CurrencyFormatter.format(total, symbol: currencySymbol),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Pie Section ──────────────────────────────────────────────────────────────

class _PieSection extends StatelessWidget {
  final Map<String, double> data;
  final int touchedIndex;
  final ValueChanged<int> onTouch;
  final String currencySymbol;
  final double total;
  final bool isExpense;

  const _PieSection({
    required this.data,
    required this.touchedIndex,
    required this.onTouch,
    required this.currencySymbol,
    required this.total,
    this.isExpense = true,
  });

  static const List<Color> _colors = [
    Color(0xFF6C5CE7), // Indigo
    Color(0xFF00B894), // Green
    Color(0xFFFDAA3D), // Yellow/Orange
    Color(0xFF0984E3), // Blue
    Color(0xFFE84393), // Pink
    Color(0xFF00CEC9), // Teal
    Color(0xFFFF7675), // Light Red
    Color(0xFFFDCB6E), // Light Yellow
    Color(0xFFE17055), // Burnt Orange
    Color(0xFFA29BFE), // Light Purple
  ];

  @override
  Widget build(BuildContext context) {
    final entries = data.entries.toList();

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < entries.length; i++) {
      final isTouched = i == touchedIndex;
      final color = _colors[i % _colors.length];
      sections.add(PieChartSectionData(
        value: entries[i].value,
        title: '',
        color: color,
        radius: isTouched ? 85 : 80,
      ));
    }

    return Column(
      children: [
        // Donut
        SizedBox(
          width: 180,
          height: 180,
          child: Stack(
            alignment: Alignment.center,
            children: [
              PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 0,
                  sectionsSpace: 2,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (response?.touchedSection != null) {
                        onTouch(response!.touchedSection!.touchedSectionIndex);
                      } else {
                        onTouch(-1);
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Legend
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.asMap().entries.map((entry) {
            final i = entry.key;
            final name = entry.value.key;
            final val = entry.value.value;
            final pct = val / total * 100;
            final color = _colors[i % _colors.length];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration:
                        BoxDecoration(color: color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Theme.of(context).textTheme.titleLarge?.color ??
                            Colors.white,
                      ),
                    ),
                  ),
                  Flexible(
                    child: Text(
                      CurrencyFormatter.format(val, symbol: currencySymbol),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyMedium?.color ??
                            Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '(${pct.toStringAsFixed(0)}%)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyMedium?.color ??
                          Colors.white,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        Divider(
            height: 1,
            color: Theme.of(context).dividerTheme.color ??
                const Color(0xFFF0F0F0)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                isExpense ? 'Total Expenses' : 'Total Income',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color ??
                      Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                CurrencyFormatter.format(total, symbol: currencySymbol),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isExpense ? AppColors.expense : AppColors.income,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Categories Tab ───────────────────────────────────────────────────────────

class _CategoriesTab extends StatelessWidget {
  const _CategoriesTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final settings = context.watch<SettingsProvider>();
    final now = DateTime.now();

    return FutureBuilder<Map<String, double>>(
      future: provider.getCategoryBreakdown(
          TransactionType.expense, now.year, now.month),
      builder: (ctx, snap) {
        if (!snap.hasData) {
          return Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final data = snap.data!;
        if (data.isEmpty) {
          return Center(
            child: Text('No expense data for this month',
                style: GoogleFonts.poppins(
                    color: Theme.of(context).textTheme.bodyMedium?.color ??
                        Colors.white)),
          );
        }
        final total = data.values.fold(0.0, (s, v) => s + v);
        final entries = data.entries.toList();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          itemCount: entries.length,
          separatorBuilder: (_, __) => Divider(
              height: 1,
              color: Theme.of(context).dividerTheme.color ??
                  const Color(0xFFF5F5F5)),
          itemBuilder: (ctx, i) {
            final name = entries[i].key;
            final val = entries[i].value;
            final pct = val / total * 100;
            final cat = CategoryModel.findByName(name);

            return Container(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cat?.color ?? AppColors.catOther,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        cat?.icon ?? Icons.more_horiz_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.color ??
                                  Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: val / total,
                              backgroundColor: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.darkSurface2
                                  : const Color(0xFFF0F0F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  cat?.color ?? AppColors.catOther),
                              minHeight: 4,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.format(val,
                              symbol: settings.currencySymbol),
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.expense,
                          ),
                        ),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color:
                                Theme.of(context).textTheme.bodyMedium?.color ??
                                    Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ─── Daily Tab ────────────────────────────────────────────────────────────────

class _DailyTab extends StatelessWidget {
  const _DailyTab();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final settings = context.watch<SettingsProvider>();

    final txs = provider.allTransactions;
    final now = DateTime.now();

    // Get all unique days
    final Set<DateTime> uniqueDays = {DateTime(now.year, now.month, now.day)};
    for (final t in txs) {
      uniqueDays.add(DateTime(t.date.year, t.date.month, t.date.day));
    }
    final days = uniqueDays.toList()..sort((a, b) => b.compareTo(a));

    final Map<String, List<DateTime>> groupedDays = {};
    for (final day in days) {
      final monthYear = DateFormat('MMMM yyyy').format(day);
      groupedDays.putIfAbsent(monthYear, () => []).add(day);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Spending (All Time)',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color:
                  Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          ...groupedDays.entries.map((entry) {
            final monthYear = entry.key;
            final monthDays = entry.value;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 8),
                  child: Text(
                    monthYear,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).textTheme.bodyMedium?.color ??
                          Colors.white,
                    ),
                  ),
                ),
                _SectionCard(
                  child: Column(
                    children: monthDays.map((day) {
                      final dayTxs = txs.where((t) {
                        final d =
                            DateTime(t.date.year, t.date.month, t.date.day);
                        return d == day;
                      }).toList();
                      final spent = dayTxs
                          .where((t) => t.isExpense)
                          .fold(0.0, (s, t) => s + t.amount);
                      final earned = dayTxs
                          .where((t) => t.isIncome)
                          .fold(0.0, (s, t) => s + t.amount);
                      final isToday =
                          day == DateTime(now.year, now.month, now.day);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 36,
                              child: Column(
                                children: [
                                  Text(
                                    DateFormat('EEE').format(day),
                                    style: GoogleFonts.poppins(
                                      fontSize: 11,
                                      color: isToday
                                          ? AppColors.primary
                                          : Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.color ??
                                              Colors.white,
                                      fontWeight: isToday
                                          ? FontWeight.w700
                                          : FontWeight.w400,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('d').format(day),
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: isToday
                                          ? AppColors.primary
                                          : Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.color ??
                                              Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (earned > 0)
                                    Text(
                                      '+${CurrencyFormatter.format(earned, symbol: settings.currencySymbol)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.income,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  if (spent > 0)
                                    Text(
                                      '-${CurrencyFormatter.format(spent, symbol: settings.currencySymbol)}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: AppColors.expense,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  if (spent == 0 && earned == 0)
                                    Text(
                                      'No activity',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color ??
                                            Colors.white,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ─── Shared Section Card ──────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Budget Tab ───────────────────────────────────────────────────────────────

class _BudgetTab extends StatefulWidget {
  const _BudgetTab();

  @override
  State<_BudgetTab> createState() => _BudgetTabState();
}

class _BudgetTabState extends State<_BudgetTab> {
  @override
  void initState() {
    super.initState();
    // Ensure budget data is loaded when the tab is first opened (Bug 6 fix).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetProvider>().loadBudgets();
    });
  }

  @override
  Widget build(BuildContext context) {
    final budgetProvider = context.watch<BudgetProvider>();
    final settings = context.watch<SettingsProvider>();
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

    if (budgetProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return budget == null
        ? _NoBudgetView(
            isDark: isDark, textPrimary: textPrimary, textSub: textSub)
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
