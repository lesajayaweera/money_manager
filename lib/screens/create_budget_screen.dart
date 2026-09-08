import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/budget_model.dart';
import '../models/category_model.dart';
import '../providers/budget_provider.dart';
import '../providers/category_provider.dart';
import '../providers/salary_plan_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import 'categories_screen.dart';

class CreateBudgetScreen extends StatefulWidget {
  /// If non-null, we're editing an existing budget.
  final BudgetModel? existing;

  const CreateBudgetScreen({super.key, this.existing});

  @override
  State<CreateBudgetScreen> createState() => _CreateBudgetScreenState();
}

class _CreateBudgetScreenState extends State<CreateBudgetScreen> {
  int _step = 0; // 0-based: 0 = Step 1, 1 = Step 2, 2 = Step 3

  // Step 1 state
  final _amountController = TextEditingController();
  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);

  // Step 2 state: category name -> allocated amount
  late Map<String, double> _allocations;

  /// Whether _allocations has been seeded yet (done once in
  /// didChangeDependencies so we have access to CategoryProvider).
  bool _allocationsInitialized = false;
  bool _isSaving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Use all expense categories from CategoryProvider.
    final allExpense =
        context.watch<CategoryProvider>().expenseCategories;

    if (!_allocationsInitialized) {
      _allocationsInitialized = true;
      final existing = widget.existing;
      if (existing != null) {
        _amountController.text = existing.totalAmount.toStringAsFixed(0);
        _startDate = existing.startDate;
        // Seed with 0 for every expense category, then overlay saved values.
        _allocations = {for (final c in allExpense) c.name: 0.0};
        for (final cat in existing.categories) {
          _allocations[cat.categoryName] = cat.allocatedAmount;
        }
      } else {
        _allocations = {for (final c in allExpense) c.name: 0.0};
      }
    } else {
      // Re-sync: add new categories with 0, remove deleted ones while
      // preserving any amounts the user has already entered.
      final currentNames = allExpense.map((c) => c.name).toSet();
      // Remove categories that no longer exist.
      final toRemove = _allocations.keys.where((k) => !currentNames.contains(k)).toList();
      // Add newly created categories with a default of 0.
      final toAdd = allExpense.where((c) => !_allocations.containsKey(c.name)).toList();
      if (toRemove.isNotEmpty || toAdd.isNotEmpty) {
        // Defer the mutation + setState to after the current build frame to
        // avoid a re-entrant build triggered by context.watch inside
        // didChangeDependencies.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            for (final k in toRemove) {
              _allocations.remove(k);
            }
            for (final c in toAdd) {
              _allocations[c.name] = 0.0;
            }
          });
        });
      }
    }
    // setState is safe here (first-init path only).
    if (!_allocationsInitialized) setState(() {});
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  double get _totalBudget =>
      double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

  double get _totalAllocated =>
      _allocations.values.fold(0, (s, v) => s + v);

  void _next() {
    if (_step == 0) {
      if (_totalBudget <= 0) {
        _showSnack('Please enter a valid budget amount.');
        return;
      }
      setState(() => _step = 1);
    } else if (_step == 1) {
      // BUG 5 FIX: guard against over-allocation before reaching review step.
      if (_totalAllocated > _totalBudget) {
        _showSnack(
          'Total allocation exceeds budget by '
          '${(_totalAllocated - _totalBudget).toStringAsFixed(0)}. '
          'Please reduce some categories.',
        );
        return;
      }
      setState(() => _step = 2);
    }
  }

  /// True if the user has entered any allocations (i.e. there is unsaved work
  /// on step 2 or beyond that would be lost on a back-navigate).
  bool get _hasAllocations => _allocationsInitialized &&
      _allocations.values.any((v) => v > 0);

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  /// Shows a "Discard changes?" bottom sheet before navigating back when the
  /// user has entered allocations. Falls through to a plain back if nothing
  /// has been entered yet.
  Future<void> _confirmBack({bool toParent = false}) async {
    // Only warn if on step 2/3 and there is actual data to lose.
    final needsConfirm = (_step >= 1 && _hasAllocations) ||
        (_step == 2 && _hasAllocations);
    if (!needsConfirm) {
      if (toParent) {
        Navigator.pop(context);
      } else {
        _back();
      }
      return;
    }
    final discard = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final textPrimary =
            Theme.of(ctx).textTheme.titleLarge?.color ?? Colors.black;
        final textSub =
            Theme.of(ctx).textTheme.bodyMedium?.color ?? Colors.grey;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: textSub.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                Icon(Icons.warning_amber_rounded,
                    color: AppColors.expense, size: 40),
                const SizedBox(height: 14),
                Text(
                  'Discard changes?',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  toParent
                      ? 'Going back will discard all the budget\nand category allocations you entered.'
                      : 'Going back will discard the category\nallocations you entered on this step.',
                  style:
                      GoogleFonts.poppins(fontSize: 13, color: textSub),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          side: BorderSide(
                              color: textSub.withValues(alpha: 0.3)),
                        ),
                        child: Text('Keep editing',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                color: textPrimary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.expense,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text('Discard',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    if (discard == true) {
      if (!mounted) return;
      if (toParent) {
        Navigator.pop(context);
      } else {
        _back();
      }
    }
  }

  Future<void> _save() async {
    // BUG 2 FIX: guard against double-tap while save is in progress.
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final provider = context.read<BudgetProvider>();
    // BUG 3 FIX: only persist categories with a non-zero allocation.
    final nonZeroAllocations = _allocations.entries.where((e) => e.value > 0);
    final budget = BudgetModel(
      id: widget.existing?.id,
      totalAmount: _totalBudget,
      startDate: _startDate,
      categories: nonZeroAllocations
          .map((e) => BudgetCategoryAllocation(
                budgetId: widget.existing?.id ?? 0,
                categoryName: e.key,
                allocatedAmount: e.value,
              ))
          .toList(),
      createdAt: DateTime.now().toIso8601String(),
    );

    try {
      if (widget.existing != null) {
        await provider.updateBudget(budget);
      } else {
        // saveBudget handles duplicate-month detection internally
        await provider.saveBudget(budget);
      }
      if (!mounted) return;

      // Two-way sync: update the matching SalaryPlan (if any) with the new
      // budget category amounts. This is best-effort — never blocks the save.
      try {
        final savedBudget = await provider.getBudgetForMonth(
            budget.startDate.year, budget.startDate.month);
        if (savedBudget != null && mounted) {
          await context
              .read<SalaryPlanProvider>()
              .updatePlanFromBudget(savedBudget);
        }
      } catch (_) {}

      if (!mounted) return;
      // Keep Dashboard's "Remaining Budget" card in sync.
      await context.read<TransactionProvider>().refreshSummary();
      if (!mounted) return;
      // BUG 1 FIX: show snack BEFORE popping, while context is still valid.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text('Budget saved!', style: GoogleFonts.poppins(fontSize: 14)),
          ]),
          backgroundColor: AppColors.income,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showSnack('Error saving budget: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.poppins(fontSize: 14)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    final textPrimary = Theme.of(context).textTheme.titleLarge?.color ?? Colors.black;
    final textSub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: textPrimary),
          onPressed: _step == 0
              ? () => Navigator.pop(context)
              : () => _confirmBack(toParent: false),
        ),
        title: Column(
          children: [
            Text(
              widget.existing != null ? 'Edit Budget' : 'Create Budget',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
            Text(
              'Step ${_step + 1} of 3',
              style: GoogleFonts.poppins(fontSize: 12, color: textSub),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.04, 0),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: _step == 0
            ? _Step1(
                key: const ValueKey(0),
                amountController: _amountController,
                startDate: _startDate,
                onDateChanged: (d) => setState(() => _startDate = d),
                onContinue: _next,
                currencySymbol: settings.currencySymbol,
                isDark: isDark,
              )
            : _step == 1
                ? _Step2(
                    key: const ValueKey(1),
                    totalBudget: _totalBudget,
                    allocations: _allocations,
                    onAllocationChanged: (name, val) =>
                        setState(() => _allocations[name] = val),
                    onBack: () => _confirmBack(toParent: false),
                    onContinue: _next,
                    onManageCategories: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CategoriesScreen(
                            initialType: CategoryType.expense,
                          ),
                        ),
                      );
                    },
                    currencySymbol: settings.currencySymbol,
                    isDark: isDark,
                  )
                : _Step3(
                    key: const ValueKey(2),
                    totalBudget: _totalBudget,
                    startDate: _startDate,
                    allocations: _allocations,
                    totalAllocated: _totalAllocated,
                    onBack: () => _confirmBack(toParent: false),
                    onSave: _isSaving ? () {} : _save,
                    isSaving: _isSaving,
                    currencySymbol: settings.currencySymbol,
                    isDark: isDark,
                  ),
      ),
    );
  }
}

