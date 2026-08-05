import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import 'category_model.dart';

// ─── Budget Category Allocation ───────────────────────────────────────────────

class BudgetCategoryAllocation {
  final int? id;
  final int budgetId;
  final String categoryName;
  final double allocatedAmount;

  const BudgetCategoryAllocation({
    this.id,
    required this.budgetId,
    required this.categoryName,
    required this.allocatedAmount,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'budget_id': budgetId,
        'category_name': categoryName,
        'allocated_amount': allocatedAmount,
      };

  factory BudgetCategoryAllocation.fromMap(Map<String, dynamic> m) =>
      BudgetCategoryAllocation(
        id: m['id'] as int?,
        budgetId: m['budget_id'] as int,
        categoryName: m['category_name'] as String,
        allocatedAmount: (m['allocated_amount'] as num).toDouble(),
      );

  BudgetCategoryAllocation copyWith({double? allocatedAmount}) =>
      BudgetCategoryAllocation(
        id: id,
        budgetId: budgetId,
        categoryName: categoryName,
        allocatedAmount: allocatedAmount ?? this.allocatedAmount,
      );
}

// ─── Budget Model ─────────────────────────────────────────────────────────────

class BudgetModel {
  final int? id;
  final double totalAmount;
  final DateTime startDate;
  final List<BudgetCategoryAllocation> categories;
  final String createdAt;

  const BudgetModel({
    this.id,
    required this.totalAmount,
    required this.startDate,
    required this.categories,
    required this.createdAt,
  });

  double get totalAllocated =>
      categories.fold(0, (s, c) => s + c.allocatedAmount);

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'total_amount': totalAmount,
        'start_date': startDate.toIso8601String(),
        'created_at': createdAt,
      };

  factory BudgetModel.fromMap(
    Map<String, dynamic> m,
    List<BudgetCategoryAllocation> categories,
  ) =>
      BudgetModel(
        id: m['id'] as int?,
        totalAmount: (m['total_amount'] as num).toDouble(),
        startDate: DateTime.parse(m['start_date'] as String),
        categories: categories,
        createdAt: m['created_at'] as String,
      );
}

// ─── Budget Category Meta (display info) ──────────────────────────────────────

class BudgetCategoryMeta {
  final String name;
  final IconData icon;
  final Color color;
  final Color lightColor;

  const BudgetCategoryMeta({
    required this.name,
    required this.icon,
    required this.color,
    required this.lightColor,
  });

  static final List<BudgetCategoryMeta> defaults = [
    const BudgetCategoryMeta(
      name: 'Food',
      icon: Icons.restaurant_rounded,
      color: AppColors.catFood,
      lightColor: Color(0xFFFDF0EC),
    ),
    const BudgetCategoryMeta(
      name: 'Transport',
      icon: Icons.directions_car_rounded,
      color: AppColors.catTransport,
      lightColor: Color(0xFFE8F4FD),
    ),
    const BudgetCategoryMeta(
      name: 'Health',
      icon: Icons.favorite_rounded,
      color: AppColors.catHealth,
      lightColor: Color(0xFFFFEEEE),
    ),
    const BudgetCategoryMeta(
      name: 'Shopping',
      icon: Icons.shopping_bag_rounded,
      color: AppColors.catShopping,
      lightColor: Color(0xFFFCE8F3),
    ),
    const BudgetCategoryMeta(
      name: 'Bills',
      icon: Icons.receipt_long_rounded,
      color: AppColors.catBills,
      lightColor: Color(0xFFFFF4E3),
    ),
    const BudgetCategoryMeta(
      name: 'Others',
      icon: Icons.more_horiz_rounded,
      color: AppColors.catOther,
      lightColor: Color(0xFFF2F2F2),
    ),
  ];

  static BudgetCategoryMeta? findByName(String name) {
    try {
      return defaults.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  /// Resolve display metadata for [name] from the defaults list first, then
  /// fall back to an [AppCategory] lookup so custom categories work too.
  static BudgetCategoryMeta fromAppCategory(AppCategory cat) {
    // Check if a hard-coded default exists for this name.
    final hardcoded = findByName(cat.name);
    if (hardcoded != null) return hardcoded;
    // Build from the AppCategory definition.
    return BudgetCategoryMeta(
      name: cat.name,
      icon: cat.icon,
      color: cat.color,
      lightColor: cat.color.withValues(alpha: 0.12),
    );
  }
}
