import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';

import '../models/transaction_model.dart';
import '../providers/transaction_provider.dart';
import '../providers/settings_provider.dart';

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

class _AddTransactionScreenState extends State<AddTransactionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TransactionType _selectedType;
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: _selectedType == TransactionType.income ? 0 : 1,
    );
    _tabController.addListener(_onTabChanged);

    if (widget.editTransaction != null) {
      final tx = widget.editTransaction!;
      _titleController.text = tx.title;
      _amountController.text = tx.amount.toStringAsFixed(0);
      _noteController.text = tx.note ?? '';
      _selectedCategory = tx.category;
      _selectedDate = tx.date;
      _selectedType = tx.type;
    }
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      setState(() {
        _selectedType = _tabController.index == 0
            ? TransactionType.income
            : TransactionType.expense;
        _selectedCategory = null;
      });
    }
  }

  List<CategoryModel> get _categories {
    return _selectedType == TransactionType.income
        ? CategoryModel.incomeCategories
        : CategoryModel.expenseCategories;
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      _showError('Please select a category');
      return;
    }

    setState(() => _isSaving = true);
    HapticFeedback.lightImpact();

    final amount = double.tryParse(_amountController.text.replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      _showError('Enter a valid amount');
      setState(() => _isSaving = false);
      return;
    }

    final tx = TransactionModel(
      id: widget.editTransaction?.id,
      title: _titleController.text.trim(),
      amount: amount,
      type: _selectedType,
      category: _selectedCategory!,
      date: _selectedDate,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    final provider = context.read<TransactionProvider>();
    if (widget.editTransaction != null) {
      await provider.updateTransaction(tx);
    } else {
      await provider.addTransaction(tx);
    }

    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editTransaction != null;
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          isEditing ? 'Edit Transaction' : 'Add Transaction',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Type tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Container(
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
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: _selectedType == TransactionType.income
                        ? AppColors.income
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorPadding: const EdgeInsets.all(4),
                  labelColor: Colors.white,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Income'),
                    Tab(text: 'Expense'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount field
                    _buildAmountField(settings.currencySymbol),
                    const SizedBox(height: 16),
                    // Title field
                    _buildTextField(
                      controller: _titleController,
                      label: 'Title',
                      hint: 'e.g. Monthly Salary, Grocery, etc.',
                      icon: Icons.title_rounded,
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Enter a title' : null,
                    ),
                    const SizedBox(height: 16),
                    // Category
                    _buildSectionLabel('Category'),
                    const SizedBox(height: 10),
                    _buildCategoryGrid(),
                    const SizedBox(height: 16),
                    // Date
                    _buildSectionLabel('Date'),
                    const SizedBox(height: 10),
                    _buildDatePicker(),
                    const SizedBox(height: 16),
                    // Note
                    _buildTextField(
                      controller: _noteController,
                      label: 'Note (optional)',
                      hint: 'Add a note...',
                      icon: Icons.notes_rounded,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _selectedType == TransactionType.income
                                  ? AppColors.income
                                  : AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                isEditing
                                    ? 'Update Transaction'
                                    : 'Save Transaction',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountField(String currencySymbol) {
    return Container(
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                currencySymbol,
                style: GoogleFonts.inter(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: _selectedType == TransactionType.income
                      ? AppColors.income
                      : AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    hintText: '0',
                    hintStyle: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textHint,
                    ),
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter an amount';
                    final val = double.tryParse(v.replaceAll(',', ''));
                    if (val == null || val <= 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.inter(
        fontSize: 14,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildCategoryGrid() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: _categories.map((cat) {
        final isSelected = _selectedCategory == cat.name;
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = cat.name),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected ? cat.color : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? cat.color : const Color(0xFFE5E7EB),
                width: isSelected ? 1.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: cat.color.withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      )
                    ]
                  : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  cat.icon,
                  size: 16,
                  color: isSelected ? Colors.white : cat.color,
                ),
                const SizedBox(width: 6),
                Text(
                  cat.name,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDatePicker() {
    return GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: const Border.fromBorderSide(
            BorderSide(color: Color(0xFFE5E7EB)),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Text(
              DateFormat('EEEE, d MMMM yyyy').format(_selectedDate),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
