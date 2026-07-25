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

  IconData get icon => WalletIconHelper.fromCodePoint(iconCodePoint);
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

// ─── Wallet Icon Helper ────────────────────────────────────────────────────────
// All IconData must be returned as const references so Flutter's icon
// tree-shaker can analyse them at compile time. Dynamic IconData(codePoint)
// construction breaks release builds.

class WalletIconHelper {
  /// Returns the matching const [IconData] for a stored [codePoint], or the
  /// default wallet icon when the code point is not recognised.
  static IconData fromCodePoint(int codePoint) {
    switch (codePoint) {
      case 0xe152: return Icons.account_balance_wallet_rounded;
      case 0xe151: return Icons.account_balance_rounded;
      case 0xe1b9: return Icons.account_box_rounded;
      case 0xe7f7: return Icons.credit_card_rounded;
      case 0xe8ff: return Icons.savings_rounded;
      case 0xe4fe: return Icons.business_center_rounded;
      case 0xe532: return Icons.payment_rounded;
      case 0xe25a: return Icons.money_rounded;
      case 0xe263: return Icons.monetization_on_rounded;
      case 0xe22b: return Icons.local_atm_rounded;
      case 0xe8d4: return Icons.receipt_rounded;
      case 0xe1b4: return Icons.account_circle_rounded;
      case 0xe319: return Icons.home_rounded;
      case 0xe88b: return Icons.shopping_cart_rounded;
      case 0xe8f9: return Icons.shopping_bag_rounded;
      case 0xe8f8: return Icons.shopping_basket_rounded;
      case 0xe4e4: return Icons.attach_money_rounded;
      case 0xe57c: return Icons.card_giftcard_rounded;
      case 0xe56c: return Icons.bar_chart_rounded;
      case 0xe57f: return Icons.show_chart_rounded;
      case 0xe6e1: return Icons.trending_up_rounded;
      case 0xe6e2: return Icons.trending_down_rounded;
      case 0xe8f5: return Icons.school_rounded;
      case 0xe548: return Icons.local_hospital_rounded;
      case 0xe53f: return Icons.local_dining_rounded;
      case 0xe542: return Icons.local_gas_station_rounded;
      case 0xe544: return Icons.local_grocery_store_rounded;
      case 0xe54b: return Icons.local_movies_rounded;
      case 0xe550: return Icons.local_pharmacy_rounded;
      case 0xe554: return Icons.local_shipping_rounded;
      case 0xe558: return Icons.local_taxi_rounded;
      case 0xe53e: return Icons.local_cafe_rounded;
      case 0xe543: return Icons.local_hotel_rounded;
      case 0xe531: return Icons.park_rounded;
      case 0xe30a: return Icons.flight_rounded;
      case 0xe53c: return Icons.directions_car_rounded;
      case 0xe534: return Icons.directions_bike_rounded;
      case 0xe535: return Icons.directions_bus_rounded;
      case 0xe57a: return Icons.train_rounded;
      case 0xe57b: return Icons.subway_rounded;
      case 0xe408: return Icons.phone_android_rounded;
      case 0xe32c: return Icons.laptop_rounded;
      case 0xe325: return Icons.headset_rounded;
      case 0xe8b8: return Icons.settings_rounded;
      case 0xe87d: return Icons.person_rounded;
      case 0xe7f2: return Icons.group_rounded;
      case 0xe8d6: return Icons.restaurant_rounded;
      case 0xe065: return Icons.music_note_rounded;
      case 0xe04f: return Icons.emoji_events_rounded;
      case 0xe7fb: return Icons.child_care_rounded;
      case 0xe63e: return Icons.pets_rounded;
      case 0xe3f6: return Icons.photo_camera_rounded;
      case 0xe412: return Icons.videocam_rounded;
      case 0xe158: return Icons.build_rounded;
      case 0xe3e1: return Icons.palette_rounded;
      case 0xe8cc: return Icons.book_rounded;
      case 0xe865: return Icons.lightbulb_rounded;
      case 0xe838: return Icons.star_rounded;
      case 0xe87e: return Icons.favorite_rounded;
      case 0xe8b0: return Icons.security_rounded;
      case 0xe32a: return Icons.lock_rounded;
      case 0xe88a: return Icons.shield_rounded;
      default:     return Icons.account_balance_wallet_rounded;
    }
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
