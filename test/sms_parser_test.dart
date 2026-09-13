import 'package:flutter_test/flutter_test.dart';
import 'package:money_manager/models/transaction_model.dart';
import 'package:money_manager/services/sms_parser.dart';

void main() {
  const hnbReceipt = r'''
HNB ATM Withdrawal e-Receipt
Amt(Approx.):  1500.00 LKR
A/C: 1540***8254
Txn Fee: 5.00LKR
Location: HNB BORALESGAMUWA CRM 01, LKA
Term ID: 888137
Date: 09.09.26 Time:13:11
Txn No: 3293123858
Avl Bal: 19398.97 LKR
Hotline:94112462462''';

  const hnbAlert = r'HNB SMS ALERT: PURCHASE, Debit account:1540***8254,'
      'Location:LITTLE LION ASSOCIATES PV, LK,Amount(Approx.):380.00 LKR,'
      'Av.Bal:19018.97 LKR,Date:12.09.26,Time:10:06, Hot Line:0112462462';

  group('Stage 1 — sender check', () {
    test('rejects unknown senders without reading content', () {
      final result = SmsParser.parse(
        sender: 'MOM',
        body: hnbReceipt,
        receivedAt: DateTime(2026, 9, 9, 13, 11),
      );
      expect(result.matched, isFalse);
      expect(result.skipReason, SmsSkipReason.notBankSender);
    });

    test('matches sender case-insensitively', () {
      final result = SmsParser.parse(
        sender: 'hnb',
        body: hnbReceipt,
        receivedAt: DateTime(2026, 9, 9, 13, 11),
      );
      expect(result.matched, isTrue);
    });
  });

  group('Stage 2 — OTP / promo block', () {
    test('drops OTP-style messages', () {
      final result = SmsParser.parse(
        sender: 'HNB',
        body: 'Your Moneygrow OTP is 487213. Do not share this code.',
        receivedAt: DateTime(2026, 9, 9, 13, 11),
      );
      expect(result.matched, isFalse);
      expect(result.skipReason, SmsSkipReason.otpOrPromo);
    });

    test('drops promo messages', () {
      final result = SmsParser.parse(
        sender: 'HNB',
        body: 'Enjoy 20% off dining this weekend with your HNB card.',
        receivedAt: DateTime(2026, 9, 9, 13, 11),
      );
      expect(result.matched, isFalse);
      expect(result.skipReason, SmsSkipReason.otpOrPromo);
    });
  });

  group('Stage 3 — payment keywords', () {
    test('rejects non-transaction alerts', () {
      final result = SmsParser.parse(
        sender: 'HNB',
        body: 'Your account balance has been updated successfully.',
        receivedAt: DateTime(2026, 9, 9, 13, 11),
      );
      expect(result.matched, isFalse);
      expect(result.skipReason, SmsSkipReason.notTransaction);
    });
  });

  group('HNB format A — ATM Withdrawal e-Receipt', () {
    test('parses amount, merchant, date, and txn dedup key', () {
      final result = SmsParser.parse(
        sender: 'HNB',
        body: hnbReceipt,
        receivedAt: DateTime(2026, 9, 9, 13, 11),
      );
      expect(result.matched, isTrue);
      expect(result.bank, 'HNB');
      expect(result.amount, 1500.00);
      expect(result.type, TransactionType.expense);
      expect(result.category, 'Other');
      expect(result.title, 'HNB BORALESGAMUWA CRM 01');
      expect(result.transactionDate, DateTime(2026, 9, 9, 13, 11));
      expect(result.dedupKey, 'HNB:txn:3293123858');
    });

    test('redacts account, balance, txn no and hotline from stored body', () {
      final result = SmsParser.parse(
        sender: 'HNB',
        body: hnbReceipt,
        receivedAt: DateTime(2026, 9, 9, 13, 11),
      );
      final redacted = result.redactedBody;
      expect(redacted.contains('1540***8254'), isFalse);
      expect(redacted.contains('19398.97'), isFalse);
      expect(redacted.contains('3293123858'), isFalse);
      expect(redacted.contains('94112462462'), isFalse);
      expect(redacted.contains('[redacted]'), isTrue);
    });
  });

  group('HNB format B — SMS ALERT', () {
    test('parses amount, merchant, type and date', () {
      final result = SmsParser.parse(
        sender: 'HNB',
        body: hnbAlert,
        receivedAt: DateTime(2026, 9, 12, 10, 6),
      );
      expect(result.matched, isTrue);
      expect(result.bank, 'HNB');
      expect(result.amount, 380.00);
      expect(result.type, TransactionType.expense);
      expect(result.category, 'Shopping');
      expect(result.title, 'LITTLE LION ASSOCIATES PV');
      expect(result.transactionDate, DateTime(2026, 9, 12, 10, 6));
      expect(result.dedupKey, 'HNB:HNB:202609121006:380.00');
    });

    test('redacts debit account and balance', () {
      final result = SmsParser.parse(
        sender: 'HNB',
        body: hnbAlert,
        receivedAt: DateTime(2026, 9, 12, 10, 6),
      );
      final redacted = result.redactedBody;
      expect(redacted.contains('1540***8254'), isFalse);
      expect(redacted.contains('19018.97'), isFalse);
      expect(redacted.contains('0112462462'), isFalse);
    });
  });

  group('Generic LKR fallback', () {
    test('parses a Rs amount when no bank format matches', () {
      final result = SmsParser.parse(
        sender: 'HNB',
        body: 'Dear customer your account paid Rs 1,500.00 to ABC Store today.',
        receivedAt: DateTime(2026, 9, 9, 13, 11),
      );
      expect(result.matched, isTrue);
      expect(result.amount, 1500.00);
      expect(result.type, TransactionType.expense);
      expect(result.title, 'HNB');
    });

    test('treats salary credit as income', () {
      final result = SmsParser.parse(
        sender: 'HNB',
        body: 'Salary credited to your account Rs 120,000.00.',
        receivedAt: DateTime(2026, 9, 1, 9, 0),
      );
      expect(result.matched, isTrue);
      expect(result.type, TransactionType.income);
      expect(result.category, 'Salary');
      expect(result.amount, 120000.00);
    });
  });

  group('Dedup keys', () {
    test('queue and inbox produce the same key for the same message', () {
      final receivedAt = DateTime(2026, 9, 12, 10, 6);
      final fromQueue = SmsParser.parse(
        sender: 'HNB',
        body: hnbAlert,
        receivedAt: receivedAt,
      );
      final fromInbox = SmsParser.parse(
        sender: 'HNB',
        body: hnbAlert,
        receivedAt: receivedAt.add(const Duration(seconds: 3)),
      );
      expect(fromQueue.dedupKey, fromInbox.dedupKey);
    });
  });
}