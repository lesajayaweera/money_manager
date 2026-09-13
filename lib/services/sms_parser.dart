import '../models/transaction_model.dart';

/// The 5-stage result of examining one SMS.
enum SmsSkipReason { notBankSender, otpOrPromo, notTransaction, notRecognised }

/// Outcome of running a captured SMS through the on-device pipeline.
class SmsParseResult {
  /// True when the message yielded a usable draft.
  final bool matched;

  /// Normalised bank name (e.g. 'HNB'), or '' when unknown.
  final String bank;

  /// Merchant / description, pre-filled for the draft.
  final String title;

  final double amount;
  final TransactionType type;
  final String category;
  final DateTime? transactionDate;

  /// Deterministic key shared by the native queue and the inbox catch-up scan
  /// so the same message never becomes two drafts.
  final String dedupKey;

  /// Privacy-cleaned body (account/card/balance/phone digits stripped).
  final String redactedBody;

  final SmsSkipReason? skipReason;

  const SmsParseResult._({
    required this.matched,
    this.bank = '',
    this.title = '',
    this.amount = 0,
    this.type = TransactionType.expense,
    this.category = 'Other',
    this.transactionDate,
    this.dedupKey = '',
    this.redactedBody = '',
    this.skipReason,
  });

  factory SmsParseResult.skipped(SmsSkipReason reason) => SmsParseResult._(
        matched: false,
        skipReason: reason,
      );
}

/// Raw fields extracted by a bank-specific format parser.
class ParsedTransaction {
  final String? title;
  final double? amount;
  final TransactionType type;
  final String? category;
  final DateTime? date;
  final String? txnNo;

  const ParsedTransaction({
    this.title,
    this.amount,
    this.type = TransactionType.expense,
    this.category,
    this.date,
    this.txnNo,
  });
}

/// One known SMS layout for a bank.
class BankSmsFormat {
  final String name;
  final RegExp header;
  final ParsedTransaction? Function(String body) extract;

  const BankSmsFormat({
    required this.name,
    required this.header,
    required this.extract,
  });
}

/// A bank: its sender ID(s) and the formats it sends.
class BankParserConfig {
  final String bank;
  final List<String> senderIds;
  final List<BankSmsFormat> formats;

  const BankParserConfig({
    required this.bank,
    required this.senderIds,
    this.formats = const [],
  });
}

/// On-device SMS pipeline: 5 stages, all local, zero network.
///
///   1. Sender check        — recognised SL bank/wallet sender?
///   2. OTP / promo block   — never turn an OTP into a transaction
///   3. Payment keywords    — does this describe a money movement?
///   4. Bank confirmation   — pick the matching bank's format parser
///   5. Redaction           — strip card/account/balance/phone digits
class SmsParser {
  static final List<BankParserConfig> _bankConfigs = [
    BankParserConfig(
      bank: 'HNB',
      senderIds: ['HNB'],
      formats: [
        BankSmsFormat(
          name: 'HNB ATM Withdrawal e-Receipt',
          header: RegExp(r'ATM\s+Withdrawal', caseSensitive: false),
          extract: _extractHnbReceipt,
        ),
        BankSmsFormat(
          name: 'HNB SMS ALERT',
          header: RegExp(r'HNB\s+SMS\s+ALERT', caseSensitive: false),
          extract: _extractHnbAlert,
        ),
      ],
    ),
  ];

  /// Banks exposed in the whitelist UI; parsing config is added per bank.
  /// Extending capture support = adding a [BankParserConfig] entry above.
  static const List<String> presetSenders = [
    'HNB',
    'Commercial Bank',
    'BOC',
    'SAMPATH',
    'HSBC',
    'SEYLAN',
    'DFCC',
    'NDB',
    'NTB',
    'FRIMI',
    'Genie',
    'eZ Cash',
    'mCash',
    'LOLC',
    'LB Finance',
  ];

  static final RegExp _otpPattern = RegExp(
    r'\b(otp|one[- ]time\s*password|verification\s*(code|pin)|security\s*(code|pin)|auth\s*code)\b'
    r'|promo|reward|offer|discount|\% off|survey|lucky draw',
    caseSensitive: false,
  );

  static final RegExp _paymentKeywordPattern = RegExp(
    r'withdrawal|purchase|debit|credit|credited|transfer|\btrf\b|salary|refund|'
    r'reversal|\bpaid\b|payment|pos\b|instal|deposit|fee|cashback|atm',
    caseSensitive: false,
  );

  static final RegExp _lkrSuffixAmount = RegExp(
    r'([\d,]+(?:\.\d{2})?)\s*LKR',
    caseSensitive: false,
  );
  static final RegExp _rsPrefixAmount = RegExp(
    r'Rs\.?\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  static final RegExp _genericDate = RegExp(
    r'(\d{2})\.(\d{2})\.(\d{2})',
  );
  static final RegExp _genericTime = RegExp(r'(\d{2}):(\d{2})');

