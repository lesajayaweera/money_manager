import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/transaction_model.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';

class MonthComparisonScreen extends StatefulWidget {
  const MonthComparisonScreen({super.key});

  @override
  State<MonthComparisonScreen> createState() => _MonthComparisonScreenState();
}

class _MonthComparisonScreenState extends State<MonthComparisonScreen> {
  DateTime _monthA = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _monthB =
      DateTime(DateTime.now().year, DateTime.now().month - 1, 1);

  Future<void> _pickMonth(bool isFirst) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isFirst ? _monthA : _monthB,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: isFirst ? 'Select First Month' : 'Select Second Month',
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
        if (isFirst) {
          _monthA = DateTime(picked.year, picked.month, 1);
        } else {
          _monthB = DateTime(picked.year, picked.month, 1);
        }
      });
    }
  }

  List<TransactionModel> _txsInMonth(
      List<TransactionModel> all, DateTime month) {
    final start = month;
    final end = DateTime(month.year, month.month + 1, 1);
    return all
        .where((t) =>
            t.date.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
            t.date.isBefore(end))
        .toList();
  }

  ({double income, double expense}) _sum(List<TransactionModel> txs) {
    double inc = 0, exp = 0;
    for (final t in txs) {
      if (t.isIncome) inc += t.amount;
      if (t.isExpense) exp += t.amount;
    }
    return (income: inc, expense: exp);
  }

  Map<String, double> _categoryBreakdown(
      List<TransactionModel> txs, TransactionType type) {
    final map = <String, double>{};
    for (final t in txs) {
      if (t.type == type) {
        map[t.category] = (map[t.category] ?? 0) + t.amount;
      }
    }
    final sorted = map.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final settings = context.watch<SettingsProvider>();
    final symbol = settings.currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        Theme.of(context).textTheme.titleLarge?.color ?? Colors.white;
    final textSub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final dividerColor =
        Theme.of(context).dividerTheme.color ?? const Color(0xFFF0F0F0);

    final txsA = _txsInMonth(provider.allTransactions, _monthA);
    final txsB = _txsInMonth(provider.allTransactions, _monthB);
    final sumA = _sum(txsA);
    final sumB = _sum(txsB);

    final expensesA =
        _categoryBreakdown(txsA, TransactionType.expense);
    final expensesB =
        _categoryBreakdown(txsB, TransactionType.expense);

    final allCats = <String>{
      ...expensesA.keys,
      ...expensesB.keys,
    }.toList();

    final netA = sumA.income - sumA.expense;
    final netB = sumB.income - sumB.expense;

    double pctChange(double current, double previous) {
      if (previous == 0) {
        if (current == 0) return 0;
        return current > 0 ? 100 : -100;
      }
      return ((current - previous) / previous.abs()) * 100;
    }

    final expenseChange = pctChange(sumA.expense, sumB.expense);
    final incomeChange = pctChange(sumA.income, sumB.income);
    final netChange = pctChange(netA, netB);

    Widget changeBadge(double change, {bool invert = false}) {
      final isUp = change > 0;
      final isDown = change < 0;
      final Color color;
      if (invert) {
        color = isUp
            ? AppColors.expense
            : isDown
                ? AppColors.income
                : textSub;
      } else {
        color =
            isUp ? AppColors.income : isDown ? AppColors.expense : textSub;
      }
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '${isUp ? '▲' : isDown ? '▼' : '●'} ${change.abs().toStringAsFixed(1)}%',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Month Comparison',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          // ── Month Selectors ──────────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _MonthSelectorCard(
                  label: 'Month A',
                  month: _monthA,
                  onTap: () => _pickMonth(true),
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSub: textSub,
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MonthSelectorCard(
                  label: 'Month B',
                  month: _monthB,
                  onTap: () => _pickMonth(false),
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSub: textSub,
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ── Income vs Expense Bar Chart ──────────────────────────────────
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Income vs Expense',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${DateFormat('MMM yyyy').format(_monthA)}  vs  '
                  '${DateFormat('MMM yyyy').format(_monthB)}',
                  style: GoogleFonts.poppins(fontSize: 12, color: textSub),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 220,
                  child: BarChart(
                    BarChartData(
                      maxY: _niceMax([
                        sumA.income,
                        sumA.expense,
                        sumB.income,
                        sumB.expense,
                      ]),
                      alignment: BarChartAlignment.spaceAround,
                      barTouchData: BarTouchData(
                        enabled: true,
                        touchTooltipData: BarTouchTooltipData(
                          tooltipBgColor: isDark
                              ? AppColors.darkSurface2
                              : Colors.white,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final labels = [
                              '${DateFormat('MMM').format(_monthA)} Income',
                              '${DateFormat('MMM').format(_monthA)} Expense',
                              '${DateFormat('MMM').format(_monthB)} Income',
                              '${DateFormat('MMM').format(_monthB)} Expense',
                            ];
                            final values = [
                              sumA.income,
                              sumA.expense,
                              sumB.income,
                              sumB.expense,
                            ];
                            return BarTooltipItem(
                              '${labels[groupIndex]}\n'
                              '${CurrencyFormatter.format(values[groupIndex], symbol: symbol)}',
                              GoogleFonts.poppins(
                                fontSize: 12,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            );
                          },
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 48,
                            getTitlesWidget: (value, meta) {
                              if (value == meta.max) return const SizedBox();
                              return Text(
                                CurrencyFormatter.formatCompact(value,
                                        symbol: '')
                                    .trim(),
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  color: textSub,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            getTitlesWidget: (value, meta) {
                              final labels = [
                                'Inc\n${DateFormat('MMM').format(_monthA)}',
                                'Exp\n${DateFormat('MMM').format(_monthA)}',
                                'Inc\n${DateFormat('MMM').format(_monthB)}',
                                'Exp\n${DateFormat('MMM').format(_monthB)}',
                              ];
                              if (value.toInt() < 0 ||
                                  value.toInt() >= labels.length) {
                                return const SizedBox();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  labels[value.toInt()],
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    color: textSub,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      ),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 20,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: dividerColor.withValues(alpha: 0.4),
                          strokeWidth: 1,
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        BarChartGroupData(x: 0, barsSpace: 4, barRods: [
                          BarChartRodData(
                            toY: sumA.income,
                            color: AppColors.income,
                            width: 12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ]),
                        BarChartGroupData(x: 1, barsSpace: 4, barRods: [
                          BarChartRodData(
                            toY: sumA.expense,
                            color: AppColors.expense,
                            width: 12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ]),
                        BarChartGroupData(x: 2, barsSpace: 4, barRods: [
                          BarChartRodData(
                            toY: sumB.income,
                            color: AppColors.income.withValues(alpha: 0.45),
                            width: 12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ]),
                        BarChartGroupData(x: 3, barsSpace: 4, barRods: [
                          BarChartRodData(
                            toY: sumB.expense,
                            color: AppColors.expense.withValues(alpha: 0.45),
                            width: 12,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Comparison Summary Cards ─────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Income',
                  monthALabel: DateFormat('MMM').format(_monthA),
                  monthBLabel: DateFormat('MMM').format(_monthB),
                  valueA: sumA.income,
                  valueB: sumB.income,
                  change: incomeChange,
                  color: AppColors.income,
                  symbol: symbol,
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSub: textSub,
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Expense',
                  monthALabel: DateFormat('MMM').format(_monthA),
                  monthBLabel: DateFormat('MMM').format(_monthB),
                  valueA: sumA.expense,
                  valueB: sumB.expense,
                  change: expenseChange,
                  color: AppColors.expense,
                  symbol: symbol,
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSub: textSub,
                  surfaceColor: surfaceColor,
                  dividerColor: dividerColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Net Savings Card ─────────────────────────────────────────────
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.savings_rounded,
                        color: netA >= 0 ? AppColors.income : AppColors.expense,
                        size: 22),
                    const SizedBox(width: 8),
                    Text(
                      'Net Savings',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const Spacer(),
                    changeBadge(netChange),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _NetRow(
                        label: DateFormat('MMM yyyy').format(_monthA),
                        amount: netA,
                        symbol: symbol,
                        textPrimary: textPrimary,
                        textSub: textSub,
                      ),
                    ),
                    Container(width: 1, height: 36, color: dividerColor),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _NetRow(
                        label: DateFormat('MMM yyyy').format(_monthB),
                        amount: netB,
                        symbol: symbol,
                        textPrimary: textPrimary,
                        textSub: textSub,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── Category Comparison Table ────────────────────────────────────
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Category Breakdown',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${DateFormat('MMM yyyy').format(_monthA)}  vs  '
                  '${DateFormat('MMM yyyy').format(_monthB)}',
                  style: GoogleFonts.poppins(fontSize: 12, color: textSub),
                ),
                const SizedBox(height: 16),
                if (allCats.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(
                      child: Text(
                        'No expense data in selected months',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: textSub),
                      ),
                    ),
                  )
                else
                  ...allCats.map((cat) {
                    final aVal = expensesA[cat] ?? 0;
                    final bVal = expensesB[cat] ?? 0;
                    final catChange = pctChange(aVal, bVal);
                    final maxVal =
                        [aVal, bVal, 1.0].reduce((a, b) => a > b ? a : b);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  cat,
                                  style: GoogleFonts.poppins(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textPrimary,
                                  ),
                                ),
                              ),
                              changeBadge(catChange, invert: true),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: aVal / maxVal,
                                        minHeight: 6,
                                        backgroundColor: dividerColor,
                                        valueColor: const AlwaysStoppedAnimation(
                                            AppColors.expense),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${DateFormat('MMM').format(_monthA)}: '
                                      '${CurrencyFormatter.format(aVal, symbol: symbol)}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 11, color: textSub),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: bVal / maxVal,
                                        minHeight: 6,
                                        backgroundColor: dividerColor,
                                        valueColor: AlwaysStoppedAnimation(
                                            AppColors.expense
                                                .withValues(alpha: 0.45)),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${DateFormat('MMM').format(_monthB)}: '
                                      '${CurrencyFormatter.format(bVal, symbol: symbol)}',
                                      style: GoogleFonts.poppins(
                                          fontSize: 11, color: textSub),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _niceMax(List<double> values) {
    if (values.isEmpty) return 100;
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    if (maxValue <= 0) return 100;
    final magnitude = maxValue.toStringAsFixed(0).length - 1;
    final step = math.pow(10, magnitude).toDouble();
    return ((maxValue / step).ceil() + 1) * step;
  }
}

class _MonthSelectorCard extends StatelessWidget {
  final String label;
  final DateTime month;
  final VoidCallback onTap;
  final bool isDark;
  final Color textPrimary;
  final Color textSub;
  final Color surfaceColor;
  final Color dividerColor;

  const _MonthSelectorCard({
    required this.label,
    required this.month,
    required this.onTap,
    required this.isDark,
    required this.textPrimary,
    required this.textSub,
    required this.surfaceColor,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: dividerColor.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textSub,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_month_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  DateFormat('MMM yyyy').format(month),
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;

  const _SectionCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: (Theme.of(context).dividerTheme.color ?? const Color(0xFFF0F0F0))
              .withValues(alpha: 0.5),
        ),
      ),
      child: child,
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String monthALabel;
  final String monthBLabel;
  final double valueA;
  final double valueB;
  final double change;
  final Color color;
  final String symbol;
  final bool isDark;
  final Color textPrimary;
  final Color textSub;
  final Color surfaceColor;
  final Color dividerColor;

  const _MetricCard({
    required this.label,
    required this.monthALabel,
    required this.monthBLabel,
    required this.valueA,
    required this.valueB,
    required this.change,
    required this.color,
    required this.symbol,
    required this.isDark,
    required this.textPrimary,
    required this.textSub,
    required this.surfaceColor,
    required this.dividerColor,
  });

  @override
  Widget build(BuildContext context) {
    final isUp = change > 0;
    final isDown = change < 0;
    final badgeColor =
        isUp ? AppColors.income : isDown ? AppColors.expense : textSub;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: dividerColor.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: color, size: 10),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSub,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${isUp ? '▲' : isDown ? '▼' : ''} '
                  '${change.abs().toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            CurrencyFormatter.format(valueA, symbol: symbol),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            monthALabel,
            style: GoogleFonts.poppins(fontSize: 10, color: textSub),
          ),
          const SizedBox(height: 8),
          Container(height: 1, color: dividerColor),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(valueB, symbol: symbol),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textSub,
            ),
          ),
          Text(
            monthBLabel,
            style: GoogleFonts.poppins(fontSize: 10, color: textSub),
          ),
        ],
      ),
    );
  }
}

class _NetRow extends StatelessWidget {
  final String label;
  final double amount;
  final String symbol;
  final Color textPrimary;
  final Color textSub;

  const _NetRow({
    required this.label,
    required this.amount,
    required this.symbol,
    required this.textPrimary,
    required this.textSub,
  });

  @override
  Widget build(BuildContext context) {
    final color = amount >= 0 ? AppColors.income : AppColors.expense;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 11, color: textSub),
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.formatWithSign(amount, symbol: symbol),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}