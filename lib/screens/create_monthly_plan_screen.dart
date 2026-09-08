import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/salary_plan_model.dart';
import '../providers/salary_plan_provider.dart';
import '../providers/settings_provider.dart';
import '../models/category_model.dart';
import '../providers/category_provider.dart';

class CreateMonthlyPlanScreen extends StatefulWidget {
  final SalaryPlan? existing;
  const CreateMonthlyPlanScreen({super.key, this.existing});

  @override
  State<CreateMonthlyPlanScreen> createState() =>
      _CreateMonthlyPlanScreenState();
}

class _CreateMonthlyPlanScreenState extends State<CreateMonthlyPlanScreen> {
  // ── Controllers ──────────────────────────────────────────────────────────
  final _nameController = TextEditingController();
  final _incomeController = TextEditingController();

  // ── State ─────────────────────────────────────────────────────────────────
  DateTime _periodStart =
      DateTime(DateTime.now().year, DateTime.now().month, 1);
  List<SalaryAllocation> _allocations = [];
  bool _isSaving = false;
  bool _hasCopiedFromPrev = false;

  // ── Derived ───────────────────────────────────────────────────────────────
  double get _income =>
      double.tryParse(_incomeController.text.replaceAll(',', '')) ?? 0;

  double get _totalAllocated =>
      _allocations.fold(0, (s, a) => s + a.amount);

  double get _unallocated => _income - _totalAllocated;

  double get _categoryTotal =>
      _sumByType(AllocationType.category);
  double get _savingsTotal => _sumByType(AllocationType.savingsGoal);
  double get _loanTotal => _sumByType(AllocationType.loan);
  double get _creditCardTotal => _sumByType(AllocationType.creditCard);

