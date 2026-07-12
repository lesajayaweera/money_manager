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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Reports',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
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
                unselectedLabelColor: AppColors.textSecondary,
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

class _OverviewTab extends StatelessWidget {
  final int touchedIndex;
  final ValueChanged<int> onPieTouch;

  const _OverviewTab(
      {required this.touchedIndex, required this.onPieTouch});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final settings = context.watch<SettingsProvider>();
    final now = DateTime.now();
    final summary = provider.summary;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Income vs Expense bar chart
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Income vs Expense (${DateFormat('MMMM yyyy').format(now)})',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 20),
                _SimpleBarChart(
                  income: summary.monthlyIncome,
                  expenses: summary.monthlyExpenses,
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
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<Map<String, double>>(
                  future: provider.getCategoryBreakdown(
                      TransactionType.expense, now.year, now.month),
                  builder: (ctx, snap) {
                    if (!snap.hasData) {
                      return const SizedBox(
                        height: 120,
                        child: Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary, strokeWidth: 2),
                        ),
                      );
                    }
                    final data = snap.data!;
                    if (data.isEmpty) {
                      return SizedBox(
                        height: 80,
                        child: Center(
                          child: Text(
                            'No expenses this month',
                            style: GoogleFonts.inter(
                                color: AppColors.textSecondary),
                          ),
                        ),
                      );
                    }
                    return _PieSection(
                      data: data,
                      touchedIndex: touchedIndex,
                      onTouch: onPieTouch,
                      currencySymbol: settings.currencySymbol,
                      total: summary.monthlyExpenses,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
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
                  _yLabel(y3),
                  _yLabel(y2),
                  _yLabel(y1),
                  _yLabel(0),
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
                            color: AppColors.textSecondary,
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
                            color: AppColors.textSecondary,
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

  Widget _yLabel(double value) {
    String label;
    if (value >= 1000) {
      label = '${(value / 1000).round()}K';
    } else {
      label = value.toInt().toString();
    }
    return Text(
      label,
      style: GoogleFonts.inter(fontSize: 10, color: AppColors.textSecondary),
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

  const _PieSection({
    required this.data,
    required this.touchedIndex,
    required this.onTouch,
    required this.currencySymbol,
    required this.total,
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
        radius: isTouched ? 52 : 44,
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
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 2,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (response?.touchedSection != null) {
                        onTouch(response!
                            .touchedSection!.touchedSectionIndex);
                      } else {
                        onTouch(-1);
                      }
                    },
                  ),
                ),
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
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        Text(
                          '${pct.toStringAsFixed(0)}%',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
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
              'Total Expenses',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              CurrencyFormatter.format(total,
                  symbol: currencySymbol),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.expense,
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
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
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
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: val / total,
                              backgroundColor: const Color(0xFFF0F0F0),
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
                            color: AppColors.textSecondary,
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
              color: AppColors.textPrimary,
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
                                    : AppColors.textSecondary,
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
                                    : AppColors.textPrimary,
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
                                  color: AppColors.textHint,
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
