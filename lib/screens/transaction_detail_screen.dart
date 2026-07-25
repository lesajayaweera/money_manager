import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/wallet_provider.dart';
import 'add_transaction_screen.dart';

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  late TransactionModel _tx;

  @override
  void initState() {
    super.initState();
    _tx = widget.transaction;
  }

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
                title: Text('Edit Transaction',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context);
                  final result = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => AddTransactionScreen(
                        initialType: _tx.type,
                        editTransaction: _tx,
                      ),
                    ),
                  );
                  if (result == true && mounted) {
                    final provider = context.read<TransactionProvider>();
                    await provider.loadAll();
                    final updated = provider.allTransactions.firstWhere(
                      (e) => e.id == _tx.id,
                      orElse: () => _tx,
                    );
                    setState(() => _tx = updated);
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
                title: Text('Delete Transaction',
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
                      title: Text('Delete Transaction',
                          style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
                      content: Text('Are you sure you want to delete this transaction?',
                          style: GoogleFonts.inter()),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('Delete',
                              style: GoogleFonts.inter(color: AppColors.expense)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true && mounted) {
                    final txProvider = context.read<TransactionProvider>();
                    final walletProvider = context.read<WalletProvider>();
                    final nav = Navigator.of(context);
                    await txProvider.deleteTransaction(_tx.id!);
                    if (mounted) {
                      await walletProvider.loadWallets();
                      nav.pop(true);
                    }
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
    final categoryProvider = context.watch<CategoryProvider>();
    final type = _tx.isIncome ? CategoryType.income : CategoryType.expense;
    final cat = categoryProvider.findByName(_tx.category, type) ??
        (type == CategoryType.income
            ? AppCategory.defaultIncomeCategories.last
            : AppCategory.defaultExpenseCategories.last);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context, true),
        ),
        title: Text(
          'Transaction Details',
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
          children: [
            // Amount Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
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
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: cat.color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(cat.icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _tx.title,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    CurrencyFormatter.formatWithSign(_tx.signedAmount,
                        symbol: settings.currencySymbol),
                    style: GoogleFonts.inter(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: _tx.isIncome ? AppColors.income : AppColors.expense,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Details List
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
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
                  _buildDetailRow(
                    'Category',
                    _tx.category,
                    icon: Icons.category_rounded,
                  ),
                  _buildDivider(),
                  _buildDetailRow(
                    'Date',
                    CurrencyFormatter.shortDate(_tx.date),
                    icon: Icons.calendar_today_rounded,
                  ),
                  _buildDivider(),
                  _buildDetailRow(
                    'Time',
                    CurrencyFormatter.time(_tx.date),
                    icon: Icons.access_time_rounded,
                  ),
                  _buildDivider(),
                  _buildDetailRow(
                    'Wallet',
                    _tx.walletName,
                    icon: Icons.account_balance_wallet_rounded,
                  ),
                  if (_tx.note != null && _tx.note!.isNotEmpty) ...[
                    _buildDivider(),
                    _buildDetailRow(
                      'Note',
                      _tx.note!,
                      icon: Icons.notes_rounded,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {required IconData icon}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 15,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: const Color(0xFFF5F5F5),
      margin: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}
