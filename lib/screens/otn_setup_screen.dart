import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/otn_models.dart';
import '../providers/otn_provider.dart';
import '../providers/settings_provider.dart';

class OtnSetupScreen extends StatefulWidget {
  const OtnSetupScreen({super.key});

  @override
  State<OtnSetupScreen> createState() => _OtnSetupScreenState();
}

class _OtnSetupScreenState extends State<OtnSetupScreen> {
  late final TextEditingController _basicController;
  late final TextEditingController _otRateController;
  late final TextEditingController _workingDaysController;
  late final TextEditingController _epfRateController;
  late final TextEditingController _etfRateController;

  bool _autoOt = false;
  bool _isSaving = false;
  late List<OtnAllowance> _allowances;
  late List<OtnDeduction> _deductions;

  @override
  void initState() {
    super.initState();
    final s = context.read<OtnProvider>().settings;
    _basicController = TextEditingController(text: _num(s.basicSalary));
    _otRateController = TextEditingController(text: _num(s.overtimeRatePerHour));
    _workingDaysController = TextEditingController(text: '${s.workingDaysPerMonth}');
    _epfRateController = TextEditingController(text: _num(s.epfRate));
    _etfRateController = TextEditingController(text: _num(s.etfRate));
    _autoOt = s.autoOt;
    _allowances = List.from(s.allowances);
    _deductions = List.from(s.deductions);
  }

