import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/wallet_model.dart';
import '../providers/settings_provider.dart';
import '../providers/wallet_provider.dart';

class AddEditWalletScreen extends StatefulWidget {
  final WalletModel? wallet; // null = add mode, non-null = edit mode
  const AddEditWalletScreen({super.key, this.wallet});

  @override
  State<AddEditWalletScreen> createState() => _AddEditWalletScreenState();
}

class _AddEditWalletScreenState extends State<AddEditWalletScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();
  final _noteController = TextEditingController();

  WalletType _selectedType = WalletType.cash;
  Color _selectedColor = WalletType.cash.defaultColor;
  IconData _selectedIcon = WalletType.cash.defaultIcon;
  bool _includeInTotal = true;
  WalletStatus _selectedStatus = WalletStatus.available;
  bool _isSaving = false;

  bool get _isEditMode => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final w = widget.wallet!;
      _nameController.text = w.name;
      _balanceController.text = w.balance.toStringAsFixed(0);
      _noteController.text = w.note ?? '';
      _selectedType = w.type;
      _selectedColor = w.color;
      _selectedIcon = w.icon;
      _includeInTotal = w.includeInTotal;
      _selectedStatus = w.status;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onTypeChanged(WalletType type) {
    setState(() {
      _selectedType = type;
      _selectedColor = type.defaultColor;
      _selectedIcon = type.defaultIcon;
      // Auto-set status
      if (type == WalletType.savings) {
        _selectedStatus = WalletStatus.saved;
      } else if (type == WalletType.kokoMintpay) {
        _selectedStatus = WalletStatus.installment;
        _includeInTotal = false;
      } else {
        _selectedStatus = WalletStatus.available;
        _includeInTotal = true;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final balance =
          double.tryParse(_balanceController.text.trim()) ?? 0.0;
      final now = DateTime.now();

      final wallet = WalletModel(
        id: widget.wallet?.id,
        name: _nameController.text.trim(),
        type: _selectedType,
        balance: balance,
        iconCodePoint: _selectedIcon.codePoint,
        colorValue: _selectedColor.toARGB32(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        includeInTotal: _includeInTotal,
        status: _selectedStatus,
        createdAt: widget.wallet?.createdAt ?? now,
      );

      final provider = context.read<WalletProvider>();
      if (_isEditMode) {
        await provider.updateWallet(wallet);
      } else {
        await provider.addWallet(wallet);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving wallet: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final previewBalance =
        double.tryParse(_balanceController.text.trim()) ?? 10000.0;

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
          _isEditMode ? 'Edit Wallet' : 'Add Wallet',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
          children: [
            // ── Wallet Name ────────────────────────────────────────────
            _SectionLabel(label: 'Wallet Name'),
            const SizedBox(height: 8),
            _InputCard(
              child: TextFormField(
                controller: _nameController,
                style: GoogleFonts.inter(
                    fontSize: 15, color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g., Emergency Fund',
                  hintStyle: GoogleFonts.inter(
                      fontSize: 15, color: AppColors.textHint),
                  prefixIcon: const Icon(
                    Icons.account_balance_wallet_outlined,
                    color: AppColors.textHint,
                    size: 20,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter wallet name' : null,
              ),
            ),
            const SizedBox(height: 22),

            // ── Wallet Type ────────────────────────────────────────────
            _SectionLabel(label: 'Wallet Type'),
            const SizedBox(height: 10),
            _WalletTypeSelector(
              selected: _selectedType,
              onChanged: _onTypeChanged,
            ),
            const SizedBox(height: 22),

            // ── Opening Balance ────────────────────────────────────────
            _SectionLabel(label: 'Opening Balance (Rs.)'),
            const SizedBox(height: 8),
            _InputCard(
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 10),
                    child: Text(
                      'Rs.',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 24,
                    color: AppColors.textHint.withOpacity(0.3),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _balanceController,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.inter(
                          fontSize: 15, color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'e.g., 0.00',
                        hintStyle: GoogleFonts.inter(
                            fontSize: 15, color: AppColors.textHint),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── Icon and Color ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel(label: 'Icon'),
                      const SizedBox(height: 8),
                      _IconDropdown(
                        icon: _selectedIcon,
                        color: _selectedColor,
                        lightColor:
                            Color.fromARGB(30, _selectedColor.red,
                                _selectedColor.green, _selectedColor.blue),
                        onChanged: (icon) =>
                            setState(() => _selectedIcon = icon),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionLabel(label: 'Color'),
                      const SizedBox(height: 8),
                      _ColorDropdown(
                        selected: _selectedColor,
                        onChanged: (color) =>
                            setState(() => _selectedColor = color),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ── Note ───────────────────────────────────────────────────
            _SectionLabel(label: 'Note (Optional)'),
            const SizedBox(height: 8),
            _InputCard(
              child: Stack(
                children: [
                  TextFormField(
                    controller: _noteController,
                    maxLength: 100,
                    maxLines: 3,
                    onChanged: (_) => setState(() {}),
                    style: GoogleFonts.inter(
                        fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Add a note about this wallet...',
                      hintStyle: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.textHint),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.only(bottom: 40),
                        child: Icon(Icons.description_outlined,
                            color: AppColors.textHint, size: 20),
                      ),
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 8,
                    child: Text(
                      '${_noteController.text.length}/100',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textHint,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── Preview ────────────────────────────────────────────────
            _SectionLabel(label: 'Preview'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Color.fromARGB(
                        30,
                        _selectedColor.red,
                        _selectedColor.green,
                        _selectedColor.blue,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_selectedIcon,
                        color: _selectedColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _nameController.text.trim().isEmpty
                              ? 'Example Wallet'
                              : _nameController.text.trim(),
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          CurrencyFormatter.format(previewBalance,
                              symbol: settings.currencySymbol),
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _selectedStatus.lightColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _selectedStatus.color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _selectedStatus.displayName,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _selectedStatus.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ── Include in Total ───────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 14),
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
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Include in Total Balance',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'This wallet balance will be added to your total balance.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _includeInTotal,
                    onChanged: (v) => setState(() => _includeInTotal = v),
                    activeColor: AppColors.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
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
        child: SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _save,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.save_rounded, size: 20),
            label: Text(
              _isEditMode ? 'Update Wallet' : 'Save Wallet',
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
}

// ─── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
    );
  }
}

// ─── Input Card ────────────────────────────────────────────────────────────────

class _InputCard extends StatelessWidget {
  final Widget child;
  const _InputCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─── Wallet Type Selector ──────────────────────────────────────────────────────

class _WalletTypeSelector extends StatelessWidget {
  final WalletType selected;
  final ValueChanged<WalletType> onChanged;

  const _WalletTypeSelector({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final types = WalletType.values;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: types.map((type) {
          final isSelected = type == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: GestureDetector(
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 72,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primarySurface
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.transparent,
                    width: 2,
                  ),
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
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Color.fromARGB(
                          30,
                          type.defaultColor.red,
                          type.defaultColor.green,
                          type.defaultColor.blue,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(type.defaultIcon,
                          color: type.defaultColor, size: 20),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      type.displayName,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Icon Dropdown ─────────────────────────────────────────────────────────────

class _IconDropdown extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color lightColor;
  final ValueChanged<IconData> onChanged;

  static const List<IconData> _icons = [
    Icons.account_balance_wallet_rounded,
    Icons.account_balance_rounded,
    Icons.credit_card_rounded,
    Icons.savings_rounded,
    Icons.business_center_rounded,
    Icons.shopping_bag_rounded,
    Icons.payments_rounded,
    Icons.attach_money_rounded,
    Icons.currency_rupee_rounded,
    Icons.monetization_on_rounded,
  ];

  const _IconDropdown({
    required this.icon,
    required this.color,
    required this.lightColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: lightColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Wallet Icon',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
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
                'Choose Icon',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: _icons.map((ic) {
                  final isSelected = ic.codePoint == icon.codePoint;
                  return GestureDetector(
                    onTap: () {
                      onChanged(ic);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primarySurface
                            : const Color(0xFFF5F6FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Icon(ic,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 24),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Color Dropdown ────────────────────────────────────────────────────────────

class _ColorDropdown extends StatelessWidget {
  final Color selected;
  final ValueChanged<Color> onChanged;

  const _ColorDropdown({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showPicker(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                WalletColors.nameForColor(selected),
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
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
                'Choose Color',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: WalletColors.all.map((wc) {
                  final isSelected = wc.color.toARGB32() == selected.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      onChanged(wc.color);
                      Navigator.pop(context);
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: wc.color,
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(
                                    color: AppColors.textPrimary,
                                    width: 3,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: wc.color.withOpacity(0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 20)
                              : null,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          wc.name,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
