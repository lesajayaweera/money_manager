import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

// ─── Goal Category ─────────────────────────────────────────────────────────────

class GoalCategory {
  final String name;
  final IconData icon;
  final Color color;
  final Color lightColor;

  const GoalCategory({
    required this.name,
    required this.icon,
    required this.color,
    required this.lightColor,
  });

  static const List<GoalCategory> all = [
    GoalCategory(
      name: 'Emergency Fund',
      icon: Icons.shield_outlined,
      color: AppColors.primary,
      lightColor: AppColors.primarySurface,
    ),
    GoalCategory(
      name: 'Electronics',
      icon: Icons.phone_android_rounded,
      color: Color(0xFF00B894),
      lightColor: Color(0xFFE6F9F5),
    ),
    GoalCategory(
      name: 'Vacation',
      icon: Icons.beach_access_rounded,
      color: Color(0xFFE17055),
      lightColor: Color(0xFFFDF0EC),
    ),
    GoalCategory(
      name: 'Education',
      icon: Icons.school_rounded,
      color: Color(0xFF74B9FF),
      lightColor: Color(0xFFEAF4FF),
    ),
    GoalCategory(
      name: 'Vehicle',
      icon: Icons.directions_car_rounded,
      color: Color(0xFF0984E3),
      lightColor: Color(0xFFE8F4FD),
    ),
    GoalCategory(
      name: 'Home',
      icon: Icons.home_rounded,
      color: Color(0xFFFDAA3D),
      lightColor: Color(0xFFFFF4E3),
    ),
    GoalCategory(
      name: 'Health',
      icon: Icons.favorite_rounded,
      color: Color(0xFFFF6B6B),
      lightColor: Color(0xFFFFEEEE),
    ),
    GoalCategory(
      name: 'Wedding',
      icon: Icons.favorite_border_rounded,
      color: Color(0xFFE84393),
      lightColor: Color(0xFFFCE8F3),
    ),
    GoalCategory(
      name: 'Business',
      icon: Icons.business_center_rounded,
      color: Color(0xFFA29BFE),
      lightColor: Color(0xFFEEECFD),
    ),
    GoalCategory(
      name: 'Other',
      icon: Icons.star_outline_rounded,
      color: Color(0xFF636E72),
      lightColor: Color(0xFFF2F2F2),
    ),
  ];

  static GoalCategory? findByName(String name) {
    try {
      return all.firstWhere((c) => c.name == name);
    } catch (_) {
      return null;
    }
  }

  static GoalCategory get fallback => all.last;
}

// ─── Goal Savings Entry ────────────────────────────────────────────────────────

class GoalSavingsEntry {
  final int? id;
  final int goalId;
  final double amount;
  final DateTime date;
  final String? note;

  const GoalSavingsEntry({
    this.id,
    required this.goalId,
    required this.amount,
    required this.date,
    this.note,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'goal_id': goalId,
        'amount': amount,
        'date': date.toIso8601String(),
        'note': note,
      };

  factory GoalSavingsEntry.fromMap(Map<String, dynamic> map) =>
      GoalSavingsEntry(
        id: map['id'] as int?,
        goalId: map['goal_id'] as int,
        amount: (map['amount'] as num).toDouble(),
        date: DateTime.parse(map['date'] as String),
        note: map['note'] as String?,
      );
}

// ─── Goal Model ────────────────────────────────────────────────────────────────

class GoalModel {
  final int? id;
  final String name;
  final double targetAmount;
  final double savedAmount;
  final DateTime targetDate;
  final String categoryName;
  final String? note;
  final DateTime createdAt;

  const GoalModel({
    this.id,
    required this.name,
    required this.targetAmount,
    required this.savedAmount,
    required this.targetDate,
    required this.categoryName,
    this.note,
    required this.createdAt,
  });

  double get progressPercent =>
      targetAmount > 0 ? (savedAmount / targetAmount).clamp(0.0, 1.0) : 0.0;

  double get remainingAmount => (targetAmount - savedAmount).clamp(0, double.infinity);

  bool get isCompleted => savedAmount >= targetAmount;

  GoalCategory get category =>
      GoalCategory.findByName(categoryName) ?? GoalCategory.fallback;

  GoalModel copyWith({
    int? id,
    String? name,
    double? targetAmount,
    double? savedAmount,
    DateTime? targetDate,
    String? categoryName,
    String? note,
    DateTime? createdAt,
  }) =>
      GoalModel(
        id: id ?? this.id,
        name: name ?? this.name,
        targetAmount: targetAmount ?? this.targetAmount,
        savedAmount: savedAmount ?? this.savedAmount,
        targetDate: targetDate ?? this.targetDate,
        categoryName: categoryName ?? this.categoryName,
        note: note ?? this.note,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'target_amount': targetAmount,
        'saved_amount': savedAmount,
        'target_date': targetDate.toIso8601String(),
        'category_name': categoryName,
        'note': note,
        'created_at': createdAt.toIso8601String(),
      };

  factory GoalModel.fromMap(Map<String, dynamic> map) => GoalModel(
        id: map['id'] as int?,
        name: map['name'] as String,
        targetAmount: (map['target_amount'] as num).toDouble(),
        savedAmount: (map['saved_amount'] as num).toDouble(),
        targetDate: DateTime.parse(map['target_date'] as String),
        categoryName: map['category_name'] as String,
        note: map['note'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
