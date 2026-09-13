import 'transaction_model.dart';

enum SmsDraftStatus { draft, saved, dismissed }

/// A captured bank SMS awaiting review. Nothing becomes a real transaction
/// until the user taps Save in the review inbox.
class SmsDraftModel {
  final int? id;
  final String sender;
  final String bank;
  final String rawBody;
  final String title;
  final double amount;
  final TransactionType txType;
  final String category;
  final String walletName;
  final DateTime? transactionDate;
  final SmsDraftStatus status;
  final String dedupKey;
  final DateTime createdAt;

  SmsDraftModel({
    this.id,
    required this.sender,
    required this.bank,
    required this.rawBody,
    required this.title,
    required this.amount,
    required this.txType,
    required this.category,
    this.walletName = 'Cash',
    this.transactionDate,
    this.status = SmsDraftStatus.draft,
    required this.dedupKey,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isDraft => status == SmsDraftStatus.draft;

  SmsDraftModel copyWith({
    int? id,
    String? sender,
    String? bank,
    String? rawBody,
    String? title,
    double? amount,
    TransactionType? txType,
    String? category,
    String? walletName,
    DateTime? transactionDate,
    SmsDraftStatus? status,
    String? dedupKey,
    DateTime? createdAt,
  }) {
    return SmsDraftModel(
      id: id ?? this.id,
      sender: sender ?? this.sender,
      bank: bank ?? this.bank,
      rawBody: rawBody ?? this.rawBody,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      txType: txType ?? this.txType,
      category: category ?? this.category,
      walletName: walletName ?? this.walletName,
      transactionDate: transactionDate ?? this.transactionDate,
      status: status ?? this.status,
      dedupKey: dedupKey ?? this.dedupKey,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'sender': sender,
      'bank': bank,
      'raw_body': rawBody,
      'title': title,
      'amount': amount,
      'tx_type': txType.name,
      'category': category,
      'wallet_name': walletName,
      'transaction_date': transactionDate?.toIso8601String(),
      'status': status.name,
      'dedup_key': dedupKey,
      'created_at': createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  factory SmsDraftModel.fromMap(Map<String, dynamic> map) {
    return SmsDraftModel(
      id: map['id'] as int?,
      sender: map['sender'] as String,
      bank: map['bank'] as String,
      rawBody: map['raw_body'] as String,
      title: map['title'] as String? ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0,
      txType: TransactionType.values.firstWhere(
        (e) => e.name == map['tx_type'],
        orElse: () => TransactionType.expense,
      ),
      category: map['category'] as String? ?? 'Other',
      walletName: map['wallet_name'] as String? ?? 'Cash',
      transactionDate: map['transaction_date'] == null
          ? null
          : DateTime.tryParse(map['transaction_date'] as String),
      status: SmsDraftStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => SmsDraftStatus.draft,
      ),
      dedupKey: map['dedup_key'] as String,
      createdAt: DateTime.tryParse(map['created_at'] as String) ?? DateTime.now(),
    );
  }
}