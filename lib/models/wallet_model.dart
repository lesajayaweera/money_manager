import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

// ─── Wallet Type ──────────────────────────────────────────────────────────────

enum WalletType {
  cash,
  bankAccount,
  card,
  savings,
  business,
  kokoMintpay,
}

extension WalletTypeExtension on WalletType {
  String get displayName {
    switch (this) {
      case WalletType.cash:
        return 'Cash';
      case WalletType.bankAccount:
        return 'Bank Account';
      case WalletType.card:
        return 'Card';
      case WalletType.savings:
        return 'Savings';
      case WalletType.business:
        return 'Business';
      case WalletType.kokoMintpay:
        return 'Koko / Mintpay';
    }
  }

  String get dbName {
    switch (this) {
      case WalletType.cash:
        return 'cash';
      case WalletType.bankAccount:
        return 'bank_account';
      case WalletType.card:
        return 'card';
      case WalletType.savings:
        return 'savings';
      case WalletType.business:
        return 'business';
      case WalletType.kokoMintpay:
        return 'koko_mintpay';
    }
  }

  IconData get defaultIcon {
    switch (this) {
      case WalletType.cash:
        return Icons.account_balance_wallet_rounded;
      case WalletType.bankAccount:
        return Icons.account_balance_rounded;
      case WalletType.card:
        return Icons.credit_card_rounded;
      case WalletType.savings:
        return Icons.savings_rounded;
      case WalletType.business:
        return Icons.business_center_rounded;
      case WalletType.kokoMintpay:
        return Icons.account_balance_wallet_rounded;
    }
  }

  Color get defaultColor {
    switch (this) {
      case WalletType.cash:
        return const Color(0xFF00B894);
      case WalletType.bankAccount:
        return const Color(0xFFE17055);
      case WalletType.card:
        return AppColors.primary;
      case WalletType.savings:
        return const Color(0xFF0984E3);
      case WalletType.business:
        return AppColors.primary;
      case WalletType.kokoMintpay:
        return const Color(0xFFFDAA3D);
    }
  }

  Color get defaultLightColor {
    switch (this) {
      case WalletType.cash:
        return const Color(0xFFE6F9F5);
      case WalletType.bankAccount:
        return const Color(0xFFFDF0EC);
      case WalletType.card:
        return AppColors.primarySurface;
      case WalletType.savings:
        return const Color(0xFFE8F4FD);
      case WalletType.business:
        return AppColors.primarySurface;
      case WalletType.kokoMintpay:
        return const Color(0xFFFFF4E3);
    }
  }

  static WalletType fromDb(String value) {
    switch (value) {
      case 'cash':
        return WalletType.cash;
      case 'bank_account':
        return WalletType.bankAccount;
      case 'card':
        return WalletType.card;
      case 'savings':
        return WalletType.savings;
      case 'business':
        return WalletType.business;
      case 'koko_mintpay':
        return WalletType.kokoMintpay;
      default:
        return WalletType.cash;
    }
  }
}

// ─── Wallet Status ─────────────────────────────────────────────────────────────

enum WalletStatus { available, saved, installment }

extension WalletStatusExtension on WalletStatus {
  String get displayName {
    switch (this) {
      case WalletStatus.available:
        return 'Available';
      case WalletStatus.saved:
        return 'Saved';
      case WalletStatus.installment:
        return 'Installment';
    }
  }

  String get dbName {
    switch (this) {
      case WalletStatus.available:
        return 'available';
      case WalletStatus.saved:
        return 'saved';
      case WalletStatus.installment:
        return 'installment';
    }
  }

  Color get color {
    switch (this) {
      case WalletStatus.available:
        return const Color(0xFF00B894);
      case WalletStatus.saved:
        return const Color(0xFF0984E3);
      case WalletStatus.installment:
        return const Color(0xFFFDAA3D);
    }
  }

  Color get lightColor {
    switch (this) {
      case WalletStatus.available:
        return const Color(0xFFE6F9F5);
      case WalletStatus.saved:
        return const Color(0xFFE8F4FD);
      case WalletStatus.installment:
        return const Color(0xFFFFF4E3);
    }
  }

