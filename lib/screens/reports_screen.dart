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
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _touchedPieIndex = -1;
  DateTime _selectedMonth = DateTime.now();

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Reports',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Month selector
                _MonthSelector(
                  selectedMonth: _selectedMonth,
                  onChanged: (month) =>
                      setState(() => _selectedMonth = month),
                ),
                const SizedBox(height: 20),
                // Income vs Expenses summary
                _IncomeExpenseSummary(
                  provider: provider,
                  month: _selectedMonth,
                ),
                const SizedBox(height: 20),
                // Bar chart
                _BarChartSection(provider: provider),
                const SizedBox(height: 20),
                // Pie chart — Expenses
                _PieChartSection(
                  provider: provider,
                  month: _selectedMonth,
                  type: TransactionType.expense,
                  touchedIndex: _touchedPieIndex,
                  onTouch: (index) =>
                      setState(() => _touchedPieIndex = index),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ─── Month Selector ───────────────────────────────────────────────────────────

class _MonthSelector extends StatelessWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onChanged;

  const _MonthSelector(
      {required this.selectedMonth, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              onChanged(DateTime(
                  selectedMonth.year, selectedMonth.month - 1));
            },
            icon: const Icon(Icons.chevron_left_rounded,
                color: AppColors.primary),
          ),
          Text(
            DateFormat('MMMM yyyy').format(selectedMonth),
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: selectedMonth.month == DateTime.now().month &&
                    selectedMonth.year == DateTime.now().year
                ? null
                : () {
                    onChanged(DateTime(
                        selectedMonth.year, selectedMonth.month + 1));
                  },
            icon: Icon(
              Icons.chevron_right_rounded,
              color: selectedMonth.month == DateTime.now().month &&
                      selectedMonth.year == DateTime.now().year
                  ? AppColors.textHint
                  : AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Income vs Expense Summary ────────────────────────────────────────────────

class _IncomeExpenseSummary extends StatelessWidget {
  final TransactionProvider provider;
  final DateTime month;

  const _IncomeExpenseSummary(
      {required this.provider, required this.month});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final summary = provider.summary;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: 'Income',
            amount: summary.monthlyIncome,
            color: AppColors.income,
            bgColor: AppColors.incomeLight,
            icon: Icons.arrow_downward_rounded,
            currencySymbol: settings.currencySymbol,
            visible: settings.balanceVisible,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: _SummaryCard(
            label: 'Expenses',
            amount: summary.monthlyExpenses,
            color: AppColors.expense,
            bgColor: AppColors.expenseLight,
            icon: Icons.arrow_upward_rounded,
            currencySymbol: settings.currencySymbol,
            visible: settings.balanceVisible,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final Color bgColor;
  final IconData icon;
  final String currencySymbol;
  final bool visible;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.currencySymbol,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  visible
                      ? CurrencyFormatter.format(amount,
                          symbol: currencySymbol)
                      : '••••',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Bar Chart ────────────────────────────────────────────────────────────────

class _BarChartSection extends StatelessWidget {
  final TransactionProvider provider;
  const _BarChartSection({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '6-Month Overview',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Income vs Expenses',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: provider.getLast6MonthsSummary(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 180,
                  child: Center(
                    child: CircularProgressIndicator(
                        color: AppColors.primary, strokeWidth: 2),
                  ),
                );
              }
              final data = _processBarData(snapshot.data!);
              return SizedBox(
                height: 180,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: data.maxY * 1.2,
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        tooltipBgColor:
                            AppColors.textPrimary.withValues(alpha: 0.9),
                        getTooltipItem: (group, groupIndex, rod, rodIndex) {
                          return BarTooltipItem(
                            CurrencyFormatter.formatCompact(rod.toY),
                            GoogleFonts.inter(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          );
                        },
                      ),
                    ),
                    titlesData: FlTitlesData(
                      show: true,
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            if (value.toInt() < data.months.length) {
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  data.months[value.toInt()],
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                          reservedSize: 28,
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 45,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              CurrencyFormatter.formatCompact(value),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: const Color(0xFFF0F0F0),
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    barGroups: data.groups,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Legend(color: AppColors.income, label: 'Income'),
              const SizedBox(width: 20),
              _Legend(color: AppColors.primary, label: 'Expenses'),
            ],
          ),
        ],
      ),
    );
  }

  _BarData _processBarData(List<Map<String, dynamic>> rawData) {
    final now = DateTime.now();
    final months = <String>[];
    final incomeMap = <String, double>{};
    final expenseMap = <String, double>{};

    for (int i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i);
      final key = DateFormat('yyyy-MM').format(d);
      months.add(DateFormat('MMM').format(d));
      incomeMap[key] = 0;
      expenseMap[key] = 0;
    }

    for (final row in rawData) {
      final key = row['month'] as String;
      final type = row['type'] as String;
      final total = (row['total'] as num).toDouble();
      if (type == 'income') {
        incomeMap[key] = total;
      } else {
        expenseMap[key] = total;
      }
    }

    final keys = incomeMap.keys.toList();
    double maxY = 0;
    final groups = <BarChartGroupData>[];

    for (int i = 0; i < keys.length; i++) {
      final inc = incomeMap[keys[i]] ?? 0;
      final exp = expenseMap[keys[i]] ?? 0;
      if (inc > maxY) maxY = inc;
      if (exp > maxY) maxY = exp;
      groups.add(BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: inc,
            color: AppColors.income,
            width: 8,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: exp,
            color: AppColors.primary,
            width: 8,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
        barsSpace: 4,
      ));
    }

    return _BarData(
        months: months,
        groups: groups,
        maxY: maxY == 0 ? 100 : maxY);
  }
}

