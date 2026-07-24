import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

enum TransactionType { income, expense }

class TransactionModel {
  final int? id;
  final String title;
  final double amount;
  final TransactionType type;
  final String category;
  final DateTime date;
  final String? note;
  final String walletName;

  const TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    this.note,
    this.walletName = 'Cash',
  });

  bool get isIncome => type == TransactionType.income;
  bool get isExpense => type == TransactionType.expense;

  double get signedAmount => isIncome ? amount : -amount;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'amount': amount,
      'type': type.name,
      'category': category,
      'date': date.toIso8601String(),
      'note': note,
      'wallet_name': walletName,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as int?,
      title: map['title'] as String,
      amount: (map['amount'] as num).toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      category: map['category'] as String,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      walletName: map['wallet_name'] as String? ?? 'Cash',
    );
  }

  TransactionModel copyWith({
    int? id,
    String? title,
    double? amount,
    TransactionType? type,
    String? category,
    DateTime? date,
    String? note,
    String? walletName,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      note: note ?? this.note,
      walletName: walletName ?? this.walletName,
    );
  }

  @override
  String toString() =>
      'Transaction(id: $id, title: $title, amount: $amount, type: ${type.name})';
}

class CategoryModel {
  final String name;
  final IconData icon;
  final Color color;
  final Color lightColor;
  final TransactionType type;

  const CategoryModel({
    required this.name,
    required this.icon,
    required this.color,
    required this.lightColor,
    required this.type,
  });

  static final List<CategoryModel> expenseCategories = [
    const CategoryModel(
      name: 'Food',
      icon: Icons.restaurant_rounded,
      color: AppColors.catFood,
      lightColor: Color(0xFFFDF0EC),
      type: TransactionType.expense,
    ),
    const CategoryModel(
      name: 'Transport',
      icon: Icons.directions_car_rounded,
      color: AppColors.catTransport,
      lightColor: Color(0xFFE8F4FD),
      type: TransactionType.expense,
    ),
    const CategoryModel(
      name: 'Bills',
      icon: Icons.receipt_long_rounded,
      color: AppColors.catBills,
      lightColor: Color(0xFFFFF4E3),
      type: TransactionType.expense,
    ),
    const CategoryModel(
      name: 'Shopping',
      icon: Icons.shopping_bag_rounded,
      color: AppColors.catShopping,
      lightColor: Color(0xFFFCE8F3),
      type: TransactionType.expense,
    ),
    const CategoryModel(
      name: 'Health',
      icon: Icons.favorite_rounded,
      color: AppColors.catHealth,
      lightColor: Color(0xFFFFEEEE),
      type: TransactionType.expense,
    ),
    const CategoryModel(
      name: 'Education',
      icon: Icons.school_rounded,
      color: AppColors.catEducation,
      lightColor: Color(0xFFEAF4FF),
      type: TransactionType.expense,
    ),
    const CategoryModel(
      name: 'Entertainment',
      icon: Icons.movie_rounded,
      color: AppColors.catEntertainment,
      lightColor: Color(0xFFEEECFD),
      type: TransactionType.expense,
    ),
    const CategoryModel(
      name: 'Goals',
      icon: Icons.flag_rounded,
      color: AppColors.primary,
      lightColor: AppColors.primarySurface,
      type: TransactionType.expense,
    ),
    const CategoryModel(
      name: 'Lent',
      icon: Icons.arrow_outward_rounded,
      color: AppColors.spending,
      lightColor: Color(0xFFFFF4E3),
      type: TransactionType.expense,
    ),
    const CategoryModel(
      name: 'Borrowed',
      icon: Icons.arrow_downward_rounded,
      color: AppColors.income,
      lightColor: Color(0xFFE6F9F5),
      type: TransactionType.expense,
    ),
    const CategoryModel(
      name: 'Other',
      icon: Icons.more_horiz_rounded,
      color: AppColors.catOther,
      lightColor: Color(0xFFF2F2F2),
      type: TransactionType.expense,
    ),
  ];

  static final List<CategoryModel> incomeCategories = [
    const CategoryModel(
      name: 'Salary',
      icon: Icons.account_balance_wallet_rounded,
      color: AppColors.catSalary,
      lightColor: Color(0xFFE6F9F5),
      type: TransactionType.income,
    ),
    const CategoryModel(
      name: 'Freelance',
      icon: Icons.laptop_rounded,
      color: AppColors.catFreelance,
      lightColor: Color(0xFFEEECFD),
      type: TransactionType.income,
    ),
    const CategoryModel(
      name: 'Savings',
      icon: Icons.savings_rounded,
      color: AppColors.catSavings,
      lightColor: Color(0xFFE8FFFA),
      type: TransactionType.income,
    ),
    const CategoryModel(
      name: 'Investment',
      icon: Icons.trending_up_rounded,
      color: AppColors.catSalary,
      lightColor: Color(0xFFE6F9F5),
      type: TransactionType.income,
    ),
    const CategoryModel(
      name: 'Gift',
      icon: Icons.card_giftcard_rounded,
      color: AppColors.catShopping,
      lightColor: Color(0xFFFCE8F3),
      type: TransactionType.income,
    ),
    const CategoryModel(
      name: 'Lent',
      icon: Icons.arrow_outward_rounded,
      color: AppColors.spending,
      lightColor: Color(0xFFFFF4E3),
      type: TransactionType.income,
    ),
    const CategoryModel(
      name: 'Borrowed',
      icon: Icons.arrow_downward_rounded,
      color: AppColors.income,
      lightColor: Color(0xFFE6F9F5),
      type: TransactionType.income,
    ),
    const CategoryModel(
      name: 'Other',
      icon: Icons.more_horiz_rounded,
      color: AppColors.catOther,
      lightColor: Color(0xFFF2F2F2),
      type: TransactionType.income,
    ),
  ];

  static CategoryModel? findByName(String name) {
    final all = [...expenseCategories, ...incomeCategories];
    try {
      return all.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  static CategoryModel fallback(TransactionType type) {
    return type == TransactionType.income
        ? incomeCategories.last
        : expenseCategories.last;
  }
}