  static WalletStatus fromDb(String value) {
    switch (value) {
      case 'saved':
        return WalletStatus.saved;
      case 'installment':
        return WalletStatus.installment;
      default:
        return WalletStatus.available;
    }
  }
}

// ─── Available Colors ──────────────────────────────────────────────────────────

class WalletColors {
  static const List<_WalletColor> all = [
    _WalletColor(name: 'Green', color: Color(0xFF00B894)),
    _WalletColor(name: 'Orange', color: Color(0xFFE17055)),
    _WalletColor(name: 'Purple', color: AppColors.primary),
    _WalletColor(name: 'Blue', color: Color(0xFF0984E3)),
    _WalletColor(name: 'Yellow', color: Color(0xFFFDAA3D)),
    _WalletColor(name: 'Pink', color: Color(0xFFE84393)),
    _WalletColor(name: 'Red', color: Color(0xFFFF6B6B)),
    _WalletColor(name: 'Teal', color: Color(0xFF55EFC4)),
  ];

  static String nameForColor(Color color) {
    try {
      return all.firstWhere((c) => c.color.toARGB32() == color.toARGB32()).name;
    } catch (_) {
      return 'Custom';
    }
  }
}

class _WalletColor {
  final String name;
  final Color color;
  const _WalletColor({required this.name, required this.color});
}

// ─── Wallet Model ──────────────────────────────────────────────────────────────

class WalletModel {
  final int? id;
  final String name;
  final WalletType type;
  final double balance;
  final int iconCodePoint;
  final int colorValue;
  final String? note;
  final bool includeInTotal;
  final WalletStatus status;
  final DateTime createdAt;

  const WalletModel({
    this.id,
    required this.name,
    required this.type,
    required this.balance,
    required this.iconCodePoint,
    required this.colorValue,
    this.note,
    this.includeInTotal = true,
    this.status = WalletStatus.available,
    required this.createdAt,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  Color get color => Color(colorValue);
  Color get lightColor {
    final base = color;
    return Color.fromARGB(
      30,
      base.red,
      base.green,
      base.blue,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'type': type.dbName,
      'balance': balance,
      'icon_code_point': iconCodePoint,
      'color_value': colorValue,
      'note': note,
      'include_in_total': includeInTotal ? 1 : 0,
      'status': status.dbName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory WalletModel.fromMap(Map<String, dynamic> map) {
    return WalletModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: WalletTypeExtension.fromDb(map['type'] as String),
      balance: (map['balance'] as num).toDouble(),
      iconCodePoint: map['icon_code_point'] as int,
      colorValue: map['color_value'] as int,
      note: map['note'] as String?,
      includeInTotal: (map['include_in_total'] as int) == 1,
      status: WalletStatusExtension.fromDb(map['status'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  WalletModel copyWith({
    int? id,
    String? name,
    WalletType? type,
    double? balance,
    int? iconCodePoint,
    int? colorValue,
    String? note,
    bool? includeInTotal,
    WalletStatus? status,
    DateTime? createdAt,
  }) {
    return WalletModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      balance: balance ?? this.balance,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      note: note ?? this.note,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// ─── Wallet Transfer Model ─────────────────────────────────────────────────────

class WalletTransfer {
  final int? id;
  final int fromWalletId;
  final int toWalletId;
  final double amount;
  final DateTime date;
  final String? note;
  final DateTime createdAt;

  const WalletTransfer({
    this.id,
    required this.fromWalletId,
    required this.toWalletId,
    required this.amount,
    required this.date,
    this.note,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'from_wallet_id': fromWalletId,
      'to_wallet_id': toWalletId,
      'amount': amount,
      'date': date.toIso8601String(),
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory WalletTransfer.fromMap(Map<String, dynamic> map) {
    return WalletTransfer(
      id: map['id'] as int?,
      fromWalletId: map['from_wallet_id'] as int,
      toWalletId: map['to_wallet_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
