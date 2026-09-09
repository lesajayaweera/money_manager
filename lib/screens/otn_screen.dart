import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/otn_models.dart';
import '../providers/otn_provider.dart';
import '../providers/settings_provider.dart';
import 'add_work_log_screen.dart';
import 'otn_setup_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  OtnScreen — main scaffold
// ─────────────────────────────────────────────────────────────────────────────

class OtnScreen extends StatefulWidget {
  const OtnScreen({super.key});

  @override
  State<OtnScreen> createState() => _OtnScreenState();
}

class _OtnScreenState extends State<OtnScreen>
    with SingleTickerProviderStateMixin {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  late final TabController _tabController;

  // Show 6 months ending at current month
  late final List<DateTime> _months;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() {}));

    final now = DateTime.now();
    _months = List.generate(
      6,
      (i) => DateTime(now.year, now.month - 5 + i),
    );
    // Clamp _month to current if it's not in the list
    if (!_months.any((m) => m.year == _month.year && m.month == _month.month)) {
      _month = _months.last;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openAdd({WorkLogEntry? existing, DateTime? forDate}) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: AddWorkLogScreen(
          existing: existing,
          initialMonth: forDate ?? _month,
        ),
      ),
    );
  }

  Future<void> _openSetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const OtnSetupScreen()),
    );
  }

  Future<void> _deleteEntry(WorkLogEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Day?',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Text(
          'Remove the entry for day ${entry.day}?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.primary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            child: Text('Delete',
                style: GoogleFonts.poppins(color: AppColors.expense)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<OtnProvider>().deleteEntry(entry.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAdd(),
        backgroundColor: AppColors.income,
        foregroundColor: Colors.white,
        elevation: 6,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded, size: 28),
      ),
      body: Consumer<OtnProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.entries.isEmpty) {
            return Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          return NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              _buildSliverAppBar(context, provider),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _DashboardTab(
                  stats: provider.statsForMonth(_month.year, _month.month),
                  month: _month,
                  onTapToday: (date) => _openAdd(forDate: date),
                  todayEntry: _todayEntry(provider),
                ),
                _DailyLogTab(
                  stats: provider.statsForMonth(_month.year, _month.month),
                  entries:
                      provider.entriesForMonth(_month.year, _month.month),
                  month: _month,
                  onEdit: (e) => _openAdd(existing: e),
                  onDelete: _deleteEntry,
                ),
                _PayPreviewTab(
                  stats: provider.statsForMonth(_month.year, _month.month),
                  settings: provider.settings,
                  month: _month,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  WorkLogEntry? _todayEntry(OtnProvider provider) {
    final now = DateTime.now();
    final entries = provider.entriesForMonth(now.year, now.month);
    try {
      return entries.firstWhere((e) => e.day == now.day);
    } catch (_) {
      return null;
    }
  }

  SliverAppBar _buildSliverAppBar(
      BuildContext context, OtnProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final symbol = context.watch<SettingsProvider>().currencySymbol;
    final stats = provider.statsForMonth(_month.year, _month.month);
    final basic = provider.settings.basicSalary;
    final ot = stats.otHours * provider.settings.overtimeRatePerHour;
    final others = provider.settings.others;
    final gross = basic + ot + others;
    final processing = provider.settings.processing;
    final ebf1 = basic * 0.08;
    final etf = basic * 0.03;
    final netPay = gross - processing - ebf1 - etf;

    return SliverAppBar(
      pinned: true,
      floating: false,
      expandedHeight: 0,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Theme.of(context).textTheme.titleLarge?.color),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OT & Salary Tracker',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          if (netPay > 0)
            Text(
              'Est. net: $symbol ${_fmtNum(netPay)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.tune_rounded,
              color: Theme.of(context).textTheme.bodySmall?.color),
          onPressed: _openSetup,
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(108),
        child: Column(
          children: [
            _buildMonthChips(isDark),
            _buildTabBar(isDark),
          ],
        ),
      ),
    );
  }

  String _fmtNum(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(0);
  }

  Widget _buildMonthChips(bool isDark) {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: _months.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final m = _months[i];
          final isActive =
              m.year == _month.year && m.month == _month.month;
          return GestureDetector(
            onTap: () => setState(() => _month = m),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? AppColors.income
                    : (isDark
                        ? AppColors.darkSurface
                        : Colors.white),
                borderRadius: BorderRadius.circular(50),
                border: Border.all(
                  color: isActive
                      ? AppColors.income
                      : (isDark
                          ? AppColors.darkDivider
                          : Colors.grey.shade300),
                  width: 1.5,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: AppColors.income.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                DateFormat("MMM ''yy").format(m),
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    final labels = ['Overview', 'Daily Log', 'Pay Preview'];
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: List.generate(labels.length, (i) {
          final isActive = _tabController.index == i;
          return Expanded(
            child: GestureDetector(
              onTap: () {
                _tabController.animateTo(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color:
                          isActive ? AppColors.income : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                ),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isActive
                        ? AppColors.income
                        : (isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Dashboard Tab
// ─────────────────────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final OtnMonthStats stats;
  final DateTime month;
  final void Function(DateTime) onTapToday;
  final WorkLogEntry? todayEntry;

  const _DashboardTab({
    required this.stats,
    required this.month,
    required this.onTapToday,
    required this.todayEntry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final isCurrentMonth =
        month.year == now.year && month.month == now.month;
    final daysInMonth =
        DateUtils.getDaysInMonth(month.year, month.month);
    final loggedDays = stats.workedDays +
        stats.leaveDays +
        stats.noPayDays +
        stats.holidays;
    final unlogged = daysInMonth - loggedDays;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 1. Hero Stats Card ──────────────────────────────────────────
          _HeroStatsCard(
            stats: stats,
            month: month,
            daysInMonth: daysInMonth,
            loggedDays: loggedDays,
            unlogged: unlogged,
            isDark: isDark,
          ),

          const SizedBox(height: 12),

          // ── 2. Today Card (only in current month) ──────────────────────
          if (isCurrentMonth)
            _TodayCard(
              now: now,
              todayEntry: todayEntry,
              isDark: isDark,
              onTap: () => onTapToday(now),
            ),

          if (isCurrentMonth) const SizedBox(height: 12),

          // ── 3. Day Breakdown Card ───────────────────────────────────────
          _DayBreakdownCard(
            stats: stats,
            isDark: isDark,
          ),

          const SizedBox(height: 12),

          // ── 4. Hours Summary Card ───────────────────────────────────────
          _HoursSummaryCard(
            stats: stats,
            isDark: isDark,
          ),

          const SizedBox(height: 12),

          // ── 5. Daily Hours Bar Chart ────────────────────────────────────
          if (stats.workedEntries.isNotEmpty)
            _WorkedPopulationsCard(
                stats: stats, isDark: isDark),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Hero Stats Card
// ─────────────────────────────────────────────────────────────────────────────

class _HeroStatsCard extends StatelessWidget {
  final OtnMonthStats stats;
  final DateTime month;
  final int daysInMonth;
  final int loggedDays;
  final int unlogged;
  final bool isDark;

  const _HeroStatsCard({
    required this.stats,
    required this.month,
    required this.daysInMonth,
    required this.loggedDays,
    required this.unlogged,
    required this.isDark,
  });

  String _fmtHours(double h) =>
      h == h.truncateToDouble() ? '${h.toStringAsFixed(0)}h' : '${h.toStringAsFixed(1)}h';

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMMM yyyy').format(month),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$loggedDays of $daysInMonth days logged · $unlogged unlogged',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _BigStat(
                    value: '${stats.workedDays}',
                    label: 'Days worked',
                    color: AppColors.income,
                    isDark: isDark,
                  ),
                ),
                VerticalDivider(
                  color: isDark
                      ? AppColors.darkDivider
                      : Colors.grey.shade200,
                  thickness: 1,
                  width: 40,
                ),
                Expanded(
                  child: _BigStat(
                    value: _fmtHours(stats.otHours),
                    label: 'OT hours',
                    color: AppColors.spending,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _BigStat({
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).textTheme.titleLarge?.color,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Today Card
// ─────────────────────────────────────────────────────────────────────────────

class _TodayCard extends StatelessWidget {
  final DateTime now;
  final WorkLogEntry? todayEntry;
  final bool isDark;
  final VoidCallback onTap;

  const _TodayCard({
    required this.now,
    required this.todayEntry,
    required this.isDark,
    required this.onTap,
  });

  String _fmtTime(String? t) {
    if (t == null || t.isEmpty) return '--:--';
    final parts = t.split(':');
    if (parts.length != 2) return t;
    final hour = int.tryParse(parts[0]) ?? 0;
    final min = int.tryParse(parts[1]) ?? 0;
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${min.toString().padLeft(2, '0')} $period';
  }

  @override
  Widget build(BuildContext context) {
    final entry = todayEntry;
    final weekday = DateFormat('EEE').format(now);
    final day = now.day;
    final hasEntry = entry != null;
    final isWorked =
        hasEntry && entry.status == WorkStatus.worked;

    final statusColor = hasEntry ? entry.status.color : AppColors.textHint;
    final statusLabel = hasEntry ? entry.status.label : 'Not logged';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Date chip
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.darkSurface2
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'TODAY  $weekday $day',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              Theme.of(context).textTheme.bodySmall?.color,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            statusLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      isWorked
                          ? '${_fmtTime(entry?.inTime)}  →  ${_fmtTime(entry?.outTime)}'
                          : '--:--  →  --:--',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color:
                            Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Text(
              hasEntry ? 'Tap to edit' : 'Tap to log',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.income,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.chevron_right_rounded,
                color: AppColors.income, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Day Breakdown Card
// ─────────────────────────────────────────────────────────────────────────────

class _DayBreakdownCard extends StatelessWidget {
  final OtnMonthStats stats;
  final bool isDark;

  const _DayBreakdownCard({required this.stats, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final total = stats.workedDays +
        stats.leaveDays +
        stats.noPayDays +
        stats.holidays;

    final segments = [
      _Segment(count: stats.workedDays, color: AppColors.income),
      _Segment(count: stats.leaveDays, color: const Color(0xFFFDAA3D)),
      _Segment(count: stats.noPayDays, color: AppColors.expense),
      _Segment(count: stats.holidays, color: AppColors.budget),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day breakdown',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 14),

          // Segmented bar
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 10,
              child: total == 0
                  ? Container(
                      color: isDark
                          ? AppColors.darkDivider
                          : Colors.grey.shade200,
                    )
                  : Row(
                      children: segments
                          .where((s) => s.count > 0)
                          .map((s) => Flexible(
                                flex: s.count,
                                child: Container(
                                  color: s.color,
                                ),
                              ))
                          .toList(),
                    ),
            ),
          ),

          const SizedBox(height: 16),

          // Legend rows
          Row(
            children: [
              Expanded(
                child: _LegendItem(
                  color: AppColors.income,
                  label: 'Worked',
                  count: stats.workedDays,
                ),
              ),
              Expanded(
                child: _LegendItem(
                  color: const Color(0xFFFDAA3D),
                  label: 'Leave',
                  count: stats.leaveDays,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _LegendItem(
                  color: AppColors.expense,
                  label: 'No Pay',
                  count: stats.noPayDays,
                ),
              ),
              Expanded(
                child: _LegendItem(
                  color: AppColors.budget,
                  label: 'Holiday',
                  count: stats.holidays,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Segment {
  final int count;
  final Color color;
  const _Segment({required this.count, required this.color});
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final int count;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        const Spacer(),
        Text(
          '$count',
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Hours Summary Card
// ─────────────────────────────────────────────────────────────────────────────

class _HoursSummaryCard extends StatelessWidget {
  final OtnMonthStats stats;
  final bool isDark;

  const _HoursSummaryCard({required this.stats, required this.isDark});

  String _fmtH(double h) =>
      '${h == h.truncateToDouble() ? h.toStringAsFixed(0) : h.toStringAsFixed(1)}h';

  @override
  Widget build(BuildContext context) {
    final rows = [
      _HourRow(
          label: 'Total worked hours', value: _fmtH(stats.totalHours)),
      _HourRow(label: 'Total OT hours', value: _fmtH(stats.otHours)),
      _HourRow(
          label: 'Avg per worked day', value: _fmtH(stats.averagePerDay)),
      _HourRow(
          label: 'Standard day',
          value: '${stats.standardHoursPerDay}h',
          isLast: true),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hours',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 12),
          ...rows.map((r) => _HourRowWidget(row: r, isDark: isDark)),
        ],
      ),
    );
  }
}

class _HourRow {
  final String label;
  final String value;
  final bool isLast;
  const _HourRow({required this.label, required this.value, this.isLast = false});
}

class _HourRowWidget extends StatelessWidget {
  final _HourRow row;
  final bool isDark;

  const _HourRowWidget({required this.row, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  row.label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
              ),
              Text(
                row.value,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
            ],
          ),
        ),
        if (!row.isLast)
          Divider(
            height: 1,
            color: isDark ? AppColors.darkDivider : Colors.grey.shade100,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Worked Populations Card (daily bar chart)
// ─────────────────────────────────────────────────────────────────────────────

class _WorkedPopulationsCard extends StatelessWidget {
  final OtnMonthStats stats;
  final bool isDark;

  const _WorkedPopulationsCard({
    required this.stats,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final worked = stats.workedEntries;
    if (worked.isEmpty) return const SizedBox.shrink();

    double max = 0;
    for (final e in worked) {
      if (e.hours > max) max = e.hours;
    }
    if (max <= 0) max = 1;

    return Container(
      padding: const EdgeInsets.all(18),
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Hours',
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color),
          ),
          const SizedBox(height: 14),
          for (final e in worked)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 42,
                    child: Text(
                      'D${e.day}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: (e.hours / max).clamp(0.0, 1.0),
                        minHeight: 7,
                        backgroundColor: isDark
                            ? AppColors.darkDivider
                            : AppColors.income.withOpacity(0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          e.hours > stats.standardHoursPerDay
                              ? AppColors.spending
                              : AppColors.income,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 48,
                    child: Text(
                      '${e.hours.toStringAsFixed(1)}h',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Daily Log Tab
// ─────────────────────────────────────────────────────────────────────────────

class _DailyLogTab extends StatelessWidget {
  final OtnMonthStats stats;
  final List<WorkLogEntry> entries;
  final DateTime month;
  final void Function(WorkLogEntry) onEdit;
  final void Function(WorkLogEntry) onDelete;

  const _DailyLogTab({
    required this.stats,
    required this.entries,
    required this.month,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (entries.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note_rounded,
                size: 56,
                color: isDark
                    ? AppColors.darkTextHint
                    : AppColors.primary.withOpacity(0.3)),
            const SizedBox(height: 16),
            Text(
              'No entries for this month',
              style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.titleLarge?.color),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap "+" to log your work days.',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: entries.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        if (i == 0) {
          return _LogSummaryHeader(
            workedDays: stats.workedDays,
            totalDays: entries.length,
            isDark: isDark,
          );
        }
        final e = entries[i - 1];
        return _LogRow(
          entry: e,
          isDark: isDark,
          onEdit: () => onEdit(e),
          onDelete: () => onDelete(e),
        );
      },
    );
  }
}

class _LogSummaryHeader extends StatelessWidget {
  final int workedDays;
  final int totalDays;
  final bool isDark;

  const _LogSummaryHeader({
    required this.workedDays,
    required this.totalDays,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.work_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$workedDays',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'days worked of $totalDays logged',
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.85),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final WorkLogEntry entry;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _LogRow({
    required this.entry,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final status = entry.status;
    final isWorked = status == WorkStatus.worked;
    final weekday = DateFormat('EEE').format(entry.date);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.15 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: status.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${entry.day}',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: status.color,
                        ),
                      ),
                      Text(
                        weekday,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: status.color,
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
                      Text(
                        status.label,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).textTheme.titleLarge?.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isWorked
                            ? '${_fmtTime(entry.inTime)} – ${_fmtTime(entry.outTime)} · ${_fmtHours(entry.hours)}h'
                            : 'No working hours',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                      size: 20),
                  color: isDark ? AppColors.darkSurface2 : Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onSelected: (v) {
                    if (v == 'edit') onEdit();
                    if (v == 'delete') onDelete();
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [
                        Icon(Icons.edit_rounded,
                            size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Edit', style: GoogleFonts.poppins(fontSize: 13)),
                      ]),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [
                        Icon(Icons.delete_outline_rounded,
                            size: 16, color: AppColors.expense),
                        const SizedBox(width: 8),
                        Text('Delete',
                            style: GoogleFonts.poppins(
                                fontSize: 13, color: AppColors.expense)),
                      ]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _fmtTime(String? t) {
    if (t == null) return '–';
    final parts = t.split(':');
    if (parts.length != 2) return t;
    final hour = int.tryParse(parts[0]) ?? 0;
    final min = int.tryParse(parts[1]) ?? 0;
    final period = hour >= 12 ? 'PM' : 'AM';
    final h = hour % 12 == 0 ? 12 : hour % 12;
    return '$h:${min.toString().padLeft(2, '0')} $period';
  }

  String _fmtHours(double h) =>
      h == h.truncateToDouble() ? h.toStringAsFixed(0) : h.toStringAsFixed(1);
}

// ─────────────────────────────────────────────────────────────────────────────
//  Pay Preview Tab
// ─────────────────────────────────────────────────────────────────────────────

class _PayPreviewTab extends StatelessWidget {
  final OtnMonthStats stats;
  final OtnSettings settings;
  final DateTime month;

  const _PayPreviewTab({
    required this.stats,
    required this.settings,
    required this.month,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final symbol = context.watch<SettingsProvider>().currencySymbol;

    final basic = settings.basicSalary;
    final ot = stats.otHours * settings.overtimeRatePerHour;
    final others = settings.others;
    final gross = basic + ot + others;
    final processing = settings.processing;
    final ebf1 = basic * 0.08;
    final etf = basic * 0.03;
    final totalDeductions = processing + ebf1 + etf;
    final netPay = gross - totalDeductions;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Net Pay hero card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.income, const Color(0xFF00CBA9)],
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.income.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.account_balance_wallet_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Net Pay',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  CurrencyFormatter.format(netPay, symbol: symbol),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${stats.workedDays} worked days  ·  ${_fmtHours(stats.otHours)}h OT',
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Earnings
          _SectionCard(
            isDark: isDark,
            title: 'Earnings',
            rows: [
              _Row('Basic Salary', basic, symbol,
                  color: Theme.of(context).textTheme.titleLarge?.color),
              _Row('Overtime (${_fmtHours(stats.otHours)}h × rate)', ot,
                  symbol,
                  color: AppColors.income),
              _Row('Others', others, symbol,
                  color: Theme.of(context).textTheme.titleLarge?.color),
            ],
            total: gross,
            totalLabel: 'Gross Pay',
            totalColor: AppColors.income,
            symbol: symbol,
          ),

          const SizedBox(height: 12),

          // Deductions
          _SectionCard(
            isDark: isDark,
            title: 'Deductions',
            rows: [
              _Row('Processing', processing, symbol, color: AppColors.expense),
              _Row('EBF1 (8% of basic)', ebf1, symbol,
                  color: AppColors.expense),
              _Row('ETF (3% of basic)', etf, symbol, color: AppColors.expense),
            ],
            total: totalDeductions,
            totalLabel: 'Total Deductions',
            totalColor: AppColors.expense,
            symbol: symbol,
          ),
        ],
      ),
    );
  }

  String _fmtHours(double h) =>
      h == h.truncateToDouble() ? h.toStringAsFixed(0) : h.toStringAsFixed(1);
}

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final List<_Row> rows;
  final double total;
  final String totalLabel;
  final Color? totalColor;
  final String symbol;

  const _SectionCard({
    required this.isDark,
    required this.title,
    required this.rows,
    required this.total,
    required this.totalLabel,
    this.totalColor,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 16,
                decoration: BoxDecoration(
                  color: totalColor ?? AppColors.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.titleLarge?.color),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      r.label,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.color),
                    ),
                  ),
                  Text(
                    CurrencyFormatter.format(r.amount, symbol: symbol),
                    style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: r.color),
                  ),
                ],
              ),
            ),
          Divider(
              height: 20,
              color: isDark ? AppColors.darkDivider : Colors.grey.shade100),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalLabel,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: Theme.of(context).textTheme.titleLarge?.color),
              ),
              Text(
                CurrencyFormatter.format(total, symbol: symbol),
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: totalColor ?? AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Row {
  final String label;
  final double amount;
  final String symbol;
  final Color? color;

  const _Row(this.label, this.amount, this.symbol, {this.color});
}