  double _sumByType(AllocationType t) =>
      _allocations.where((a) => a.type == t).fold(0, (s, a) => s + a.amount);

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameController.text = e.name;
      _incomeController.text = e.monthlyIncome.toStringAsFixed(0);
      _periodStart = e.periodStart;
      _allocations = List.from(e.allocations);
    }
    _incomeController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  // ── Save ─────────────────────────────────────────────────────────────────
  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _showError('Please enter a plan name.');
      return;
    }
    if (_income <= 0) {
      _showError('Please enter your monthly income.');
      return;
    }

    setState(() => _isSaving = true);
    final plan = SalaryPlan(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: name,
      monthlyIncome: _income,
      periodStart: _periodStart,
      allocations: _allocations,
      createdAt: widget.existing?.createdAt ?? DateTime.now(),
    );

    try {
      final provider = context.read<SalaryPlanProvider>();
      if (widget.existing != null) {
        await provider.updatePlan(plan);
      } else {
        await provider.createPlan(plan);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Failed to save plan: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppColors.expense,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Copy from previous month ───────────────────────────────────────────────
  void _copyFromPrevious() {
    final prev = context.read<SalaryPlanProvider>().previousPlan(
          _periodStart.year,
          _periodStart.month,
        );
    if (prev == null) {
      _showError('No previous plan found to copy from.');
      return;
    }
    setState(() {
      // Copy income amount
      _incomeController.text = prev.monthlyIncome.toStringAsFixed(0);
      // Copy all allocations with fresh IDs so they don\'t clash
      _allocations = prev.allocations
          .map((a) => SalaryAllocation(
                id: '${a.name}_${_periodStart.year}_${_periodStart.month}',
                name: a.name,
                type: a.type,
                amount: a.amount,
              ))
          .toList();
      _hasCopiedFromPrev = true;
    });
  }

  // ── Add / Edit Allocation ────────────────────────────────────────────────
  Future<void> _showAddAllocationSheet({SalaryAllocation? editing}) async {
    final result = await showModalBottomSheet<SalaryAllocation>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddAllocationSheet(
        existing: editing,
        income: _income,
        unallocated: _unallocated + (editing?.amount ?? 0),
      ),
    );
    if (result != null) {
      setState(() {
        if (editing != null) {
          final idx = _allocations.indexWhere((a) => a.id == editing.id);
          if (idx != -1) _allocations[idx] = result;
        } else {
          _allocations.add(result);
        }
      });
    }
  }

  void _deleteAllocation(SalaryAllocation a) {
    setState(() => _allocations.removeWhere((x) => x.id == a.id));
  }

  // ── Period picker ─────────────────────────────────────────────────────────
  Future<void> _pickPeriod() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodStart,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030, 12),
      helpText: 'Select plan month',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Theme.of(context).brightness),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _periodStart = DateTime(picked.year, picked.month, 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final symbol = context.watch<SettingsProvider>().currencySymbol;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Plan Name ────────────────────────────────────────────
                _SectionLabel('Plan name'),
                const SizedBox(height: 8),
                _InputField(
                  controller: _nameController,
                  hintText: 'e.g. August Budget',
                  keyboardType: TextInputType.text,
                ),

                const SizedBox(height: 20),

                // ── Period ───────────────────────────────────────────────
                _SectionLabel('Plan period'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickPeriod,
                  child: _PeriodTile(periodStart: _periodStart, isDark: isDark),
                ),

                // Copy from previous month (only for new plans)
                if (widget.existing == null) ...[  
                  const SizedBox(height: 8),
                  _CopyFromPreviousButton(
                    isDark: isDark,
                    hasCopied: _hasCopiedFromPrev,
                    hasPreviousPlan: context.read<SalaryPlanProvider>().previousPlan(
                      _periodStart.year, _periodStart.month) != null,
                    onCopy: _copyFromPrevious,
                  ),
                ],

                const SizedBox(height: 20),

                // ── Monthly Income ────────────────────────────────────────
                _SectionLabel('Monthly Income'),
                const SizedBox(height: 8),
                _AmountInputField(
                  controller: _incomeController,
                  symbol: symbol,
                  hintText: 'Enter salary amount',
                ),

                const SizedBox(height: 20),

                // ── Summary Card ─────────────────────────────────────────
                _SummaryCard(
                  income: _income,
                  unallocated: _unallocated,
                  categoryTotal: _categoryTotal,
                  savingsTotal: _savingsTotal,
                  loanTotal: _loanTotal,
                  creditCardTotal: _creditCardTotal,
                  symbol: symbol,
                  isDark: isDark,
                ),

                const SizedBox(height: 24),

                // ── Allocations ───────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionLabel('Allocations'),
                    GestureDetector(
                      onTap: _income > 0
                          ? () => _showAddAllocationSheet()
                          : null,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _income > 0
                              ? AppColors.income.withOpacity(0.12)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: _income > 0 ? AppColors.income : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (_allocations.isEmpty)
                  _EmptyAllocations(
                    hasIncome: _income > 0,
                    onAdd: () => _showAddAllocationSheet(),
                  )
                else
                  _AllocationGroups(
                    allocations: _allocations,
                    symbol: symbol,
                    isDark: isDark,
                    onEdit: (a) => _showAddAllocationSheet(editing: a),
                    onDelete: _deleteAllocation,
                  ),
              ],
            ),
          ),

          // ── Bottom button ─────────────────────────────────────────────
          Align(
            alignment: Alignment.bottomCenter,
            child: _BottomButton(
              isSaving: _isSaving,
              label: widget.existing != null ? 'Update Plan' : 'Create Plan',
              onPressed: _save,
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: Theme.of(context).textTheme.titleLarge?.color),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        widget.existing != null ? 'Edit Monthly Plan' : 'Create Monthly Plan',
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).textTheme.titleLarge?.color,
        ),
      ),
    );
  }
}

// ─── Period Tile ──────────────────────────────────────────────────────────────

class _PeriodTile extends StatelessWidget {
  final DateTime periodStart;
  final bool isDark;
  const _PeriodTile({required this.periodStart, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_rounded,
              size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Text(
            CurrencyFormatter.monthYear(periodStart),
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const Spacer(),
          Icon(Icons.chevron_right_rounded,
              color: Theme.of(context).textTheme.bodySmall?.color),
        ],
      ),
    );
  }
}

