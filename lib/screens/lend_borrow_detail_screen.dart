import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/lend_borrow_model.dart';
import '../providers/lend_borrow_provider.dart';
import '../providers/settings_provider.dart';
import 'add_lend_borrow_screen.dart';

class LendBorrowDetailScreen extends StatefulWidget {
  final LendBorrowModel entry;

  const LendBorrowDetailScreen({super.key, required this.entry});

  @override
  State<LendBorrowDetailScreen> createState() =>
      _LendBorrowDetailScreenState();
}

class _LendBorrowDetailScreenState extends State<LendBorrowDetailScreen> {
  late LendBorrowModel _entry;
  bool _isMarkingSettled = false;

  @override
  void initState() {
    super.initState();
    _entry = widget.entry;
  }

  // ─── Mark as Settled ─────────────────────────────────────────────────────────
  Future<void> _markAsSettled() async {
    if (_entry.status == LendBorrowStatus.paid) return;
    setState(() => _isMarkingSettled = true);
    try {
      final updated = _entry.copyWith(status: LendBorrowStatus.paid);
      await context.read<LendBorrowProvider>().updateEntry(updated);
      setState(() {
        _entry = updated;
        _isMarkingSettled = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Marked as settled!',
              style: GoogleFonts.inter(fontSize: 14),
            ),
            backgroundColor: AppColors.income,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    } catch (e) {
      setState(() => _isMarkingSettled = false);
    }
  }

  // ─── Send Reminder ────────────────────────────────────────────────────────────
  void _sendReminder() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Reminder Sent',
          style: GoogleFonts.inter(
              fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'A reminder has been sent to ${_entry.personName}.',
          style: GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'OK',
              style: GoogleFonts.inter(
                  color: AppColors.primary, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Options menu ─────────────────────────────────────────────────────────────
  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.edit_outlined,
                      color: AppColors.primary, size: 18),
                ),
                title: Text('Edit Entry',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) =>
                          AddLendBorrowScreen(editEntry: _entry),
                    ),
                  );
                  if (result == true && mounted) {
                    // Reload from provider
                    final provider = context.read<LendBorrowProvider>();
                    await provider.loadEntries();
                    final updated = provider.entries.firstWhere(
                      (e) => e.id == _entry.id,
                      orElse: () => _entry,
                    );
                    setState(() => _entry = updated);
                  }
                },
              ),
              ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.expenseLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: AppColors.expense, size: 18),
                ),
                title: Text('Delete Entry',
                    style: GoogleFonts.inter(
                        color: AppColors.expense,
                        fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      title: Text('Delete Entry',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700)),
                      content: Text(
                        'Delete entry for "${_entry.personName}"? This cannot be undone.',
                        style: GoogleFonts.inter(),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('Delete',
                              style: GoogleFonts.inter(
                                  color: AppColors.expense)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    await context
                        .read<LendBorrowProvider>()
                        .deleteEntry(_entry.id!);
                    if (mounted) Navigator.pop(context);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isLent = _entry.isLent;
    final isSettled = _entry.status == LendBorrowStatus.paid;

    // Avatar
    final initials =
        _entry.personName.isNotEmpty ? _entry.personName[0].toUpperCase() : '?';
    const colors = [
      AppColors.primary,
      AppColors.income,
      AppColors.expense,
      AppColors.budget,
      AppColors.spending,
    ];
    final avatarColor = colors[initials.codeUnitAt(0) % colors.length];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Entry Details',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textPrimary),
            onPressed: _showOptions,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Person header card ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
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
                children: [
                  Row(
                    children: [
                      // Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: avatarColor,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Name + type
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _entry.personName,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isLent ? 'Lent to' : 'Borrowed from',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status badge
                      _StatusBadge(status: _entry.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Amount
                  Text(
                    CurrencyFormatter.format(_entry.amount,
                        symbol: settings.currencySymbol),
                    style: GoogleFonts.inter(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Details card ──────────────────────────────────────────────────
            Container(
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
                children: [
                  _DetailRow(
                    icon: Icons.timer_outlined,
                    iconColor: AppColors.textSecondary,
                    label: 'Type',
                    valueWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: isLent
                                ? AppColors.incomeLight
                                : AppColors.expenseLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            isLent
                                ? Icons.arrow_upward_rounded
                                : Icons.arrow_downward_rounded,
                            size: 13,
                            color: isLent ? AppColors.income : AppColors.expense,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isLent ? 'Lent' : 'Borrowed',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _divider(),
                  _DetailRow(
                    icon: Icons.calendar_month_outlined,
                    iconColor: AppColors.textSecondary,
                    label: 'Given On',
                    valueWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.calendar_today_outlined,
                              size: 13, color: AppColors.primary),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          CurrencyFormatter.shortDate(_entry.date),
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  _divider(),
                  _DetailRow(
                    icon: Icons.calendar_month_outlined,
                    iconColor: AppColors.textSecondary,
                    label: 'Due Date',
                    valueWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.calendar_today_outlined,
                              size: 13, color: AppColors.primary),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          CurrencyFormatter.shortDate(_entry.dueDate),
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  _divider(),
                  _DetailRow(
                    icon: Icons.timer_outlined,
                    iconColor: AppColors.textSecondary,
                    label: 'Status',
                    valueWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: _entry.status.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _entry.status.label,
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  _divider(),
                  _DetailRow(
                    icon: Icons.note_outlined,
                    iconColor: AppColors.textSecondary,
                    label: 'Note',
                    valueWidget: Text(
                      _entry.note?.isNotEmpty == true
                          ? _entry.note!
                          : '—',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textPrimary),
                    ),
                  ),
                  _divider(),
                  _DetailRow(
                    icon: Icons.receipt_outlined,
                    iconColor: AppColors.textSecondary,
                    label: 'Payment Method',
                    valueWidget: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 22,
                          height: 22,
                          decoration: BoxDecoration(
                            color: AppColors.incomeLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.payments_rounded,
                              size: 13, color: AppColors.income),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _entry.paymentMethod ?? 'Cash',
                          style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ── Action buttons ────────────────────────────────────────────────
            Row(
              children: [
                // Mark as Settled
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        (isSettled || _isMarkingSettled) ? null : _markAsSettled,
                    icon: _isMarkingSettled
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Icon(
                            isSettled
                                ? Icons.check_circle_rounded
                                : Icons.check_rounded,
                            size: 18),
                    label: Text(
                      isSettled ? 'Settled' : 'Mark as Settled',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isSettled ? AppColors.income : AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      disabledBackgroundColor: AppColors.income,
                      disabledForegroundColor: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Send Reminder
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: isSettled ? null : _sendReminder,
                    icon: const Icon(Icons.notifications_outlined, size: 18),
                    label: Text(
                      'Send Reminder',
                      style: GoogleFonts.inter(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── History ───────────────────────────────────────────────────────
            Text(
              'History',
              style: GoogleFonts.inter(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE6F9F5),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_downward_rounded,
                          color: AppColors.income, size: 18),
                    ),
                    const SizedBox(width: 12),
                    // Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isLent ? 'Lent' : 'Borrowed',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${CurrencyFormatter.shortDate(_entry.date)} • ${_entry.paymentMethod ?? 'Cash'}',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Amount
                    Text(
                      '+${CurrencyFormatter.format(_entry.amount, symbol: settings.currencySymbol)}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.income,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Settled entry shown if paid
            if (isSettled) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.budgetLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_rounded,
                            color: AppColors.budget, size: 18),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Settled',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              CurrencyFormatter.relativeDate(DateTime.now()),
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '-${CurrencyFormatter.format(_entry.amount, symbol: settings.currencySymbol)}',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColors.expense,
                        ),
                      ),
                    ],
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

// ─── Detail Row ───────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget valueWidget;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          valueWidget,
        ],
      ),
    );
  }
}

Widget _divider() =>
    const Divider(height: 1, indent: 44, endIndent: 16, color: Color(0xFFF0F0F0));

// ─── Status Badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final LendBorrowStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.lightColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: status.color,
        ),
      ),
    );
  }
}
