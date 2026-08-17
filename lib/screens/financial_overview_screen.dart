import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/lend_borrow_model.dart';
import '../providers/lend_borrow_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/wallet_provider.dart';

class FinancialOverviewScreen extends StatefulWidget {
  const FinancialOverviewScreen({super.key});

  @override
  State<FinancialOverviewScreen> createState() =>
      _FinancialOverviewScreenState();
}

class _FinancialOverviewScreenState extends State<FinancialOverviewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _chartAnimCtrl;
  late Animation<double> _chartAnim;

  final List<String> _periods = ['This month', 'Last month', 'This year'];
  int _selectedPeriod = 0;

  @override
  void initState() {
    super.initState();
    _chartAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _chartAnim = CurvedAnimation(
      parent: _chartAnimCtrl,
      curve: Curves.easeOutCubic,
    );
    _chartAnimCtrl.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<WalletProvider>().loadWallets();
      context.read<LendBorrowProvider>().loadEntries();
    });
  }

  @override
  void dispose() {
    _chartAnimCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary =
        Theme.of(context).textTheme.titleLarge?.color ?? Colors.white;
    final textSecondary =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return Consumer3<WalletProvider, LendBorrowProvider, SettingsProvider>(
      builder: (context, walletProvider, lbProvider, settings, _) {
        final totalAssets = walletProvider.totalBalance;
        final totalLiabilities = lbProvider.borrowedEntries
            .where((e) => e.effectiveStatus != LendBorrowStatus.paid)
            .fold(
                0.0,
                (s, e) =>
                    s + (e.amount - e.accumulatedAmount).clamp(0, double.infinity));

        final netWorth = totalAssets - totalLiabilities;
        final sym = settings.currencySymbol;

        final totalForPercent = totalAssets + totalLiabilities;
        final assetsPercent =
            totalForPercent == 0 ? 1.0 : totalAssets / totalForPercent;
        final liabPercent = 1.0 - assetsPercent;

        final financialStatus = netWorth >= 0 ? 'Healthy' : 'Deficit';
        final statusColor =
            netWorth >= 0 ? AppColors.income : AppColors.expense;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: textPrimary),
              onPressed: () => Navigator.pop(context),
            ),
            title: Text(
              'Financial Overview',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            centerTitle: true,
            actions: [
              Container(
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface2 : AppColors.background,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(Icons.ios_share_outlined,
                      color: textSecondary, size: 20),
                  onPressed: () {},
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Net Worth Card
                _NetWorthCard(
                  netWorth: netWorth,
                  currencySymbol: sym,
                  financialStatus: financialStatus,
                  statusColor: statusColor,
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  selectedPeriod: _selectedPeriod,
                  periods: _periods,
                  onPeriodTap: () => _showPeriodPicker(context),
                ),
                const SizedBox(height: 16),

                // Assets + Liabilities mini cards
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: 'TOTAL ASSETS',
                        amount: totalAssets,
                        symbol: sym,
                        color: AppColors.income,
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        label: 'TOTAL LIABILITIES',
                        amount: totalLiabilities,
                        symbol: sym,
                        color: AppColors.expense,
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Balance Sheet heading
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'BALANCE SHEET',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                        color: textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Assets breakdown
                _BalanceSheetCard(
                  label: 'TOTAL ASSETS',
                  total: totalAssets,
                  symbol: sym,
                  iconColor: AppColors.income,
                  icon: Icons.account_balance_wallet_rounded,
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  items: walletProvider.wallets
                      .where((w) => w.includeInTotal)
                      .map((w) => _BalanceItem(
                            icon: w.icon,
                            label: w.name,
                            amount: w.balance,
                            color: w.color,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),

                // Liabilities breakdown
                _BalanceSheetCard(
                  label: 'TOTAL LIABILITIES',
                  total: totalLiabilities,
                  symbol: sym,
                  iconColor: AppColors.expense,
                  icon: Icons.account_balance_rounded,
                  isDark: isDark,
                  textPrimary: textPrimary,
                  textSecondary: textSecondary,
                  items: lbProvider.borrowedEntries
                      .where((e) => e.effectiveStatus != LendBorrowStatus.paid)
                      .map((e) => _BalanceItem(
                            icon: Icons.person_rounded,
                            label: e.personName,
                            amount: (e.amount - e.accumulatedAmount)
                                .clamp(0, double.infinity),
                            color: AppColors.expense,
                          ))
                      .toList(),
                ),
                const SizedBox(height: 24),

                // Donut chart card
                AnimatedBuilder(
                  animation: _chartAnim,
                  builder: (context, _) => _DonutChartCard(
                    assetsAmount: totalAssets,
                    liabilitiesAmount: totalLiabilities,
                    assetsPercent: assetsPercent,
                    liabPercent: liabPercent,
                    symbol: sym,
                    isDark: isDark,
                    textPrimary: textPrimary,
                    textSecondary: textSecondary,
                    progress: _chartAnim.value,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPeriodPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
              const SizedBox(height: 20),
              Text(
                'Select Period',
                style: GoogleFonts.poppins(
                    fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              ..._periods.asMap().entries.map((entry) {
                final isSelected = entry.key == _selectedPeriod;
                return ListTile(
                  title: Text(entry.value,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  trailing: isSelected
                      ? Icon(Icons.check_rounded, color: AppColors.primary)
                      : null,
                  onTap: () {
                    setState(() => _selectedPeriod = entry.key);
                    Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Net Worth Card ────────────────────────────────────────────────────────────

class _NetWorthCard extends StatelessWidget {
  final double netWorth;
  final String currencySymbol;
  final String financialStatus;
  final Color statusColor;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final int selectedPeriod;
  final List<String> periods;
  final VoidCallback onPeriodTap;

  const _NetWorthCard({
    required this.netWorth,
    required this.currencySymbol,
    required this.financialStatus,
    required this.statusColor,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.selectedPeriod,
    required this.periods,
    required this.onPeriodTap,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? AppColors.darkSurface
        : Theme.of(context).colorScheme.surface;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: isDark ? 0.06 : 0.08),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NET WORTH',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                  color: textSecondary,
                ),
              ),
              GestureDetector(
                onTap: onPeriodTap,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkSurface2
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded,
                          size: 14, color: textSecondary),
                      const SizedBox(width: 5),
                      Text(
                        periods[selectedPeriod],
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            CurrencyFormatter.format(netWorth, symbol: currencySymbol),
            style: GoogleFonts.poppins(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: AppColors.income,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                'Your financial position  ',
                style:
                    GoogleFonts.poppins(fontSize: 13, color: textSecondary),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                          color: statusColor, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      financialStatus,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Track this month's progress as you add data.",
            style: GoogleFonts.poppins(fontSize: 12, color: textSecondary),
          ),
        ],
      ),
    );
  }
}

// ─── Summary Mini Card ─────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final String symbol;
  final Color color;
  final bool isDark;

  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.symbol,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? AppColors.darkSurface
        : Theme.of(context).colorScheme.surface;
    final textPrimary =
        Theme.of(context).textTheme.titleLarge?.color ?? Colors.white;
    final textSecondary =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyFormatter.format(amount, symbol: symbol),
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.arrow_upward_rounded,
                color: color,
                size: 13,
              ),
              const SizedBox(width: 3),
              Text(
                '+0.0%',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Balance Sheet Card ────────────────────────────────────────────────────────

class _BalanceItem {
  final IconData icon;
  final String label;
  final double amount;
  final Color color;

  const _BalanceItem({
    required this.icon,
    required this.label,
    required this.amount,
    required this.color,
  });
}

class _BalanceSheetCard extends StatelessWidget {
  final String label;
  final double total;
  final String symbol;
  final Color iconColor;
  final IconData icon;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final List<_BalanceItem> items;

  const _BalanceSheetCard({
    required this.label,
    required this.total,
    required this.symbol,
    required this.iconColor,
    required this.icon,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? AppColors.darkSurface
        : Theme.of(context).colorScheme.surface;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 12,
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
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    CurrencyFormatter.format(total, symbol: symbol),
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.arrow_upward_rounded,
                color: iconColor,
                size: 13,
              ),
              const SizedBox(width: 4),
              Text(
                '+0.0% this period',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: iconColor,
                ),
              ),
            ],
          ),
          if (items.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(color: Theme.of(context).dividerColor, height: 1),
            const SizedBox(height: 8),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(item.icon, color: item.color, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.label,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      CurrencyFormatter.format(item.amount, symbol: symbol),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.income,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 12),
            Center(
              child: Text(
                'No entries',
                style:
                    GoogleFonts.poppins(fontSize: 13, color: textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Donut Chart Card ──────────────────────────────────────────────────────────

class _DonutChartCard extends StatelessWidget {
  final double assetsAmount;
  final double liabilitiesAmount;
  final double assetsPercent;
  final double liabPercent;
  final String symbol;
  final bool isDark;
  final Color textPrimary;
  final Color textSecondary;
  final double progress;

  const _DonutChartCard({
    required this.assetsAmount,
    required this.liabilitiesAmount,
    required this.assetsPercent,
    required this.liabPercent,
    required this.symbol,
    required this.isDark,
    required this.textPrimary,
    required this.textSecondary,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark
        ? AppColors.darkSurface
        : Theme.of(context).colorScheme.surface;

    final centerLabel =
        assetsAmount == 0 && liabilitiesAmount == 0
            ? '0%'
            : '${(assetsPercent * 100).toStringAsFixed(0)}%';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.12 : 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 220,
            height: 220,
            child: CustomPaint(
              painter: _DonutPainter(
                assetsPercent: assetsPercent,
                liabPercent: liabPercent,
                assetsColor: AppColors.income,
                liabColor: AppColors.expense,
                bgColor: isDark
                    ? AppColors.darkSurface2
                    : AppColors.background,
                progress: progress,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      centerLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.income,
                        letterSpacing: -1,
                      ),
                    ),
                    Text(
                      'Assets',
                      style: GoogleFonts.poppins(
                          fontSize: 13, color: textSecondary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          _LegendRow(
            color: AppColors.income,
            label: 'Assets',
            amount: assetsAmount,
            percent: assetsPercent * 100,
            symbol: symbol,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
          const SizedBox(height: 6),
          _MiniBar(
              assetsPercent: assetsPercent, liabPercent: liabPercent),
          const SizedBox(height: 6),
          _LegendRow(
            color: AppColors.expense,
            label: 'Liabilities',
            amount: liabilitiesAmount,
            percent: liabPercent * 100,
            symbol: symbol,
            textPrimary: textPrimary,
            textSecondary: textSecondary,
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String label;
  final double amount;
  final double percent;
  final String symbol;
  final Color textPrimary;
  final Color textSecondary;

  const _LegendRow({
    required this.color,
    required this.label,
    required this.amount,
    required this.percent,
    required this.symbol,
    required this.textPrimary,
    required this.textSecondary,
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
              fontWeight: FontWeight.w500,
              color: textSecondary),
        ),
        const Spacer(),
        Text(
          CurrencyFormatter.format(amount, symbol: symbol),
          style: GoogleFonts.poppins(
              fontSize: 13, fontWeight: FontWeight.w700, color: textPrimary),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            '${percent.toStringAsFixed(1)}%',
            textAlign: TextAlign.end,
            style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary),
          ),
        ),
      ],
    );
  }
}

class _MiniBar extends StatelessWidget {
  final double assetsPercent;
  final double liabPercent;

  const _MiniBar(
      {required this.assetsPercent, required this.liabPercent});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox(
        height: 6,
        child: Row(
          children: [
            Expanded(
              flex: (assetsPercent * 100).round().clamp(1, 99),
              child: Container(color: AppColors.income),
            ),
            Expanded(
              flex: (liabPercent * 100).round().clamp(1, 99),
              child: Container(color: AppColors.expense),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Donut Painter ─────────────────────────────────────────────────────────────

class _DonutPainter extends CustomPainter {
  final double assetsPercent;
  final double liabPercent;
  final Color assetsColor;
  final Color liabColor;
  final Color bgColor;
  final double progress;

  _DonutPainter({
    required this.assetsPercent,
    required this.liabPercent,
    required this.assetsColor,
    required this.liabColor,
    required this.bgColor,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 10;
    const strokeWidth = 30.0;
    const gapAngle = 0.04;

    final bgPaint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    if ((assetsPercent + liabPercent) == 0) return;

    final fullSweep = 2 * math.pi * progress;
    const startAngle = -math.pi / 2;

    final assetsSweep =
        (assetsPercent * fullSweep - gapAngle).clamp(0.0, 2 * math.pi);
    final liabSweep =
        (liabPercent * fullSweep - gapAngle).clamp(0.0, 2 * math.pi);

    final assetsPaint = Paint()
      ..color = assetsColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final liabPaint = Paint()
      ..color = liabColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    if (assetsSweep > 0) {
      canvas.drawArc(rect, startAngle, assetsSweep, false, assetsPaint);
    }
    if (liabSweep > 0) {
      canvas.drawArc(rect, startAngle + assetsSweep + gapAngle, liabSweep,
          false, liabPaint);
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.progress != progress ||
      old.assetsPercent != assetsPercent ||
      old.liabPercent != liabPercent;
}
