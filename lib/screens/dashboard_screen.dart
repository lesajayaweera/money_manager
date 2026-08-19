import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../main_scaffold.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import 'add_transaction_screen.dart';
import 'create_budget_screen.dart';
import 'goals_screen.dart';
import 'lends_borrowed_screen.dart';
import 'quick_add_transaction_sheet.dart';

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
              Icon(Icons.widgets_outlined, color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white, size: 26),
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
                  color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
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
                      lightColor: Theme.of(context).brightness == Brightness.dark ? AppColors.darkPrimarySurface : AppColors.primarySurface,
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
              height: 145,
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (p) => setState(() => _page = p),
                children: [
                  // ── Card 1: Total Balance ───────────────────────────────
                  GestureDetector(
                    onTap: () => _showCashFlowSheet(context, cashIn, cashOut, sym),
                    child: _TotalBalanceCard(
                      settings: settings,
                      totalBalance: walletProvider.totalBalance,
                    ),
                  ),

                  // ── Card 2: Net Cash Flow ───────────────────────────────
                  GestureDetector(
                    onTap: () => _showCashFlowSheet(context, cashIn, cashOut, sym),
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
            child: settings.balanceVisible
                ? Text(
                    CurrencyFormatter.format(totalBalance,
                        symbol: settings.currencySymbol),
                    key: const ValueKey('vis'),
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  )
                : Text(
                    '${settings.currencySymbol} ••••••',
                    key: const ValueKey('hid'),
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 4,
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
    final pct = cashIn == 0
        ? 0.0
        : ((netCashFlow / cashIn) * 100).clamp(-999.0, 999.0);
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
              Text(
                'Net Cash Flow',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '− $pctStr',
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
          visible
              ? Text(
                  CurrencyFormatter.format(netCashFlow,
                      symbol: currencySymbol),
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                )
              : Text(
                  '$currencySymbol ••••••',
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 2,
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
              Text(
                'Net Income',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
              Row(
                children: [
                  Text(
                    visible
                        ? CurrencyFormatter.format(cashIn,
                            symbol: currencySymbol)
                        : '••••••',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
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
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
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
                    color: netCashFlow >= 0 ? AppColors.income : AppColors.expense,
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
              color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              visible
                  ? CurrencyFormatter.format(amount, symbol: currencySymbol)
                  : '••••••',
              key: ValueKey(visible),
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
            Text(
              'Recent Transactions',
              style: GoogleFonts.poppins(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
              ),
            ),
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
              color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your first income or expense below',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.white,
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
                  (transaction.note != null &&
                          transaction.note!.trim().isNotEmpty)
                      ? transaction.note!
                      : transaction.title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  CurrencyFormatter.relativeDate(transaction.date),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                settings.balanceVisible
                    ? CurrencyFormatter.formatWithSign(
                        transaction.signedAmount,
                        symbol: settings.currencySymbol,
                      )
                    : '••••',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isIncome ? AppColors.income : AppColors.expense,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                transaction.walletName,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Theme.of(context).textTheme.bodySmall?.color ?? Colors.white,
                ),
              ),
            ],
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
                              ? [const Color(0xFF1A6B3A), const Color(0xFF27AE60)]
                              : [const Color(0xFF27AE60), const Color(0xFF2ECC71)],
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
                              ? [const Color(0xFF7B1C1C), const Color(0xFFE74C3C)]
                              : [const Color(0xFFE74C3C), const Color(0xFFFF6B6B)],
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
