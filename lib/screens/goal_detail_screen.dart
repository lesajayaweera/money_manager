import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/goal_model.dart';
import '../providers/goal_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/wallet_provider.dart';
import '../models/wallet_model.dart';
import 'add_edit_goal_screen.dart';

class GoalDetailScreen extends StatefulWidget {
  final GoalModel goal;

  const GoalDetailScreen({super.key, required this.goal});

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  late GoalModel _goal;
  List<GoalSavingsEntry> _savings = [];
  bool _loadingSavings = true;

  @override
  void initState() {
    super.initState();
    _goal = widget.goal;
    _loadSavings();
  }

  Future<void> _loadSavings() async {
    if (_goal.id == null) return;
    final provider = context.read<GoalProvider>();
    final entries = await provider.getSavingsHistory(_goal.id!);
    if (mounted) {
      setState(() {
        _savings = entries;
        _loadingSavings = false;
      });
    }
  }

  Future<void> _refreshGoal() async {
    final provider = context.read<GoalProvider>();
    await provider.loadGoals();
    if (mounted) {
      final updated = provider.goals.firstWhere(
        (g) => g.id == _goal.id,
        orElse: () => _goal,
      );
      setState(() => _goal = updated);
      await _loadSavings();
    }
  }

  void _showAddSavings() {
    final controller = TextEditingController();
    String? selectedWalletName;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Add Savings',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Amount (Rs.)',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                autofocus: true,
                style: GoogleFonts.poppins(
                    fontSize: 16, color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle:
                      GoogleFonts.poppins(color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.white, fontSize: 15),
                  filled: true,
                  fillColor: Theme.of(context).scaffoldBackgroundColor,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide:
                        BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Account Type',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Consumer<WalletProvider>(
                builder: (_, walletProvider, __) {
                  final wallets = walletProvider.wallets;
                  final effectiveSelected = (selectedWalletName != null &&
                          wallets.any((w) => w.name == selectedWalletName))
                      ? selectedWalletName
                      : null;
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Theme.of(context).dividerColor),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: effectiveSelected,
                        isExpanded: true,
                        hint: Text(
                          'Select wallet (optional)',
                          style: GoogleFonts.poppins(
                              color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.white, fontSize: 14),
                        ),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        icon: Icon(Icons.keyboard_arrow_down_rounded,
                            color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white),
                        dropdownColor: Theme.of(context).colorScheme.surface,
                        items: [
                          DropdownMenuItem<String>(
                            value: null,
                            child: Text('None',
                                style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white)),
                          ),
                          ...wallets.map((w) => DropdownMenuItem<String>(
                                value: w.name,
                                child: Row(children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: Color(w.colorValue)
                                          .withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Icon(
                                      WalletIconHelper.fromCodePoint(w.iconCodePoint),
                                      color: Color(w.colorValue),
                                      size: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(w.name,
                                      style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white)),
                                ]),
                              ))
                        ],
                        onChanged: (val) =>
                            setSheetState(() => selectedWalletName = val),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = double.tryParse(controller.text.trim());
                    if (amount == null || amount <= 0) return;
                    Navigator.pop(ctx);
                    // Cache providers before async gaps
                    final provider = context.read<GoalProvider>();
                    final txProvider = context.read<TransactionProvider>();
                    final walletProv = context.read<WalletProvider>();
                    await provider.addSavings(
                      GoalSavingsEntry(
                        goalId: _goal.id!,
                        amount: amount,
                        date: DateTime.now(),
                      ),
                      goalName: _goal.name,
                      walletName: selectedWalletName,
                    );
                    // Refresh TransactionProvider and WalletProvider so balances update
                    if (mounted) {
                      await txProvider.loadAll();
                      await walletProv.loadWallets();
                    }
                    await _refreshGoal();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Save',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
      ),
    );
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
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
                  color: Theme.of(context).dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.expense),
                title: Text('Delete Goal',
                    style: GoogleFonts.poppins(
                        color: AppColors.expense,
                        fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Delete Goal',
                          style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                      content: Text('Delete "${_goal.name}"? This cannot be undone.',
                          style: GoogleFonts.poppins()),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text('Delete',
                                style: GoogleFonts.poppins(
                                    color: AppColors.expense))),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    await context.read<GoalProvider>().deleteGoal(_goal.id!);
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
    final pct = _goal.progressPercent;

    Color ringColor;
    if (pct >= 0.7) {
      ringColor = AppColors.primary;
    } else if (pct >= 0.4) {
      ringColor = AppColors.income;
    } else {
      ringColor = AppColors.expense;
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Goal Details',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert_rounded,
                color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white),
            onPressed: _showOptions,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Progress card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    _goal.name,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Large circular ring
                  SizedBox(
                    width: 140,
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(140, 140),
                          painter: _DetailRingPainter(
                            percent: pct,
                            color: ringColor,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(pct * 100).round()}%',
                              style: GoogleFonts.poppins(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                              ),
                            ),
                            Text(
                              'Completed',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
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
            const SizedBox(height: 20),

            // Stats
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _StatRow(
                    icon: Icons.timer_outlined,
                    iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                    label: 'Target Amount',
                    value: CurrencyFormatter.format(_goal.targetAmount,
                        symbol: settings.currencySymbol),
                    valueColor: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _StatRow(
                    icon: Icons.refresh_rounded,
                    iconColor: AppColors.income,
                    label: 'Saved Amount',
                    value: CurrencyFormatter.format(_goal.savedAmount,
                        symbol: settings.currencySymbol),
                    valueColor: AppColors.income,
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _StatRow(
                    icon: Icons.timer_off_outlined,
                    iconColor: AppColors.expense,
                    label: 'Remaining Amount',
                    value: CurrencyFormatter.format(_goal.remainingAmount,
                        symbol: settings.currencySymbol),
                    valueColor: AppColors.expense,
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _StatRow(
                    icon: Icons.calendar_month_outlined,
                    iconColor: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                    label: 'Target Date',
                    value: CurrencyFormatter.shortDate(_goal.targetDate),
                    valueColor: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _showAddSavings,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      '+ Add Savings',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              AddEditGoalScreen(editGoal: _goal),
                        ),
                      );
                      await _refreshGoal();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      'Edit Goal',
                      style: GoogleFonts.poppins(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Recent savings
            Text(
              'Recent Savings',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingSavings)
              Center(
                  child: CircularProgressIndicator(color: AppColors.primary))
            else if (_savings.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    'No savings added yet',
                    style: GoogleFonts.poppins(
                        color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white, fontSize: 14),
                  ),
                ),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _savings.take(5).length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, indent: 56, endIndent: 16),
                  itemBuilder: (_, i) {
                    final entry = _savings[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE6F9F5),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_downward_rounded,
                                color: AppColors.income, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Added to Goal',
                                  style: GoogleFonts.poppins(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                                  ),
                                ),
                                Text(
                                  CurrencyFormatter.relativeDate(entry.date),
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '+${CurrencyFormatter.format(entry.amount, symbol: settings.currencySymbol)}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.income,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            if (_savings.length > 5) ...[
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () {},
                  child: Text(
                    'View All',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
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

// ─── Detail Ring Painter ──────────────────────────────────────────────────────

class _DetailRingPainter extends CustomPainter {
  final double percent;
  final Color color;

  const _DetailRingPainter({required this.percent, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 10.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final bgPaint = Paint()
      ..color = const Color(0xFFE8E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    final fgPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * percent,
      false,
      fgPaint,
    );
  }

  @override
  bool shouldRepaint(_DetailRingPainter old) =>
      old.percent != percent || old.color != color;
}

// ─── Stat Row ─────────────────────────────────────────────────────────────────

class _StatRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;

  const _StatRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}
