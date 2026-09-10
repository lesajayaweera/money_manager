import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/otn_models.dart';

/// Month aggregate statistics for the OTN dashboard.
class OtnMonthStats {
  final int workedDays;
  final int leaveDays;
  final int noPayDays;
  final int holidays;
  final double totalHours;
  final int standardHoursPerDay;
  final List<WorkLogEntry> workedEntries;

  const OtnMonthStats({
    required this.workedDays,
    required this.leaveDays,
    required this.noPayDays,
    required this.holidays,
    required this.totalHours,
    required this.standardHoursPerDay,
    required this.workedEntries,
  });

  /// Overtime hours beyond the standard working day (never negative).
  double get otHours {
    final expected = workedDays * standardHoursPerDay;
    final ot = totalHours - expected;
    return ot < 0 ? 0 : ot;
  }

  /// Average worked hours per worked day (0 if no worked days).
  double get averagePerDay =>
      workedDays == 0 ? 0 : totalHours / workedDays;
}

class OtnProvider extends ChangeNotifier {
  static const String _entriesKey = 'otn_work_entries_v1';
  static const String _settingsKey = 'otn_settings_v1';

  List<WorkLogEntry> _entries = [];
  OtnSettings _settings = OtnSettings();
  bool _isLoading = false;
  String? _error;

  List<WorkLogEntry> get entries => _entries;
  OtnSettings get settings => _settings;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> load() async {
    _isLoading = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();

      final entriesRaw = prefs.getString(_entriesKey);
      if (entriesRaw != null && entriesRaw.isNotEmpty) {
        _entries = WorkLogEntry.listFromJsonString(entriesRaw);
      }

      final settingsRaw = prefs.getString(_settingsKey);
      if (settingsRaw != null && settingsRaw.isNotEmpty) {
        _settings = OtnSettings.fromJsonString(settingsRaw);
      }

      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _persistEntries() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_entriesKey, WorkLogEntry.listToJsonString(_entries));
  }

  Future<void> _persistSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_settingsKey, _settings.toJsonString());
  }

  // ── Settings ──────────────────────────────────────────────────────────────

  Future<void> saveSettings(OtnSettings settings) async {
    _settings = settings;
    notifyListeners();
    await _persistSettings();
  }

  // ── Entries ───────────────────────────────────────────────────────────────

  Future<void> addEntry(WorkLogEntry entry) async {
    _entries.add(entry);
    notifyListeners();
    await _persistEntries();
  }

  Future<void> updateEntry(WorkLogEntry updated) async {
    final idx = _entries.indexWhere((e) => e.id == updated.id);
    if (idx == -1) return;
    _entries[idx] = updated;
    notifyListeners();
    await _persistEntries();
  }

  Future<void> deleteEntry(String id) async {
    _entries.removeWhere((e) => e.id == id);
    notifyListeners();
    await _persistEntries();
  }

  // ── Queries ───────────────────────────────────────────────────────────────

  /// Removes all work log entries and resets settings from SharedPreferences.
  Future<void> clearAllData() async {
    _entries = [];
    _settings = OtnSettings();
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_entriesKey);
    await prefs.remove(_settingsKey);
  }

  /// All entries for the given calendar month, sorted by day ascending.
  List<WorkLogEntry> entriesForMonth(int year, int month) {
    final list = _entries
        .where((e) => e.year == year && e.month == month)
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    return list;
  }

  /// Aggregate statistics for the given calendar month.
  OtnMonthStats statsForMonth(int year, int month) {
    final monthEntries = entriesForMonth(year, month);
    final worked = monthEntries
        .where((e) => e.status == WorkStatus.worked)
        .toList();

    return OtnMonthStats(
      workedDays: worked.length,
      leaveDays:
          monthEntries.where((e) => e.status == WorkStatus.leave).length,
      noPayDays:
          monthEntries.where((e) => e.status == WorkStatus.noPay).length,
      holidays:
          monthEntries.where((e) => e.status == WorkStatus.holiday).length,
      totalHours: worked.fold(0, (sum, e) => sum + e.hours),
      standardHoursPerDay: _settings.standardHoursPerDay.round(),
      workedEntries: worked,
    );
  }

  /// Returns true if an entry already exists for the given date (excluding [exceptId]).
  bool hasEntryForDate(int year, int month, int day, {String? exceptId}) =>
      _entries.any((e) =>
          e.year == year &&
          e.month == month &&
          e.day == day &&
          (exceptId == null || e.id != exceptId));
}
