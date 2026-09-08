import 'dart:convert';
import 'package:flutter/material.dart';

// ─── Work Status ──────────────────────────────────────────────────────────────

enum WorkStatus { worked, leave, noPay, holiday }

extension WorkStatusX on WorkStatus {
  String get label {
    switch (this) {
      case WorkStatus.worked:
        return 'Worked';
      case WorkStatus.leave:
        return 'Leave';
      case WorkStatus.noPay:
        return 'No Pay';
      case WorkStatus.holiday:
        return 'Holiday';
    }
  }

  IconData get icon {
    switch (this) {
      case WorkStatus.worked:
        return Icons.work_rounded;
      case WorkStatus.leave:
        return Icons.beach_access_rounded;
      case WorkStatus.noPay:
        return Icons.money_off_rounded;
      case WorkStatus.holiday:
        return Icons.celebration_rounded;
    }
  }

  Color get color {
    switch (this) {
      case WorkStatus.worked:
        return const Color(0xFF00B894);
      case WorkStatus.leave:
        return const Color(0xFF0984E3);
      case WorkStatus.noPay:
        return const Color(0xFFE17055);
      case WorkStatus.holiday:
        return const Color(0xFFFDAA3D);
    }
  }

  String get jsonKey {
    switch (this) {
      case WorkStatus.worked:
        return 'worked';
      case WorkStatus.leave:
        return 'leave';
      case WorkStatus.noPay:
        return 'noPay';
      case WorkStatus.holiday:
        return 'holiday';
    }
  }

  static WorkStatus fromJsonKey(String key) {
    switch (key) {
      case 'leave':
        return WorkStatus.leave;
      case 'noPay':
        return WorkStatus.noPay;
      case 'holiday':
        return WorkStatus.holiday;
      default:
        return WorkStatus.worked;
    }
  }
}

// ─── Single Work Log Entry ────────────────────────────────────────────────────

class WorkLogEntry {
  final String id;
  final int year;
  final int month; // 1-12
  final int day;
  final String? inTime; // "HH:mm", null for non-worked days
  final String? outTime; // "HH:mm", null for non-worked days
  final double hours;
  final WorkStatus status;

  const WorkLogEntry({
    required this.id,
    required this.year,
    required this.month,
    required this.day,
    this.inTime,
    this.outTime,
    required this.hours,
    required this.status,
  });

  DateTime get date => DateTime(year, month, day);

  WorkLogEntry copyWith({
    String? id,
    int? year,
    int? month,
    int? day,
    String? inTime,
    String? outTime,
    double? hours,
    WorkStatus? status,
  }) {
    return WorkLogEntry(
      id: id ?? this.id,
      year: year ?? this.year,
      month: month ?? this.month,
      day: day ?? this.day,
      inTime: inTime ?? this.inTime,
      outTime: outTime ?? this.outTime,
      hours: hours ?? this.hours,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'year': year,
        'month': month,
        'day': day,
        'inTime': inTime,
        'outTime': outTime,
        'hours': hours,
        'status': status.jsonKey,
      };

  factory WorkLogEntry.fromJson(Map<String, dynamic> json) => WorkLogEntry(
        id: json['id'] as String,
        year: json['year'] as int,
        month: json['month'] as int,
        day: json['day'] as int,
        inTime: json['inTime'] as String?,
        outTime: json['outTime'] as String?,
        hours: (json['hours'] as num).toDouble(),
        status: WorkStatusX.fromJsonKey(json['status'] as String),
      );

  // ── SharedPreferences helpers ─────────────────────────────────────────────

  static List<WorkLogEntry> listFromJsonString(String jsonString) {
    final list = json.decode(jsonString) as List<dynamic>;
    return list
        .map((e) => WorkLogEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static String listToJsonString(List<WorkLogEntry> entries) =>
      json.encode(entries.map((e) => e.toJson()).toList());
}

// ─── OTN Settings ─────────────────────────────────────────────────────────────

class OtnSettings {
  double basicSalary;
  double overtimeRatePerHour;
  int workingDaysPerMonth;
  double standardHoursPerDay;
  double others;
  double processing;

  OtnSettings({
    this.basicSalary = 0,
    this.overtimeRatePerHour = 0,
    this.workingDaysPerMonth = 30,
    this.standardHoursPerDay = 8,
    this.others = 0,
    this.processing = 0,
  });

  OtnSettings copyWith({
    double? basicSalary,
    double? overtimeRatePerHour,
    int? workingDaysPerMonth,
    double? standardHoursPerDay,
    double? others,
    double? processing,
  }) {
    return OtnSettings(
      basicSalary: basicSalary ?? this.basicSalary,
      overtimeRatePerHour: overtimeRatePerHour ?? this.overtimeRatePerHour,
      workingDaysPerMonth: workingDaysPerMonth ?? this.workingDaysPerMonth,
      standardHoursPerDay: standardHoursPerDay ?? this.standardHoursPerDay,
      others: others ?? this.others,
      processing: processing ?? this.processing,
    );
  }

  Map<String, dynamic> toJson() => {
        'basicSalary': basicSalary,
        'overtimeRatePerHour': overtimeRatePerHour,
        'workingDaysPerMonth': workingDaysPerMonth,
        'standardHoursPerDay': standardHoursPerDay,
        'others': others,
        'processing': processing,
      };

  factory OtnSettings.fromJson(Map<String, dynamic> json) => OtnSettings(
        basicSalary: (json['basicSalary'] as num).toDouble(),
        overtimeRatePerHour: (json['overtimeRatePerHour'] as num).toDouble(),
        workingDaysPerMonth: json['workingDaysPerMonth'] as int,
        standardHoursPerDay: (json['standardHoursPerDay'] as num).toDouble(),
        others: (json['others'] as num?)?.toDouble() ?? 0,
        processing: (json['processing'] as num?)?.toDouble() ?? 0,
      );

  String toJsonString() => json.encode(toJson());

  factory OtnSettings.fromJsonString(String jsonString) =>
      OtnSettings.fromJson(json.decode(jsonString) as Map<String, dynamic>);
}
