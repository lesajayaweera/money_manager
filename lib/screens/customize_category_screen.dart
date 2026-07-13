import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/constants/app_colors.dart';
import '../models/category_model.dart';

class CustomizeCategoryScreen extends StatefulWidget {
  final String categoryName;
  final CategoryType categoryType;
  final IconData initialIcon;
  final Color initialColor;

  const CustomizeCategoryScreen({
    super.key,
    required this.categoryName,
    required this.categoryType,
    required this.initialIcon,
    required this.initialColor,
  });

  @override
  State<CustomizeCategoryScreen> createState() =>
      _CustomizeCategoryScreenState();
}

class _CustomizeCategoryScreenState extends State<CustomizeCategoryScreen> {
  late IconData _selectedIcon;
  late Color _selectedColor;

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.initialIcon;
    _selectedColor = widget.initialColor;
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
          'Customize Category',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Preview Header ──────────────────────────────────────────────
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
                      color: _selectedColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(_selectedIcon,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.categoryName,
                        style: GoogleFonts.inter(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.categoryType == CategoryType.expense
                              ? 'Expense'
                              : 'Income',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── Choose Icon ─────────────────────────────────────────────────
            Text(
              'Choose Icon',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: AppCategory.availableIcons.length,
              itemBuilder: (ctx, i) {
                final icon = AppCategory.availableIcons[i];
                final isSelected = _selectedIcon == icon;
                return GestureDetector(
                  onTap: () => setState(() => _selectedIcon = icon),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primarySurface
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : const Color(0xFFEEEEEE),
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 22,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 28),

            // ── Choose Color ────────────────────────────────────────────────
            Text(
              'Choose Color',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: AppCategory.availableColors.map((color) {
                final isSelected = _selectedColor == color;
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = color),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        width: 2.5,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 40),

            // ── Apply Button ────────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, {
                    'icon': _selectedIcon,
                    'color': _selectedColor,
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  'Apply',
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
    );
  }
}
