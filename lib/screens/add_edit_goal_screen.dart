import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../models/goal_model.dart';
import '../providers/goal_provider.dart';

class AddEditGoalScreen extends StatefulWidget {
  final GoalModel? editGoal;

  const AddEditGoalScreen({super.key, this.editGoal});

  @override
  State<AddEditGoalScreen> createState() => _AddEditGoalScreenState();
}

class _AddEditGoalScreenState extends State<AddEditGoalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  final _savedController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _targetDate = DateTime.now().add(const Duration(days: 180));
  String _selectedCategory = GoalCategory.all.first.name;
  bool _isSaving = false;

  bool get _isEditing => widget.editGoal != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final g = widget.editGoal!;
      _nameController.text = g.name;
      _targetController.text = g.targetAmount.toStringAsFixed(0);
      _savedController.text = g.savedAmount.toStringAsFixed(0);
      _noteController.text = g.note ?? '';
      _targetDate = g.targetDate;
      _selectedCategory = g.categoryName;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    _savedController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate,
      firstDate: DateTime.now(),
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
    if (picked != null) setState(() => _targetDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final target = double.tryParse(_targetController.text.trim());
    final saved = double.tryParse(_savedController.text.trim()) ?? 0.0;

    if (target == null || target <= 0) {
      _showSnack('Enter a valid target amount');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final provider = context.read<GoalProvider>();
      final goal = GoalModel(
        id: widget.editGoal?.id,
        name: _nameController.text.trim(),
        targetAmount: target,
        savedAmount: saved,
        targetDate: _targetDate,
        categoryName: _selectedCategory,
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        createdAt: widget.editGoal?.createdAt ?? DateTime.now(),
      );

      if (_isEditing) {
        await provider.updateGoal(goal);
      } else {
        await provider.addGoal(goal);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        _showSnack('Error: ${e.toString()}');
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
          _isEditing ? 'Edit Goal' : 'Add Goal',
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
              // Goal Name
              _FormLabel('Goal Name'),
              const SizedBox(height: 8),
              _TextInput(
                controller: _nameController,
                hint: 'e.g. New Laptop',
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter goal name' : null,
              ),
              const SizedBox(height: 20),

              // Target Amount
              _FormLabel('Target Amount (Rs.)'),
              const SizedBox(height: 8),
              _NumberInput(
                controller: _targetController,
                hint: '120,000',
              ),
              const SizedBox(height: 20),

              // Saved Amount
              _FormLabel('Saved Amount (Rs.)'),
              const SizedBox(height: 8),
              _NumberInput(
                controller: _savedController,
                hint: '0',
                required: false,
              ),
              const SizedBox(height: 20),

              // Target Date
              _FormLabel('Target Date'),
              const SizedBox(height: 8),
              _DateField(date: _targetDate, onTap: _pickDate),
              const SizedBox(height: 20),

              // Icon / Category
              _FormLabel('Icon / Category'),
              const SizedBox(height: 8),
              _CategoryDropdown(
                selected: _selectedCategory,
                onChanged: (val) => setState(() => _selectedCategory = val!),
              ),
              const SizedBox(height: 20),

              // Note
              _FormLabel('Note (Optional)'),
              const SizedBox(height: 8),
              _NoteInput(
                controller: _noteController,
                hint: 'e.g. Save for a new work laptop.',
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
                        AppColors.primary.withOpacity(0.6),
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
                          _isEditing ? 'Update Goal' : 'Save Goal',
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

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final String? Function(String?)? validator;

  const _TextInput(
      {required this.controller, required this.hint, this.validator});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
      decoration: _inputDecoration(hint),
      validator: validator,
    );
  }
}

class _NumberInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool required;

  const _NumberInput(
      {required this.controller, required this.hint, this.required = true});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
      decoration: _inputDecoration(hint),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Enter an amount' : null
          : null,
    );
  }
}

class _NoteInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _NoteInput({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 4,
      style: GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
      decoration: _inputDecoration(hint),
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateField({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
              DateFormat('d MMM yyyy').format(date),
              style:
                  GoogleFonts.inter(fontSize: 15, color: AppColors.textPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryDropdown extends StatelessWidget {
  final String selected;
  final ValueChanged<String?> onChanged;

  const _CategoryDropdown({required this.selected, required this.onChanged});

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
          selectedItemBuilder: (_) => GoalCategory.all
              .map((c) => _CatRow(cat: c, isSelected: true))
              .toList(),
          items: GoalCategory.all
              .map((c) => DropdownMenuItem<String>(
                    value: c.name,
                    child: _CatRow(cat: c, isSelected: false),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _CatRow extends StatelessWidget {
  final GoalCategory cat;
  final bool isSelected;
  const _CatRow({required this.cat, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration:
              BoxDecoration(color: cat.lightColor, shape: BoxShape.circle),
          child: Icon(cat.icon, color: cat.color, size: 17),
        ),
        const SizedBox(width: 12),
        Text(
          cat.name,
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
