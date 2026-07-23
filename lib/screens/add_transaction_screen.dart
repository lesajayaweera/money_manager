import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../models/transaction_model.dart';
import '../models/category_model.dart';
import '../providers/transaction_provider.dart';
import '../providers/category_provider.dart';
import '../providers/wallet_provider.dart';
import 'categories_screen.dart';

class AddTransactionScreen extends StatefulWidget {
  final TransactionType initialType;
  final TransactionModel? editTransaction;

  const AddTransactionScreen({
    super.key,
    required this.initialType,
    this.editTransaction,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedCategory;
  String _selectedPaymentMethod = 'Cash';
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;
  late TransactionType _type;

  // (Will be dynamically populated in build method)

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;

    if (widget.editTransaction != null) {
      final tx = widget.editTransaction!;
      _amountController.text = tx.amount.toStringAsFixed(0);
      _noteController.text = tx.note ?? '';
      _selectedCategory = tx.category;
      _selectedDate = tx.date;
      _type = tx.type;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  List<AppCategory> _getAppCategories(BuildContext context) {
    final catType = _type == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;
    return context.read<CategoryProvider>().categoriesForType(catType);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  // ─── FIXED SAVE METHOD ────────────────────────────────────────────────────
  Future<void> _save() async {
    // 1. Validate form fields
    if (!_formKey.currentState!.validate()) return;

    // 2. Validate category selection
    if (_selectedCategory == null) {
      _showSnack('Please select a category');
      return;
    }

    // 3. Parse amount (guaranteed clean by FilteringTextInputFormatter)
    final amountText = _amountController.text.trim();
    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      _showSnack('Please enter a valid amount');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final tx = TransactionModel(
        id: widget.editTransaction?.id,
        title: _selectedCategory!,
        amount: amount,
        type: _type,
        category: _selectedCategory!,
        date: DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          DateTime.now().hour,
          DateTime.now().minute,
        ),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
      );

      final provider = context.read<TransactionProvider>();
      final walletProvider = context.read<WalletProvider>();

      if (widget.editTransaction != null) {
        await provider.updateTransaction(tx);
        
        // Update wallet balance by difference
        try {
          final wallet = walletProvider.wallets.firstWhere((w) => w.name == _selectedPaymentMethod);
          final diff = amount - widget.editTransaction!.amount;
          if (diff != 0) {
            final newBalance = _type == TransactionType.income 
                ? wallet.balance + diff 
                : wallet.balance - diff;
            await walletProvider.updateWallet(wallet.copyWith(balance: newBalance));
          }
        } catch (_) {}
      } else {
        await provider.addTransaction(tx);

        // Update wallet balance
        try {
          final wallet = walletProvider.wallets.firstWhere((w) => w.name == _selectedPaymentMethod);
          final newBalance = _type == TransactionType.income 
              ? wallet.balance + amount 
              : wallet.balance - amount;
          await walletProvider.updateWallet(wallet.copyWith(balance: newBalance));
        } catch (_) {}
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        _showSnack('Error saving: ${e.toString()}');
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(fontSize: 14)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: AppColors.textPrimary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _type == TransactionType.expense;
    final isEditing = widget.editTransaction != null;

    final wallets = context.watch<WalletProvider>().wallets;
    final List<_PayMethod> payMethods = wallets
        .map((w) => _PayMethod(w.name, w.icon, w.color))
        .toList();

    // Ensure selected is valid
    if (payMethods.isEmpty) {
      _selectedPaymentMethod = '';
    } else if (!payMethods.any((m) => m.name == _selectedPaymentMethod)) {
      _selectedPaymentMethod = payMethods.first.name;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing
              ? (isExpense ? 'Edit Expense' : 'Edit Income')
              : (isExpense ? 'Add Expense' : 'Add Income'),
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Amount
              _Label('Amount (Rs.)'),
              const SizedBox(height: 8),
              _AmountField(controller: _amountController),
              const SizedBox(height: 20),

              // Category
              _Label(isExpense ? 'Category' : 'Source / Category'),
              const SizedBox(height: 8),
              _CategoryDropdown(
                categories: _getAppCategories(context),
                selectedCategory: _selectedCategory,
                onChanged: (val) => setState(() => _selectedCategory = val),
                onManage: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CategoriesScreen(
                        initialType: isExpense
                            ? CategoryType.expense
                            : CategoryType.income,
                      ),
                    ),
                  );
                  setState(() {});
                },
              ),
              const SizedBox(height: 20),

              // Date
              _Label('Date'),
              const SizedBox(height: 8),
              _DatePickerField(
                selectedDate: _selectedDate,
                onTap: _pickDate,
              ),
              const SizedBox(height: 20),

              // Account Type
              _Label('Payment Method'),
              const SizedBox(height: 8),
              _PaymentMethodDropdown(
                payMethods: payMethods,
                selected: _selectedPaymentMethod,
                onChanged: (val) =>
                    setState(() => _selectedPaymentMethod = val),
              ),
              const SizedBox(height: 20),

              // Note
              _Label('Note (Optional)'),
              const SizedBox(height: 8),
              _NoteField(
                controller: _noteController,
                hint: isExpense
                    ? 'e.g. Lunch at restaurant'
                    : 'e.g. May salary',
              ),
              const SizedBox(height: 36),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          isExpense ? 'Save Expense' : 'Save Income',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Helper Widgets ───────────────────────────────────────────────────────────

class _PayMethod {
  final String name;
  final IconData icon;
  final Color color;
  const _PayMethod(this.name, this.icon, this.color);
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  const _AmountField({required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        hintText: '0',
        hintStyle: GoogleFonts.inter(fontSize: 18, color: AppColors.textHint),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.expense),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.expense, width: 1.5),
        ),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Enter an amount';
        return null;
      },
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final List<AppCategory> categories;
  final String? selectedCategory;
  final ValueChanged<String?> onChanged;
  final VoidCallback? onManage;

  const _CategoryDropdown({
    required this.categories,
    required this.selectedCategory,
    required this.onChanged,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedCategory,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary),
          hint: Text(
            'Select category',
            style: GoogleFonts.inter(
                fontSize: 15, color: AppColors.textHint),
          ),
          dropdownColor: AppColors.surface,
          selectedItemBuilder: (_) => categories
              .map((cat) => _CatRow(cat: cat, isSelected: true))
              .toList(),
          items: [
            ...categories.map((cat) => DropdownMenuItem<String>(
                  value: cat.name,
                  child: _CatRow(cat: cat, isSelected: false),
                )),
            if (onManage != null)
              DropdownMenuItem<String>(
                value: '__manage__',
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                          color: AppColors.primarySurface,
                          shape: BoxShape.circle),
                      child: const Icon(Icons.settings_rounded,
                          color: AppColors.primary, size: 17),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Manage Categories',
                      style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary),
                    ),
                  ],
                ),
              ),
          ],
          onChanged: (val) {
            if (val == '__manage__') {
              onManage?.call();
            } else {
              onChanged(val);
            }
          },
        ),
      ),
    );
  }
}

