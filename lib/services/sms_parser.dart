import '../models/sms_draft_model.dart';
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

  /// How the saved draft should become a transaction:
  /// income (cash added), expense (money outflow), or withdrawal (bank → cash).
  final DraftKind kind;

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
    this.kind = DraftKind.expense,
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
  final DraftKind? kind;
  final String? category;
  final DateTime? date;
  final String? txnNo;

  const ParsedTransaction({
    this.title,
    this.amount,
    this.type = TransactionType.expense,
    this.kind,
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
    // ── HNB ────────────────────────────────────────────────────────────────────
    BankParserConfig(
      bank: 'HNB',
      senderIds: ['HNB', 'HNBSL', 'HNB-SL'],
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

    // ── BOC (Bank of Ceylon) ───────────────────────────────────────────────────
    BankParserConfig(
      bank: 'BOC',
      senderIds: ['BOC', 'BOCSL', 'BOC-SL', 'BankofCeylon'],
      formats: [
        BankSmsFormat(
          name: 'BOC Transaction Alert',
          header: RegExp(
            r'(debited|credited|withdrawn|transfer|purchase|pos\b)',
            caseSensitive: false,
          ),
          extract: _extractBocAlert,
        ),
      ],
    ),

    // ── Sampath Bank ───────────────────────────────────────────────────────────
    BankParserConfig(
      bank: 'SAMPATH',
      senderIds: ['SAMPATH', 'SAMPATHBNK', 'SAMPATHBK', 'Sampath'],
      formats: [
        BankSmsFormat(
          name: 'Sampath Debit/Credit Alert',
          header: RegExp(
            r'(debited|credited|transfer|purchase|withdrawal|atm)',
            caseSensitive: false,
          ),
          extract: _extractSampathAlert,
        ),
      ],
    ),

    // ── Commercial Bank ────────────────────────────────────────────────────────
    BankParserConfig(
      bank: 'Commercial Bank',
      senderIds: [
        'COMBANK',
        'CommercialBank',
        'Com Bank',
        'COMBANKSL',
        'CMBK',
        'Commercial Bank',
      ],
      formats: [
        BankSmsFormat(
          name: 'ComBank Transaction Alert',
          header: RegExp(
            r'(debited|credited|transfer|purchase|withdrawal|pos\b|payment)',
            caseSensitive: false,
          ),
          extract: _extractComBankAlert,
        ),
      ],
    ),

    // ── Pan Asia Bank (PABC) ──────────────────────────────────────────────────
    BankParserConfig(
      bank: 'Pan Asia',
      senderIds: ['PABC', 'PanAsia', 'Pan Asia', 'PABCSL', 'Pan-Asia'],
      formats: [
        BankSmsFormat(
          name: 'Pan Asia Transaction Alert',
          header: RegExp(
            r'(debited|credited|transfer|purchase|withdrawal|pos\b)',
            caseSensitive: false,
          ),
          extract: _extractPanAsiaAlert,
        ),
      ],
    ),

    // ── NTB (Nations Trust Bank) ───────────────────────────────────────────────
    BankParserConfig(
      bank: 'NTB',
      senderIds: ['NTB', 'NationsTrust', 'NTBSL'],
      formats: [
        BankSmsFormat(
          name: 'NTB Transaction Alert',
          header: RegExp(
            r'(debited|credited|transfer|purchase|withdrawal|pos\b)',
            caseSensitive: false,
          ),
          extract: _extractGenericNamedAlert,
        ),
      ],
    ),

    // ── DFCC Bank ──────────────────────────────────────────────────────────────
    BankParserConfig(
      bank: 'DFCC',
      senderIds: ['DFCC', 'DFCCSL', 'DFCCBank'],
      formats: [
        BankSmsFormat(
          name: 'DFCC Transaction Alert',
          header: RegExp(
            r'(debited|credited|transfer|purchase|withdrawal|pos\b)',
            caseSensitive: false,
          ),
          extract: _extractGenericNamedAlert,
        ),
      ],
    ),

    // ── NDB ────────────────────────────────────────────────────────────────────
    BankParserConfig(
      bank: 'NDB',
      senderIds: ['NDB', 'NDBSL', 'NDBBank'],
      formats: [
        BankSmsFormat(
          name: 'NDB Transaction Alert',
          header: RegExp(
            r'(debited|credited|transfer|purchase|withdrawal|pos\b)',
            caseSensitive: false,
          ),
          extract: _extractGenericNamedAlert,
        ),
      ],
    ),

    // ── Seylan Bank ────────────────────────────────────────────────────────────
    BankParserConfig(
      bank: 'SEYLAN',
      senderIds: ['SEYLAN', 'SeylanBank', 'SEYLANSL'],
      formats: [
        BankSmsFormat(
          name: 'Seylan Transaction Alert',
          header: RegExp(
            r'(debited|credited|transfer|purchase|withdrawal|pos\b)',
            caseSensitive: false,
          ),
          extract: _extractGenericNamedAlert,
        ),
      ],
    ),

    // ── LOLC ───────────────────────────────────────────────────────────────────
    BankParserConfig(
      bank: 'LOLC',
      senderIds: ['LOLC', 'LOLCFinance'],
      formats: [
        BankSmsFormat(
          name: 'LOLC Transaction Alert',
          header: RegExp(
            r'(debited|credited|transfer|purchase|withdrawal|payment)',
            caseSensitive: false,
          ),
          extract: _extractGenericNamedAlert,
        ),
      ],
    ),
  ];

  /// Banks exposed in the whitelist UI; a dedicated parser config is added per
  /// bank as needed. Senders in this list but without a [BankParserConfig] are
  /// routed through the generic "Rs / LKR" fallback so they still capture.
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
    'Pan Asia',
    // Alternate sender IDs used by the same banks in carrier networks
    'BOCSL',
    'SAMPATHBNK',
    'COMBANK',
    'PABC',
    'NTBSL',
    'DFCCSL',
    'NDBSL',
    'SEYLANSL',
    'HNBSL',
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
    final kind = parsed.kind ?? _classify(body, type);
    final category = parsed.category ?? _guessCategory(body, type, kind);
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
      kind: kind,
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
    // Sender is a bank/wallet we recognise (user whitelisted it) but have no
    // dedicated format for yet — build a virtual config so the generic
    // "Rs / LKR" fallback can still turn it into a draft.
    for (final preset in presetSenders) {
      final entry = preset.toLowerCase().trim();
      if (normalized == entry ||
          normalized.contains(entry) ||
          entry.contains(normalized)) {
        return BankParserConfig(bank: preset, senderIds: [preset]);
      }
    }
    return null;
  }

  static bool isWhitelistedSender(String sender) =>
      _findBank(sender) != null;

  /// True when [sender] matches one of the known bank/wallet sender IDs.
  static bool isKnownBankSender(String sender) =>
      bankNameForSender(sender) != null;

  /// Returns the canonical preset bank name for a detected inbox sender, or
  /// null when the sender doesn't look like a known bank.
  static String? bankNameForSender(String sender) {
    if (sender.trim().isEmpty) return null;
    final normalized = sender.toLowerCase().trim();
    for (final preset in presetSenders) {
      final entry = preset.toLowerCase().trim();
      if (normalized == entry ||
          normalized.contains(entry) ||
          entry.contains(normalized)) {
        return preset;
      }
    }
    return null;
  }

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
      kind: DraftKind.withdrawal,
      category: RegExp(r'withdrawal', caseSensitive: false).hasMatch(body)
          ? 'Other'
          : null,
      date: _buildDate(dateMatch, timeMatch),
      txnNo: txnMatch?.group(1),
    );
  }

  // ── BOC Transaction Alert ────────────────────────────────────────────────────
  /// Bank of Ceylon typical format:
  /// "Your A/C XXXX debited by LKR 610.00 on 09/09/26 at 14:30 at MERCHANT NAME.
  ///  Avl Bal: LKR 12,345.67"
  static ParsedTransaction? _extractBocAlert(String body) {
    // Try LKR amount first (BOC uses "LKR 610.00" prefix format)
    final amountMatch = RegExp(
          r'(?:debited|credited|transferred)\s+(?:by|of)?\s*(?:LKR|Rs\.?)\s*([\d,]+(?:\.\d{1,2})?)',
          caseSensitive: false,
        ).firstMatch(body) ??
        _lkrSuffixAmount.firstMatch(body) ??
        _rsPrefixAmount.firstMatch(body);
    if (amountMatch == null) return null;

    // Merchant comes after "at <MERCHANT>" (last occurrence before period/newline)
    final merchantMatch = RegExp(
      r"(?:at|from|to|@)\s+([A-Z0-9 &.\-]+?)(?:\.|\n|Avl|Bal|$)",
      caseSensitive: false,
    ).allMatches(body).lastOrNull;

    final isIncome = RegExp(r'credited|deposited|salary|refund|cashback',
            caseSensitive: false)
        .hasMatch(body);
    final isWithdrawal = RegExp(r'withdraw(al|n)?|atm',
            caseSensitive: false)
        .hasMatch(body);

    final dateMatch = RegExp(r'(\d{2})/(\d{2})/(\d{2,4})').firstMatch(body);
    final timeMatch = _genericTime.firstMatch(body);
    DateTime? date;
    if (dateMatch != null) {
      final d = int.tryParse(dateMatch.group(1)!);
      final m = int.tryParse(dateMatch.group(2)!);
      var y = int.tryParse(dateMatch.group(3)!) ?? 0;
      if (y < 100) y += 2000;
      if (d != null && m != null) {
        int h = 0, min = 0;
        if (timeMatch != null) {
          h = int.tryParse(timeMatch.group(1)!) ?? 0;
          min = int.tryParse(timeMatch.group(2)!) ?? 0;
        }
        try { date = DateTime(y, m, d, h, min); } catch (_) {}
      }
    }

    final rawTitle = merchantMatch?.group(1)?.trim();
    final title = (rawTitle != null && rawTitle.length > 2) ? rawTitle : null;

    return ParsedTransaction(
      title: title,
      amount: _parseAmount(amountMatch.group(1)!),
      type: isIncome ? TransactionType.income : TransactionType.expense,
      kind: isWithdrawal ? DraftKind.withdrawal : null,
      date: date,
    );
  }

  // ── Sampath Transaction Alert ─────────────────────────────────────────────────
  /// Sampath typical format:
  /// "SAMPATH BANK ALERT: Rs.610.00 has been debited from your A/C XXXX at
  ///  MERCHANT. Balance: Rs.XX,XXX.XX"
  static ParsedTransaction? _extractSampathAlert(String body) {
    final amountMatch = RegExp(
          r'Rs\.?\s*([\d,]+(?:\.\d{1,2})?)\s+has been',
          caseSensitive: false,
        ).firstMatch(body) ??
        _rsPrefixAmount.firstMatch(body) ??
        _lkrSuffixAmount.firstMatch(body);
    if (amountMatch == null) return null;

    // Merchant: after "at <MERCHANT>" before period / Balance
    final merchantMatch = RegExp(
      r"(?:at|from|to)\s+([A-Z0-9 &.\-]+?)(?:\s*\.\s*|\s*Balance|\s*Bal)",
      caseSensitive: false,
    ).firstMatch(body);

    final isIncome = RegExp(r'credited|deposited|salary|refund|cashback',
            caseSensitive: false)
        .hasMatch(body);
    final isWithdrawal = RegExp(r'withdraw(al|n)?|atm', caseSensitive: false)
        .hasMatch(body);

    final dateMatch = _genericDate.firstMatch(body);
    final timeMatch = _genericTime.firstMatch(body);
    final rawTitle = merchantMatch?.group(1)?.trim();
    final title = (rawTitle != null && rawTitle.length > 2) ? rawTitle : null;

    return ParsedTransaction(
      title: title,
      amount: _parseAmount(amountMatch.group(1)!),
      type: isIncome ? TransactionType.income : TransactionType.expense,
      kind: isWithdrawal ? DraftKind.withdrawal : null,
      date: _buildDate(dateMatch, timeMatch),
    );
  }

  // ── Commercial Bank Transaction Alert ────────────────────────────────────────
  /// ComBank typical format:
  /// "ComBank Alert: Your a/c XXXX debited Rs. 610.00 on 09-Sep-26
  ///  at MERCHANT NAME. Avail Bal: Rs.XX,XXX.XX"
  static ParsedTransaction? _extractComBankAlert(String body) {
    final amountMatch = RegExp(
          r'(?:debited|credited)\s+Rs\.?\s*([\d,]+(?:\.\d{1,2})?)',
          caseSensitive: false,
        ).firstMatch(body) ??
        _rsPrefixAmount.firstMatch(body) ??
        _lkrSuffixAmount.firstMatch(body);
    if (amountMatch == null) return null;

    // Merchant: after "at <MERCHANT>" before period or Avail
    final merchantMatch = RegExp(
      r"(?:\bat\b)\s+([A-Z0-9 &.\-]+?)(?:\s*\.\s*|\s*Avail|\s*Bal)",
      caseSensitive: false,
    ).firstMatch(body);

    final isIncome = RegExp(r'credited|deposited|salary|refund|cashback',
            caseSensitive: false)
        .hasMatch(body);
    final isWithdrawal = RegExp(r'withdraw(al|n)?|atm', caseSensitive: false)
        .hasMatch(body);

    // ComBank uses "09-Sep-26" format
    final comDate = RegExp(
      r'(\d{2})-(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)-(\d{2,4})',
      caseSensitive: false,
    ).firstMatch(body);
    DateTime? date;
    if (comDate != null) {
      const months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
      };
      final d = int.tryParse(comDate.group(1)!);
      final m = months[comDate.group(2)!.toLowerCase()];
      var y = int.tryParse(comDate.group(3)!) ?? 0;
      if (y < 100) y += 2000;
      if (d != null && m != null) {
        try { date = DateTime(y, m, d); } catch (_) {}
      }
    } else {
      final dm = _genericDate.firstMatch(body);
      final tm = _genericTime.firstMatch(body);
      date = _buildDate(dm, tm);
    }

    final rawTitle = merchantMatch?.group(1)?.trim();
    final title = (rawTitle != null && rawTitle.length > 2) ? rawTitle : null;

    return ParsedTransaction(
      title: title,
      amount: _parseAmount(amountMatch.group(1)!),
      type: isIncome ? TransactionType.income : TransactionType.expense,
      kind: isWithdrawal ? DraftKind.withdrawal : null,
      date: date,
    );
  }

  // ── Pan Asia (PABC) Transaction Alert ────────────────────────────────────────
  /// PABC typical format:
  /// "PABC Alert: LKR 660.00 has been debited from your account.
  ///  Merchant: H P C Rasika. Date: 09-Sep-2026 Ref: XXXXXXXX"
  static ParsedTransaction? _extractPanAsiaAlert(String body) {
    final amountMatch = RegExp(
          r'(?:LKR|Rs\.?)\s*([\d,]+(?:\.\d{1,2})?)\s+has been',
          caseSensitive: false,
        ).firstMatch(body) ??
        _lkrSuffixAmount.firstMatch(body) ??
        _rsPrefixAmount.firstMatch(body);
    if (amountMatch == null) return null;

    // Pan Asia often puts merchant on its own line: "Merchant: X"
    final merchantMatch = RegExp(
      r'(?:Merchant|At|From|To)\s*:\s*([^\n\r\.]+)',
      caseSensitive: false,
    ).firstMatch(body);

    final isIncome = RegExp(r'credited|deposited|salary|refund|cashback',
            caseSensitive: false)
        .hasMatch(body);
    final isWithdrawal = RegExp(r'withdraw(al|n)?|atm', caseSensitive: false)
        .hasMatch(body);

    final dateMatch = _genericDate.firstMatch(body);
    final timeMatch = _genericTime.firstMatch(body);
    final rawTitle = merchantMatch?.group(1)?.trim();
    final title = (rawTitle != null && rawTitle.length > 2) ? rawTitle : null;

    return ParsedTransaction(
      title: title,
      amount: _parseAmount(amountMatch.group(1)!),
      type: isIncome ? TransactionType.income : TransactionType.expense,
      kind: isWithdrawal ? DraftKind.withdrawal : null,
      date: _buildDate(dateMatch, timeMatch),
    );
  }

  // ── Generic named-alert fallback (NTB, DFCC, NDB, Seylan, LOLC) ─────────────
  /// Shared extractor for banks whose SMS layouts we match well enough with
  /// the generic Rs / LKR patterns but we want to try to extract a merchant name.
  static ParsedTransaction? _extractGenericNamedAlert(String body) {
    final amountMatch = _lkrSuffixAmount.firstMatch(body) ??
        _rsPrefixAmount.firstMatch(body);
    if (amountMatch == null) return null;

    // Attempt to find a merchant label pattern common to many SL bank alerts
    final merchantMatch = RegExp(
      r"(?:at|from|to|merchant|payee)\s*:?\s+([A-Z0-9 &.\-]+?)"
      r'(?:\.|\n|\r|Bal|Avail|Ref|Date|$)',
      caseSensitive: false,
    ).firstMatch(body);

    final isIncome = RegExp(r'credited|deposited|salary|refund|cashback',
            caseSensitive: false)
        .hasMatch(body);
    final isWithdrawal = RegExp(r'withdraw(al|n)?|atm', caseSensitive: false)
        .hasMatch(body);

    final dateMatch = _genericDate.firstMatch(body);
    final timeMatch = _genericTime.firstMatch(body);
    final rawTitle = merchantMatch?.group(1)?.trim();
    final title = (rawTitle != null && rawTitle.length > 2) ? rawTitle : null;

    return ParsedTransaction(
      title: title,
      amount: _parseAmount(amountMatch.group(1)!),
      type: isIncome ? TransactionType.income : TransactionType.expense,
      kind: isWithdrawal ? DraftKind.withdrawal : null,
      date: _buildDate(dateMatch, timeMatch),
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
      return null;
    }

    final dateMatch = _genericDate.firstMatch(body);
    final timeMatch = _genericTime.firstMatch(body);
    final isIncome = RegExp(r'salary|refund|credited|deposit',
            caseSensitive: false)
        .hasMatch(body);

    // Try to extract a merchant rather than falling back to the raw sender ID.
    final merchantMatch = RegExp(
      r"(?:at|from|to|merchant|payee)\s*:?\s+([A-Z0-9 &.\-]+?)"
      r'(?:\.|\n|\r|Bal|Avail|Ref|Date|$)',
      caseSensitive: false,
    ).firstMatch(body);
    final rawTitle = merchantMatch?.group(1)?.trim();
    final title = (rawTitle != null && rawTitle.length > 2) ? rawTitle : null;

    return ParsedTransaction(
      title: title, // null → will fall back to bank name in parse()
      amount: amount,
      type: isIncome ? TransactionType.income : TransactionType.expense,
      date: _buildDate(dateMatch, timeMatch),
    );
  }

  // ── Category / dedup / kind helpers ─────────────────────────────────────────

  /// Keyword classification of what a money SMS means:
  ///   • credited/deposited/salary/refund/cashback → cash added  → income
  ///   • withdrawal/ATM/withdrawn                 → bank → cash → transfer
  ///   • everything else (paid/purchased/POS/etc.)               → expense
  static DraftKind _classify(String body, TransactionType type) {
    if (type == TransactionType.income) return DraftKind.income;
    final b = body.toLowerCase();
    if (RegExp(r'\b(withdraw(al|n|s|ing)?|atm withdrawal|withdrawn)\b',
            caseSensitive: false)
        .hasMatch(b)) {
      return DraftKind.withdrawal;
    }
    if (RegExp(r'\bcredited|deposit(ed)?|salary|refund|cashback|cash in\b',
            caseSensitive: false)
        .hasMatch(b)) {
      return DraftKind.income;
    }
    return DraftKind.expense;
  }

  static String _guessCategory(String body, TransactionType type,
      [DraftKind kind = DraftKind.expense]) {
    final b = body.toLowerCase();
    if (type == TransactionType.income) {
      if (b.contains('salary')) {
        return 'Salary';
      }
      if (b.contains('refund')) {
        return 'Savings';
      }
      return 'Other';
    }
    if (kind == DraftKind.withdrawal) {
      return 'Other';
    }

    if (RegExp(
            r'restaurant|cafe|lunch|dinner|food|pizza|kottu|burger|rice curve|'
            r'\bhotel\b|eat|noodles|dosa|breakfast|tea shop|kfc|mcd'
            , caseSensitive: false)
        .hasMatch(b)) {
      return 'Food';
    }
    if (RegExp(
            r'fuel|petrol|diesel|gas station|taxi|uber|pickme|bus|train|'
            r'toll|transport'
            , caseSensitive: false)
        .hasMatch(b)) {
      return 'Transport';
    }
    if (RegExp(
            r'elec|water|ceb|cey|dialog|mobitel|hutch|airtel|tariff|bill|'
            r'recharge|insurance|internet|invoice|loan instal'
            , caseSensitive: false)
        .hasMatch(b)) {
      return 'Bills';
    }
    if (RegExp(
            r'pharm|medical|hospital|doctor|clinic|medicare|health|dental'
            , caseSensitive: false)
        .hasMatch(b)) {
      return 'Health';
    }
    if (RegExp(
            r'school|tuition|university|college|fees|exam|bookstore|education'
            , caseSensitive: false)
        .hasMatch(b)) {
      return 'Education';
    }
    if (RegExp(
            r'cinema|carnival|theatre|netflix|spotify|entertainment|movie|'
            r'games'
            , caseSensitive: false)
        .hasMatch(b)) {
      return 'Entertainment';
    }
    if (RegExp(
            r'purchase|pos|debit|mall|supermarket|keells|cargills|abans|'
            r'singhagiri|lanka sathosa|shopping|retail|store|shop'
            , caseSensitive: false)
        .hasMatch(b)) {
      return 'Shopping';
    }
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
    // Account numbers
    b = b.replaceAll(
        RegExp(r'A/C:?\s*\S+', caseSensitive: false), 'A/C: [REDACTED]');
    b = b.replaceAll(
        RegExp(r'(?:account|a/c|acct)\.?\s*(?:no\.?)?\s*[Xx*\d]{4,}',
            caseSensitive: false),
        'A/C: [REDACTED]');
    b = b.replaceAll(RegExp(r'Debit\s+account:?\s*\S+', caseSensitive: false),
        'Debit account: [REDACTED]');
    // Card digits (masked like XXXX1234)
    b = b.replaceAll(
        RegExp(r'[Xx*]{4,}\d{4}'), 'CARD [REDACTED]');
    // Balances
    b = b.replaceAll(
        RegExp(
            r'(?:Av\.?l?\s*)?Bal(?:ance)?:?\s*(?:LKR|Rs\.?)?\s*[\d,]+(?:\.\d{1,2})?',
            caseSensitive: false),
        'Bal: [REDACTED]');
    b = b.replaceAll(
        RegExp(r'Avail(?:able)?\s*Bal(?:ance)?:?\s*(?:LKR|Rs\.?)?\s*[\d,]+(?:\.\d{1,2})?',
            caseSensitive: false),
        'Avail Bal: [REDACTED]');
    // Phone numbers (SL format: 07XXXXXXXX or +947XXXXXXXX)
    b = b.replaceAll(
        RegExp(r'(?:\+94|0)[7][01234568]\d{7}'), '[PHONE REDACTED]');
    // Hotline / contact numbers
    b = b.replaceAll(RegExp(r'Hot\s?Line:?\s*[\d\s]+', caseSensitive: false),
        'Hotline: [REDACTED]');
    // Terminal / Txn IDs
    b = b.replaceAll(RegExp(r'Term\s?ID:?\s*\S+', caseSensitive: false),
        'Term ID: [REDACTED]');
    b = b.replaceAll(RegExp(r'Txn\s?No:?\s*\S+', caseSensitive: false),
        'Txn No: [REDACTED]');
    b = b.replaceAll(RegExp(r'Ref(?:erence)?\s*(?:No\.?)?:?\s*\S+',
            caseSensitive: false),
        'Ref: [REDACTED]');
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