// ─── Summary Card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final double income;
  final double unallocated;
  final double categoryTotal;
  final double savingsTotal;
  final double loanTotal;
  final double creditCardTotal;
  final String symbol;
  final bool isDark;

  const _SummaryCard({
    required this.income,
    required this.unallocated,
    required this.categoryTotal,
    required this.savingsTotal,
    required this.loanTotal,
    required this.creditCardTotal,
    required this.symbol,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final remainingColor = unallocated < 0
        ? AppColors.expense
        : unallocated == 0 && income > 0
            ? AppColors.income
            : AppColors.income;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkPrimarySurface : AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withOpacity(0.2)
              : AppColors.primary.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            unallocated <= 0 && income > 0
                ? 'Fully Allocated ✓'
                : 'Remaining Amount',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            unallocated >= 0
                ? CurrencyFormatter.format(unallocated, symbol: symbol)
                : '-${CurrencyFormatter.format(unallocated.abs(), symbol: symbol)}',
            style: GoogleFonts.poppins(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: unallocated < 0 ? AppColors.expense : remainingColor,
            ),
          ),

          if (income > 0) ...[
            const SizedBox(height: 4),
            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (income > 0
                        ? ((income - unallocated.clamp(0.0, income)) / income)
                        : 0.0)
                    .clamp(0.0, 1.0),
                minHeight: 5,
                backgroundColor: isDark
                    ? AppColors.darkDivider
                    : AppColors.primary.withOpacity(0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  unallocated < 0 ? AppColors.expense : AppColors.income,
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),

          _SummaryRow(
            label: 'Total Allocated',
            value: categoryTotal + savingsTotal + loanTotal + creditCardTotal,
            symbol: symbol,
            context: context,
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Expenses',
            value: categoryTotal,
            symbol: symbol,
            context: context,
            iconColor: AllocationType.category.color,
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Savings Goals',
            value: savingsTotal,
            symbol: symbol,
            context: context,
            iconColor: AllocationType.savingsGoal.color,
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Loan Payments',
            value: loanTotal,
            symbol: symbol,
            context: context,
            iconColor: AllocationType.loan.color,
          ),
          const SizedBox(height: 8),
          _SummaryRow(
            label: 'Credit Card Payments',
            value: creditCardTotal,
            symbol: symbol,
            context: context,
            iconColor: AllocationType.creditCard.color,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final double value;
  final String symbol;
  final BuildContext context;
  final Color? iconColor;

  const _SummaryRow({
    required this.label,
    required this.value,
    required this.symbol,
    required this.context,
    this.iconColor,
  });

  @override
  Widget build(BuildContext outerContext) {
    return Row(
      children: [
        if (iconColor != null) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: iconColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
        const Spacer(),
        Text(
          CurrencyFormatter.format(value, symbol: symbol),
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }
}

// ─── Empty Allocations ────────────────────────────────────────────────────────

class _EmptyAllocations extends StatelessWidget {
  final bool hasIncome;
  final VoidCallback onAdd;
  const _EmptyAllocations({required this.hasIncome, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 48,
            color: isDark ? AppColors.darkTextHint : Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            hasIncome
                ? 'No allocations yet'
                : 'Enter income first',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            hasIncome
                ? 'Tap "+" to allocate your income'
                : 'Enter your monthly income amount above',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          if (hasIncome) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: Text('Add Allocation',
                  style: GoogleFonts.poppins(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.income,
                side: BorderSide(color: AppColors.income),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Allocation Groups ────────────────────────────────────────────────────────

class _AllocationGroups extends StatelessWidget {
  final List<SalaryAllocation> allocations;
  final String symbol;
  final bool isDark;
  final void Function(SalaryAllocation) onEdit;
  final void Function(SalaryAllocation) onDelete;

  const _AllocationGroups({
    required this.allocations,
    required this.symbol,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final type in AllocationType.values)
          _GroupSection(
            type: type,
            items: allocations.where((a) => a.type == type).toList(),
            symbol: symbol,
            isDark: isDark,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
      ],
    );
  }
}

class _GroupSection extends StatelessWidget {
  final AllocationType type;
  final List<SalaryAllocation> items;
  final String symbol;
  final bool isDark;
  final void Function(SalaryAllocation) onEdit;
  final void Function(SalaryAllocation) onDelete;

  const _GroupSection({
    required this.type,
    required this.items,
    required this.symbol,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Icon(type.icon, size: 14, color: type.color),
              const SizedBox(width: 6),
              Text(
                type.label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: type.color,
                ),
              ),
            ],
          ),
        ),
        ...items.map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _AllocationTile(
              allocation: a,
              symbol: symbol,
              isDark: isDark,
              onEdit: () => onEdit(a),
              onDelete: () => onDelete(a),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _AllocationTile extends StatelessWidget {
  final SalaryAllocation allocation;
  final String symbol;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AllocationTile({
    required this.allocation,
    required this.symbol,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final type = allocation.type;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : Colors.grey.shade100,
        ),
      ),
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: type.color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(type.icon, size: 16, color: type.color),
        ),
        title: Text(
          allocation.name,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CurrencyFormatter.format(allocation.amount, symbol: symbol),
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 4),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded,
                  size: 18,
                  color: Theme.of(context).textTheme.bodySmall?.color),
              color: isDark ? AppColors.darkSurface2 : Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    Icon(Icons.edit_rounded,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Text('Edit', style: GoogleFonts.poppins(fontSize: 13)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    Icon(Icons.delete_outline_rounded,
                        size: 14, color: AppColors.expense),
                    const SizedBox(width: 8),
                    Text('Delete',
                        style: GoogleFonts.poppins(
                            fontSize: 13, color: AppColors.expense)),
                  ]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom Button ────────────────────────────────────────────────────────────

class _BottomButton extends StatelessWidget {
  final bool isSaving;
  final String label;
  final VoidCallback onPressed;
  const _BottomButton(
      {required this.isSaving,
      required this.label,
      required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: isSaving ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.income,
            foregroundColor: Colors.white,
            elevation: 0,
            disabledBackgroundColor: AppColors.income.withOpacity(0.6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5),
                )
              : Text(
                  label,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }
}

// ─── Shared input widgets ─────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).textTheme.titleLarge?.color,
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final TextInputType keyboardType;

  const _InputField({
    required this.controller,
    required this.hintText,
    required this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: GoogleFonts.poppins(fontSize: 15),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(
            fontSize: 15,
            color: isDark ? AppColors.darkTextHint : AppColors.textHint),
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class _AmountInputField extends StatelessWidget {
  final TextEditingController controller;
  final String symbol;
  final String hintText;

  const _AmountInputField({
    required this.controller,
    required this.symbol,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
      ],
      style: GoogleFonts.poppins(fontSize: 15),
      decoration: InputDecoration(
        prefixText: '$symbol  ',
        prefixStyle: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
        hintText: hintText,
        hintStyle: GoogleFonts.poppins(
            fontSize: 15,
            color: isDark ? AppColors.darkTextHint : AppColors.textHint),
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

// ─── Add / Edit Allocation Bottom Sheet ──────────────────────────────────────

class _AddAllocationSheet extends StatefulWidget {
  final SalaryAllocation? existing;
  final double income;
  final double unallocated;

  const _AddAllocationSheet({
    this.existing,
    required this.income,
    required this.unallocated,
  });

  @override
  State<_AddAllocationSheet> createState() => _AddAllocationSheetState();
}

class _AddAllocationSheetState extends State<_AddAllocationSheet> {
  AllocationType _selectedType = AllocationType.category;
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  String? _selectedCategory;
  String? _nameError;
  String? _amountError;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _selectedType = e.type;
      if (e.type == AllocationType.category) {
        _selectedCategory = e.name;
      } else {
        _nameController.text = e.name;
      }
      _amountController.text = e.amount.toStringAsFixed(0);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _selectedType == AllocationType.category
        ? (_selectedCategory ?? '')
        : _nameController.text.trim();
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

    setState(() {
      _nameError = name.isEmpty 
          ? (_selectedType == AllocationType.category ? 'Select a category' : 'Enter a name') 
          : null;
      _amountError = amount <= 0
          ? 'Enter a valid amount'
          : amount > widget.unallocated + 0.01
              ? 'Exceeds remaining amount'
              : null;
    });

    if (_nameError != null || _amountError != null) return;

    Navigator.of(context).pop(
      SalaryAllocation(
        id: widget.existing?.id ?? const Uuid().v4(),
        name: name,
        type: _selectedType,
        amount: amount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final symbol = context.watch<SettingsProvider>().currencySymbol;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkDivider : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          Text(
            widget.existing != null ? 'Edit Allocation' : 'Add Allocation',
            style: GoogleFonts.poppins(
                fontSize: 18, fontWeight: FontWeight.w700),
          ),

          // Remaining indicator
          const SizedBox(height: 4),
          Text(
            '${CurrencyFormatter.format(widget.unallocated, symbol: symbol)} remaining to allocate',
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: widget.unallocated <= 0
                  ? AppColors.income
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),

          const SizedBox(height: 20),

          // ── Type Selector ──────────────────────────────────────────────
          Text('Destination',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          _TypeSelector(
            selected: _selectedType,
            onChanged: (t) {
              setState(() {
                _selectedType = t;
                _nameController.clear();
                _selectedCategory = null;
                _nameError = null;
              });
            },
          ),

          const SizedBox(height: 18),

          // ── Hint for type ─────────────────────────────────────────────
          _TypeHint(type: _selectedType),
          const SizedBox(height: 14),

          // ── Name ──────────────────────────────────────────────────────
          Text(_namePlaceholder,
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (_selectedType == AllocationType.category)
            _buildCategoryDropdown(isDark)
          else
            TextField(
              controller: _nameController,
              style: GoogleFonts.poppins(fontSize: 14),
              decoration: InputDecoration(
                hintText: _nameHint,
                hintStyle: GoogleFonts.poppins(
                    color: isDark ? AppColors.darkTextHint : AppColors.textHint,
                    fontSize: 14),
                errorText: _nameError,
                filled: true,
                fillColor:
                    isDark ? AppColors.darkBackground : Colors.grey.shade50,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      BorderSide(color: AppColors.primary, width: 1.5),
                ),
              ),
            ),

          const SizedBox(height: 14),

          // ── Amount ────────────────────────────────────────────────────
          Text('Amount',
              style: GoogleFonts.poppins(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*'))
                  ],
                  style: GoogleFonts.poppins(fontSize: 14),
                  decoration: InputDecoration(
                    prefixText: '$symbol  ',
                    prefixStyle: GoogleFonts.poppins(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
                    hintText: '0',
                    errorText: _amountError,
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkBackground
                        : Colors.grey.shade50,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkDivider
                            : Colors.grey.shade200,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isDark
                            ? AppColors.darkDivider
                            : Colors.grey.shade200,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Quick fill remaining
              if (widget.unallocated > 0)
                OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _amountController.text =
                          widget.unallocated.toStringAsFixed(0);
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 12),
                  ),
                  child: Text('All',
                      style: GoogleFonts.poppins(
                          fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedType.color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                widget.existing != null ? 'Update' : 'Add',
                style: GoogleFonts.poppins(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryDropdown(bool isDark) {
    final expenseCategories = context.watch<CategoryProvider>().categoriesForType(CategoryType.expense);
    final safeValue = expenseCategories.any((c) => c.name == _selectedCategory)
        ? _selectedCategory
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBackground : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: safeValue,
              isExpanded: true,
              hint: Text(
                'Select expense category',
                style: GoogleFonts.poppins(
                  color: isDark ? AppColors.darkTextHint : AppColors.textHint,
                  fontSize: 14,
                ),
              ),
              dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
              items: expenseCategories.map((cat) {
                return DropdownMenuItem<String>(
                  value: cat.name,
                  child: Row(
                    children: [
                      Icon(cat.icon, color: cat.color, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        cat.name,
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCategory = val;
                  _nameError = null;
                });
              },
            ),
          ),
        ),
        if (_nameError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 14),
            child: Text(
              _nameError!,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: AppColors.expense,
              ),
            ),
          ),
      ],
    );
  }

  String get _namePlaceholder {
    switch (_selectedType) {
      case AllocationType.category:
        return 'Category name';
      case AllocationType.savingsGoal:
        return 'Goal name';
      case AllocationType.loan:
        return 'Loan name';
      case AllocationType.creditCard:
        return 'Card name';
    }
  }

  String get _nameHint {
    switch (_selectedType) {
      case AllocationType.category:
        return 'e.g. Food, Transport, Utilities';
      case AllocationType.savingsGoal:
        return 'e.g. Emergency Fund, Vacation';
      case AllocationType.loan:
        return 'e.g. Home Loan, Car Loan';
      case AllocationType.creditCard:
        return 'e.g. HDFC Visa, Sampath Card';
    }
  }
}

// ─── Type Selector ────────────────────────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  final AllocationType selected;
  final void Function(AllocationType) onChanged;

  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: AllocationType.values
            .map((t) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _TypeChip(
                    type: t,
                    isSelected: selected == t,
                    onTap: () => onChanged(t),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  final AllocationType type;
  final bool isSelected;
  final VoidCallback onTap;
  const _TypeChip(
      {required this.type,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? type.color
              : isDark
                  ? AppColors.darkBackground
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? type.color : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              type.icon,
              size: 14,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodySmall?.color,
            ),
            const SizedBox(width: 6),
            Text(
              type.shortLabel,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Type Hint ────────────────────────────────────────────────────────────────

class _TypeHint extends StatelessWidget {
  final AllocationType type;
  const _TypeHint({required this.type});

  String get _hint {
    switch (type) {
      case AllocationType.category:
        return 'Creates a spending limit — money you expect to consume. Syncs to the Budget screen.';
      case AllocationType.savingsGoal:
        return 'A contribution — money that moves to a savings goal. Not counted as spending.';
      case AllocationType.loan:
        return 'An EMI payment — money that reduces a loan liability. Not counted as spending.';
      case AllocationType.creditCard:
        return 'A card payment — money set aside to pay your credit card bill. Not counted as spending.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: type.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: type.color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 14, color: type.color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _hint,
              style: GoogleFonts.poppins(
                fontSize: 11,
                color: type.color,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Copy From Previous Month Button ─────────────────────────────────────────

class _CopyFromPreviousButton extends StatelessWidget {
  final bool isDark;
  final bool hasCopied;
  final bool hasPreviousPlan;
  final VoidCallback onCopy;

  const _CopyFromPreviousButton({
    required this.isDark,
    required this.hasCopied,
    required this.hasPreviousPlan,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    if (!hasPreviousPlan) return const SizedBox.shrink();
    return GestureDetector(
      onTap: hasCopied ? null : onCopy,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: hasCopied
              ? AppColors.income.withOpacity(0.08)
              : isDark
                  ? AppColors.darkBackground
                  : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: hasCopied
                ? AppColors.income.withOpacity(0.3)
                : isDark
                    ? AppColors.darkDivider
                    : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasCopied
                  ? Icons.check_circle_rounded
                  : Icons.copy_all_rounded,
              size: 16,
              color: hasCopied
                  ? AppColors.income
                  : AppColors.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                hasCopied
                    ? 'Copied from previous month'
                    : 'Copy from previous month',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: hasCopied
                      ? AppColors.income
                      : Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
            if (!hasCopied)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Auto-fill',
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