// ─── Step 1: Set Monthly Budget ───────────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final TextEditingController amountController;
  final DateTime startDate;
  final ValueChanged<DateTime> onDateChanged;
  final VoidCallback onContinue;
  final String currencySymbol;
  final bool isDark;

  const _Step1({
    super.key,
    required this.amountController,
    required this.startDate,
    required this.onDateChanged,
    required this.onContinue,
    required this.currencySymbol,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).textTheme.titleLarge?.color ?? Colors.black;
    final textSub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final dividerColor = Theme.of(context).dividerTheme.color ?? const Color(0xFFF0F0F0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 8),
          // Illustration
          _WalletIllustration(isDark: isDark),
          const SizedBox(height: 24),
          Text(
            'Set Your Monthly Budget',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'This helps you track your spending\nand reach your goals.',
            style: GoogleFonts.poppins(fontSize: 14, color: textSub),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Amount field
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Monthly Budget Amount',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: dividerColor),
            ),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    currencySymbol,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                ),
                Container(width: 1, height: 40, color: dividerColor),
                Expanded(
                  child: TextField(
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: false),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: '0',
                      hintStyle: GoogleFonts.poppins(color: textSub),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Start date picker
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Budget Starts From',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: startDate,
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
                builder: (ctx, child) => Theme(
                  data: Theme.of(ctx).copyWith(
                    colorScheme: Theme.of(ctx).colorScheme.copyWith(
                          primary: AppColors.primary,
                        ),
                  ),
                  child: child!,
                ),
              );
              if (picked != null) onDateChanged(picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: dividerColor),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: textSub, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      DateFormat('dd MMMM yyyy').format(startDate),
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: textPrimary,
                      ),
                    ),
                  ),
                  Icon(Icons.keyboard_arrow_down_rounded, color: textSub, size: 22),
                ],
              ),
            ),
          ),
          const SizedBox(height: 40),

          // Continue button
          _PrimaryButton(label: 'Continue', onTap: onContinue),
        ],
      ),
    );
  }
}

