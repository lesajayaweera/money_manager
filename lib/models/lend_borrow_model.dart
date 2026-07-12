import 'package:flutter/material.dart';

// ─── Enums ────────────────────────────────────────────────────────────────────

enum LendBorrowType { lent, borrowed }

enum LendBorrowStatus { dueSoon, overdue, paid, pending }

// ─── Status helpers ──────────────────────────────────────────────────────────

extension LendBorrowStatusX on LendBorrowStatus {
  String get label {
    switch (this) {
      case LendBorrowStatus.dueSoon:
        return 'Due Soon';
      case LendBorrowStatus.overdue:
        return 'Overdue';
      case LendBorrowStatus.paid:
        return 'Paid';
      case LendBorrowStatus.pending:
        return 'Pending';
    }
  }

  Color get color {
    switch (this) {
      case LendBorrowStatus.dueSoon:
        return const Color(0xFF00B894);
      case LendBorrowStatus.overdue:
        return const Color(0xFFE17055);
      case LendBorrowStatus.paid:
        return const Color(0xFF0984E3);
      case LendBorrowStatus.pending:
        return const Color(0xFFFDAA3D);
    }
  }

  Color get lightColor {
    switch (this) {
      case LendBorrowStatus.dueSoon:
        return const Color(0xFFE6F9F5);
      case LendBorrowStatus.overdue:
        return const Color(0xFFFDF0EC);
      case LendBorrowStatus.paid:
        return const Color(0xFFE8F4FD);
      case LendBorrowStatus.pending:
        return const Color(0xFFFFF4E3);
    }
  }

  static LendBorrowStatus fromString(String s) {
    switch (s) {
      case 'dueSoon':
        return LendBorrowStatus.dueSoon;
      case 'overdue':
        return LendBorrowStatus.overdue;
      case 'paid':
        return LendBorrowStatus.paid;
      default:
        return LendBorrowStatus.pending;
    }
  }
}

// ─── Payment Method ───────────────────────────────────────────────────────────

class LBPaymentMethod {
  final String name;
  final IconData icon;

  const LBPaymentMethod(this.name, this.icon);

  static const List<LBPaymentMethod> all = [
    LBPaymentMethod('Cash', Icons.payments_rounded),
    LBPaymentMethod('Credit Card', Icons.credit_card_rounded),
    LBPaymentMethod('Debit Card', Icons.credit_card_outlined),
    LBPaymentMethod('UPI', Icons.qr_code_rounded),
    LBPaymentMethod('Net Banking', Icons.account_balance_rounded),
    LBPaymentMethod('Other', Icons.more_horiz_rounded),
  ];

  static LBPaymentMethod? findByName(String name) {
    try {
      return all.firstWhere((m) => m.name == name);
    } catch (_) {
      return null;
    }
  }
}

// ─── Lend/Borrow Model ────────────────────────────────────────────────────────

class LendBorrowModel {
  final int? id;
  final LendBorrowType type;
  final String personName;
  final double amount;
  final DateTime date;
  final DateTime dueDate;
  final String? note;
  final LendBorrowStatus status;
  final String? paymentMethod;
  final DateTime createdAt;

  const LendBorrowModel({
    this.id,
    required this.type,
    required this.personName,
    required this.amount,
    required this.date,
    required this.dueDate,
    this.note,
    required this.status,
    this.paymentMethod,
    required this.createdAt,
  });

  bool get isLent => type == LendBorrowType.lent;
  bool get isBorrowed => type == LendBorrowType.borrowed;

  LendBorrowModel copyWith({
    int? id,
    LendBorrowType? type,
    String? personName,
    double? amount,
    DateTime? date,
    DateTime? dueDate,
    String? note,
    LendBorrowStatus? status,
    String? paymentMethod,
    DateTime? createdAt,
  }) =>
      LendBorrowModel(
        id: id ?? this.id,
        type: type ?? this.type,
        personName: personName ?? this.personName,
        amount: amount ?? this.amount,
        date: date ?? this.date,
        dueDate: dueDate ?? this.dueDate,
        note: note ?? this.note,
        status: status ?? this.status,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'type': type.name,
        'person_name': personName,
        'amount': amount,
        'date': date.toIso8601String(),
        'due_date': dueDate.toIso8601String(),
        'note': note,
        'status': status.name,
        'payment_method': paymentMethod,
        'created_at': createdAt.toIso8601String(),
      };

  factory LendBorrowModel.fromMap(Map<String, dynamic> map) => LendBorrowModel(
        id: map['id'] as int?,
        type: map['type'] == 'lent' ? LendBorrowType.lent : LendBorrowType.borrowed,
        personName: map['person_name'] as String,
        amount: (map['amount'] as num).toDouble(),
        date: DateTime.parse(map['date'] as String),
        dueDate: DateTime.parse(map['due_date'] as String),
        note: map['note'] as String?,
        status: LendBorrowStatusX.fromString(map['status'] as String),
        paymentMethod: map['payment_method'] as String?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );
}
