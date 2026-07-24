import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/wallet_model.dart';
import '../providers/settings_provider.dart';
import '../providers/wallet_provider.dart';

class TransferMoneyScreen extends StatefulWidget {
  final WalletModel? fromWallet;
  const TransferMoneyScreen({super.key, this.fromWallet});

  @override
  State<TransferMoneyScreen> createState() => _TransferMoneyScreenState();
}

class _TransferMoneyScreenState extends State<TransferMoneyScreen> {
  WalletModel? _fromWallet;
  WalletModel? _toWallet;
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _isTransferring = false;

  @override
  void initState() {
    super.initState();
    _fromWallet = widget.fromWallet;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double get _amount =>
      double.tryParse(_amountController.text.trim()) ?? 0.0;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _confirmTransfer() async {
    if (_fromWallet == null || _toWallet == null) {
      _showError('Please select both wallets');
      return;
    }
    if (_fromWallet!.id == _toWallet!.id) {
      _showError('From and To wallet must be different');
      return;
    }
    if (_amount <= 0) {
      _showError('Enter a valid amount');
      return;
    }
    if (_amount > _fromWallet!.balance) {
      _showError('Insufficient balance in ${_fromWallet!.name}');
      return;
    }

    setState(() => _isTransferring = true);
    try {
      await context.read<WalletProvider>().transferBetweenWallets(
            fromId: _fromWallet!.id!,
            toId: _toWallet!.id!,
            amount: _amount,
            date: _selectedDate,
            note: _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transfer successful!'),
            backgroundColor: AppColors.income,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.expense),
    );
  }

  Future<void> _pickWallet({required bool isFrom}) async {
    final wallets = context.read<WalletProvider>().wallets;
    final result = await showModalBottomSheet<WalletModel>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _WalletPickerSheet(
        wallets: wallets,
        excludeId: isFrom ? _toWallet?.id : _fromWallet?.id,
        currencySymbol:
            context.read<SettingsProvider>().currencySymbol,
      ),
    );
    if (result != null) {
      setState(() {
        if (isFrom) {
          _fromWallet = result;
        } else {
          _toWallet = result;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final sym = settings.currencySymbol;

    final fromBal = _fromWallet?.balance ?? 0;
    final toBal = _toWallet?.balance ?? 0;
    final afterFrom = fromBal - _amount;
    final afterTo = toBal + _amount;

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
          'Transfer Money',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
        children: [
          // ── Visual From → To header ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EFFD),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                // From wallet
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (_fromWallet != null) ...[
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _fromWallet!.lightColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(_fromWallet!.icon,
                                  color: _fromWallet!.color, size: 18),
                            ),
                            const SizedBox(width: 8),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _fromWallet?.name ?? 'Select',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_fromWallet != null)
                                  Text(
                                    CurrencyFormatter.format(fromBal,
                                        symbol: sym),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Arrow
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _buildDash(),
                      _buildDash(),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 16),
                      ),
                      _buildDash(),
                      _buildDash(),
                    ],
                  ),
                ),
                // To wallet
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'To',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _toWallet?.name ?? 'Select',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  textAlign: TextAlign.end,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (_toWallet != null)
                                  Text(
                                    CurrencyFormatter.format(toBal,
                                        symbol: sym),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (_toWallet != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _toWallet!.lightColor,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(_toWallet!.icon,
                                  color: _toWallet!.color, size: 18),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // ── From Wallet Selector ──────────────────────────────────────
          _FieldCard(
            onTap: () => _pickWallet(isFrom: true),
            child: Row(
              children: [
                if (_fromWallet != null)
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _fromWallet!.lightColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_fromWallet!.icon,
                        color: _fromWallet!.color, size: 20),
                  )
                else
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined,
                        color: AppColors.primary, size: 20),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'From Wallet',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _fromWallet?.name ?? 'Select wallet',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _fromWallet != null
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_fromWallet != null)
                  Text(
                    CurrencyFormatter.format(fromBal, symbol: sym),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── To Wallet Selector ────────────────────────────────────────
          _FieldCard(
            onTap: () => _pickWallet(isFrom: false),
            child: Row(
              children: [
                if (_toWallet != null)
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: _toWallet!.lightColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_toWallet!.icon,
                        color: _toWallet!.color, size: 20),
                  )
                else
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.incomeLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.account_balance_wallet_outlined,
                        color: AppColors.income, size: 20),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'To Wallet',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        _toWallet?.name ?? 'Select wallet',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _toWallet != null
                              ? AppColors.textPrimary
                              : AppColors.textHint,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_toWallet != null)
                  Text(
                    CurrencyFormatter.format(toBal, symbol: sym),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Amount ────────────────────────────────────────────────────
          _FieldCard(
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.currency_rupee_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Amount (Rs.)',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      TextField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,2}')),
                        ],
                        onChanged: (_) => setState(() {}),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter amount',
                          hintStyle: GoogleFonts.inter(
                            fontSize: 14,
                            color: AppColors.textHint,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Date ──────────────────────────────────────────────────────
          _FieldCard(
            onTap: _pickDate,
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Date',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.shortDate(_selectedDate),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.calendar_today_outlined,
                    color: AppColors.textHint, size: 20),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // ── Note ──────────────────────────────────────────────────────
          _FieldCard(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_outlined,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Stack(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Note (Optional)',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          TextField(
                            controller: _noteController,
                            maxLength: 60,
                            onChanged: (_) => setState(() {}),
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Add a note for this transfer',
                              hintStyle: GoogleFonts.inter(
                                fontSize: 13,
                                color: AppColors.textHint,
                              ),
                              border: InputBorder.none,
                              counterText: '',
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Text(
                          '${_noteController.text.length}/60',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textHint,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Info ──────────────────────────────────────────────────────
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 15, color: AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(
                'Transfers do not affect total balance.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // ── After Transfer Preview ────────────────────────────────────
          if (_fromWallet != null && _toWallet != null) ...[
            Text(
              'After Transfer',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
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
                children: [
                  _AfterTransferRow(
                    wallet: _fromWallet!,
                    originalBalance: fromBal,
                    afterBalance: afterFrom,
                    sym: sym,
                    isDecrease: true,
                  ),
                  const Divider(height: 20),
                  _AfterTransferRow(
                    wallet: _toWallet!,
                    originalBalance: toBal,
                    afterBalance: afterTo,
                    sym: sym,
                    isDecrease: false,
                  ),
                ],
              ),
            ),
          ],
        ],
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
        child: SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isTransferring ? null : _confirmTransfer,
            icon: _isTransferring
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              'Confirm Transfer',
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDash() {
    return Container(
      width: 8,
      height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.5),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

// ─── Field Card ────────────────────────────────────────────────────────────────

class _FieldCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _FieldCard({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
        child: child,
      ),
    );
  }
}

// ─── After Transfer Row ────────────────────────────────────────────────────────

class _AfterTransferRow extends StatelessWidget {
  final WalletModel wallet;
  final double originalBalance;
  final double afterBalance;
  final String sym;
  final bool isDecrease;

  const _AfterTransferRow({
    required this.wallet,
    required this.originalBalance,
    required this.afterBalance,
    required this.sym,
    required this.isDecrease,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: wallet.lightColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(wallet.icon, color: wallet.color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                wallet.name,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                CurrencyFormatter.format(originalBalance, symbol: sym),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.arrow_forward_rounded,
            color: AppColors.textHint, size: 16),
        const SizedBox(width: 8),
        Text(
          isDecrease
              ? '${CurrencyFormatter.format(originalBalance, symbol: sym)} - Amount'
              : '${CurrencyFormatter.format(originalBalance, symbol: sym)} + Amount',
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDecrease ? AppColors.expense : AppColors.income,
          ),
        ),
      ],
    );
  }
}

// ─── Wallet Picker Sheet ───────────────────────────────────────────────────────

class _WalletPickerSheet extends StatelessWidget {
  final List<WalletModel> wallets;
  final int? excludeId;
  final String currencySymbol;

  const _WalletPickerSheet({
    required this.wallets,
    this.excludeId,
    required this.currencySymbol,
  });

  @override
  Widget build(BuildContext context) {
    final filtered =
        wallets.where((w) => w.id != excludeId).toList();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
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
            Text(
              'Select Wallet',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            if (filtered.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No wallets available',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
            else
              ...filtered.map((wallet) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: wallet.lightColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(wallet.icon,
                          color: wallet.color, size: 22),
                    ),
                    title: Text(
                      wallet.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Text(
                      CurrencyFormatter.format(wallet.balance,
                          symbol: currencySymbol),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    onTap: () => Navigator.pop(context, wallet),
                  )),
          ],
        ),
      ),
    );
  }
}
