import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../core/utils/responsive.dart';
import '../main_scaffold.dart';
import '../models/category_model.dart';
import '../models/sms_draft_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/sms_draft_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import '../widgets/sms_message_card.dart';
import 'create_budget_screen.dart';
import 'goals_screen.dart';
import 'lends_borrowed_screen.dart';
import 'quick_add_transaction_sheet.dart';
import 'sms_review_inbox_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransactionProvider>().loadAll();
      // Non-blocking: drain any SMS captured since the last session so the
      // dashboard badge shows up-to-date pending drafts immediately.
      final sms = context.read<SmsDraftProvider>();
      if (sms.enabled) sms.refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(),
      body: Consumer<TransactionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.allTransactions.isEmpty) {
            return Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () => provider.loadAll(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _BalanceCard(summary: provider.summary),
                  // Pending SMS drafts — shown right after balance card when drafts exist.
                  const _SmsDraftsBannerCard(),
                  const SizedBox(height: 20),
                  _StatsGrid(summary: provider.summary),
                  const SizedBox(height: 24),
                  _RecentTransactionsSection(
                    transactions: provider.recentTransactions,
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        onPressed: () => _showAddSheet(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.add_rounded, size: 30),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    final txProvider = context.read<TransactionProvider>();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AddTransactionSheet(
        onAdd: (type) async {
          if (!mounted) return;
          await showQuickAddSheet(context, type);
          if (mounted) txProvider.loadAll();
        },
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      leading: IconButton(
        icon: Icon(
          Icons.menu_rounded,
          color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
          size: 26,
        ),
        onPressed: () => mainScaffoldKey.currentState?.openDrawer(),
      ),
      title: Text(
        'Dashboard',
        style: GoogleFonts.poppins(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
        ),
      ),
      actions: [
        IconButton(
          icon: Stack(
            children: [
              Icon(Icons.widgets_outlined,
                  color: Theme.of(context).textTheme.titleLarge?.color ??
                      Colors.white,
                  size: 26),
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.expense,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          onPressed: () => _showQuickNav(context),
        ),
        const SizedBox(width: 4),
      ],
    );
  }

  void _showQuickNav(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
              const SizedBox(height: 20),
              Text(
                'Quick Navigation',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.titleLarge?.color ??
                      Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _QuickNavTile(
                      icon: Icons.flag_rounded,
                      label: 'Goals',
                      color: AppColors.primary,
                      lightColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppColors.darkPrimarySurface
                              : AppColors.primarySurface,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const GoalsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _QuickNavTile(
                      icon: Icons.flag_rounded,
                      label: 'Borrowed',
                      color: AppColors.expense,
                      lightColor: AppColors.expenseLight,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const LendsBorrowedScreen(initialIndex: 1),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _QuickNavTile(
                      icon: Icons.swap_horiz_rounded,
                      label: 'Lends',
                      color: AppColors.budget,
                      lightColor: AppColors.budgetLight,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const LendsBorrowedScreen(initialIndex: 0),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _QuickNavTile(
                      icon: Icons.account_balance_wallet_rounded,
                      label: 'Create Budget',
                      color: AppColors.spending,
                      lightColor: AppColors.spendingLight,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CreateBudgetScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Quick Nav Tile ────────────────────────────────────────────────────────────

class _QuickNavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color lightColor;
  final VoidCallback onTap;

  const _QuickNavTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.lightColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? color.withValues(alpha: 0.15)
              : lightColor,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
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
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Balance Card (swipable: Total Balance ↔ Net Cash Flow) ───────────────────

class _BalanceCard extends StatefulWidget {
  final DashboardSummary summary;
  const _BalanceCard({required this.summary});

  @override
  State<_BalanceCard> createState() => _BalanceCardState();
}

class _BalanceCardState extends State<_BalanceCard> {
  final PageController _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _showCashFlowSheet(
      BuildContext context, double cashIn, double cashOut, String sym) {
    final netCashFlow = cashIn - cashOut;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CashFlowBottomSheet(
        cashIn: cashIn,
        cashOut: cashOut,
        netCashFlow: netCashFlow,
        currencySymbol: sym,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SettingsProvider, WalletProvider>(
      builder: (context, settings, walletProvider, _) {
        final sym = settings.currencySymbol;
        final cashIn = widget.summary.monthlyIncome;
        final cashOut = widget.summary.monthlyExpenses;
        final netCashFlow = cashIn - cashOut;

        final now = DateTime.now();
        final firstDay = DateTime(now.year, now.month, 1);
        final lastDay = DateTime(now.year, now.month + 1, 0);
        final dateRange =
            '${DateFormat('MMM d, yyyy').format(firstDay)} - ${DateFormat('MMM d, yyyy').format(lastDay)}';

        return Column(
          children: [
            SizedBox(
              height: Responsive.scaledHeight(context, 145, extra: 38),
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  // ── Card 1: Total Balance ───────────────────────────────
                  GestureDetector(
                    onTap: () =>
                        _showCashFlowSheet(context, cashIn, cashOut, sym),
                    child: _TotalBalanceCard(
                      settings: settings,
                      totalBalance: walletProvider.totalBalance,
                    ),
                  ),

                  // ── Card 2: Net Cash Flow ───────────────────────────────
                  GestureDetector(
                    onTap: () =>
                        _showCashFlowSheet(context, cashIn, cashOut, sym),
                    child: _NetCashFlowCard(
                      netCashFlow: netCashFlow,
                      cashIn: cashIn,
                      cashOut: cashOut,
                      dateRange: dateRange,
                      currencySymbol: sym,
                      visible: settings.balanceVisible,
                    ),
                  ),
                ],
              ),
            ),

            // ── Dot indicator ─────────────────────────────────────────────
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(2, (i) {
                final active = i == _page;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: active
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }
}

// ─── Card 1 widget ─────────────────────────────────────────────────────────────

class _TotalBalanceCard extends StatelessWidget {
  final SettingsProvider settings;
  final double totalBalance;

  const _TotalBalanceCard({
    required this.settings,
    required this.totalBalance,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Balance',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              Row(
                children: [
                  GestureDetector(
                    onTap: settings.toggleBalanceVisibility,
                    child: Icon(
                      settings.balanceVisible
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: Colors.white.withValues(alpha: 0.85),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: FittedBox(
              key: ValueKey(settings.balanceVisible),
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                settings.balanceVisible
                    ? CurrencyFormatter.format(totalBalance,
                        symbol: settings.currencySymbol)
                    : '${settings.currencySymbol} ••••••',
                maxLines: 1,
                softWrap: false,
                style: GoogleFonts.poppins(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: settings.balanceVisible ? -1 : 4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Card 2 widget ─────────────────────────────────────────────────────────────

class _NetCashFlowCard extends StatelessWidget {
  final double netCashFlow;
  final double cashIn;
  final double cashOut;
  final String dateRange;
  final String currencySymbol;
  final bool visible;

  const _NetCashFlowCard({
    required this.netCashFlow,
    required this.cashIn,
    required this.cashOut,
    required this.dateRange,
    required this.currencySymbol,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    final pct =
        cashIn == 0 ? 0.0 : ((netCashFlow / cashIn) * 100).clamp(-999.0, 999.0);
    final pctStr = '${pct >= 0 ? '' : ''}${pct.toStringAsFixed(0)}%';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Label row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Net Cash Flow',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '− $pctStr',
                  maxLines: 1,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Amount
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              visible
                  ? CurrencyFormatter.format(netCashFlow,
                      symbol: currencySymbol)
                  : '$currencySymbol ••••••',
              maxLines: 1,
              softWrap: false,
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: visible ? -0.5 : 2,
              ),
            ),
          ),
          const SizedBox(height: 2),
          // Date range
          Text(
            dateRange,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const Spacer(),
          // Net Income row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Net Income',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          visible
                              ? CurrencyFormatter.format(cashIn,
                                  symbol: currencySymbol)
                              : '••••••',
                          maxLines: 1,
                          softWrap: false,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '− 0%',
                        maxLines: 1,
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Net Cash Flow Bottom Sheet ────────────────────────────────────────────────

class _CashFlowBottomSheet extends StatelessWidget {
  final double cashIn;
  final double cashOut;
  final double netCashFlow;
  final String currencySymbol;

  const _CashFlowBottomSheet({
    required this.cashIn,
    required this.cashOut,
    required this.netCashFlow,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        Theme.of(context).textTheme.titleLarge?.color ?? Colors.white;
    final textSecondary =
        Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
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

            // Title
            Text(
              'Net Cash Flow',
              style: GoogleFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Excludes loan disbursements and wallet transfers.',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 24),

            // Cash In row
            _SheetRow(
              label: 'Cash In',
              amount: cashIn,
              symbol: currencySymbol,
              color: AppColors.income,
            ),
            const SizedBox(height: 16),

            // Cash Out row
            _SheetRow(
              label: 'Cash Out',
              amount: cashOut,
              symbol: currencySymbol,
              color: AppColors.expense,
            ),
            const SizedBox(height: 20),

            // Divider
            Divider(color: Theme.of(context).dividerColor),
            const SizedBox(height: 16),

            // Net Cash Flow row (bold)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Net Cash Flow',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                Text(
                  CurrencyFormatter.format(netCashFlow, symbol: currencySymbol),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color:
                        netCashFlow >= 0 ? AppColors.income : AppColors.expense,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  final String label;
  final double amount;
  final String symbol;
  final Color color;

  const _SheetRow({
    required this.label,
    required this.amount,
    required this.symbol,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        Text(
          CurrencyFormatter.format(amount, symbol: symbol),
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Stats Grid ───────────────────────────────────────────────────────────────

class _StatsGrid extends StatelessWidget {
  final DashboardSummary summary;
  const _StatsGrid({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'This Month Income',
                    amount: summary.monthlyIncome,
                    icon: Icons.account_balance_wallet_rounded,
                    iconColor: AppColors.income,
                    visible: settings.balanceVisible,
                    currencySymbol: settings.currencySymbol,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _StatCard(
                    label: 'This Month Expenses',
                    amount: summary.monthlyExpenses,
                    icon: Icons.receipt_long_rounded,
                    iconColor: AppColors.expense,
                    visible: settings.balanceVisible,
                    currencySymbol: settings.currencySymbol,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    label: 'Remaining Budget',
                    amount: summary.remainingBudget,
                    icon: Icons.savings_rounded,
                    iconColor: AppColors.budget,
                    visible: settings.balanceVisible,
                    currencySymbol: settings.currencySymbol,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _StatCard(
                    label: "Today's Spending",
                    amount: summary.todaySpending,
                    icon: Icons.today_rounded,
                    iconColor: AppColors.spending,
                    visible: settings.balanceVisible,
                    currencySymbol: settings.currencySymbol,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color iconColor;
  final bool visible;
  final String currencySymbol;

  const _StatCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.iconColor,
    required this.visible,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color:
                  Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: FittedBox(
              key: ValueKey(visible),
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                visible
                    ? CurrencyFormatter.format(amount, symbol: currencySymbol)
                    : '••••••',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.titleLarge?.color ??
                      Colors.white,
                ),
                maxLines: 1,
                softWrap: false,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recent Transactions ──────────────────────────────────────────────────────

class _RecentTransactionsSection extends StatelessWidget {
  final List<TransactionModel> transactions;
  const _RecentTransactionsSection({required this.transactions});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Recent Transactions',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.titleLarge?.color ??
                      Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                // Switch to Transactions tab via MainScaffold
                final scaffold =
                    context.findAncestorStateOfType<MainScaffoldState>();
                scaffold?.setTab(1);
              },
              child: Text(
                '+ View All',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (transactions.isEmpty)
          _EmptyTransactions()
        else
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: transactions.length,
              separatorBuilder: (_, __) => const Divider(
                height: 1,
                indent: 70,
                endIndent: 16,
              ),
              itemBuilder: (context, index) {
                return _TransactionTile(transaction: transactions[index]);
              },
            ),
          ),
      ],
    );
  }
}

class _EmptyTransactions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.white,
          ),
          const SizedBox(height: 12),
          Text(
            'No transactions yet',
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color:
                  Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your first income or expense below',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color:
                  Theme.of(context).textTheme.bodySmall?.color ?? Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  const _TransactionTile({required this.transaction});

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final type =
        transaction.isIncome ? CategoryType.income : CategoryType.expense;
    final category = categoryProvider.findByName(transaction.category, type) ??
        (type == CategoryType.income
            ? AppCategory.defaultIncomeCategories.last
            : AppCategory.defaultExpenseCategories.last);
    final settings = context.watch<SettingsProvider>();
    final isIncome = transaction.isIncome;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Category icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: category.lightColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(category.icon, color: category.color, size: 22),
          ),
          const SizedBox(width: 14),
          // Title + date
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color ??
                        Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  CurrencyFormatter.relativeDate(transaction.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color ??
                        Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    settings.balanceVisible
                        ? CurrencyFormatter.formatWithSign(
                            transaction.signedAmount,
                            symbol: settings.currencySymbol,
                          )
                        : '••••',
                    maxLines: 1,
                    softWrap: false,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isIncome ? AppColors.income : AppColors.expense,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  transaction.walletName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Theme.of(context).textTheme.bodySmall?.color ??
                        Colors.white,
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

// ─── Add Transaction Sheet ────────────────────────────────────────────────────

class _AddTransactionSheet extends StatelessWidget {
  final Future<void> Function(TransactionType) onAdd;
  const _AddTransactionSheet({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
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
              'Add Transaction',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                // Add Income
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onAdd(TransactionType.income);
                    },
                    child: Container(
                      height: 130,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF1A6B3A),
                                  const Color(0xFF27AE60)
                                ]
                              : [
                                  const Color(0xFF27AE60),
                                  const Color(0xFF2ECC71)
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF27AE60).withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_upward_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Add Income',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Salary, gifts, etc.',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Add Expense
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      onAdd(TransactionType.expense);
                    },
                    child: Container(
                      height: 130,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isDark
                              ? [
                                  const Color(0xFF7B1C1C),
                                  const Color(0xFFE74C3C)
                                ]
                              : [
                                  const Color(0xFFE74C3C),
                                  const Color(0xFFFF6B6B)
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFE74C3C).withOpacity(0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_downward_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Add Expense',
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Bills, shopping, etc.',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
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

// ─── SMS Drafts Banner Card ────────────────────────────────────────────────────
//
// Shows on the dashboard whenever there are pending SMS-captured drafts.
// Expands inline to show up to 3 mini tiles; tapping a tile opens the full
// edit sheet without leaving the dashboard. "View All" navigates to the
// full SmsReviewInboxScreen.

class _SmsDraftsBannerCard extends StatefulWidget {
  const _SmsDraftsBannerCard();

  @override
  State<_SmsDraftsBannerCard> createState() => _SmsDraftsBannerCardState();
}

class _SmsDraftsBannerCardState extends State<_SmsDraftsBannerCard> {
  bool _expanded = true;

  void _toggleExpand() => setState(() => _expanded = !_expanded);

  void _openEditSheet(BuildContext context, SmsDraftModel draft) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _DashboardDraftEditSheet(draft: draft),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final smsProvider = context.watch<SmsDraftProvider>();
    final pending = smsProvider.pendingDrafts;

    // Banner visible whenever there are pending drafts (even if capture was
    // just toggled off — drafts already captured should still be reviewable).
    if (pending.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;
    final previewDrafts = pending.take(3).toList();

    return Column(
      children: [
        const SizedBox(height: 16),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header row ────────────────────────────────────────────────
                  InkWell(
                    onTap: _toggleExpand,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                      bottom: Radius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          // Badge icon with count overlay
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.sms_rounded,
                                    color: AppColors.primary, size: 20),
                              ),
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  width: 18,
                                  height: 18,
                                  decoration: BoxDecoration(
                                    color: AppColors.expense,
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: cardColor, width: 2),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '${pending.length > 9 ? '9+' : pending.length}',
                                    style: const TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${pending.length} Pending Transaction${pending.length == 1 ? '' : 's'}',
                                  style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.color),
                                ),
                                Text(
                                  'Tap to review & save',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedRotation(
                            turns: _expanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(Icons.keyboard_arrow_down_rounded,
                                size: 22,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Expandable draft list ─────────────────────────────────────
                  AnimatedCrossFade(
                    duration: const Duration(milliseconds: 250),
                    firstCurve: Curves.easeOut,
                    secondCurve: Curves.easeIn,
                    crossFadeState: _expanded
                        ? CrossFadeState.showFirst
                        : CrossFadeState.showSecond,
                    firstChild: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Divider(height: 1, thickness: 1, color: borderColor),
                        ...previewDrafts.map((draft) => _MiniDraftTile(
                              draft: draft,
                              onTap: () => _openEditSheet(context, draft),
                            )),
                        if (pending.length > 3)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                            child: Text(
                              '+ ${pending.length - 3} more drafts',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.color,
                              ),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                          child: SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: ElevatedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SmsReviewInboxScreen(),
                                ),
                              ),
                              icon: const Icon(Icons.inbox_rounded, size: 18),
                              label: Text('View All ${pending.length} Drafts',
                                  style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    secondChild: const SizedBox.shrink(),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: IgnorePointer(
                  child: Container(width: 4, color: AppColors.primary),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Mini Draft Tile ──────────────────────────────────────────────────────────

class _MiniDraftTile extends StatelessWidget {
  final SmsDraftModel draft;
  final VoidCallback onTap;
  const _MiniDraftTile({required this.draft, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isIncome = draft.txType == TransactionType.income;
    final isWithdrawal = draft.isWithdrawal;
    final accent = isIncome
        ? AppColors.income
        : isWithdrawal
            ? AppColors.primary
            : AppColors.expense;
    final symbol = context.watch<SettingsProvider>().currencySymbol;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade100;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: borderColor, width: 1)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                isWithdrawal
                    ? Icons.swap_horiz_rounded
                    : isIncome
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                color: accent,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    draft.title.isEmpty ? draft.bank : draft.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    '${draft.bank} · ${draft.category}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      isWithdrawal
                          ? CurrencyFormatter.format(draft.amount,
                              symbol: symbol)
                          : CurrencyFormatter.formatWithSign(
                              isIncome ? draft.amount : -draft.amount,
                              symbol: symbol,
                            ),
                      maxLines: 1,
                      softWrap: false,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: accent),
                    ),
                  ),
                  Text(
                    draft.transactionDate == null
                        ? 'Unknown date'
                        : CurrencyFormatter.shortDate(draft.transactionDate!),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textHint),
          ],
        ),
      ),
    );
  }
}

// ─── Dashboard Inline Draft Edit Sheet ───────────────────────────────────────

class _DashboardDraftEditSheet extends StatefulWidget {
  final SmsDraftModel draft;
  const _DashboardDraftEditSheet({required this.draft});

  @override
  State<_DashboardDraftEditSheet> createState() =>
      _DashboardDraftEditSheetState();
}

class _DashboardDraftEditSheetState extends State<_DashboardDraftEditSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _amountCtrl;
  late TransactionType _type;
  late DraftKind _kind;
  late String _category;
  late String _wallet;
  late DateTime? _date;
  int? _fromWalletId;
  int? _toWalletId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.draft.title);
    _amountCtrl =
        TextEditingController(text: widget.draft.amount.toStringAsFixed(2));
    _type = widget.draft.txType;
    _kind = widget.draft.kind;
    _category = widget.draft.category;
    _wallet = widget.draft.walletName;
    _date = widget.draft.transactionDate;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  List<String> _categoryOptions() {
    const incomeNames = ['Salary', 'Freelance', 'Investment', 'Gift', 'Other'];
    const expenseNames = [
      'Food',
      'Transport',
      'Bills',
      'Health',
      'Education',
      'Entertainment',
      'Shopping',
      'Other',
    ];
    final names = _type == TransactionType.income
        ? List<String>.from(incomeNames)
        : List<String>.from(expenseNames);
    if (!names.contains(_category)) names.add(_category);
    return names;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  WalletModel? _walletById(List<WalletModel> wallets, int? id) {
    if (id == null) return null;
    for (final w in wallets) {
      if (w.id == id) return w;
    }
    return null;
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Enter a valid amount.',
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppColors.expense,
      ));
      return;
    }
    setState(() => _saving = true);

    final smsProvider = context.read<SmsDraftProvider>();
    final txProvider = context.read<TransactionProvider>();
    final walletProvider = context.read<WalletProvider>();
    final updated = widget.draft.copyWith(
      title: _titleCtrl.text.trim().isEmpty
          ? widget.draft.bank
          : _titleCtrl.text.trim(),
      amount: amount,
      txType: _type,
      kind: _kind,
      category: _category,
      walletName: _kind == DraftKind.withdrawal ? null : _wallet,
      transactionDate: _date,
    );

    if (_kind == DraftKind.withdrawal) {
      final wallets = walletProvider.wallets;
      final from = _walletById(wallets, _fromWalletId) ??
          SmsDraftProvider.bestBankWallet(wallets, widget.draft.bank);
      final to = _walletById(wallets, _toWalletId) ??
          SmsDraftProvider.bestCashWallet(wallets);
      if (from == null || to == null || from.id == to.id) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(from == null || to == null
              ? 'Add the bank and cash wallets first.'
              : 'Choose two different wallets.'),
          backgroundColor: AppColors.expense,
        ));
        return;
      }
      await walletProvider.transferBetweenWallets(
        fromId: from.id!,
        toId: to.id!,
        amount: amount,
        date: _date ?? DateTime.now(),
        note: SmsDraftProvider.describe(updated),
        smsBody: SmsDraftProvider.messageText(updated),
      );
      await smsProvider.markSaved(widget.draft.id!);
    } else {
      await txProvider.addTransaction(smsProvider.toTransaction(updated));
      await smsProvider.markSaved(widget.draft.id!);
    }
    // Refresh the transactions list so the Recent Transactions section updates.
    if (mounted) txProvider.loadAll();
    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _dismiss() async {
    await context.read<SmsDraftProvider>().dismissDraft(widget.draft.id!);
    if (mounted) Navigator.pop(context);
  }

  InputDecoration _inputDec(String hint, Color borderColor, bool isDark) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.poppins(fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: borderColor)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: AppColors.primary, width: 1.5)),
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;
    final symbol = context.watch<SettingsProvider>().currencySymbol;
    final wallets = context.watch<WalletProvider>().wallets;
    final walletNamesRaw = wallets.map((w) => w.name).toList();
    if (!walletNamesRaw.contains(_wallet)) walletNamesRaw.add(_wallet);
    final walletNames = walletNamesRaw.toSet().toList(); // deduplicate
    final isWithdrawal = _kind == DraftKind.withdrawal;
    final fromWallet = _walletById(wallets, _fromWalletId) ??
        SmsDraftProvider.bestBankWallet(wallets, widget.draft.bank);
    final toWallet = _walletById(wallets, _toWalletId) ??
        SmsDraftProvider.bestCashWallet(wallets);

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                        color: borderColor,
                        borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Review SMS Draft',
                              style: GoogleFonts.poppins(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.darkTextPrimary
                                    : AppColors.textPrimary,
                              )),
                          Text(
                            'From ${widget.draft.bank} · ${widget.draft.transactionDate == null ? 'Unknown date' : CurrencyFormatter.shortDate(widget.draft.transactionDate!)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),

                // Captured bank SMS (original content)
                const SizedBox(height: 10),
                SmsMessageCard(draft: widget.draft),
                const SizedBox(height: 14),

                // Amount display
                Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${isWithdrawal ? '' : _type == TransactionType.income ? '+' : '-'}'
                      '${CurrencyFormatter.format(double.tryParse(_amountCtrl.text.replaceAll(',', '')) ?? widget.draft.amount, symbol: symbol)}',
                      maxLines: 1,
                      softWrap: false,
                      style: GoogleFonts.poppins(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: _kind == DraftKind.income
                            ? AppColors.income
                            : _kind == DraftKind.withdrawal
                                ? AppColors.primary
                                : AppColors.expense,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),

                // Kind selector
                _DashboardKindSelector(
                  kind: _kind,
                  onChange: (k) => setState(() {
                    _kind = k;
                    _type = k == DraftKind.income
                        ? TransactionType.income
                        : TransactionType.expense;
                    if (k == DraftKind.withdrawal) {
                      _category = 'Other';
                    } else if (!_categoryOptions().contains(_category)) {
                      _category = 'Other';
                    }
                  }),
                ),
                const SizedBox(height: 14),

                // Title
                Text('Title',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _titleCtrl,
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration:
                      _inputDec('Merchant / description', borderColor, isDark),
                ),
                const SizedBox(height: 14),

                // Amount (editable)
                Text('Amount',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                  ],
                  style: GoogleFonts.poppins(fontSize: 14),
                  onChanged: (_) => setState(() {}),
                  decoration: _inputDec('$symbol 0.00', borderColor, isDark)
                      .copyWith(prefixText: '$symbol  '),
                ),
                const SizedBox(height: 14),

                // Category chips
                if (!isWithdrawal) ...[
                  Text('Category',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _categoryOptions()
                        .map((c) => GestureDetector(
                              onTap: () => setState(() => _category = c),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: c == _category
                                      ? AppColors.primary
                                          .withValues(alpha: 0.12)
                                      : isDark
                                          ? AppColors.darkSurface2
                                          : Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: c == _category
                                        ? AppColors.primary
                                            .withValues(alpha: 0.5)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Text(
                                  c,
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: c == _category
                                        ? AppColors.primary
                                        : Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.color,
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 14),
                ],

                // Wallet / transfer pickers
                if (isWithdrawal) ...[
                  Text('From wallet (${widget.draft.bank})',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: fromWallet?.id,
                    isExpanded: true,
                    decoration: _inputDec('Bank wallet', borderColor, isDark),
                    style: GoogleFonts.poppins(fontSize: 14),
                    items: wallets
                        .map((w) =>
                            DropdownMenuItem(value: w.id, child: Text(w.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _fromWalletId = v),
                  ),
                  const SizedBox(height: 14),
                  Text('To wallet (Cash)',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<int>(
                    value: toWallet?.id,
                    isExpanded: true,
                    decoration: _inputDec('Cash wallet', borderColor, isDark),
                    style: GoogleFonts.poppins(fontSize: 14),
                    items: wallets
                        .map((w) =>
                            DropdownMenuItem(value: w.id, child: Text(w.name)))
                        .toList(),
                    onChanged: (v) => setState(() => _toWalletId = v),
                  ),
                  const SizedBox(height: 14),
                ] else ...[
                  Text('Wallet',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: walletNames.contains(_wallet)
                        ? _wallet
                        : walletNames.firstOrNull,
                    isExpanded: true,
                    decoration: _inputDec('Wallet', borderColor, isDark),
                    style: GoogleFonts.poppins(fontSize: 14),
                    items: walletNames
                        .map((w) => DropdownMenuItem(value: w, child: Text(w)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _wallet = v);
                    },
                  ),
                  const SizedBox(height: 14),
                ],

                // Date picker
                Text('Date',
                    style: GoogleFonts.poppins(
                        fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Text(
                          _date == null
                              ? 'Now'
                              : CurrencyFormatter.shortDate(_date!),
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Save / Dismiss
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: _saving ? null : _dismiss,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.expense,
                            side: const BorderSide(color: AppColors.expense),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('Dismiss',
                                maxLines: 1,
                                softWrap: false,
                                style: GoogleFonts.poppins(
                                    fontSize: 15, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _saving ? null : _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  height: 18,
                                  width: 18,
                                  child: CircularProgressIndicator(
                                      color: Colors.white, strokeWidth: 2))
                              : FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text('Save Transaction',
                                      maxLines: 1,
                                      softWrap: false,
                                      style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600)),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Dashboard Kind Selector ──────────────────────────────────────────────────

class _DashboardKindSelector extends StatelessWidget {
  final DraftKind kind;
  final ValueChanged<DraftKind> onChange;
  const _DashboardKindSelector({required this.kind, required this.onChange});

  @override
  Widget build(BuildContext context) {
    Widget option(DraftKind k, String label, IconData icon, Color color) {
      final selected = kind == k;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChange(k),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color:
                  selected ? color.withValues(alpha: 0.14) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      maxLines: 1,
                      softWrap: false,
                      style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? color
                              : Theme.of(context).textTheme.bodySmall?.color),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.darkSurface
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          option(DraftKind.expense, 'Expense', Icons.arrow_upward_rounded,
              AppColors.expense),
          const SizedBox(width: 4),
          option(DraftKind.withdrawal, 'Withdraw', Icons.swap_horiz_rounded,
              AppColors.primary),
          const SizedBox(width: 4),
          option(DraftKind.income, 'Income', Icons.arrow_downward_rounded,
              AppColors.income),
        ],
      ),
    );
  }
}
