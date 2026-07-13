import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../models/lend_borrow_model.dart';
import '../providers/lend_borrow_provider.dart';
import '../providers/transaction_provider.dart';

class AddLendBorrowScreen extends StatefulWidget {
  final LendBorrowType initialType;
  final LendBorrowModel? editEntry;

  const AddLendBorrowScreen({
    super.key,
    this.initialType = LendBorrowType.lent,
    this.editEntry,
  });

  @override
  State<AddLendBorrowScreen> createState() => _AddLendBorrowScreenState();
}

class _AddLendBorrowScreenState extends State<AddLendBorrowScreen> {
  final _formKey = GlobalKey<FormState>();
  final _personController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  late LendBorrowType _type;
  DateTime _date = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  LendBorrowStatus _status = LendBorrowStatus.dueSoon;
  String _paymentMethod = 'Cash';
  bool _isSaving = false;

  bool get _isEditing => widget.editEntry != null;

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    if (_isEditing) {
      final e = widget.editEntry!;
      _personController.text = e.personName;
      _amountController.text = e.amount.toStringAsFixed(0);
      _noteController.text = e.note ?? '';
      _type = e.type;
      _date = e.date;
      _dueDate = e.dueDate;
      _status = e.status;
      _paymentMethod = e.paymentMethod ?? 'Cash';
    }
  }

  @override
  void dispose() {
    _personController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isDueDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDueDate ? _dueDate : _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
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
    if (picked != null) {
      setState(() {
        if (isDueDate) {
          _dueDate = picked;
        } else {
          _date = picked;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid amount');
      return;
    }
    setState(() => _isSaving = true);
    try {
      final provider = context.read<LendBorrowProvider>();
      final entry = LendBorrowModel(
        id: widget.editEntry?.id,
        type: _type,
        personName: _personController.text.trim(),
        amount: amount,
        date: _date,
        dueDate: _dueDate,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        status: _status,
        paymentMethod: _paymentMethod,
        createdAt: widget.editEntry?.createdAt ?? DateTime.now(),
      );

      if (_isEditing) {
        await provider.updateEntry(entry);
      } else {
        await provider.addEntry(entry);
      }
      // Refresh TransactionProvider so balance updates on dashboard
      if (mounted) {
        await context.read<TransactionProvider>().loadAll();
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        _showSnack('Error: $e');
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(fontSize: 14)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          _isEditing ? 'Edit Entry' : 'Add Entry',
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
              // Lent / Borrowed toggle
              _TypeToggle(
                selected: _type,
                onChanged: (t) => setState(() => _type = t),
              ),
              const SizedBox(height: 20),

              // Person Name
              _FormLabel('Person Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _personController,
                style: GoogleFonts.inter(
                    fontSize: 15, color: AppColors.textPrimary),
                decoration: _inputDecoration('Nimal Perera'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Enter person name'
                    : null,
              ),
              const SizedBox(height: 20),

              // Amount
              _FormLabel('Amount (Rs.)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.inter(
                    fontSize: 15, color: AppColors.textPrimary),
                decoration: _inputDecoration('5,000'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter amount' : null,
              ),
              const SizedBox(height: 20),

              // Date and Due Date
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormLabel('Date'),
                        const SizedBox(height: 8),
                        _DateField(date: _date, onTap: () => _pickDate(false)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _FormLabel('Due Date'),
                        const SizedBox(height: 8),
                        _DateField(
                            date: _dueDate, onTap: () => _pickDate(true)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Note
              _FormLabel('Note (Optional)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _noteController,
                maxLines: 3,
                style: GoogleFonts.inter(
                    fontSize: 15, color: AppColors.textPrimary),
                decoration: _inputDecoration('Lunch and transport'),
              ),
              const SizedBox(height: 20),

              // Status
              _FormLabel('Status'),
              const SizedBox(height: 8),
              _StatusDropdown(
                selected: _status,
                onChanged: (s) => setState(() => _status = s),
              ),
              const SizedBox(height: 20),

              // Payment Method
              _FormLabel('Payment Method (Optional)'),
              const SizedBox(height: 8),
              _PaymentMethodDropdown(
                selected: _paymentMethod,
                onChanged: (m) => setState(() => _paymentMethod = m),
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
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      : Text(
                          _isEditing ? 'Update Entry' : 'Save Entry',
                          style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w600),
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

// ─── Type Toggle ──────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  final LendBorrowType selected;
  final ValueChanged<LendBorrowType> onChanged;

  const _TypeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFFEEECFD),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(LendBorrowType.lent),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selected == LendBorrowType.lent
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Lent',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected == LendBorrowType.lent
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(LendBorrowType.borrowed),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  color: selected == LendBorrowType.borrowed
                      ? AppColors.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(22),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Borrowed',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: selected == LendBorrowType.borrowed
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Status Dropdown ──────────────────────────────────────────────────────────

class _StatusDropdown extends StatelessWidget {
  final LendBorrowStatus selected;
  final ValueChanged<LendBorrowStatus> onChanged;

  const _StatusDropdown({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final statuses = LendBorrowStatus.values;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LendBorrowStatus>(
          value: selected,
          isExpanded: true,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary),
          dropdownColor: AppColors.surface,
          items: statuses
              .map((s) => DropdownMenuItem<LendBorrowStatus>(
                    value: s,
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                              color: s.color, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 10),
                        Text(s.label,
                            style: GoogleFonts.inter(
                                fontSize: 15, color: AppColors.textPrimary)),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (s) {
            if (s != null) onChanged(s);
          },
        ),
      ),
    );
  }
}

// ─── Payment Method Dropdown ──────────────────────────────────────────────────

class _PaymentMethodDropdown extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onChanged;

  const _PaymentMethodDropdown(
      {required this.selected, required this.onChanged});

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
          items: LBPaymentMethod.all
              .map((m) => DropdownMenuItem<String>(
                    value: m.name,
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.primarySurface,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(m.icon,
                              color: AppColors.primary, size: 16),
                        ),
                        const SizedBox(width: 12),
                        Text(m.name,
                            style: GoogleFonts.inter(
                                fontSize: 15, color: AppColors.textPrimary)),
                      ],
                    ),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

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

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 15),
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    );

class _DateField extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateField({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_month_outlined,
                color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                DateFormat('d MMM yyyy').format(date),
                style: GoogleFonts.inter(
                    fontSize: 13, color: AppColors.textPrimary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
