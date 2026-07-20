import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../models/category_model.dart';
import '../providers/category_provider.dart';
import 'customize_category_screen.dart';

class AddEditCategoryScreen extends StatefulWidget {
  final CategoryType initialType;
  final AppCategory? editCategory;

  const AddEditCategoryScreen({
    super.key,
    required this.initialType,
    this.editCategory,
  });

  @override
  State<AddEditCategoryScreen> createState() => _AddEditCategoryScreenState();
}

class _AddEditCategoryScreenState extends State<AddEditCategoryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  late CategoryType _type;
  late IconData _selectedIcon;
  late Color _selectedColor;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.editCategory?.type ?? widget.initialType;
    _selectedIcon =
        widget.editCategory?.icon ?? AppCategory.availableIcons.first;
    _selectedColor =
        widget.editCategory?.color ?? AppCategory.availableColors.first;

    if (widget.editCategory != null) {
      final e = widget.editCategory!;
      _nameCtrl.text = e.name;
      _noteCtrl.text = e.note ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final provider = context.read<CategoryProvider>();
    final name = _nameCtrl.text.trim();
    final newCategory = widget.editCategory?.copyWith(
          name: name,
          icon: _selectedIcon,
          color: _selectedColor,
          type: _type,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          parentCategory: null,
          monthlyBudget: null,
        ) ??
        AppCategory(
          name: name,
          icon: _selectedIcon,
          color: _selectedColor,
          type: _type,
          isDefault: false,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          includeInReports: true,
          showOnDashboard: true,
          isActive: true,
        );

    if (widget.editCategory != null) {
      provider.updateCategory(widget.editCategory!, newCategory);
    } else {
      provider.addCategory(newCategory);
    }

    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) Navigator.pop(context, newCategory);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.editCategory != null;
    final previewName =
        _nameCtrl.text.trim().isEmpty ? 'Category' : _nameCtrl.text.trim();

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
          isEditing ? 'Edit Category' : 'Add Category',
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
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Preview Card ────────────────────────────────────────────────
              Column(
                children: [
                  Container(
                    width: 120,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primarySurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: _selectedColor,
                          child: Icon(_selectedIcon,
                              color: Colors.white, size: 26),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          previewName,
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _type == CategoryType.expense
                                ? 'Expense'
                                : 'Income',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Preview',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // ── Form Column ──────────────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Category Name
                    _FormLabel('Category Name'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameCtrl,
                      onChanged: (_) => setState(() {}),
                      style: GoogleFonts.inter(
                          fontSize: 15, color: AppColors.textPrimary),
                      decoration: _inputDecor('e.g. Pet Care'),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Enter a category name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 18),

                    // Type toggle
                    _FormLabel('Type'),
                    const SizedBox(height: 8),
                    _TypeToggle(
                      selected: _type,
                      onChanged: (t) => setState(() => _type = t),
                    ),
                    const SizedBox(height: 18),



                    // Icon picker
                    _FormLabel('Icon'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _openCustomize(),
                      child: _PickerField(
                        child: Row(
                          children: [
                            Icon(_selectedIcon,
                                color: _selectedColor, size: 22),
                            const SizedBox(width: 10),
                            Text(
                              'Choose icon',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textHint),
                            ),
                            const Spacer(),
                            const Icon(Icons.chevron_right_rounded,
                                color: AppColors.textHint, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Color picker
                    _FormLabel('Color'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => _openCustomize(),
                      child: _PickerField(
                        child: Row(
                          children: [
                            CircleAvatar(
                                backgroundColor: _selectedColor, radius: 12),
                            const SizedBox(width: 10),
                            Text(
                              '#${_selectedColor.toARGB32().toRadixString(16).toUpperCase().substring(2)}',
                              style: GoogleFonts.inter(
                                  fontSize: 14,
                                  color: AppColors.textPrimary),
                            ),
                            const Spacer(),
                            const Icon(Icons.keyboard_arrow_down_rounded,
                                color: AppColors.textHint, size: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),



                    // Note
                    _FormLabel('Note (Optional)'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _noteCtrl,
                      maxLines: 3,
                      style: GoogleFonts.inter(
                          fontSize: 14, color: AppColors.textPrimary),
                      decoration: _inputDecor('Add a note...'),
                    ),
                    const SizedBox(height: 28),

                    // Save button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white),
                              )
                            : Text(
                                'Save Category',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCustomize() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomizeCategoryScreen(
          categoryName: _nameCtrl.text.trim().isEmpty
              ? 'Category'
              : _nameCtrl.text.trim(),
          categoryType: _type,
          initialIcon: _selectedIcon,
          initialColor: _selectedColor,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedIcon = result['icon'] as IconData;
        _selectedColor = result['color'] as Color;
      });
    }
  }

  InputDecoration _inputDecor(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(
            color: AppColors.textHint, fontSize: 14),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.expense),
        ),
      );
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _FormLabel extends StatelessWidget {
  final String text;
  const _FormLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  final Widget child;
  const _PickerField({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E0E0)),
      ),
      child: child,
    );
  }
}

class _TypeToggle extends StatelessWidget {
  final CategoryType selected;
  final ValueChanged<CategoryType> onChanged;
  const _TypeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _ToggleBtn(
            label: 'Expense',
            isActive: selected == CategoryType.expense,
            onTap: () => onChanged(CategoryType.expense),
          ),
          _ToggleBtn(
            label: 'Income',
            isActive: selected == CategoryType.income,
            onTap: () => onChanged(CategoryType.income),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  const _ToggleBtn(
      {required this.label,
      required this.isActive,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}


