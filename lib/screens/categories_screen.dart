import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../models/category_model.dart';
import '../providers/category_provider.dart';
import 'add_edit_category_screen.dart';
import 'category_detail_screen.dart';

enum _CatFilter { all, defaultCat, custom }

class CategoriesScreen extends StatefulWidget {
  final CategoryType initialType;

  const CategoriesScreen({
    super.key,
    this.initialType = CategoryType.expense,
  });

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  _CatFilter _filter = _CatFilter.all;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialType == CategoryType.expense ? 0 : 1,
    );
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  CategoryType get _currentType =>
      _tabController.index == 0 ? CategoryType.expense : CategoryType.income;

  List<AppCategory> _filtered(List<AppCategory> cats) {
    var list = cats;
    if (_filter == _CatFilter.defaultCat) {
      list = list.where((c) => c.isDefault).toList();
    } else if (_filter == _CatFilter.custom) {
      list = list.where((c) => !c.isDefault).toList();
    }
    if (_search.isNotEmpty) {
      list = list
          .where((c) => c.name.toLowerCase().contains(_search.toLowerCase()))
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CategoryProvider>();
    final isExpense = _currentType == CategoryType.expense;
    final allCats = isExpense
        ? provider.expenseCategories
        : provider.incomeCategories;
    final displayCats = _filtered(allCats);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(isExpense),
      body: Column(
        children: [
          // ── Search ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: _SearchBar(
              controller: _searchCtrl,
              hint: isExpense
                  ? 'Search expense categories'
                  : 'Search income categories',
              onChanged: (v) => setState(() => _search = v),
            ),
          ),

          // ── Type Tabs ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _TypeTabBar(controller: _tabController),
          ),
          const SizedBox(height: 8),

          // ── All / Default / Custom chips ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: _CatFilter.values.map((f) {
                final labels = {
                  _CatFilter.all: 'All',
                  _CatFilter.defaultCat: 'Default',
                  _CatFilter.custom: 'Custom',
                };
                final selected = _filter == f;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _filter = f),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: selected
                              ? AppColors.primary
                              : const Color(0xFFE0E0E0),
                        ),
                      ),
                      child: Text(
                        labels[f]!,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: selected
                              ? Colors.white
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // ── List ──────────────────────────────────────────────────────────
          Expanded(
            child: displayCats.isEmpty
                ? _EmptyState(isExpense: isExpense)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: displayCats.length,
                    itemBuilder: (ctx, i) {
                      final cat = displayCats[i];
                      return _CategoryTile(
                        category: cat,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  CategoryDetailScreen(category: cat),
                            ),
                          );
                          setState(() {});
                        },
                      );
                    },
                  ),
          ),
        ],
      ),

      // ── Add Button ────────────────────────────────────────────────────────
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddEditCategoryScreen(initialType: _currentType),
                  ),
                );
                setState(() {});
              },
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                isExpense ? 'Add Expense Category' : 'Add Income Category',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  AppBar _buildAppBar(bool isExpense) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: Text(
        isExpense ? 'Expense Categories' : 'Income Categories',
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
          onPressed: () {},
        ),
      ],
    );
  }
}

// ─── Sub Widgets ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const _SearchBar(
      {required this.controller,
      required this.hint,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: GoogleFonts.inter(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              GoogleFonts.inter(fontSize: 14, color: AppColors.textHint),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppColors.textHint, size: 20),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        ),
      ),
    );
  }
}

class _TypeTabBar extends StatelessWidget {
  final TabController controller;
  const _TypeTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    // Custom tab bar — two buttons side by side matching the design
    return Row(
      children: [
        _TabButton(
          label: 'Expense',
          isSelected: controller.index == 0,
          onTap: () => controller.animateTo(0),
        ),
        const SizedBox(width: 8),
        _TabButton(
          label: 'Income',
          isSelected: controller.index == 1,
          onTap: () => controller.animateTo(1),
        ),
      ],
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _TabButton(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? AppColors.primary : const Color(0xFFE0E0E0),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color:
                isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final AppCategory category;
  final VoidCallback onTap;
  const _CategoryTile({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 1),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(0),
          border: const Border(
            bottom: BorderSide(color: Color(0xFFF0F0F0), width: 1),
          ),
        ),
        child: Row(
          children: [
            // Icon circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: category.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(category.icon, color: category.color, size: 22),
            ),
            const SizedBox(width: 14),

            // Name + tag
            Expanded(
              child: Row(
                children: [
                  Text(
                    category.name,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _Tag(isDefault: category.isDefault),
                ],
              ),
            ),


            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textHint, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final bool isDefault;
  const _Tag({required this.isDefault});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isDefault
            ? AppColors.income.withValues(alpha: 0.12)
            : const Color(0xFFF0F0F5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isDefault ? 'Default' : 'Custom',
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDefault
              ? AppColors.income
              : AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isExpense;
  const _EmptyState({required this.isExpense});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.category_outlined,
                color: AppColors.primary, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            'No categories found',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isExpense
                ? 'Add your first expense category'
                : 'Add your first income category',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
