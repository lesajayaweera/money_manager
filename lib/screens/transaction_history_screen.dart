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
import '../providers/wallet_provider.dart';
import 'transaction_detail_screen.dart';

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
            child: Consumer2<TransactionProvider, WalletProvider>(
              builder: (context, provider, walletProvider, _) {
                final txs = provider.filteredTransactions;
                
                // Map transfers to dummy transactions (Out and In)
                final allTransfers = walletProvider.allTransfers;
                final mappedTransfers = allTransfers.expand((t) {
                   final fromW = walletProvider.findById(t.fromWalletId);
                   final toW = walletProvider.findById(t.toWalletId);
                   
                   final baseTitleOut = (t.note != null && t.note!.isNotEmpty) 
                       ? t.note! 
                       : 'Transfer to ${toW?.name ?? '?'}';
                   
                   final baseTitleIn = (t.note != null && t.note!.isNotEmpty) 
                       ? t.note! 
                       : 'Transfer from ${fromW?.name ?? '?'}';

                   final outTx = TransactionModel(
                     id: -(t.id ?? 999999) * 2,
                     title: '$baseTitleOut (Out)',
                     amount: t.amount,
                     type: TransactionType.expense,
                     category: 'Transfer',
                     date: t.date,
                     note: null, // Note is integrated into title
                     walletName: fromW?.name ?? 'Unknown',
                   );

                   final inTx = TransactionModel(
                     id: -(t.id ?? 999999) * 2 - 1,
                     title: '$baseTitleIn (In)',
                     amount: t.amount,
                     type: TransactionType.income,
                     category: 'Transfer',
                     date: t.date,
                     note: null,
                     walletName: toW?.name ?? 'Unknown',
                   );

                   return [outTx, inTx];
                }).where((tx) {
                  // Apply active filters
                  final f = provider.activeFilter;
                  if (f == TransactionFilter.income) return false; // Hide transfers when filtering income
                  if (f == TransactionFilter.expense) return false; // Hide transfers when filtering expense
                  final now = DateTime.now();
                  if (f == TransactionFilter.today) {
                    if (tx.date.year != now.year || tx.date.month != now.month || tx.date.day != now.day) return false;
                  }
                  if (f == TransactionFilter.thisMonth) {
                    if (tx.date.year != now.year || tx.date.month != now.month) return false;
                  }
                  if (provider.searchQuery.isNotEmpty) {
                    final q = provider.searchQuery.toLowerCase();
                    if (!tx.title.toLowerCase().contains(q) && !(tx.note?.toLowerCase().contains(q) ?? false)) return false;
                  }
                  return true;
                }).toList();
                
                final transactions = [...txs, ...mappedTransfers];
                transactions.sort((a, b) => b.date.compareTo(a.date));

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
                onEdit: () async {
                        final result = await Navigator.of(context).push<bool>(
                          MaterialPageRoute(
                            builder: (_) => TransactionDetailScreen(
                              transaction: tx,
                            ),
                          ),
                        );
                        if (result == true && context.mounted) {
                          await context.read<TransactionProvider>().loadAll();
                        }
                      },
                onDelete: () => _deleteTx(ctx, tx),
              );
            }),
            const SizedBox(height: 8),
          ],
        );
      },
    );
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
    final walletProvider = context.watch<WalletProvider>();
    final type = transaction.isIncome ? CategoryType.income : CategoryType.expense;
    final settings = context.watch<SettingsProvider>();
    final isIncome = transaction.isIncome;
    
    final isTransfer = transaction.category == 'Transfer';
    final matchingWallets = walletProvider.wallets.where((w) => w.name == transaction.walletName);
    final transferWallet = (isTransfer && matchingWallets.isNotEmpty) ? matchingWallets.first : null;

    final Color bgColor;
    final IconData iconData;
    if (isTransfer && transferWallet != null) {
      bgColor = Color(transferWallet.colorValue);
      iconData = IconData(transferWallet.iconCodePoint, fontFamily: 'MaterialIcons');
    } else {
      final cat = categoryProvider.findByName(transaction.category, type) ??
          (type == CategoryType.income
              ? AppCategory.defaultIncomeCategories.last
              : AppCategory.defaultExpenseCategories.last);
      bgColor = cat.color;
      iconData = cat.icon;
    }

    return Dismissible(
      key: ValueKey('tx-${transaction.id}'),
      direction: isTransfer ? DismissDirection.none : DismissDirection.endToStart,
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
        onTap: isTransfer ? null : onEdit,
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
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(iconData, color: Colors.white, size: 20),
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatWithSign(transaction.signedAmount,
                        symbol: settings.currencySymbol),
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isIncome ? AppColors.income : AppColors.expense,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    transaction.walletName,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textHint,
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
