import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/transaction_model.dart';
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
  TransactionType? _selectedFilter;

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
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Transactions',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search + Filter
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Column(
              children: [
                // Search bar
                TextField(
                  controller: _searchController,
                  onChanged: (q) {
                    context.read<TransactionProvider>().setSearchQuery(q);
                  },
                  style: GoogleFonts.inter(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search transactions...',
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: AppColors.textSecondary, size: 20),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded,
                                size: 18, color: AppColors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                              context
                                  .read<TransactionProvider>()
                                  .setSearchQuery('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 10),
                // Filter chips
                Row(
                  children: [
                    _FilterChip(
                      label: 'All',
                      isSelected: _selectedFilter == null,
                      color: AppColors.primary,
                      onTap: () {
                        setState(() => _selectedFilter = null);
                        context
                            .read<TransactionProvider>()
                            .setFilterType(null);
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Income',
                      isSelected: _selectedFilter == TransactionType.income,
                      color: AppColors.income,
                      onTap: () {
                        setState(
                            () => _selectedFilter = TransactionType.income);
                        context
                            .read<TransactionProvider>()
                            .setFilterType(TransactionType.income);
                      },
                    ),
                    const SizedBox(width: 8),
                    _FilterChip(
                      label: 'Expense',
                      isSelected: _selectedFilter == TransactionType.expense,
                      color: AppColors.expense,
                      onTap: () {
                        setState(
                            () => _selectedFilter = TransactionType.expense);
                        context
                            .read<TransactionProvider>()
                            .setFilterType(TransactionType.expense);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Transaction list
          Expanded(
            child: Consumer<TransactionProvider>(
              builder: (context, provider, _) {
                final transactions = provider.filteredTransactions;
                if (transactions.isEmpty) {
                  return _EmptyState(
                    hasSearch: _searchController.text.isNotEmpty ||
                        _selectedFilter != null,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    // Group by date
                    final tx = transactions[index];
                    final showDateHeader = index == 0 ||
                        !_isSameDay(
                            transactions[index - 1].date, tx.date);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showDateHeader) ...[
                          Padding(
                            padding:
                                const EdgeInsets.only(top: 16, bottom: 8),
                            child: Text(
                              CurrencyFormatter.relativeDate(tx.date),
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                        _TransactionCard(
                          transaction: tx,
                          onEdit: () => _editTransaction(tx),
                          onDelete: () => _deleteTransaction(tx),
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Future<void> _editTransaction(TransactionModel tx) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          initialType: tx.type,
          editTransaction: tx,
        ),
      ),
    );
    if (result == true && mounted) {
      context.read<TransactionProvider>().loadAll();
    }
  }

  Future<void> _deleteTransaction(TransactionModel tx) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Delete Transaction',
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'Are you sure you want to delete "${tx.title}"?',
          style: GoogleFonts.inter(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(
                  color: AppColors.expense, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await context.read<TransactionProvider>().deleteTransaction(tx.id!);
    }
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TransactionCard({
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final category =
        CategoryModel.findByName(transaction.category) ??
            CategoryModel.fallback(transaction.type);
    final settings = context.watch<SettingsProvider>();
    final isIncome = transaction.isIncome;

    return Dismissible(
      key: ValueKey(transaction.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.expense,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false;
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: category.lightColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(category.icon, color: category.color, size: 22),
          ),
          title: Text(
            transaction.title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.category,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              if (transaction.note != null && transaction.note!.isNotEmpty)
                Text(
                  transaction.note!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppColors.textHint,
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          trailing: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                settings.balanceVisible
                    ? CurrencyFormatter.formatWithSign(
                        transaction.signedAmount,
                        symbol: settings.currencySymbol,
                      )
                    : '••••',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isIncome ? AppColors.income : AppColors.expense,
                ),
              ),
              Text(
                CurrencyFormatter.time(transaction.date),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
          onTap: onEdit,
        ),
      ),
    );
  }
}

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
                : 'Add your first transaction using the\nDashboard',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textHint,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
