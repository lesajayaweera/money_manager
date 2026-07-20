import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/category_model.dart';
import '../providers/category_provider.dart';
import 'add_edit_category_screen.dart';
import 'customize_category_screen.dart';

class CategoryDetailScreen extends StatefulWidget {
  final AppCategory category;

  const CategoryDetailScreen({super.key, required this.category});

  @override
  State<CategoryDetailScreen> createState() => _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends State<CategoryDetailScreen> {
  late AppCategory _category;

  @override
  void initState() {
    super.initState();
    _category = widget.category;
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Remove Category',
          style: GoogleFonts.inter(
              fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        ),
        content: Text(
          'Are you sure you want to remove "${_category.name}"? This cannot be undone.',
          style:
              GoogleFonts.inter(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              context.read<CategoryProvider>().deleteCategory(_category);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text('Remove',
                style: GoogleFonts.inter(
                    color: AppColors.expense, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Future<void> _openCustomize() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomizeCategoryScreen(
          categoryName: _category.name,
          categoryType: _category.type,
          initialIcon: _category.icon,
          initialColor: _category.color,
        ),
      ),
    );
    if (result != null && mounted) {
      final updated = _category.copyWith(
        icon: result['icon'] as IconData,
        color: result['color'] as Color,
      );
      context.read<CategoryProvider>().updateCategory(updated);
      setState(() => _category = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isExpense = _category.type == CategoryType.expense;

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
          'Category Details',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded,
                color: AppColors.textSecondary),
            onPressed: () => _showMoreMenu(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ── Header Card ──────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: _category.color,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_category.icon, color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            _category.name,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _TypeBadge(isExpense: isExpense),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _category.isDefault
                            ? 'Default Category'
                            : 'Custom Category',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Details Section ──────────────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  _DetailRow(
                    label: 'Category Name',
                    value: _category.name,
                    onTap: () => _editCategory(),
                  ),
                  _Divider(),
                  _DetailRow(
                    label: 'Type',
                    value: isExpense ? 'Expense' : 'Income',
                    valueColor: AppColors.primary,
                    onTap: () => _editCategory(),
                  ),
                  _Divider(),
                  _IconColorRow(
                    color: _category.color,
                    onTap: () => _openCustomize(),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Toggle Section ───────────────────────────────────────────────
            // Container(
            //   decoration: BoxDecoration(
            //     color: AppColors.surface,
            //     borderRadius: BorderRadius.circular(16),
            //   ),
            //   child: Column(
            //     children: [
            //       _ToggleRow(
            //         label: 'Include in Reports',
            //         value: _category.includeInReports,
            //         onChanged: (v) {
            //           final updated =
            //               _category.copyWith(includeInReports: v);
            //           context
            //               .read<CategoryProvider>()
            //               .updateCategory(updated);
            //           setState(() => _category = updated);
            //         },
            //       ),
            //       _Divider(),
            //       _ToggleRow(
            //         label: 'Show on Dashboard',
            //         value: _category.showOnDashboard,
            //         onChanged: (v) {
            //           final updated =
            //               _category.copyWith(showOnDashboard: v);
            //           context
            //               .read<CategoryProvider>()
            //               .updateCategory(updated);
            //           setState(() => _category = updated);
            //         },
            //       ),
            //       _Divider(),
            //       _ToggleRow(
            //         label: 'Active Status',
            //         value: _category.isActive,
            //         onChanged: (v) {
            //           final updated = _category.copyWith(isActive: v);
            //           context
            //               .read<CategoryProvider>()
            //               .updateCategory(updated);
            //           setState(() => _category = updated);
            //         },
            //       ),
            //     ],
            //   ),
            // ),
            const SizedBox(height: 16),

            // ── Save Changes ──────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _category),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Save Changes',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // ── Remove ────────────────────────────────────────────────────────
            if (!_category.isDefault)
              TextButton(
                onPressed: _showDeleteDialog,
                child: Text(
                  'Remove Category',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.expense,
                  ),
                ),
              ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _editCategory() async {
    final result = await Navigator.push<AppCategory>(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditCategoryScreen(
          initialType: _category.type,
          editCategory: _category,
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() => _category = result);
    }
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded, color: AppColors.primary),
              title: Text('Edit Category',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                _editCategory();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.palette_rounded, color: AppColors.primary),
              title: Text('Customize Icon & Color',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(context);
                _openCustomize();
              },
            ),
            if (!_category.isDefault)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded,
                    color: AppColors.expense),
                title: Text('Remove Category',
                    style: GoogleFonts.inter(
                        color: AppColors.expense, fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteDialog();
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Sub Widgets ──────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  final bool isExpense;
  const _TypeBadge({required this.isExpense});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isExpense ? 'Expense' : 'Income',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback onTap;
  const _DetailRow(
      {required this.label,
      required this.value,
      this.valueColor,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                Text(
                  value,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: valueColor ?? AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _IconColorRow extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  const _IconColorRow({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Icon & Color',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
            Row(
              children: [
                CircleAvatar(backgroundColor: color, radius: 10),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint, size: 18),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _ToggleRow(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style:
                GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.5),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1,
        thickness: 1,
        color: Color(0xFFF5F5F5),
        indent: 16,
        endIndent: 16);
  }
}

class _SubcategoryChip extends StatelessWidget {
  final String label;
  const _SubcategoryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