  String _num(double v) => v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _basicController.dispose();
    _otRateController.dispose();
    _workingDaysController.dispose();
    _epfRateController.dispose();
    _etfRateController.dispose();
    super.dispose();
  }

  double get _basic => CurrencyFormatter.parse(_basicController.text) ?? 0;
  double get _otRate => CurrencyFormatter.parse(_otRateController.text) ?? 0;
  int get _workingDays => int.tryParse(_workingDaysController.text.replaceAll(',', '')) ?? 0;
  double get _epfRate => CurrencyFormatter.parse(_epfRateController.text) ?? 0;
  double get _etfRate => CurrencyFormatter.parse(_etfRateController.text) ?? 0;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final current = context.read<OtnProvider>().settings;

    await context.read<OtnProvider>().saveSettings(current.copyWith(
      basicSalary: _basic,
      overtimeRatePerHour: _otRate,
      workingDaysPerMonth: _workingDays,
      autoOt: _autoOt,
      epfRate: _epfRate,
      etfRate: _etfRate,
      allowances: _allowances,
      deductions: _deductions,
    ));

    if (!mounted) return;
    setState(() => _isSaving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Settings saved', style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _showAllowanceSheet({OtnAllowance? editing}) async {
    final result = await showModalBottomSheet<OtnAllowance>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _AllowanceSheet(existing: editing),
      ),
    );

    if (result == null) return;

    setState(() {
      if (editing != null) {
        final idx = _allowances.indexWhere((a) => a.id == editing.id);
        if (idx != -1) _allowances[idx] = result;
      } else {
        _allowances.add(result);
      }
    });
  }

  void _deleteAllowance(OtnAllowance a) {
    setState(() => _allowances.removeWhere((x) => x.id == a.id));
  }

  Future<void> _showDeductionSheet({OtnDeduction? editing}) async {
    final result = await showModalBottomSheet<OtnDeduction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _DeductionSheet(existing: editing),
      ),
    );

    if (result == null) return;

    setState(() {
      if (editing != null) {
        final idx = _deductions.indexWhere((d) => d.id == editing.id);
        if (idx != -1) _deductions[idx] = result;
      } else {
        _deductions.add(result);
      }
    });
  }

  void _deleteDeduction(OtnDeduction d) {
    setState(() => _deductions.removeWhere((x) => x.id == d.id));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final symbol = context.watch<SettingsProvider>().currencySymbol;
    final bgColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Pay Basics'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _SetupRow(
                        title: 'Currency symbol',
                        valueWidget: Text(symbol,
                            style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                      _Divider(color: borderColor),
                      _SetupRow(
                        title: 'Basic salary',
                        valueWidget: _InlineTextField(
                            controller: _basicController, isDark: isDark),
                      ),
                      _Divider(color: borderColor),
                      _SetupRow(
                        title: 'OT rate (per hour)',
                        valueWidget: _InlineTextField(
                            controller: _otRateController, isDark: isDark, hint: '0.00'),
                      ),
                      _Divider(color: borderColor),
                      _SetupRow(
                        title: 'Working days / month',
                        valueWidget: _InlineTextField(
                            controller: _workingDaysController, isDark: isDark, hint: '22'),
                      ),
                      _Divider(color: borderColor),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Auto-OT',
                                      style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).textTheme.titleLarge?.color)),
                                  const SizedBox(height: 2),
                                  Text('Calculate OT from daily attendance',
                                      style: GoogleFonts.poppins(
                                          fontSize: 13,
                                          color: Theme.of(context).textTheme.bodySmall?.color,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                            Switch(
                              value: _autoOt,
                              onChanged: (val) => setState(() => _autoOt = val),
                              activeColor: AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                _SectionTitle('EPF / ETF'),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                  ),
                  child: Column(
                    children: [
                      _SetupRow(
                        title: 'EPF employee rate (%)',
                        valueWidget: _InlineTextField(
                            controller: _epfRateController, isDark: isDark, hint: '12'),
                      ),
                      _Divider(color: borderColor),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('ETF rate (%)',
                                      style: GoogleFonts.poppins(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: Theme.of(context).textTheme.titleLarge?.color)),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Employer-paid — for reference\nonly, not deducted from your net',
                                    style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        color: Theme.of(context).textTheme.bodySmall?.color,
                                        fontWeight: FontWeight.w600,
                                        height: 1.3),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            _InlineTextField(
                                controller: _etfRateController, isDark: isDark, hint: '3'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Allowances ──────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionTitle('Allowances'),
                    GestureDetector(
                      onTap: () => _showAllowanceSheet(),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 18, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text('Add',
                              style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_allowances.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      'No allowances yet. Tap Add to create one.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < _allowances.length; i++) ...[
                          if (i > 0) _Divider(color: borderColor),
                          _AllowanceRow(
                            allowance: _allowances[i],
                            symbol: symbol,
                            isDark: isDark,
                            onEdit: () => _showAllowanceSheet(editing: _allowances[i]),
                            onDelete: () => _deleteAllowance(_allowances[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 24),

                // ── Deductions ─────────────────────────────────────────────
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _SectionTitle('Deductions'),
                    GestureDetector(
                      onTap: () => _showDeductionSheet(),
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 18, color: AppColors.expense),
                          const SizedBox(width: 4),
                          Text('Add',
                              style: GoogleFonts.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.expense)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_deductions.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Text(
                      'No deductions yet. Tap Add to create one.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: Theme.of(context).textTheme.bodySmall?.color,
                          fontWeight: FontWeight.w600),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      children: [
                        for (int i = 0; i < _deductions.length; i++) ...[
                          if (i > 0) _Divider(color: borderColor),
                          _DeductionRow(
                            deduction: _deductions[i],
                            symbol: symbol,
                            onEdit: () => _showDeductionSheet(editing: _deductions[i]),
                            onDelete: () => _deleteDeduction(_deductions[i]),
                          ),
                        ],
                      ],
                    ),
                  ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),

        // ── Save Button ───────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text('Save Settings',
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Allowance Row ────────────────────────────────────────────────────────────

class _AllowanceRow extends StatelessWidget {
  final OtnAllowance allowance;
  final String symbol;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AllowanceRow({
    required this.allowance,
    required this.symbol,
    required this.isDark,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(allowance.name,
                    style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.titleLarge?.color)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Text('$symbol ${allowance.amount.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary)),
                    const SizedBox(width: 10),
                    if (allowance.epfEligible)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('EPF eligible',
                            style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary)),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: Icon(Icons.edit_rounded, size: 18,
                color: Theme.of(context).textTheme.bodySmall?.color),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.expense),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ─── Allowance Bottom Sheet ───────────────────────────────────────────────────

class _AllowanceSheet extends StatefulWidget {
  final OtnAllowance? existing;
  const _AllowanceSheet({this.existing});

  @override
  State<_AllowanceSheet> createState() => _AllowanceSheetState();
}

class _AllowanceSheetState extends State<_AllowanceSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  bool _epfEligible = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _amountController = TextEditingController(
        text: widget.existing != null ? widget.existing!.amount.toStringAsFixed(0) : '');
    _epfEligible = widget.existing?.epfEligible ?? false;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final amount = double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please enter an allowance name.',
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppColors.expense,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    final allowance = OtnAllowance(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: name,
      amount: amount,
      epfEligible: _epfEligible,
    );
    Navigator.of(context).pop(allowance);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;
    final symbol = context.watch<SettingsProvider>().currencySymbol;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkDivider : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existing != null ? 'Edit Allowance' : 'Add Allowance',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.titleLarge?.color),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Theme.of(context).textTheme.titleLarge?.color),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Name field
              Text('Allowance name',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.titleLarge?.color)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.poppins(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'e.g. Transport, Meal',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 15,
                      color: isDark ? AppColors.darkTextHint : AppColors.textHint),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Amount field
              Text('Amount',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.titleLarge?.color)),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                style: GoogleFonts.poppins(fontSize: 15),
                decoration: InputDecoration(
                  prefixText: '$symbol  ',
                  prefixStyle: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color:
                          isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  hintText: '0.00',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 15,
                      color: isDark ? AppColors.darkTextHint : AppColors.textHint),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // EPF Eligible toggle
              GestureDetector(
                onTap: () => setState(() => _epfEligible = !_epfEligible),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: _epfEligible
                        ? AppColors.primary.withOpacity(0.08)
                        : (isDark ? AppColors.darkSurface : Colors.white),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: _epfEligible ? AppColors.primary.withOpacity(0.4) : borderColor,
                      width: _epfEligible ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('EPF eligible',
                                style: GoogleFonts.poppins(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: _epfEligible
                                        ? AppColors.primary
                                        : Theme.of(context).textTheme.titleLarge?.color)),
                            const SizedBox(height: 2),
                            Text('This allowance counts toward EPF calculation',
                                style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).textTheme.bodySmall?.color)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _epfEligible,
                        onChanged: (val) => setState(() => _epfEligible = val),
                        activeColor: AppColors.primary,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    widget.existing != null ? 'Update Allowance' : 'Add Allowance',
                    style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).textTheme.titleLarge?.color,
      ),
    );
  }
}