class _CatRow extends StatelessWidget {
  final AppCategory cat;
  final bool isSelected;
  const _CatRow({required this.cat, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: cat.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8)),
          child: Icon(cat.icon, color: cat.color, size: 17),
        ),
        const SizedBox(width: 12),
        Text(
          cat.name,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight:
                isSelected ? FontWeight.w500 : FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _PaymentMethodDropdown extends StatelessWidget {
  final List<_PayMethod> payMethods;
  final String selected;
  final ValueChanged<String> onChanged;

  const _PaymentMethodDropdown({
    required this.payMethods,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary),
          dropdownColor: AppColors.surface,
          selectedItemBuilder: (_) => payMethods
              .map((m) => _PayRow(method: m, isSelected: true))
              .toList(),
          items: payMethods
              .map((m) => DropdownMenuItem<String>(
                    value: m.name,
                    child: _PayRow(method: m, isSelected: false),
                  ))
              .toList(),
          onChanged: (val) {
            if (val != null) onChanged(val);
          },
        ),
      ),
    );
  }
}

class _PayRow extends StatelessWidget {
  final _PayMethod method;
  final bool isSelected;
  const _PayRow({required this.method, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: method.color, shape: BoxShape.circle),
          child: Icon(method.icon, color: Colors.white, size: 17),
        ),
        const SizedBox(width: 12),
        Text(
          method.name,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight:
                isSelected ? FontWeight.w500 : FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _DatePickerField extends StatelessWidget {
  final DateTime selectedDate;
  final VoidCallback onTap;
  const _DatePickerField(
      {required this.selectedDate, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined,
                color: AppColors.textSecondary, size: 20),
            const SizedBox(width: 12),
            Text(
              DateFormat('d MMM yyyy').format(selectedDate),
              style: GoogleFonts.inter(
                fontSize: 15,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoteField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  const _NoteField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 4,
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            color: AppColors.textHint, fontSize: 14),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
