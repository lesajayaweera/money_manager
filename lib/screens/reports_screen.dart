import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../providers/settings_provider.dart';

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
        title: Text(
          'Reports',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
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
                color: const Color(0xFFEEECFD),
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
                unselectedLabelColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                dividerColor: Colors.transparent,
                labelStyle: GoogleFonts.inter(
                    fontSize: 14, fontWeight: FontWeight.w600),
                unselectedLabelStyle:
                    GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'Overview'),
                  Tab(text: 'Categories'),
                  Tab(text: 'Daily'),
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

  const _OverviewTab(
      {required this.touchedIndex, required this.onPieTouch});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  ReportPeriod _selectedPeriod = ReportPeriod.monthly;
  DateTimeRange? _customDateRange;
  int _touchedIncomePieIndex = -1;

  List<TransactionModel> _getFilteredTransactions(List<TransactionModel> allTxs) {
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
      return (t.date.isAfter(start.subtract(const Duration(milliseconds: 1))) || t.date.isAtSameMomentAs(start)) && t.date.isBefore(end);
    }).toList();
  }

  Map<String, double> _getCategoryBreakdown(List<TransactionModel> txs, TransactionType type) {
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
              onSurface: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
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
    } else if (_selectedPeriod == ReportPeriod.custom && _customDateRange == null) {
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
    
    final filteredTxs = _getFilteredTransactions(provider.allTransactions);
    
    double totalIncome = 0;
    double totalExpense = 0;
    for (final tx in filteredTxs) {
      if (tx.isIncome) totalIncome += tx.amount;
      if (tx.isExpense) totalExpense += tx.amount;
    }

    final expenseBreakdown = _getCategoryBreakdown(filteredTxs, TransactionType.expense);
    final incomeBreakdown = _getCategoryBreakdown(filteredTxs, TransactionType.income);

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
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
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
                        onTap: () => setState(() => _selectedPeriod = ReportPeriod.daily),
                      ),
                      const SizedBox(width: 8),
                      _PeriodChip(
                        label: 'Monthly',
                        isSelected: _selectedPeriod == ReportPeriod.monthly,
                        onTap: () => setState(() => _selectedPeriod = ReportPeriod.monthly),
                      ),
                      const SizedBox(width: 8),
                      _PeriodChip(
                        label: 'Annually',
                        isSelected: _selectedPeriod == ReportPeriod.annually,
                        onTap: () => setState(() => _selectedPeriod = ReportPeriod.annually),
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
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
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

          // Category-wise expenses pie chart
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category-wise Expenses',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                if (expenseBreakdown.isEmpty)
                  SizedBox(
                    height: 80,
                    child: Center(
                      child: Text(
                        'No expenses in this period',
                        style: GoogleFonts.inter(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white),
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
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                if (incomeBreakdown.isEmpty)
                  SizedBox(
                    height: 80,
                    child: Center(
                      child: Text(
                        'No income in this period',
                        style: GoogleFonts.inter(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white),
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
          color: isSelected ? AppColors.primary : const Color(0xFFF0F0F0),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
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
                          style: GoogleFonts.inter(
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
                          style: GoogleFonts.inter(
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
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: barWidth,
                      child: Center(
                        child: Text(
                          'Expenses',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
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
      style: GoogleFonts.inter(fontSize: 10, color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white),
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
    AppColors.catFood,
    AppColors.catTransport,
    AppColors.catBills,
    AppColors.catShopping,
    AppColors.catOther,
    AppColors.catHealth,
    AppColors.catFreelance,
    AppColors.catEntertainment,
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
        radius: isTouched ? 28 : 22,
      ));
    }

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Donut
            SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  PieChart(
                    PieChartData(
                      sections: sections,
                      centerSpaceRadius: 42,
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
                  if (touchedIndex >= 0 && touchedIndex < entries.length)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entries[touchedIndex].key,
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(entries[touchedIndex].value,
                                symbol: currencySymbol),
                            style: GoogleFonts.inter(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isExpense ? AppColors.expense : AppColors.income,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            // Legend
            Expanded(
              child: Column(
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
                          decoration: BoxDecoration(
                              color: color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          '${pct.toStringAsFixed(0)}%',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(height: 1, color: Color(0xFFF0F0F0)),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isExpense ? 'Total Expenses' : 'Total Income',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
              ),
            ),
            Text(
              CurrencyFormatter.format(total,
                  symbol: currencySymbol),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isExpense ? AppColors.expense : AppColors.income,
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
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }
        final data = snap.data!;
        if (data.isEmpty) {
          return Center(
            child: Text('No expense data for this month',
                style: GoogleFonts.inter(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white)),
          );
        }
        final total = data.values.fold(0.0, (s, v) => s + v);
        final entries = data.entries.toList();

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          itemCount: entries.length,
          separatorBuilder: (_, __) =>
              const Divider(height: 1, color: Color(0xFFF5F5F5)),
          itemBuilder: (ctx, i) {
            final name = entries[i].key;
            final val = entries[i].value;
            final pct = val / total * 100;
            final cat = CategoryModel.findByName(name);

            return Container(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: cat?.color ?? Colors.white ?? AppColors.catOther,
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
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: val / total,
                              backgroundColor: const Color(0xFFF0F0F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  cat?.color ?? Colors.white ?? AppColors.catOther),
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
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.expense,
                          ),
                        ),
                        Text(
                          '${pct.toStringAsFixed(1)}%',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
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

    // Get last 7 days
    final now = DateTime.now();
    final days = List.generate(7, (i) {
      final d = now.subtract(Duration(days: 6 - i));
      return DateTime(d.year, d.month, d.day);
    });

    final txs = provider.allTransactions;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Spending (Last 7 Days)',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            child: Column(
              children: days.map((day) {
                final dayTxs = txs.where((t) {
                  final d = DateTime(t.date.year, t.date.month, t.date.day);
                  return d == day;
                }).toList();
                final spent = dayTxs
                    .where((t) => t.isExpense)
                    .fold(0.0, (s, t) => s + t.amount);
                final earned = dayTxs
                    .where((t) => t.isIncome)
                    .fold(0.0, (s, t) => s + t.amount);
                final isToday = day == DateTime(now.year, now.month, now.day);

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
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: isToday
                                    ? AppColors.primary
                                    : Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                                fontWeight: isToday
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                            Text(
                              DateFormat('d').format(day),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isToday
                                    ? AppColors.primary
                                    : Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
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
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.income,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (spent > 0)
                              Text(
                                '-${CurrencyFormatter.format(spent, symbol: settings.currencySymbol)}',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: AppColors.expense,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            if (spent == 0 && earned == 0)
                              Text(
                                'No activity',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.white,
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}