class _BarData {
  final List<String> months;
  final List<BarChartGroupData> groups;
  final double maxY;
  _BarData({required this.months, required this.groups, required this.maxY});
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 12, color: AppColors.textSecondary)),
      ],
    );
  }
}

// ─── Pie Chart ────────────────────────────────────────────────────────────────

class _PieChartSection extends StatelessWidget {
  final TransactionProvider provider;
  final DateTime month;
  final TransactionType type;
  final int touchedIndex;
  final ValueChanged<int> onTouch;

  const _PieChartSection({
    required this.provider,
    required this.month,
    required this.type,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Expense Breakdown',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          Text(
            DateFormat('MMMM yyyy').format(month),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 20),
          FutureBuilder<Map<String, double>>(
            future: provider.getCategoryBreakdown(type, month.year, month.month),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary, strokeWidth: 2)),
                );
              }
              final data = snapshot.data!;
              if (data.isEmpty) {
                return SizedBox(
                  height: 120,
                  child: Center(
                    child: Text(
                      'No expense data for this month',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                );
              }

              final pieColors = [
                AppColors.catFood,
                AppColors.catTransport,
                AppColors.catBills,
                AppColors.catShopping,
                AppColors.catHealth,
                AppColors.catEducation,
                AppColors.catEntertainment,
                AppColors.catOther,
              ];

              final total =
                  data.values.fold(0.0, (sum, v) => sum + v);
              final entries = data.entries.toList();

              final sections = <PieChartSectionData>[];
              for (int i = 0; i < entries.length; i++) {
                final pct = entries[i].value / total * 100;
                final isTouched = i == touchedIndex;
                final cat = CategoryModel.findByName(entries[i].key);
                final color =
                    cat?.color ?? pieColors[i % pieColors.length];

                sections.add(PieChartSectionData(
                  value: entries[i].value,
                  title: isTouched ? '${pct.toStringAsFixed(1)}%' : '',
                  color: color,
                  radius: isTouched ? 70 : 56,
                  titleStyle: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ));
              }

              return Column(
                children: [
                  SizedBox(
                    height: 200,
                    child: PieChart(
                      PieChartData(
                        sections: sections,
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
                        centerSpaceRadius: 44,
                        sectionsSpace: 2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Legend
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: entries.asMap().entries.map((entry) {
                      final i = entry.key;
                      final cat =
                          CategoryModel.findByName(entry.value.key);
                      final color =
                          cat?.color ?? pieColors[i % pieColors.length];
                      final pct = entry.value.value / total * 100;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${entry.value.key} (${pct.toStringAsFixed(1)}%)',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
