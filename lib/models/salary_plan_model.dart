import 'dart:convert';
import 'package:flutter/material.dart';

// ─── Allocation Destination Types ─────────────────────────────────────────────

enum AllocationType { category, savingsGoal, loan, creditCard }

extension AllocationTypeX on AllocationType {
  String get label {
    switch (this) {
      case AllocationType.category:
        return 'Expense Category';
      case AllocationType.savingsGoal:
        return 'Savings Goal';
      case AllocationType.loan:
        return 'Loan Payment';
      case AllocationType.creditCard:
        return 'Credit Card Payment';
    }
  }

  String get shortLabel {
    switch (this) {
      case AllocationType.category:
        return 'Expense';
      case AllocationType.savingsGoal:
        return 'Savings';
      case AllocationType.loan:
        return 'Loan';
      case AllocationType.creditCard:
        return 'Credit Card';
    }
  }

  IconData get icon {
    switch (this) {
      case AllocationType.category:
        return Icons.shopping_bag_rounded;
      case AllocationType.savingsGoal:
        return Icons.savings_rounded;
      case AllocationType.loan:
        return Icons.account_balance_rounded;
      case AllocationType.creditCard:
        return Icons.credit_card_rounded;
    }
  }

  Color get color {
    switch (this) {
      case AllocationType.category:
        return const Color(0xFFE17055);
      case AllocationType.savingsGoal:
        return const Color(0xFF00B894);
      case AllocationType.loan:
        return const Color(0xFF0984E3);
      case AllocationType.creditCard:
        return const Color(0xFFA29BFE);
    }
  }

  String get jsonKey {
    switch (this) {
      case AllocationType.category:
        return 'category';
      case AllocationType.savingsGoal:
        return 'savingsGoal';
      case AllocationType.loan:
        return 'loan';
      case AllocationType.creditCard:
        return 'creditCard';
    }
  }

  static AllocationType fromJsonKey(String key) {
    switch (key) {
      case 'savingsGoal':
        return AllocationType.savingsGoal;
      case 'loan':
        return AllocationType.loan;
      case 'creditCard':
        return AllocationType.creditCard;
      default:
        return AllocationType.category;
    }
  }
}

// ─── Single Allocation Entry ───────────────────────────────────────────────────

class SalaryAllocation {
  final String id; // unique within a plan
  final String name; // e.g. "Food", "Home Loan", "HDFC Visa"
  final AllocationType type;
  final double amount;

  const SalaryAllocation({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
  });

  SalaryAllocation copyWith({
    String? id,
    String? name,
    AllocationType? type,
    double? amount,
  }) {
    return SalaryAllocation(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      amount: amount ?? this.amount,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type.jsonKey,
        'amount': amount,
      };

  factory SalaryAllocation.fromJson(Map<String, dynamic> json) =>
      SalaryAllocation(
        id: json['id'] as String,
        name: json['name'] as String,
        type: AllocationTypeX.fromJsonKey(json['type'] as String),
        amount: (json['amount'] as num).toDouble(),
      );
}

// ─── Salary Plan ──────────────────────────────────────────────────────────────

class SalaryPlan {
  final String id;
  final String name;
  final double monthlyIncome;
  final DateTime periodStart; // calendar month: first day
  final List<SalaryAllocation> allocations;
  final DateTime createdAt;

  const SalaryPlan({
    required this.id,
    required this.name,
    required this.monthlyIncome,
    required this.periodStart,
    required this.allocations,
    required this.createdAt,
  });

  // ── Derived figures ───────────────────────────────────────────────────────

  double get totalAllocated =>
      allocations.fold(0, (s, a) => s + a.amount);

  double get unallocated => monthlyIncome - totalAllocated;

  bool get isComplete => unallocated <= 0;

  double get categoryTotal => _sumByType(AllocationType.category);
  double get savingsTotal => _sumByType(AllocationType.savingsGoal);
  double get loanTotal => _sumByType(AllocationType.loan);
  double get creditCardTotal => _sumByType(AllocationType.creditCard);

  double _sumByType(AllocationType t) =>
      allocations.where((a) => a.type == t).fold(0, (s, a) => s + a.amount);

  List<SalaryAllocation> byType(AllocationType t) =>
      allocations.where((a) => a.type == t).toList();

  // ── CopyWith ──────────────────────────────────────────────────────────────

  SalaryPlan copyWith({
    String? id,
    String? name,
    double? monthlyIncome,
    DateTime? periodStart,
    List<SalaryAllocation>? allocations,
    DateTime? createdAt,
  }) {
    return SalaryPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      periodStart: periodStart ?? this.periodStart,
      allocations: allocations ?? this.allocations,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'monthlyIncome': monthlyIncome,
        'periodStart': periodStart.toIso8601String(),
        'allocations': allocations.map((a) => a.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory SalaryPlan.fromJson(Map<String, dynamic> json) => SalaryPlan(
        id: json['id'] as String,
        name: json['name'] as String,
        monthlyIncome: (json['monthlyIncome'] as num).toDouble(),
        periodStart: DateTime.parse(json['periodStart'] as String),
        allocations: (json['allocations'] as List<dynamic>)
            .map((e) =>
                SalaryAllocation.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
      );

  // ── SharedPreferences helpers ─────────────────────────────────────────────

  static List<SalaryPlan> listFromJsonString(String jsonString) {
    final list = json.decode(jsonString) as List<dynamic>;
    return list
        .map((e) => SalaryPlan.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJsonString(List<SalaryPlan> plans) =>
      json.encode(plans.map((p) => p.toJson()).toList());
}
