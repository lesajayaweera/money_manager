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

class OtnScreen extends StatefulWidget {
  const OtnScreen({super.key});

  @override
  State<OtnScreen> createState() => _OtnScreenState();
}

class _OtnScreenState extends State<OtnScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  int _tabIndex = 0;

  void _changeMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  Future<void> _openAdd({WorkLogEntry? existing}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddWorkLogScreen(existing: existing, initialMonth: _month),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAdd(),
        backgroundColor: AppColors.income,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, size: 24),
        label: Text('Add Day',
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w600)),
      ),
      body: Consumer<OtnProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.entries.isEmpty) {
            return Center(
                child:
                    CircularProgressIndicator(color: AppColors.primary));
          }
          return Column(
            children: [
              _buildMonthPicker(context, isDark),
              _buildTabs(isDark),
              Expanded(
                child: IndexedStack(
                  index: _tabIndex,
                  children: [
                    _DashboardTab(
                      stats: provider.statsForMonth(_month.year, _month.month),
                    ),
                    _DailyLogTab(
                      stats: provider.statsForMonth(_month.year, _month.month),
                      entries: provider.entriesForMonth(_month.year, _month.month),
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
              ),
            ],
          );
        },
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Theme.of(context).textTheme.titleLarge?.color),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'OTN Salary',
        style: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.titleLarge?.color,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.tune_rounded,
              color: Theme.of(context).textTheme.bodySmall?.color),
          onPressed: _openSetup,
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  Widget _buildMonthPicker(BuildContext context, bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => _changeMonth(-1),
            icon: Icon(Icons.chevron_left_rounded,
                color: Theme.of(context).textTheme.titleLarge?.color),
          ),
          Text(
            DateFormat('MMMM yyyy').format(_month),
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          IconButton(
            onPressed: () => _changeMonth(1),
            icon: Icon(Icons.chevron_right_rounded,
                color: Theme.of(context).textTheme.titleLarge?.color),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            _tabButton(0, 'Dashboard', isDark),
            _tabButton(1, 'Daily Log', isDark),
            _tabButton(2, 'Pay Preview', isDark),
          ],
        ),
      ),
    );
  }

  Widget _tabButton(int index, String label, bool isDark) {
    final isActive = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? AppColors.darkSurface2 : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? AppColors.primary
                    : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Dashboard Tab ─────────────────────────────────────────────────────────────

class _DashboardTab extends StatelessWidget {
  final OtnMonthStats stats;
  const _DashboardTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final symbol = context.watch<SettingsProvider>().currencySymbol;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatCard(
                label: 'Days Worked',
                value: '${stats.workedDays}',
                icon: Icons.work_rounded,
                color: AppColors.income,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Leave',
                value: '${stats.leaveDays}',
                icon: WorkStatus.leave.icon,
                color: WorkStatus.leave.color,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCard(
                label: 'No Pay',
                value: '${stats.noPayDays}',
                icon: WorkStatus.noPay.icon,
                color: WorkStatus.noPay.color,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Holidays',
                value: '${stats.holidays}',
                icon: WorkStatus.holiday.icon,
                color: WorkStatus.holiday.color,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCard(
                label: 'Hours Worked',
                value: _fmtHours(stats.totalHours),
                icon: Icons.schedule_rounded,
                color: AppColors.budget,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'OT Hours',
                value: _fmtHours(stats.otHours),
                icon: Icons.bolt_rounded,
                color: AppColors.spending,
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _StatCard(
                label: 'Avg / Day',
                value: _fmtHours(stats.averagePerDay),
                icon: Icons.insights_rounded,
                color: AppColors.primary,
                isDark: isDark,
              ),
              const SizedBox(width: 12),
              _StatCard(
                label: 'Standard Day',
                value: '${stats.standardHoursPerDay} hrs',
                icon: Icons.straighten_rounded,
                color: const Color(0xFFA29BFE),
                isDark: isDark,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _WorkedPopulationsCard(stats: stats, symbol: symbol, isDark: isDark),
        ],
      ),
    );
  }

  String _fmtHours(double h) {
    if (h == h.truncateToDouble()) return h.toStringAsFixed(0);
    return h.toStringAsFixed(1);
  }
}

class _WorkedPopulationsCard extends StatelessWidget {
  final OtnMonthStats stats;
  final String symbol;
  final bool isDark;

  const _WorkedPopulationsCard({
    required this.stats,
    required this.symbol,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final worked = stats.workedEntries;
    if (worked.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        width: double.infinity,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(Icons.today_rounded,
                size: 40,
                color: isDark
                    ? AppColors.darkTextHint
                    : AppColors.primary.withOpacity(0.3)),
            const SizedBox(height: 10),
            Text(
              'No worked days yet this month',
              style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).textTheme.titleLarge?.color),
            ),
          ],
        ),
      );
    }

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
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Daily Hours',
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700),
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
                        color: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.color,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (e.hours / max).clamp(0.0, 1.0),
                        minHeight: 6,
                        backgroundColor: isDark
                            ? AppColors.darkDivider
                            : AppColors.primary.withOpacity(0.08),
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
                      '${e.hours.toStringAsFixed(0)} hr',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.color,
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

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Daily Log Tab ─────────────────────────────────────────────────────────────

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
              'Tap "Add Day" to log your work days.',
              style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
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
        borderRadius: BorderRadius.circular(16),
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
                  width: 46,
                  height: 46,
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
                          color: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isWorked
                            ? '${_fmtTime(entry.inTime)} – ${_fmtTime(entry.outTime)} · ${_fmtHours(entry.hours)} hrs'
                            : 'No working hours',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color:
                              Theme.of(context).textTheme.bodySmall?.color,
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

// ─── Pay Preview Tab ──────────────────────────────────────────────────────────

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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Net Pay highlight card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Net Pay — ${DateFormat('MMMM yyyy').format(month)}',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  CurrencyFormatter.format(netPay, symbol: symbol),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${stats.workedDays} worked days · ${_fmtHours(stats.otHours)} OT hrs',
                  style: GoogleFonts.poppins(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
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
              _Row('Overtime (${_fmtHours(stats.otHours)} hrs × rate)', ot,
                  symbol,
                  color: AppColors.primary),
              _Row('Others', others, symbol,
                  color: Theme.of(context).textTheme.titleLarge?.color),
            ],
            total: gross,
            totalLabel: 'Gross Pay',
            symbol: symbol,
          ),

          const SizedBox(height: 12),

          // Deductions
          _SectionCard(
            isDark: isDark,
            title: 'Deductions',
            rows: [
              _Row('Processing', processing, symbol,
                  color: AppColors.expense),
              _Row('EBF1 (8% of basic)', ebf1, symbol,
                  color: AppColors.expense),
              _Row('ETF (3% of basic)', etf, symbol,
                  color: AppColors.expense),
            ],
            total: totalDeductions,
            totalLabel: 'Total Deductions',
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
  final String symbol;

  const _SectionCard({
    required this.isDark,
    required this.title,
    required this.rows,
    required this.total,
    required this.totalLabel,
    required this.symbol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
                fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      r.label,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color:
                              Theme.of(context).textTheme.bodyMedium?.color),
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
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                totalLabel,
                style: GoogleFonts.poppins(
                    fontSize: 13, fontWeight: FontWeight.w700),
              ),
              Text(
                CurrencyFormatter.format(total, symbol: symbol),
                style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary),
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
