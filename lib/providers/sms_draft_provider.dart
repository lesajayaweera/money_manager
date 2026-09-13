import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sms_draft_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../services/sms_capture_service.dart';
import '../services/sms_parser.dart';

/// Manages SMS-captured drafts: the review inbox, capture settings, and the
/// import pipeline (native pending queue + catch-up inbox scan → parser).
class SmsDraftProvider extends ChangeNotifier {
  static const String _enabledKey = 'sms_capture_enabled';
  static const String _sendersKey = 'sms_capture_senders';
  static const String _lastScanKey = 'sms_capture_last_scan';

  /// How far back the very first inbox scan looks when capture is enabled.
  static const Duration initialScanWindow = Duration(days: 30);

  final DatabaseService _db = DatabaseService.instance;

  List<SmsDraftModel> _drafts = [];
  bool _isLoading = false;
  bool _enabled = false;
  List<String> _senders = const [];
  String? _lastError;

  List<SmsDraftModel> get drafts => _drafts;
  bool get isLoading => _isLoading;
  bool get enabled => _enabled;
  List<String> get senders => _senders;
  String? get lastError => _lastError;

  List<SmsDraftModel> get pendingDrafts =>
      _drafts.where((d) => d.isDraft).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get pendingCount => pendingDrafts.length;

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? false;
      _senders = prefs.getStringList(_sendersKey) ?? [];
      await _reloadDrafts();
      if (_enabled) {
        await importCaptures();
      }
      _lastError = null;
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadDrafts() async {
    _drafts = await _db.getSmsDrafts();
  }

  /// Drains the native pending queue and runs a catch-up inbox scan.
  /// Returns the number of new drafts inserted.
  Future<int> importCaptures() async {
    var inserted = 0;
    try {
      // 1. Pending queue from the silent receiver.
      final pending = await SmsCaptureService.getPendingCaptures();
      for (final raw in pending) {
        final receivedAt = _epochToDate(raw['date']);
        final result = SmsParser.parse(
          sender: raw['sender'] as String? ?? '',
          body: raw['body'] as String? ?? '',
          receivedAt: receivedAt,
        );
        if (result.matched) {
          inserted += await _insertIfNew(result, sender: raw['sender'] as String? ?? '');
        }
      }
      await SmsCaptureService.clearPendingCaptures();

      // 2. Catch-up scan of the SMS inbox since last scan.
      final prefs = await SharedPreferences.getInstance();
      var lastScan = prefs.getInt(_lastScanKey);
      if (lastScan == null) {
        lastScan =
            DateTime.now().subtract(initialScanWindow).millisecondsSinceEpoch;
      }
      final scanned = await SmsCaptureService.scanInboxSince(
        DateTime.fromMillisecondsSinceEpoch(lastScan),
      );
      for (final raw in scanned) {
        final receivedAt = _epochToDate(raw['date']);
        final result = SmsParser.parse(
          sender: raw['sender'] as String? ?? '',
          body: raw['body'] as String? ?? '',
          receivedAt: receivedAt,
        );
        if (result.matched) {
          inserted += await _insertIfNew(result, sender: raw['sender'] as String? ?? '');
        }
      }
      await prefs.setInt(_lastScanKey, DateTime.now().millisecondsSinceEpoch);

      await _reloadDrafts();
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
    }
    return inserted;
  }

  Future<int> _insertIfNew(SmsParseResult result, {required String sender}) async {
    final draft = SmsDraftModel(
      sender: sender,
      bank: result.bank,
      rawBody: result.redactedBody,
      title: result.title,
      amount: result.amount,
      txType: result.type,
      category: result.category,
      transactionDate: result.transactionDate,
      dedupKey: result.dedupKey,
    );
    final id = await _db.insertSmsDraft(draft);
    return id == -1 ? 0 : 1;
  }

  // ── Settings ──────────────────────────────────────────────────────────────────

  /// Requires the SMS permission to have been granted already.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    await SmsCaptureService.setCaptureEnabled(value);
    if (value) {
      await importCaptures();
    } else {
      await SmsCaptureService.clearPendingCaptures();
    }
  }

  Future<void> setSenders(List<String> senders) async {
    _senders = List.unmodifiable(senders);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_sendersKey, senders);
    await SmsCaptureService.setSenderWhitelist(senders);
  }

  // ── Review inbox actions ─────────────────────────────────────────────────────

  Future<void> markSaved(int id) async {
    await _db.markDraftStatus(id, SmsDraftStatus.saved);
    await _reloadDrafts();
    notifyListeners();
  }

  Future<void> dismissDraft(int id) async {
    await _db.markDraftStatus(id, SmsDraftStatus.dismissed);
    await _reloadDrafts();
    notifyListeners();
  }

  Future<void> updateDraft(SmsDraftModel updated) async {
    await _db.updateSmsDraft(updated);
    await _reloadDrafts();
    notifyListeners();
  }

  Future<void> clearAllDrafts() async {
    await _db.clearAllSmsDrafts();
    await _reloadDrafts();
    notifyListeners();
  }

  /// Builds the real [TransactionModel] a saved draft becomes.
  TransactionModel toTransaction(SmsDraftModel draft) {
    return TransactionModel(
      title: draft.title,
      amount: draft.amount,
      type: draft.txType,
      category: draft.category,
      date: draft.transactionDate ?? DateTime.now(),
      walletName: draft.walletName,
      note: 'Auto-captured from ${draft.bank} SMS',
    );
  }

  DateTime _epochToDate(dynamic value) {
    final millis = value is num ? value.toInt() : (int.tryParse('$value') ?? 0);
    return millis <= 0
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(millis);
  }
}