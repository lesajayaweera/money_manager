import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/wallet_model.dart';
import '../models/transaction_model.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';
import 'add_edit_wallet_screen.dart';
import 'transfer_money_screen.dart';
import 'transaction_history_screen.dart';

class WalletDetailScreen extends StatefulWidget {
  final WalletModel wallet;
  const WalletDetailScreen({super.key, required this.wallet});

  @override
  State<WalletDetailScreen> createState() => _WalletDetailScreenState();
}

class _WalletDetailScreenState extends State<WalletDetailScreen> {
  late WalletModel _wallet;

  // Wallet-specific stats (we use overall transaction totals for now)
  double _monthIncome = 0;
  double _monthExpenses = 0;
  double _transfers = 0;
  List<WalletTransfer> _transfersList = [];

  @override
  void initState() {
    super.initState();
    _wallet = widget.wallet;
    _loadStats();
  }

  Future<void> _loadStats() async {
    final provider = context.read<TransactionProvider>();
    final walletProvider = context.read<WalletProvider>();
    final now = DateTime.now();
    final results = await Future.wait([
      provider.getTransactionsByMonth(now.year, now.month),
    ]);
    final txList = results[0];
    double income = 0, expenses = 0;
    for (final tx in txList) {
      if (tx.isIncome) {
        income += tx.amount;
      } else {
        expenses += tx.amount;
      }
    }
    // Transfers from wallet provider
    final transfers = await walletProvider.getTransfersForWallet(_wallet.id!);
    double transferTotal = 0;
    for (final t in transfers) {
      final now2 = DateTime.now();
      if (t.date.year == now2.year && t.date.month == now2.month) {
        transferTotal += t.amount;
      }
    }
    if (mounted) {
      setState(() {
        _monthIncome = income;
        _monthExpenses = expenses;
        _transfers = transferTotal;
        _transfersList = transfers;
      });
    }
  }

  Future<void> _openEdit() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditWalletScreen(wallet: _wallet),
      ),
    );
    if (result == true && mounted) {
      // Refresh wallet
      final updated = context.read<WalletProvider>().findById(_wallet.id!);
      if (updated != null) setState(() => _wallet = updated);
    }
  }

  void _openTransfer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransferMoneyScreen(fromWallet: _wallet),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final txProvider = context.watch<TransactionProvider>();
    final walletProvider = context.watch<WalletProvider>();
    
    // Convert transfers to TransactionModel for unified display
    final mappedTransfers = _transfersList.map((t) {
      final isIncome = t.toWalletId == _wallet.id;
      final otherWalletId = isIncome ? t.fromWalletId : t.toWalletId;
      final otherWallet = walletProvider.findById(otherWalletId);
      final title = isIncome 
          ? 'Transfer from ${otherWallet?.name ?? 'Wallet'}' 
          : 'Transfer to ${otherWallet?.name ?? 'Wallet'}';
      
      return TransactionModel(
        id: -(t.id ?? 999999), // Dummy negative id
        title: title,
        amount: t.amount,
        type: isIncome ? TransactionType.income : TransactionType.expense,
        category: 'Transfer',
        date: t.date,
        note: t.note,
        walletName: _wallet.name,
      );
    }).toList();

    // Combine standard recent transactions with transfers
    final combinedTxs = [
      ...txProvider.allTransactions,
      ...mappedTransfers
    ];
    // Sort combined by date descending
    combinedTxs.sort((a, b) => b.date.compareTo(a.date));
    
    final recentTxs = combinedTxs.take(5).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded,
              color: AppColors.textPrimary, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Wallet Details',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications_outlined,
                    color: AppColors.textPrimary, size: 26),
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
            onPressed: () {},
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Wallet Header Card ──────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _wallet.lightColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_wallet.icon, color: _wallet.color, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _wallet.name,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _wallet.status.lightColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _wallet.status.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _wallet.status.displayName,
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: _wallet.status.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _wallet.type.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          CurrencyFormatter.format(_wallet.balance,
                              symbol: settings.currencySymbol),
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Stats Row ───────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: _StatMiniCard(
                    icon: Icons.wallet_rounded,
                    iconColor: AppColors.income,
                    iconBgColor: AppColors.incomeLight,
                    label: 'This Month Income',
                    value: CurrencyFormatter.format(_monthIncome,
                        symbol: settings.currencySymbol),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatMiniCard(
                    icon: Icons.receipt_long_rounded,
                    iconColor: AppColors.expense,
                    iconBgColor: AppColors.expenseLight,
                    label: 'This Month Expenses',
                    value: CurrencyFormatter.format(_monthExpenses,
                        symbol: settings.currencySymbol),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatMiniCard(
                    icon: Icons.swap_horiz_rounded,
                    iconColor: AppColors.primary,
                    iconBgColor: AppColors.primarySurface,
                    label: 'Transfers',
                    value: CurrencyFormatter.format(_transfers,
                        symbol: settings.currencySymbol),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Recent Transactions ─────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Transactions',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const TransactionHistoryScreen(),
                    ));
                  },
                  child: Text(
                    'View All',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (recentTxs.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'No transactions yet',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
            else
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
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: recentTxs.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: 1, indent: 70, endIndent: 16),
                  itemBuilder: (context, index) {
                    return _TxTile(
                      tx: recentTxs[index],
                      currencySymbol: settings.currencySymbol,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        decoration: BoxDecoration(
          color: AppColors.background,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _openTransfer,
                icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                label: Text(
                  'Transfer Money',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _openEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(
                  'Edit Wallet',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Stat Mini Card ────────────────────────────────────────────────────────────

class _StatMiniCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String label;
  final String value;

  const _StatMiniCard({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Transaction Tile ──────────────────────────────────────────────────────────

class _TxTile extends StatelessWidget {
  final TransactionModel tx;
  final String currencySymbol;
  const _TxTile({required this.tx, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final isIncome = tx.isIncome;
    final walletProvider = context.watch<WalletProvider>();
    final isTransfer = tx.category == 'Transfer';
    final matchingWallets = walletProvider.wallets.where((w) => w.name == tx.walletName);
    final transferWallet = (isTransfer && matchingWallets.isNotEmpty) ? matchingWallets.first : null;

    final IconData iconData;
    final Color iconColor;
    final Color iconBgColor;

    if (isTransfer && transferWallet != null) {
      iconColor = Color(transferWallet.colorValue);
      iconBgColor = iconColor.withValues(alpha: 0.15);
      iconData = IconData(transferWallet.iconCodePoint, fontFamily: 'MaterialIcons');
    } else {
      iconData = isIncome
          ? Icons.account_balance_wallet_rounded
          : Icons.receipt_long_rounded;
      iconColor = isIncome ? AppColors.income : AppColors.expense;
      iconBgColor = isIncome ? AppColors.incomeLight : AppColors.expenseLight;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(iconData, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.note?.isNotEmpty == true ? tx.note! : tx.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  CurrencyFormatter.relativeDate(tx.date),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatWithSign(tx.signedAmount,
                    symbol: currencySymbol),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: isIncome ? AppColors.income : AppColors.expense,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                tx.walletName,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textHint,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