class _SetupRow extends StatelessWidget {
  final String title;
  final Widget valueWidget;

  const _SetupRow({required this.title, required this.valueWidget});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
          ),
          const SizedBox(width: 16),
          valueWidget,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  final Color color;
  const _Divider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: color, indent: 16, endIndent: 16);
  }
}

class _InlineTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool isDark;
  final String? hint;

  const _InlineTextField({required this.controller, required this.isDark, this.hint});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 120,
      child: TextField(
        controller: controller,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
        style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
          border: InputBorder.none,
          hintText: hint,
          hintStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkTextHint : AppColors.textHint,
          ),
        ),
      ),
    );
  }
}

// ─── Deduction Row ────────────────────────────────────────────────────────────

class _DeductionRow extends StatelessWidget {
  final OtnDeduction deduction;
  final String symbol;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DeductionRow({
    required this.deduction,
    required this.symbol,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deduction.name,
                  style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.titleLarge?.color),
                ),
                const SizedBox(height: 3),
                Text(
                  '- $symbol ${deduction.amount.toStringAsFixed(0)}',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.expense),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: Icon(Icons.edit_rounded,
                size: 18, color: Theme.of(context).textTheme.bodySmall?.color),
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded,
                size: 18, color: AppColors.expense),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ─── Deduction Bottom Sheet ───────────────────────────────────────────────────

class _DeductionSheet extends StatefulWidget {
  final OtnDeduction? existing;
  const _DeductionSheet({this.existing});

  @override
  State<_DeductionSheet> createState() => _DeductionSheetState();
}

class _DeductionSheetState extends State<_DeductionSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _amountController = TextEditingController(
        text: widget.existing != null
            ? widget.existing!.amount.toStringAsFixed(0)
            : '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    final amount =
        double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Please enter a deduction name.',
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppColors.expense,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }

    Navigator.of(context).pop(OtnDeduction(
      id: widget.existing?.id ?? const Uuid().v4(),
      name: name,
      amount: amount,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final borderColor = isDark ? AppColors.darkDivider : Colors.grey.shade200;
    final symbol = context.watch<SettingsProvider>().currencySymbol;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),

              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkDivider : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.existing != null ? 'Edit Deduction' : 'Add Deduction',
                    style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.titleLarge?.color),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Theme.of(context).textTheme.titleLarge?.color),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Name field
              Text('Deduction name',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.titleLarge?.color)),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.poppins(fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'e.g. Loan, Advance',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 15,
                      color: isDark ? AppColors.darkTextHint : AppColors.textHint),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.expense, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Amount field
              Text('Amount',
                  style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).textTheme.titleLarge?.color)),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
                ],
                style: GoogleFonts.poppins(fontSize: 15),
                decoration: InputDecoration(
                  prefixText: '- $symbol  ',
                  prefixStyle: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.expense),
                  hintText: '0.00',
                  hintStyle: GoogleFonts.poppins(
                      fontSize: 15,
                      color: isDark ? AppColors.darkTextHint : AppColors.textHint),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: borderColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: AppColors.expense, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.expense,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    widget.existing != null
                        ? 'Update Deduction'
                        : 'Add Deduction',
                    style:
                        GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