  static SmsParseResult parse({
    required String sender,
    required String body,
    required DateTime receivedAt,
  }) {
    // Stage 1 — sender check.
    final config = _findBank(sender);
    if (config == null) return SmsParseResult.skipped(SmsSkipReason.notBankSender);

    // Stage 2 — OTP / promo block.
    if (_otpPattern.hasMatch(body)) {
      return SmsParseResult.skipped(SmsSkipReason.otpOrPromo);
    }

    // Stage 3 — payment keywords.
    if (!_paymentKeywordPattern.hasMatch(body)) {
      return SmsParseResult.skipped(SmsSkipReason.notTransaction);
    }

    // Stage 4 — bank confirmation: match a known format, else generic LKR.
    ParsedTransaction? parsed;
    for (final format in config.formats) {
      if (format.header.hasMatch(body)) {
        parsed = format.extract(body);
        break;
      }
    }
    parsed ??= _tryGeneric(sender, body);

    if (parsed?.amount == null) {
      return SmsParseResult.skipped(SmsSkipReason.notRecognised);
    }

    final type = parsed!.type;
    final category = parsed.category ?? _guessCategory(body, type);
    final dedupKey = _buildDedupKey(
      bank: config.bank,
      sender: sender,
      parsed: parsed,
      receivedAt: receivedAt,
    );

    // Stage 5 — redaction before anything is stored.
    final redacted = redactSmsBody(body);

    return SmsParseResult._(
      matched: true,
      bank: config.bank,
      title: parsed.title?.isNotEmpty == true ? parsed.title! : config.bank,
      amount: parsed.amount!,
      type: type,
      category: category,
      transactionDate: parsed.date,
      dedupKey: dedupKey,
      redactedBody: redacted,
    );
  }

  // ── Bank discovery ───────────────────────────────────────────────────────────

  static BankParserConfig? _findBank(String sender) {
    if (sender.trim().isEmpty) return null;
    final normalized = sender.toLowerCase().trim();
    for (final config in _bankConfigs) {
      for (final id in config.senderIds) {
        final entry = id.toLowerCase().trim();
        if (normalized == entry ||
            normalized.contains(entry) ||
            entry.contains(normalized)) {
          return config;
        }
      }
    }
    return null;
  }

  static bool isWhitelistedSender(String sender) =>
      _findBank(sender) != null;

  // ── Stage 4 parsers ──────────────────────────────────────────────────────────

  /// HNB "SMS ALERT: <LABEL>, Debit account:...,Location:...,Amount(Approx.):..."
  static ParsedTransaction? _extractHnbAlert(String body) {
    final amountMatch =
        RegExp(r'Amount\(Approx\.\):\s*([\d,]+(?:\.\d{2})?)',
                caseSensitive: false)
            .firstMatch(body);
    if (amountMatch == null) return null;

    final labelMatch =
        RegExp(r'HNB\s+SMS\s+ALERT:\s*([A-Za-z ]+)', caseSensitive: false)
            .firstMatch(body);
    final label = labelMatch?.group(1)?.trim().toUpperCase();

    final merchantMatch = RegExp(
      r'Location:(.*?),\s*Amount\(Approx\.\)',
      caseSensitive: false,
    ).firstMatch(body);

    final dateMatch = _genericDate.firstMatch(body);
    final timeMatch = _genericTime.firstMatch(body);

    final isIncome = label == 'CREDIT' ||
        label == 'CASHBACK' ||
        label == 'REFUND' ||
        label == 'SALARY' ||
        RegExp(r'credited', caseSensitive: false).hasMatch(body);

    final type = isIncome ? TransactionType.income : TransactionType.expense;

    return ParsedTransaction(
      title: merchantMatch?.group(1)?.trim().split(',').first,
      amount: _parseAmount(amountMatch.group(1)!),
      type: type,
      date: _buildDate(dateMatch, timeMatch),
    );
  }

