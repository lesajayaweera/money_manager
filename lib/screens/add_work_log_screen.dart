import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../core/constants/app_colors.dart';
import '../models/otn_models.dart';
import '../providers/otn_provider.dart';

class AddWorkLogScreen extends StatefulWidget {
  final WorkLogEntry? existing;
  final DateTime? initialMonth;

  const AddWorkLogScreen({super.key, this.existing, this.initialMonth});

  @override
  State<AddWorkLogScreen> createState() => _AddWorkLogScreenState();
}

class _AddWorkLogScreenState extends State<AddWorkLogScreen> {
  final _hoursController = TextEditingController();

  late DateTime _month;
  late int _day;
  TimeOfDay? _inTime;
  TimeOfDay? _outTime;
  late WorkStatus _status;
  bool _isSaving = false;
  int _daysInMonth = 31;

  bool get _isWorked => _status == WorkStatus.worked;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _month = DateTime(e.year, e.month);
      _day = e.day;
      _inTime = e.inTime != null ? _parseTime(e.inTime!) : null;
      _outTime = e.outTime != null ? _parseTime(e.outTime!) : null;
      _status = e.status;
      _hoursController.text =
          e.hours == e.hours.truncateToDouble()
              ? e.hours.toStringAsFixed(0)
              : e.hours.toString();
    } else {
      final now = DateTime.now();
      _month = DateTime(now.year, now.month);
      _day = now.day;
      _status = WorkStatus.worked;
      _hoursController.text = '8';
    }
    _daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    _hoursController.addListener(() => setState(() {}));
  }

  TimeOfDay? _parseTime(String t) {
    final parts = t.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }

  double get _hours => double.tryParse(_hoursController.text.replaceAll(',', '')) ?? 0;

  void _recalcDaysInMonth() {
    setState(() {
      _daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
      if (_day > _daysInMonth) _day = _daysInMonth;
    });
  }

  Future<void> _pickMonthAndDay() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(_month.year, _month.month, _day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2035, 12),
      helpText: 'Select date',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Theme.of(context).brightness),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _month = DateTime(picked.year, picked.month);
        _day = picked.day;
      });
      _recalcDaysInMonth();
    }
  }

  Future<void> _pickTime({required bool isIn}) async {
    final current = isIn ? _inTime : _outTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: current ?? const TimeOfDay(hour: 8, minute: 0),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
              brightness: Theme.of(context).brightness),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isIn) {
          _inTime = picked;
        } else {
          _outTime = picked;
        }
        // Auto-fill hours from in/out when both are set
        if (_inTime != null && _outTime != null) {
          _hoursController.text =
              _computeFromTimes(_inTime!, _outTime!).toStringAsFixed(1);
        }
      });
    }
  }

  double _computeFromTimes(TimeOfDay in_, TimeOfDay out) {
    var diff = (out.hour * 60 + out.minute) - (in_.hour * 60 + in_.minute);
    if (diff < 0) diff += 24 * 60; // crosses midnight
    return diff / 60.0;
  }

  void _showDuplicateWarning() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('An entry already exists for this day.',
            style: GoogleFonts.poppins(fontSize: 13)),
        backgroundColor: AppColors.expense,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _save() async {
    final provider = context.read<OtnProvider>();

    final duplicate = provider.hasEntryForDate(
      _month.year,
      _month.month,
      _day,
      exceptId: widget.existing?.id,
    );
    if (duplicate && mounted) {
      _showDuplicateWarning();
      return;
    }

    if (_isWorked && (_hours <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter worked hours.',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final entry = WorkLogEntry(
      id: widget.existing?.id ?? const Uuid().v4(),
      year: _month.year,
      month: _month.month,
      day: _day,
      inTime: _isWorked && _inTime != null
          ? _fmt(_inTime!)
          : null,
      outTime: _isWorked && _outTime != null
          ? _fmt(_outTime!)
          : null,
      hours: _isWorked ? _hours : 0,
      status: _status,
    );

    try {
      if (widget.existing != null) {
        await provider.updateEntry(entry);
      } else {
        await provider.addEntry(entry);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e',
              style: GoogleFonts.poppins(fontSize: 13)),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Text(
                      widget.existing != null ? 'Edit Day' : 'Add Day',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).textTheme.titleLarge?.color,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Theme.of(context).textTheme.titleLarge?.color),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionLabel('Status of work'),
                    const SizedBox(height: 8),
                    _StatusSelector(
                      selected: _status,
                      onChanged: (s) => setState(() => _status = s),
                    ),

                    const SizedBox(height: 20),
                    _SectionLabel('Date'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _pickMonthAndDay,
                      child: _TileRow(
                        icon: Icons.calendar_today_rounded,
                        text: DateFormat(
                                'EEE, d MMMM yyyy')
                            .format(DateTime(_month.year, _month.month, _day)),
                        isDark: isDark,
                      ),
                    ),

                    if (_isWorked) ...[
                      const SizedBox(height: 20),
                      _SectionLabel('In / Out time'),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _pickTime(isIn: true),
                              child: _TileRow(
                                icon: Icons.login_rounded,
                                text: _inTime == null
                                    ? 'In time'
                                    : _inTime!.format(context),
                                isDark: isDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => _pickTime(isIn: false),
                              child: _TileRow(
                                icon: Icons.logout_rounded,
                                text: _outTime == null
                                    ? 'Out time'
                                    : _outTime!.format(context),
                                isDark: isDark,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),
                      _SectionLabel('Hours worked'),
                      const SizedBox(height: 8),
                      _HoursField(controller: _hoursController),
                      const SizedBox(height: 10),
                      if (_inTime != null && _outTime != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Text(
                            'Calculated from in/out: ${_computeFromTimes(_inTime!, _outTime!).toStringAsFixed(1)} hrs',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color:
                                  Theme.of(context).textTheme.bodySmall?.color,
                            ),
                          ),
                        ),
                    ],
                  ],
                ),
              ),
            ),

            // Save button
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    widget.existing != null ? 'Update' : 'Save Day',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.poppins(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).textTheme.titleLarge?.color,
      ),
    );
  }
}

class _TileRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;

  const _TileRow({required this.icon, required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkDivider : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: Theme.of(context).textTheme.bodySmall?.color),
        ],
      ),
    );
  }
}

class _StatusSelector extends StatelessWidget {
  final WorkStatus selected;
  final ValueChanged<WorkStatus> onChanged;

  const _StatusSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: WorkStatus.values.map((s) {
        final isSelected = s == selected;
        return GestureDetector(
          onTap: () => onChanged(s),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? s.color
                  : Theme.of(context).brightness == Brightness.dark
                      ? AppColors.darkSurface
                      : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? s.color : Colors.grey.shade300,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(s.icon,
                    size: 16,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.color),
                const SizedBox(width: 6),
                Text(
                  s.label,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _HoursField extends StatelessWidget {
  final TextEditingController controller;

  const _HoursField({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))
      ],
      style: GoogleFonts.poppins(fontSize: 15),
      decoration: InputDecoration(
        suffixText: 'hours',
        suffixStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
        hintText: 'e.g. 8.5',
        hintStyle: GoogleFonts.poppins(
            fontSize: 15,
            color: isDark ? AppColors.darkTextHint : AppColors.textHint),
        filled: true,
        fillColor: isDark ? AppColors.darkSurface : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isDark ? AppColors.darkDivider : Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
              color: isDark ? AppColors.darkDivider : Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}
