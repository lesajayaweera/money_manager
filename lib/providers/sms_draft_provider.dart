import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sms_draft_model.dart';
import '../models/transaction_model.dart';
import '../models/wallet_model.dart';
import '../services/database_service.dart';
import '../services/sms_capture_service.dart';
import '../services/sms_parser.dart';

/// Manages SMS-captured drafts: the review inbox, capture settings, and the
/// import pipeline (native pending queue + catch-up inbox scan → parser).
class SmsDraftProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const String _enabledKey = 'sms_capture_enabled';
  static const String _sendersKey = 'sms_capture_senders';
  static const String _lastScanKey = 'sms_capture_last_scan';
  static const String _lastDetectKey = 'sms_capture_last_detect';

  /// Persisted flag: have we ever done a full-history import?
  static const String _historyScanKey = 'sms_capture_history_scanned';

  /// Persisted: comma-joined set of senders whose history was already imported.
  static const String _historyScannedSendersKey = 'sms_capture_history_senders';

  /// How far back the very first inbox scan looks when capture is enabled.
  static const Duration initialScanWindow = Duration(days: 30);

  /// How often the native pending queue is drained while capture is on, so
  /// drafts appear without needing an app restart.
  static const Duration drainInterval = Duration(seconds: 45);

  /// How often the inbox is re-scanned to auto-discover new bank senders.
  static const Duration detectionInterval = Duration(minutes: 5);

  final DatabaseService _db = DatabaseService.instance;

  List<SmsDraftModel> _drafts = [];
  bool _isLoading = false;
  bool _enabled = false;
  List<String> _senders = const [];
  List<String> _detectedBanks = const [];
  String? _lastError;

  Timer? _drainTimer;
  bool _importing = false;
  bool _importingHistory = false;
  bool _detecting = false;
  bool _observing = false;

  /// Emits progress during a full-history scan: (scanned so far, total inserted).
  final _historyProgressCtrl =
      StreamController<({int scanned, int inserted, bool done})>.broadcast();
  Stream<({int scanned, int inserted, bool done})> get historyImportProgress =>
      _historyProgressCtrl.stream;
  bool get isImportingHistory => _importingHistory;

  List<SmsDraftModel> get drafts => _drafts;
  bool get isLoading => _isLoading;
  bool get enabled => _enabled;
  List<String> get senders => _senders;

  /// Banks auto-detected from the SMS inbox (canonical names).
  List<String> get detectedBanks => _detectedBanks;
  bool get hasDetectedBanks => _detectedBanks.isNotEmpty;
  String? get lastError => _lastError;

  List<SmsDraftModel> get pendingDrafts =>
      _drafts.where((d) => d.isDraft).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  int get pendingCount => pendingDrafts.length;

  // ── Lifecycle ─────────────────────────────────────────────────────────────────

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      _enabled = prefs.getBool(_enabledKey) ?? false;
      _senders = prefs.getStringList(_sendersKey) ?? [];
      if (_enabled) {
        await _setDefaultSendersIfEmpty();
      }
      // Re-arm the native side to whatever Flutter thinks the state is, so the
      // background receiver + inbox scanner match the UI after every start,
      // even if a previous session was interrupted mid-sync.
      await SmsCaptureService.setCaptureEnabled(_enabled);
      await SmsCaptureService.setSenderWhitelist(_senders);
      if (!_observing) {
        WidgetsBinding.instance.addObserver(this);
        _observing = true;
      }
      await _reloadDrafts();
      if (_enabled) {
        await importCaptures();
        _startDrainTimer();
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
    if (_importing) return 0;
    _importing = true;
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
          inserted += await _insertIfNew(result,
              sender: raw['sender'] as String? ?? '');
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
          inserted += await _insertIfNew(result,
              sender: raw['sender'] as String? ?? '');
        }
      }
      await prefs.setInt(_lastScanKey, DateTime.now().millisecondsSinceEpoch);

      // 3. Auto-discover banks so the whitelist stays filled without prompts
      //    (throttled internally; needs READ_SMS which the inbox scan has).
      await detectBanks();

      await _reloadDrafts();
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _importing = false;
    }
    return inserted;
  }

  /// Re-imports captures and refreshes the draft list. Safe to call on screen
  /// open / app resume so newly captured SMS show up without a restart.
  Future<void> refresh() async {
    if (_enabled) {
      await importCaptures();
    } else {
      await _reloadDrafts();
      notifyListeners();
    }
  }

  Future<int> _insertIfNew(SmsParseResult result,
      {required String sender}) async {
    final draft = SmsDraftModel(
      sender: sender,
      bank: result.bank,
      rawBody: result.redactedBody,
      originalBody: result.originalBody,
      title: result.title,
      amount: result.amount,
      txType: result.type,
      kind: result.kind,
      category: result.category,
      transactionDate: result.transactionDate,
      dedupKey: result.dedupKey,
    );
    final id = await _db.insertSmsDraft(draft);
    if (id == -1) {
      await _db.backfillOriginalBody(result.dedupKey, result.originalBody);
      return 0;
    }
    return 1;
  }

  // ── Bank discovery ───────────────────────────────────────────────────────────

  /// Scans the inbox for known bank senders and **auto-merges** them into the
  /// whitelist so the feature captures new banks without re-prompting.
  /// Throttled by [detectionInterval] unless [force] is true.
  Future<void> detectBanks({bool force = false}) async {
    if (_detecting) return;
    final prefs = await SharedPreferences.getInstance();
    if (!force) {
      final last = prefs.getInt(_lastDetectKey) ?? 0;
      final elapsed = DateTime.now().millisecondsSinceEpoch - last;
      if (elapsed >= 0 && elapsed < detectionInterval.inMilliseconds) return;
    }
    _detecting = true;
    try {
      final raw = await SmsCaptureService.discoverSenders();
      final banks = <String>[];
      final seen = <String>{};
      for (final r in raw) {
        final bank = SmsParser.bankNameForSender(r['sender'] as String? ?? '');
        if (bank != null && seen.add(bank.toLowerCase())) banks.add(bank);
      }
      banks.sort();
      await prefs.setInt(_lastDetectKey, DateTime.now().millisecondsSinceEpoch);
      _detectedBanks = List.unmodifiable(banks);
      if (banks.isNotEmpty) {
        await autoMergeDetected();
      }
      notifyListeners();
    } catch (e) {
      _lastError = e.toString();
    } finally {
      _detecting = false;
    }
  }

  /// Appends every detected bank that isn't already in the whitelist and pushes
  /// the merged list to the native receiver + inbox scanner.
  Future<void> autoMergeDetected() async {
    final toAdd = _detectedBanks
        .where((b) => !_senders
            .any((s) => s.toLowerCase().trim() == b.toLowerCase().trim()))
        .toList();
    if (toAdd.isEmpty) return;
    _senders = List.unmodifiable([..._senders, ...toAdd]);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_sendersKey, _senders);
    await SmsCaptureService.setSenderWhitelist(_senders);
    // Auto-scan full history for newly detected banks so their past
    // transactions immediately appear in the drafts inbox.
    await importHistoryFor(toAdd);
  }

  // ── Settings ──────────────────────────────────────────────────────────────────

  /// When the user has not picked any senders, capture everything from the
  /// known bank/wallet sender list so the feature works out of the box.
  Future<void> _setDefaultSendersIfEmpty() async {
    if (_senders.isNotEmpty) return;
    _senders = List.unmodifiable(SmsParser.presetSenders);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_sendersKey, _senders);
  }

  /// Requires the SMS permission to have been granted already.
  Future<void> setEnabled(bool value) async {
    _enabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enabledKey, value);
    if (value) {
      await _setDefaultSendersIfEmpty();
    }
    await SmsCaptureService.setCaptureEnabled(value);
    await SmsCaptureService.setSenderWhitelist(_senders);
    if (value) {
      await importCaptures();
      _startDrainTimer();
    } else {
      _stopDrainTimer();
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

  // ── Live import ──────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_enabled) {
        _startDrainTimer();
        // Deliberately not awaited: starts a background import while the UI
        // steadies after returning to the foreground.
        importCaptures();
      }
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      if (_enabled) _stopDrainTimer();
    }
  }

  void _startDrainTimer() {
    _stopDrainTimer();
    _drainTimer = Timer.periodic(drainInterval, (_) {
      importCaptures();
    });
  }

  void _stopDrainTimer() {
    _drainTimer?.cancel();
    _drainTimer = null;
  }

  @override
  void dispose() {
    _stopDrainTimer();
    _historyProgressCtrl.close();
    if (_observing) {
      WidgetsBinding.instance.removeObserver(this);
      _observing = false;
    }
    super.dispose();
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

  // ── Full history scan ────────────────────────────────────────────────────────

  /// Analyses [messages] that the user manually selected from their inbox.
  /// Each entry must have 'sender' (String), 'body' (String), and 'date' (int
  /// epoch-ms) fields. The sender-whitelist gate is intentionally bypassed so
  /// any message the user picks is examined regardless of its origin.
  ///
  /// Returns a record: (inserted, skipped) counts.
  Future<({int inserted, int skipped})> analyzeSelectedMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    var inserted = 0;
    var skipped = 0;
    for (final raw in messages) {
      final sender = raw['sender'] as String? ?? '';
      final body = raw['body'] as String? ?? '';
      final receivedAt = _epochToDate(raw['date']);
      final result = SmsParser.parseIgnoringWhitelist(
        sender: sender,
        body: body,
        receivedAt: receivedAt,
      );
      if (result.matched) {
        final added = await _insertIfNew(result, sender: sender);
        inserted += added;
      } else {
        skipped++;
      }
    }
    if (inserted > 0) {
      await _reloadDrafts();
      notifyListeners();
    }
    return (inserted: inserted, skipped: skipped);
  }

  /// Scans the entire SMS inbox from the beginning of time (or since a

  /// custom [since]) for all whitelisted senders and inserts every bank
  /// transaction found as a draft.
  ///
  /// Progress is emitted on [historyImportProgress].
  /// Already-imported senders are tracked so re-running is safe (dedup key
  /// prevents duplicate rows; existing drafts are never overwritten).
  Future<int> importFullHistory({DateTime? since}) async {
    if (_importingHistory) return 0;
    _importingHistory = true;
    notifyListeners();
    var inserted = 0;
    var scanned = 0;
    try {
      final from = since ?? DateTime.fromMillisecondsSinceEpoch(0);
      final raw = await SmsCaptureService.scanInboxSince(from);
      for (final msg in raw) {
        scanned++;
        final receivedAt = _epochToDate(msg['date']);
        final result = SmsParser.parse(
          sender: msg['sender'] as String? ?? '',
          body: msg['body'] as String? ?? '',
          receivedAt: receivedAt,
        );
        if (result.matched) {
          inserted += await _insertIfNew(result,
              sender: msg['sender'] as String? ?? '');
        }
        // Emit progress every 25 messages
        if (scanned % 25 == 0) {
          _historyProgressCtrl
              .add((scanned: scanned, inserted: inserted, done: false));
        }
      }
      // Mark full history as done
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_historyScanKey, true);
      await _reloadDrafts();
      notifyListeners();
      _historyProgressCtrl
          .add((scanned: scanned, inserted: inserted, done: true));
    } catch (e) {
      _lastError = e.toString();
      _historyProgressCtrl
          .add((scanned: scanned, inserted: inserted, done: true));
    } finally {
      _importingHistory = false;
      notifyListeners();
    }
    return inserted;
  }

  /// Scans the full SMS inbox history **only** for the given [bankSenders]
  /// (e.g. newly auto-detected banks). Uses the same dedup key so it's safe
  /// to call multiple times.
  Future<int> importHistoryFor(List<String> bankSenders) async {
    if (bankSenders.isEmpty) return 0;
    if (_importingHistory) return 0;
    _importingHistory = true;
    notifyListeners();
    var inserted = 0;
    var scanned = 0;
    try {
      final prefs = await SharedPreferences.getInstance();
      final alreadyScanned =
          (prefs.getStringList(_historyScannedSendersKey) ?? []).toSet();

      // Only scan senders that haven't had their history imported yet
      final toScan = bankSenders
          .where((b) => !alreadyScanned
              .any((s) => s.toLowerCase().trim() == b.toLowerCase().trim()))
          .toList();
      if (toScan.isEmpty) {
        _importingHistory = false;
        notifyListeners();
        return 0;
      }

      final raw = await SmsCaptureService.scanInboxSince(
          DateTime.fromMillisecondsSinceEpoch(0));
      for (final msg in raw) {
        final sender = msg['sender'] as String? ?? '';
        // Only process messages from the target senders
        final isTarget = toScan.any((b) {
          final bn = b.toLowerCase();
          final sn = sender.toLowerCase();
          return sn == bn || sn.contains(bn) || bn.contains(sn);
        });
        if (!isTarget) continue;
        scanned++;
        final receivedAt = _epochToDate(msg['date']);
        final result = SmsParser.parse(
          sender: sender,
          body: msg['body'] as String? ?? '',
          receivedAt: receivedAt,
        );
        if (result.matched) {
          inserted += await _insertIfNew(result, sender: sender);
        }
        if (scanned % 25 == 0) {
          _historyProgressCtrl
              .add((scanned: scanned, inserted: inserted, done: false));
          notifyListeners();
        }
      }
      // Record these senders as history-scanned
      final nowScanned = {...alreadyScanned, ...toScan};
      await prefs.setStringList(_historyScannedSendersKey, nowScanned.toList());
      await _reloadDrafts();
      notifyListeners();
      _historyProgressCtrl
          .add((scanned: scanned, inserted: inserted, done: true));
    } catch (e) {
      _lastError = e.toString();
      _historyProgressCtrl
          .add((scanned: scanned, inserted: inserted, done: true));
    } finally {
      _importingHistory = false;
      notifyListeners();
    }
    return inserted;
  }

  /// Builds the real [TransactionModel] a saved income/expense draft becomes.
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

  /// Best-guess wallet whose name matches a bank (used to prefill wallet
  /// pickers; the user confirms before saving).
  static WalletModel? bestBankWallet(List<WalletModel> wallets, String bank) {
    if (bank.isNotEmpty) {
      final norm = bank.toLowerCase().trim();
      for (final w in wallets) {
        final name = w.name.toLowerCase().trim();
        if (name.contains(norm) || norm.contains(name)) return w;
      }
    }
    for (final w in wallets) {
      if (w.type == WalletType.bankAccount) return w;
    }
    return null;
  }

  /// Best-guess Cash wallet (used to prefill the "To" picker for withdrawals).
  static WalletModel? bestCashWallet(List<WalletModel> wallets) {
    for (final w in wallets) {
      if (w.type == WalletType.cash) return w;
    }
    return null;
  }

  DateTime _epochToDate(dynamic value) {
    final millis = value is num ? value.toInt() : (int.tryParse('$value') ?? 0);
    return millis <= 0
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(millis);
  }
}
