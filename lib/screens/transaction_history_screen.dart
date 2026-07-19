import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../providers/category_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/settings_provider.dart';
import 'add_transaction_screen.dart';

class TransactionHistoryScreen extends StatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  State<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends State<TransactionHistoryScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Search bar (visible only when tapped)
          if (_showSearch)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (q) =>
                    context.read<TransactionProvider>().setSearchQuery(q),
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search transactions...',
                  hintStyle: GoogleFonts.inter(
                      color: AppColors.textHint, fontSize: 14),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AppColors.textSecondary, size: 20),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded,
                        size: 18, color: AppColors.textSecondary),
                    onPressed: () {
                      _searchController.clear();
                      context
                          .read<TransactionProvider>()
                          .setSearchQuery('');
                    },
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

          // Filter chips
          _FilterChipsRow(),

          // Transaction list
          Expanded(
            child: Consumer<TransactionProvider>(
              builder: (context, provider, _) {
                final transactions = provider.filteredTransactions;
                if (transactions.isEmpty) {
                  return _EmptyState(
                      hasSearch: _searchController.text.isNotEmpty);
                }
                return _GroupedList(transactions: transactions);
              },
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      title: Text(
        'Transactions',
        style: GoogleFonts.inter(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _showSearch
                ? Icons.search_off_rounded
                : Icons.filter_list_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () {
            setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchController.clear();
                context.read<TransactionProvider>().setSearchQuery('');
              }
            });
          },
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

// ─── Filter Chips ─────────────────────────────────────────────────────────────

class _FilterChipsRow extends StatelessWidget {
  const _FilterChipsRow();

  @override
  Widget build(BuildContext context) {
    return Consumer<TransactionProvider>(
      builder: (context, provider, _) {
        final activeFilter = provider.activeFilter;
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Chip(
                  label: 'All',
                  isActive: activeFilter == TransactionFilter.all,
                  activeColor: AppColors.primary,
                  textColor: AppColors.primary,
                  onTap: () => provider.setFilter(TransactionFilter.all),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'Income',
                  isActive: activeFilter == TransactionFilter.income,
                  activeColor: AppColors.income,
                  textColor: AppColors.income,
                  onTap: () =>
                      provider.setFilter(TransactionFilter.income),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'Expense',
                  isActive: activeFilter == TransactionFilter.expense,
                  activeColor: AppColors.expense,
                  textColor: AppColors.expense,
                  onTap: () =>
                      provider.setFilter(TransactionFilter.expense),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'Today',
                  isActive: activeFilter == TransactionFilter.today,
                  activeColor: AppColors.primary,
                  textColor: AppColors.textSecondary,
                  onTap: () =>
                      provider.setFilter(TransactionFilter.today),
                ),
                const SizedBox(width: 8),
                _Chip(
                  label: 'This Month',
                  isActive: activeFilter == TransactionFilter.thisMonth,
                  activeColor: AppColors.primary,
                  textColor: AppColors.textSecondary,
                  onTap: () =>
                      provider.setFilter(TransactionFilter.thisMonth),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isActive;
  final Color activeColor;
  final Color textColor;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? activeColor : const Color(0xFFE0E0E0),
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }
}

// ─── Grouped List ─────────────────────────────────────────────────────────────

class _GroupedList extends StatelessWidget {
  final List<TransactionModel> transactions;
  const _GroupedList({required this.transactions});

  @override
  Widget build(BuildContext context) {
    // Group transactions by month
    final groups = <String, List<TransactionModel>>{};
    for (final tx in transactions) {
      final key = DateFormat('MMMM yyyy').format(tx.date);
      groups.putIfAbsent(key, () => []).add(tx);
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: groups.length,
      itemBuilder: (ctx, groupIndex) {
        final month = groups.keys.elementAt(groupIndex);
        final txs = groups[month]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 12),
              child: Text(
                month,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ...txs.asMap().entries.map((entry) {
              final i = entry.key;
              final tx = entry.value;
              return _TxTile(
                transaction: tx,
                isLast: i == txs.length - 1,
                onEdit: () => _editTx(ctx, tx),
                onDelete: () => _deleteTx(ctx, tx),
              );
            }),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Future<void> _editTx(BuildContext context, TransactionModel tx) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          initialType: tx.type,
          editTransaction: tx,
        ),
      ),
    );
    if (result == true && context.mounted) {
      context.read<TransactionProvider>().loadAll();
    }
  }

  Future<void> _deleteTx(
      BuildContext context, TransactionModel tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Delete Transaction',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'Delete "${tx.title}"?',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style:
                    GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: GoogleFonts.inter(
                    color: AppColors.expense,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted && tx.id != null) {
      try {
        await context.read<TransactionProvider>().deleteTransaction(tx.id!);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }
}

// ─── Transaction Tile ─────────────────────────────────────────────────────────

class _TxTile extends StatelessWidget {
  final TransactionModel transaction;
  final bool isLast;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TxTile({
    required this.transaction,
    required this.isLast,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final categoryProvider = context.watch<CategoryProvider>();
    final type = transaction.isIncome ? CategoryType.income : CategoryType.expense;
    final cat = categoryProvider.findByName(transaction.category, type) ??
        (type == CategoryType.income
            ? AppCategory.defaultIncomeCategories.last
            : AppCategory.defaultExpenseCategories.last);
    final settings = context.watch<SettingsProvider>();
    final isIncome = transaction.isIncome;

    return Dismissible(
      key: ValueKey('tx-${transaction.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 1),
        decoration: BoxDecoration(
          color: AppColors.expense.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColors.expense),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: InkWell(
        onTap: onEdit,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            border: isLast
                ? null
                : const Border(
                    bottom: BorderSide(color: Color(0xFFF5F5F5))),
          ),
          child: Row(
            children: [
              // Category icon circle
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: cat.color,
                  shape: BoxShape.circle,
                ),
                child: Icon(cat.icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              // Title + date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (transaction.note != null && transaction.note!.trim().isNotEmpty)
                          ? transaction.note!
                          : transaction.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      CurrencyFormatter.shortDate(transaction.date),
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
                settings.balanceVisible
                    ? (isIncome ? '+' : '-') +
                        '${settings.currencySymbol} ' +
                        NumberFormat('#,##,###')
                            .format(transaction.amount)
                    : '••••',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isIncome ? AppColors.income : AppColors.expense,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasSearch;
  const _EmptyState({required this.hasSearch});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            hasSearch
                ? Icons.search_off_rounded
                : Icons.receipt_long_outlined,
            size: 64,
            color: AppColors.textHint,
          ),
          const SizedBox(height: 16),
          Text(
            hasSearch ? 'No results found' : 'No transactions yet',
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasSearch
                ? 'Try a different search term'
                : 'Add your first transaction\nfrom the Dashboard',
            style: GoogleFonts.inter(
                fontSize: 13, color: AppColors.textHint),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
