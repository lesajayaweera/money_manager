import 'package:flutter/material.dart';

enum CategoryType { income, expense }

class AppCategory {
  final int? id;
  final String name;
  final IconData icon;
  final Color color;
  final CategoryType type;
  final bool isDefault;
  final String? parentCategory;
  final List<String> subcategories;
  final double? monthlyBudget;
  final String? note;
  final bool includeInReports;
  final bool showOnDashboard;
  final bool isActive;
  final int usageCount; // how many transactions use this category

  const AppCategory({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
    this.isDefault = false,
    this.parentCategory,
    this.subcategories = const [],
    this.monthlyBudget,
    this.note,
    this.includeInReports = true,
    this.showOnDashboard = true,
    this.isActive = true,
    this.usageCount = 0,
  });

  Color get lightColor => color.withValues(alpha: 0.15);

  AppCategory copyWith({
    int? id,
    String? name,
    IconData? icon,
    Color? color,
    CategoryType? type,
    bool? isDefault,
    String? parentCategory,
    List<String>? subcategories,
    double? monthlyBudget,
    String? note,
    bool? includeInReports,
    bool? showOnDashboard,
    bool? isActive,
    int? usageCount,
  }) {
    return AppCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      parentCategory: parentCategory ?? this.parentCategory,
      subcategories: subcategories ?? this.subcategories,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      note: note ?? this.note,
      includeInReports: includeInReports ?? this.includeInReports,
      showOnDashboard: showOnDashboard ?? this.showOnDashboard,
      isActive: isActive ?? this.isActive,
      usageCount: usageCount ?? this.usageCount,
    );
  }

  // ─── Selectable Icons ─────────────────────────────────────────────────────
  static const List<IconData> availableIcons = [
    Icons.card_giftcard_rounded,
    Icons.pets_rounded,
    Icons.shopping_bag_rounded,
    Icons.shopping_cart_rounded,
    Icons.directions_car_rounded,
    Icons.home_rounded,
    Icons.favorite_rounded,
    Icons.fitness_center_rounded,
    Icons.school_rounded,
    Icons.flight_rounded,
    Icons.music_note_rounded,
    Icons.sports_esports_rounded,
    Icons.restaurant_rounded,
    Icons.account_balance_wallet_rounded,
    Icons.receipt_long_rounded,
    Icons.headphones_rounded,
    Icons.eco_rounded,
    Icons.star_rounded,
    Icons.child_care_rounded,
    Icons.more_horiz_rounded,
    Icons.laptop_rounded,
    Icons.trending_up_rounded,
    Icons.savings_rounded,
    Icons.business_center_rounded,
    Icons.monetization_on_rounded,
    Icons.currency_exchange_rounded,
    Icons.attach_money_rounded,
    Icons.local_gas_station_rounded,
    Icons.movie_rounded,
    Icons.medical_services_rounded,
  ];

  // ─── Selectable Colors ────────────────────────────────────────────────────
  static const List<Color> availableColors = [
    Color(0xFF6C5CE7), // purple (primary)
    Color(0xFF0984E3), // blue
    Color(0xFF00B894), // teal
    Color(0xFF00CEC9), // cyan
    Color(0xFFFFAA00), // amber
    Color(0xFFE17055), // orange
    Color(0xFFE84393), // pink
    Color(0xFF636E72), // grey
  ];

  // ─── Default Expense Categories ───────────────────────────────────────────
  static List<AppCategory> get defaultExpenseCategories => [
        const AppCategory(
          name: 'Food',
          icon: Icons.restaurant_rounded,
          color: Color(0xFFE17055),
          type: CategoryType.expense,
          isDefault: true,
          usageCount: 128,
          subcategories: ['Breakfast', 'Lunch', 'Dinner', 'Snacks'],
        ),
        const AppCategory(
          name: 'Transport',
          icon: Icons.directions_car_rounded,
          color: Color(0xFF0984E3),
          type: CategoryType.expense,
          isDefault: true,
          usageCount: 96,
          subcategories: ['Auto', 'Cab', 'Bus', 'Metro'],
        ),
        const AppCategory(
          name: 'Bills',
          icon: Icons.receipt_long_rounded,
          color: Color(0xFFFDAA3D),
          type: CategoryType.expense,
          isDefault: true,
          usageCount: 42,
          subcategories: ['Electricity', 'Water', 'Internet', 'Gas'],
        ),
        const AppCategory(
          name: 'Shopping',
          icon: Icons.shopping_bag_rounded,
          color: Color(0xFFE84393),
          type: CategoryType.expense,
          isDefault: false,
          usageCount: 74,
          subcategories: ['Clothing', 'Electronics', 'Books'],
        ),
        const AppCategory(
          name: 'Health',
          icon: Icons.favorite_rounded,
          color: Color(0xFFFF6B6B),
          type: CategoryType.expense,
          isDefault: true,
          usageCount: 28,
          subcategories: ['Medicine', 'Doctor', 'Gym'],
        ),
        const AppCategory(
          name: 'Education',
          icon: Icons.school_rounded,
          color: Color(0xFF6C5CE7),
          type: CategoryType.expense,
          isDefault: false,
          usageCount: 18,
          subcategories: ['Tuition', 'Books', 'Courses'],
        ),
        const AppCategory(
          name: 'Entertainment',
          icon: Icons.movie_rounded,
          color: Color(0xFFA29BFE),
          type: CategoryType.expense,
          isDefault: true,
          usageCount: 36,
          subcategories: ['Movies', 'Concerts', 'Streaming'],
        ),
        const AppCategory(
          name: 'Rent',
          icon: Icons.home_rounded,
          color: Color(0xFFE17055),
          type: CategoryType.expense,
          isDefault: true,
          usageCount: 24,
        ),
        const AppCategory(
          name: 'Fuel',
          icon: Icons.local_gas_station_rounded,
          color: Color(0xFFFFAA00),
          type: CategoryType.expense,
          isDefault: true,
          usageCount: 19,
        ),
        const AppCategory(
          name: 'Pets',
          icon: Icons.pets_rounded,
          color: Color(0xFF00B894),
          type: CategoryType.expense,
          isDefault: false,
          usageCount: 11,
        ),
        const AppCategory(
          name: 'Parents',
          icon: Icons.people_rounded,
          color: Color(0xFFE17055),
          type: CategoryType.expense,
          isDefault: false,
          usageCount: 9,
        ),
        const AppCategory(
          name: 'Online Orders',
          icon: Icons.shopping_cart_rounded,
          color: Color(0xFF6C5CE7),
          type: CategoryType.expense,
          isDefault: false,
          usageCount: 15,
        ),
      ];

  // ─── Default Income Categories ────────────────────────────────────────────
  static List<AppCategory> get defaultIncomeCategories => [
        const AppCategory(
          name: 'Salary',
          icon: Icons.monetization_on_rounded,
          color: Color(0xFF00B894),
          type: CategoryType.income,
          isDefault: true,
          usageCount: 3,
        ),
        const AppCategory(
          name: 'Business',
          icon: Icons.business_center_rounded,
          color: Color(0xFF0984E3),
          type: CategoryType.income,
          isDefault: true,
          usageCount: 5,
        ),
        const AppCategory(
          name: 'Freelance',
          icon: Icons.laptop_rounded,
          color: Color(0xFF00B894),
          type: CategoryType.income,
          isDefault: false,
          usageCount: 7,
        ),
        const AppCategory(
          name: 'Bonus',
          icon: Icons.card_giftcard_rounded,
          color: Color(0xFFFFAA00),
          type: CategoryType.income,
          isDefault: true,
          usageCount: 4,
        ),
        const AppCategory(
          name: 'Gift',
          icon: Icons.card_giftcard_rounded,
          color: Color(0xFFE17055),
          type: CategoryType.income,
          isDefault: false,
          usageCount: 6,
          subcategories: ['Birthday', 'Wedding', 'Anniversary'],
        ),
        const AppCategory(
          name: 'Rental Income',
          icon: Icons.home_rounded,
          color: Color(0xFFE17055),
          type: CategoryType.income,
          isDefault: false,
          usageCount: 3,
        ),
        const AppCategory(
          name: 'Investments',
          icon: Icons.trending_up_rounded,
          color: Color(0xFF00B894),
          type: CategoryType.income,
          isDefault: true,
          usageCount: 8,
        ),
        const AppCategory(
          name: 'Cashback',
          icon: Icons.currency_exchange_rounded,
          color: Color(0xFF00B894),
          type: CategoryType.income,
          isDefault: false,
          usageCount: 5,
        ),
        const AppCategory(
          name: 'Other',
          icon: Icons.more_horiz_rounded,
          color: Color(0xFF00B894),
          type: CategoryType.income,
          isDefault: false,
          usageCount: 2,
        ),
      ];
}