// ─── Step 2: Set Budget by Category ──────────────────────────────────────────

class _Step2 extends StatelessWidget {
  final double totalBudget;
  final Map<String, double> allocations;
  final void Function(String name, double val) onAllocationChanged;
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final VoidCallback onManageCategories;
  final String currencySymbol;
  final bool isDark;

  const _Step2({
    super.key,
    required this.totalBudget,
    required this.allocations,
    required this.onAllocationChanged,
    required this.onBack,
    required this.onContinue,
    required this.onManageCategories,
    required this.currencySymbol,
    required this.isDark,
  });

  double get _totalAllocated => allocations.values.fold(0, (s, v) => s + v);

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).textTheme.titleLarge?.color ?? Colors.black;
    final textSub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final dividerColor = Theme.of(context).dividerTheme.color ?? const Color(0xFFF0F0F0);
    final pct = totalBudget == 0 ? 0.0 : (_totalAllocated / totalBudget * 100);
    final isOverBudget = _totalAllocated > totalBudget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set Budget by Category',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap a category to set its allocation.',
                  style: GoogleFonts.poppins(fontSize: 13, color: textSub),
                ),
                const SizedBox(height: 12),
                // UX5: Progress summary pill
                Builder(builder: (ctx) {
                  final allocatedCount =
                      allocations.values.where((v) => v > 0).length;
                  final unallocated =
                      (totalBudget - _totalAllocated).clamp(0.0, double.infinity);
                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isOverBudget
                          ? AppColors.expense.withValues(alpha: 0.08)
                          : AppColors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isOverBudget
                            ? AppColors.expense.withValues(alpha: 0.25)
                            : AppColors.primary.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isOverBudget
                              ? Icons.warning_amber_rounded
                              : Icons.pie_chart_rounded,
                          size: 16,
                          color: isOverBudget
                              ? AppColors.expense
                              : AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isOverBudget
                                ? 'Over budget — reduce some categories'
                                : allocatedCount == 0
                                    ? 'No categories allocated yet'
                                    : '$allocatedCount ${allocatedCount == 1 ? 'category' : 'categories'} allocated',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isOverBudget
                                  ? AppColors.expense
                                  : AppColors.primary,
                            ),
                          ),
                        ),
                        if (!isOverBudget)
                          Text(
                            '${CurrencyFormatter.format(unallocated, symbol: currencySymbol)} left',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Category rows
                Container(
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: () {
                      // Build display from the allocations map keys, which
                      // are seeded from CategoryProvider (Bug 4 fix).
                      final categoryProvider =
                          context.watch<CategoryProvider>();
                      final entries = allocations.entries.toList();
                      return entries.asMap().entries.map((mapEntry) {
                        final i = mapEntry.key;
                        final entry = mapEntry.value;
                        final isLast = i == entries.length - 1;
                        final amount = entry.value;
                        final catPct = totalBudget == 0
                            ? 0.0
                            : (amount / totalBudget * 100);

                        // Resolve display info from CategoryProvider or
                        // fall back to BudgetCategoryMeta defaults.
                        final appCat = categoryProvider.findByName(
                          entry.key,
                          CategoryType.expense,
                        );
                        final meta = appCat != null
                            ? BudgetCategoryMeta.fromAppCategory(appCat)
                            : BudgetCategoryMeta.findByName(entry.key) ??
                                BudgetCategoryMeta(
                                  name: entry.key,
                                  icon: Icons.more_horiz_rounded,
                                  color: AppColors.primary,
                                  lightColor: AppColors.primarySurface,
                                );

                        return Column(
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.only(
                                topLeft: i == 0
                                    ? const Radius.circular(16)
                                    : Radius.zero,
                                topRight: i == 0
                                    ? const Radius.circular(16)
                                    : Radius.zero,
                                bottomLeft: isLast
                                    ? const Radius.circular(16)
                                    : Radius.zero,
                                bottomRight: isLast
                                    ? const Radius.circular(16)
                                    : Radius.zero,
                              ),
                              onTap: () =>
                                  _showAmountDialog(context, meta, amount),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    // Icon
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: meta.color.withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(meta.icon,
                                          color: meta.color, size: 20),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        meta.name,
                                        style: GoogleFonts.poppins(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: textPrimary,
                                        ),
                                      ),
                                    ),
                                    // Amount
                                    Text(
                                      CurrencyFormatter.format(amount,
                                          symbol: currencySymbol),
                                      style: GoogleFonts.poppins(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: amount > 0
                                            ? textPrimary
                                            : textSub,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    SizedBox(
                                      width: 44,
                                      child: Text(
                                        '${catPct.toStringAsFixed(1)}%',
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: textSub,
                                        ),
                                        textAlign: TextAlign.end,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(Icons.chevron_right_rounded,
                                        color: textSub, size: 18),
                                  ],
                                ),
                              ),
                            ),
                            if (!isLast)
                              Divider(
                                  height: 1,
                                  indent: 70,
                                  endIndent: 0,
                                  color: dividerColor),
                          ],
                        );
                      }).toList();
                    }(),
                  ),
                ),

                const SizedBox(height: 20),

                // Manage Categories button
                GestureDetector(
                  onTap: onManageCategories,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 16),
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withOpacity(0.35)),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(isDark ? 0.12 : 0.06),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.settings_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Manage Categories',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Total budget footer card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isOverBudget
                        ? AppColors.expense.withValues(alpha: 0.06)
                        : surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOverBudget
                          ? AppColors.expense
                          : pct >= 100
                              ? AppColors.income
                              : dividerColor,
                      width: (isOverBudget || pct >= 100) ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Budget',
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textPrimary,
                              ),
                            ),
                            if (isOverBudget) ...
                              [
                                const SizedBox(height: 2),
                                Text(
                                  'Over by ${CurrencyFormatter.format(_totalAllocated - totalBudget, symbol: currencySymbol)}',
                                  style: GoogleFonts.poppins(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.expense,
                                  ),
                                ),
                              ],
                          ],
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(totalBudget, symbol: currencySymbol),
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isOverBudget ? AppColors.expense : AppColors.income,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Row(
                        children: [
                          if (isOverBudget)
                            Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Icon(
                                Icons.warning_amber_rounded,
                                size: 14,
                                color: AppColors.expense,
                              ),
                            ),
                          Text(
                            isOverBudget
                                ? '${pct.toStringAsFixed(0)}%'
                                : '${pct.toStringAsFixed(0)}%',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isOverBudget
                                  ? AppColors.expense
                                  : pct >= 100
                                      ? AppColors.income
                                      : textSub,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Bottom buttons — UX4: Continue renamed to 'Review Budget'
        _BottomButtonRow(
          onBack: onBack,
          onContinue: onContinue,
          continueLabel: 'Review Budget',
        ),
      ],
    );
  }

  void _showAmountDialog(BuildContext context, BudgetCategoryMeta meta, double current) {
    final ctrl = TextEditingController(
      text: current > 0 ? current.toStringAsFixed(0) : '',
    );
    final textPrimary = Theme.of(context).textTheme.titleLarge?.color ?? Colors.black;
    final textSub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    // Max this category can hold = total budget minus all OTHER categories' allocations.
    final otherAllocated = _totalAllocated - current;
    final available = (totalBudget - otherAllocated).clamp(0.0, double.infinity);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final entered = double.tryParse(ctrl.text) ?? 0;
          final isOver = entered > available;
          final remaining = available - entered;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: meta.color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(meta.icon, color: meta.color, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    meta.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Available budget chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isOver
                        ? AppColors.expense.withValues(alpha: 0.08)
                        : AppColors.income.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isOver
                          ? AppColors.expense.withValues(alpha: 0.3)
                          : AppColors.income.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOver
                            ? Icons.warning_amber_rounded
                            : Icons.account_balance_wallet_rounded,
                        size: 14,
                        color: isOver ? AppColors.expense : AppColors.income,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          isOver
                              ? 'Exceeds by ${CurrencyFormatter.format(entered - available, symbol: currencySymbol)}'
                              : 'Available: ${CurrencyFormatter.format(remaining, symbol: currencySymbol)}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isOver ? AppColors.expense : AppColors.income,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Amount input
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: false),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isOver ? AppColors.expense : textPrimary,
                  ),
                  onChanged: (_) => setDialogState(() {}),
                  decoration: InputDecoration(
                    hintText: '0',
                    hintStyle: GoogleFonts.poppins(color: textSub),
                    labelText: 'Allocated Amount',
                    labelStyle: GoogleFonts.poppins(
                      color: isOver ? AppColors.expense : textSub,
                      fontSize: 13,
                    ),
                    errorText: isOver
                        ? 'Amount exceeds total budget of ${CurrencyFormatter.format(totalBudget, symbol: currencySymbol)}'
                        : null,
                    errorStyle: GoogleFonts.poppins(fontSize: 11),
                    errorMaxLines: 2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isOver
                            ? AppColors.expense
                            : Theme.of(context).dividerColor,
                        width: isOver ? 1.5 : 1,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: isOver ? AppColors.expense : AppColors.primary,
                        width: 2,
                      ),
                    ),
                    focusedErrorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.expense, width: 2),
                    ),
                    errorBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: AppColors.expense, width: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Budget cap hint
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    'Max for this category: ${CurrencyFormatter.format(available, symbol: currencySymbol)}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: textSub,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              // UX1: Clear button to zero-out this category
              if (current > 0)
                TextButton(
                  onPressed: () {
                    onAllocationChanged(meta.name, 0);
                    Navigator.pop(ctx);
                  },
                  child: Text(
                    'Clear',
                    style: GoogleFonts.poppins(
                        color: AppColors.expense,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text('Cancel', style: GoogleFonts.poppins(color: textSub)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: isOver ? Colors.grey.shade400 : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                ),
                onPressed: isOver
                    ? null
                    : () {
                        final val = double.tryParse(ctrl.text) ?? 0;
                        onAllocationChanged(meta.name, val);
                        Navigator.pop(ctx);
                      },
                child: Text('Set', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ─── Step 3: Review Budget ────────────────────────────────────────────────────

class _Step3 extends StatelessWidget {
  final double totalBudget;
  final DateTime startDate;
  final Map<String, double> allocations;
  final double totalAllocated;
  final VoidCallback onBack;
  final VoidCallback onSave;
  final bool isSaving;
  final String currencySymbol;
  final bool isDark;

  const _Step3({
    super.key,
    required this.totalBudget,
    required this.startDate,
    required this.allocations,
    required this.totalAllocated,
    required this.onBack,
    required this.onSave,
    required this.isSaving,
    required this.currencySymbol,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textPrimary = Theme.of(context).textTheme.titleLarge?.color ?? Colors.black;
    final textSub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;
    final surfaceColor = Theme.of(context).colorScheme.surface;
    final dividerColor = Theme.of(context).dividerTheme.color ?? const Color(0xFFF0F0F0);
    final allocatedCats = allocations.entries.where((e) => e.value > 0).length;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Column(
              children: [
                // Illustration
                _ReviewIllustration(isDark: isDark),
                const SizedBox(height: 24),
                Text(
                  'Review Your Budget',
                  style: GoogleFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Review your budget details before\nwe save it.',
                  style: GoogleFonts.poppins(fontSize: 14, color: textSub),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Summary card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _ReviewRow(
                        label: 'Monthly Budget',
                        value: CurrencyFormatter.format(totalBudget, symbol: currencySymbol),
                        valueColor: textPrimary,
                        dividerColor: dividerColor,
                        isFirst: true,
                      ),
                      _ReviewRow(
                        label: 'Start Date',
                        value: DateFormat('dd MMMM yyyy').format(startDate),
                        valueColor: textPrimary,
                        dividerColor: dividerColor,
                      ),
                      _ReviewRow(
                        label: 'Categories',
                        value: '$allocatedCats',
                        valueColor: textPrimary,
                        dividerColor: dividerColor,
                      ),
                      _ReviewRow(
                        label: 'Total Allocation',
                        value: CurrencyFormatter.format(totalAllocated, symbol: currencySymbol),
                        valueColor: AppColors.income,
                        dividerColor: dividerColor,
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),

        // Bottom buttons — Save Budget uses green
        _BottomButtonRow(
          onBack: isSaving ? () {} : onBack,
          onContinue: isSaving ? () {} : onSave,
          continueLabel: isSaving ? 'Saving…' : 'Save Budget',
          continueColor: isSaving ? Colors.grey.shade400 : AppColors.income,
        ),
      ],
    );
  }
}

// ─── Review Row ───────────────────────────────────────────────────────────────

class _ReviewRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;
  final Color dividerColor;
  final bool isFirst;
  final bool isLast;

  const _ReviewRow({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.dividerColor,
    this.isFirst = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final textSub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return Column(
      children: [
        if (!isFirst) Divider(height: 1, color: dividerColor),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.poppins(fontSize: 14, color: textSub),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Bottom Button Row ────────────────────────────────────────────────────────

class _BottomButtonRow extends StatelessWidget {
  final VoidCallback onBack;
  final VoidCallback onContinue;
  final String continueLabel;
  final Color? continueColor;

  const _BottomButtonRow({
    required this.onBack,
    required this.onContinue,
    this.continueLabel = 'Continue',
    this.continueColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? Theme.of(context).colorScheme.surface : Colors.white;
    final dividerColor = Theme.of(context).dividerTheme.color ?? const Color(0xFFF0F0F0);
    final textSub = Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      decoration: BoxDecoration(
        color: surfaceColor,
        border: Border(top: BorderSide(color: dividerColor)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onBack,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  side: BorderSide(color: dividerColor, width: 1.5),
                ),
                child: Text(
                  'Back',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: textSub,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              flex: 2,
              child: _PrimaryButton(
                label: continueLabel,
                onTap: onContinue,
                color: continueColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Primary Button ───────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _PrimaryButton({required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? AppColors.primary;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        child: Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─── Wallet Illustration (Step 1) ─────────────────────────────────────────────

class _WalletIllustration extends StatelessWidget {
  final bool isDark;
  const _WalletIllustration({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sparkles
          Positioned(
            top: 8,
            left: 60,
            child: _Sparkle(size: 14, color: const Color(0xFFFDAA3D)),
          ),
          Positioned(
            top: 4,
            right: 55,
            child: _Sparkle(size: 18, color: const Color(0xFFFDAA3D)),
          ),
          Positioned(
            bottom: 16,
            right: 48,
            child: _Sparkle(size: 12, color: const Color(0xFFFDAA3D)),
          ),
          // Wallet body
          Container(
            width: 130,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF6C5CE7),
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),
          // Wallet flap
          Positioned(
            top: 30,
            child: Container(
              width: 130,
              height: 40,
              decoration: const BoxDecoration(
                color: Color(0xFF7C6CEF),
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
            ),
          ),
          // Clasp
          Positioned(
            right: 95,
            top: 80,
            child: Container(
              width: 22,
              height: 14,
              decoration: BoxDecoration(
                color: const Color(0xFFFDAA3D),
                borderRadius: BorderRadius.circular(7),
              ),
            ),
          ),
          // Paper money (back)
          Positioned(
            top: 10,
            left: 52,
            child: Transform.rotate(
              angle: -0.18,
              child: Container(
                width: 70,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('\$', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
          // Paper money (front)
          Positioned(
            top: 14,
            left: 68,
            child: Transform.rotate(
              angle: 0.14,
              child: Container(
                width: 70,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF66BB6A),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('\$', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ),
          // Gold coin left
          Positioned(
            bottom: 14,
            left: 38,
            child: _GoldCoin(size: 34),
          ),
          // Gold coin right
          Positioned(
            bottom: 6,
            right: 36,
            child: _GoldCoin(size: 28),
          ),
        ],
      ),
    );
  }
}

class _GoldCoin extends StatelessWidget {
  final double size;
  const _GoldCoin({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [Color(0xFFFFD54F), Color(0xFFFDAA3D)],
          center: Alignment(-0.3, -0.3),
        ),
      ),
      child: Center(
        child: Text(
          '\$',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.38,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _Sparkle extends StatelessWidget {
  final double size;
  final Color color;
  const _Sparkle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Icon(Icons.auto_awesome, size: size, color: color);
  }
}

// ─── Review Illustration (Step 3) ─────────────────────────────────────────────

class _ReviewIllustration extends StatelessWidget {
  final bool isDark;
  const _ReviewIllustration({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Sparkles
          Positioned(
            top: 6,
            left: 58,
            child: _Sparkle(size: 18, color: const Color(0xFFFDAA3D)),
          ),
          Positioned(
            top: 4,
            right: 52,
            child: _Sparkle(size: 14, color: const Color(0xFFFDAA3D)),
          ),
          // Clipboard background
          Container(
            width: 110,
            height: 130,
            decoration: BoxDecoration(
              color: const Color(0xFF00B894),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00B894).withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
          ),
          // Clipboard top clip
          Positioned(
            top: 0,
            child: Container(
              width: 44,
              height: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF00B894).withOpacity(0.8),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
            ),
          ),
          // Clipboard paper
          Positioned(
            top: 18,
            child: Container(
              width: 90,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CheckRow(checked: true),
                  _CheckRow(checked: true),
                  _CheckRow(checked: true),
                ],
              ),
            ),
          ),
          // Target icon (bottom-right)
          Positioned(
            bottom: 4,
            right: 36,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.gps_fixed_rounded, color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final bool checked;
  const _CheckRow({required this.checked});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          checked ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
          color: checked ? AppColors.income : Colors.grey,
          size: 14,
        ),
        const SizedBox(width: 6),
        Container(
          height: 6,
          width: 40,
          decoration: BoxDecoration(
            color: Colors.grey.withOpacity(0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }
}