  /// HNB ATM Withdrawal e-Receipt (multi-line).
  static ParsedTransaction? _extractHnbReceipt(String body) {
    final amountMatch =
        RegExp(r'Amt\(Approx\.\):\s*([\d,]+(?:\.\d{2})?)',
                caseSensitive: false)
            .firstMatch(body);
    if (amountMatch == null) return null;

    final locationMatch =
        RegExp(r'Location:\s*(.+)', caseSensitive: false).firstMatch(body);
    final dateMatch = _genericDate.firstMatch(body);
    final timeMatch = _genericTime.firstMatch(body);
    final txnMatch =
        RegExp(r'Txn\s*No[.:]?\s*([0-9A-Za-z]+)', caseSensitive: false)
            .firstMatch(body);

    return ParsedTransaction(
      title: locationMatch?.group(1)?.replaceAll(RegExp(r',\s*LKA\s*$'), '').trim(),
      amount: _parseAmount(amountMatch.group(1)!),
      type: TransactionType.expense,
      category: RegExp(r'withdrawal', caseSensitive: false).hasMatch(body)
          ? 'Other'
          : null,
      date: _buildDate(dateMatch, timeMatch),
      txnNo: txnMatch?.group(1),
    );
  }

  /// Generic LKR fallback for banks without a dedicated format yet.
  static ParsedTransaction? _tryGeneric(String sender, String body) {
    double? amount;
    var amountMatch = _lkrSuffixAmount.firstMatch(body) ??
        _rsPrefixAmount.firstMatch(body);
    if (amountMatch != null) {
      amount = _parseAmount(amountMatch.group(1)!);
    } else {
      // Bare number like "Rs 1,500" handled above; give up otherwise.
      return null;
    }

    final dateMatch = _genericDate.firstMatch(body);
    final timeMatch = _genericTime.firstMatch(body);
    final isIncome = RegExp(r'salary|refund|credited|deposit',
            caseSensitive: false)
        .hasMatch(body);

    return ParsedTransaction(
      title: sender,
      amount: amount,
      type: isIncome ? TransactionType.income : TransactionType.expense,
      date: _buildDate(dateMatch, timeMatch),
    );
  }

  // ── Category / dedup helpers ─────────────────────────────────────────────────

  static String _guessCategory(String body, TransactionType type) {
    final b = body.toLowerCase();
    if (type == TransactionType.income) {
      if (b.contains('salary')) return 'Salary';
      return 'Other';
    }
    if (b.contains('purchase') || b.contains('pos') || b.contains('debit')) {
      return 'Shopping';
    }
    if (b.contains('transport') || b.contains('fuel')) return 'Transport';
    if (b.contains('withdrawal')) return 'Other';
    return 'Other';
  }

  static String _buildDedupKey({
    required String bank,
    required String sender,
    required ParsedTransaction parsed,
    required DateTime receivedAt,
  }) {
    if (parsed.txnNo != null && parsed.txnNo!.isNotEmpty) {
      return '$bank:txn:${parsed.txnNo}';
    }
    final d = parsed.date ?? receivedAt;
    final stamp =
        '${d.year}${_two(d.month)}${_two(d.day)}${_two(d.hour)}${_two(d.minute)}';
    final amount = parsed.amount?.toStringAsFixed(2) ?? 'na';
    return '$bank:$sender:$stamp:$amount';
  }

  // ── Stage 5: redaction ────────────────────────────────────────────────────────

  static String redactSmsBody(String body) {
    var b = body;
    b = b.replaceAll(
        RegExp(r'A/C:?\s*\S+', caseSensitive: false), 'A/C: [redacted]');
    b = b.replaceAll(RegExp(r'Debit\s+account:?\s*\S+', caseSensitive: false),
        'Debit account: [redacted]');
    b = b.replaceAll(
        RegExp(r'Av\.?l?\s*Bal:?\s*[\d,.]+(?:\s*LKR)?', caseSensitive: false),
        'Av.Bal: [redacted]');
    b = b.replaceAll(RegExp(r'Hot\s?Line:?\s*[\d\s]+', caseSensitive: false),
        'Hotline: [redacted]');
    b = b.replaceAll(RegExp(r'Term\s?ID:?\s*\S+', caseSensitive: false),
        'Term ID: [redacted]');
    b = b.replaceAll(RegExp(r'Txn\s?No:?\s*\S+', caseSensitive: false),
        'Txn No: [redacted]');
    return b;
  }

  // ── Low-level helpers ────────────────────────────────────────────────────────

  static double? _parseAmount(String raw) =>
      double.tryParse(raw.replaceAll(',', ''));

  /// dd.MM.yy + optional (HH:mm) → DateTime (yy → 20yy).
  static DateTime? _buildDate(Match? date, Match? time) {
    if (date == null) return null;
    final day = int.tryParse(date.group(1)!);
    final month = int.tryParse(date.group(2)!);
    final year = 2000 + (int.tryParse(date.group(3)!) ?? 0);
    int hour = 0, minute = 0;
    if (time != null) {
      hour = int.tryParse(time.group(1)!) ?? 0;
      minute = int.tryParse(time.group(2)!) ?? 0;
    }
    if (day == null || month == null) return null;
    try {
      return DateTime(year, month, day, hour, minute);
    } catch (_) {
      return null;
    }
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
}