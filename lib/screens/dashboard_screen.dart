import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../main_scaffold.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import 'add_transaction_screen.dart';
import 'goals_screen.dart';
import 'lends_borrowed_screen.dart';

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

  Future<void> _openAddTransaction(TransactionType type) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(initialType: type),
      ),
    );
    if (result == true && mounted) {
      context.read<TransactionProvider>().loadAll();
    }
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
            return const Center(
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
      bottomSheet: _ActionButtons(onAdd: _openAddTransaction),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              Icon(Icons.menu, color: Theme.of(context).textTheme.titleLarge?.color ?? Colors.white, size: 26),
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
                  color: const Color(0xFFE0E0E0),
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
                      lightColor: AppColors.primarySurface,
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

// ─── Balance Card ─────────────────────────────────────────────────────────────

class _BalanceCard extends StatelessWidget {
  final DashboardSummary summary;
  const _BalanceCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
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
                    'Total Balance',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.85),
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
                          color: Colors.white.withOpacity(0.85),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
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
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: settings.balanceVisible
                        ? Text(
                            CurrencyFormatter.format(
                              summary.totalBalance,
                              symbol: settings.currencySymbol,
                            ),
                            key: const ValueKey('visible'),
                            style: GoogleFonts.poppins(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -1,
                            ),
                          )
                        : Text(
                            '${settings.currencySymbol} ••••••',
                            key: const ValueKey('hidden'),
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
            ],
          ),
        );
      },
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

// ─── Action Buttons ───────────────────────────────────────────────────────────

class _ActionButtons extends StatelessWidget {
  final Future<void> Function(TransactionType) onAdd;
  const _ActionButtons({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: Colors.grey.withOpacity(0.1)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => onAdd(TransactionType.income),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Income'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.income,
                side: const BorderSide(color: AppColors.income, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => onAdd(TransactionType.expense),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Expense'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
