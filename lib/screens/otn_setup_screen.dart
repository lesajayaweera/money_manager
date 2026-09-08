import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';
import '../models/otn_models.dart';
import '../providers/otn_provider.dart';
import '../providers/settings_provider.dart';

class OtnSetupScreen extends StatefulWidget {
  const OtnSetupScreen({super.key});

  @override
  State<OtnSetupScreen> createState() => _OtnSetupScreenState();
}

class _OtnSetupScreenState extends State<OtnSetupScreen> {
  late final TextEditingController _basicController;
  late final TextEditingController _otRateController;
  late final TextEditingController _workingDaysController;
  late final TextEditingController _stdHoursController;
  late final TextEditingController _othersController;
  late final TextEditingController _processingController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<OtnProvider>().settings;
    _basicController = TextEditingController(text: _num(s.basicSalary));
    _otRateController =
        TextEditingController(text: _num(s.overtimeRatePerHour));
    _workingDaysController =
        TextEditingController(text: '${s.workingDaysPerMonth}');
    _stdHoursController =
        TextEditingController(text: _num(s.standardHoursPerDay));
    _othersController = TextEditingController(text: _num(s.others));
    _processingController = TextEditingController(text: _num(s.processing));

    for (final c in [
      _basicController,
      _otRateController,
      _workingDaysController,
      _stdHoursController,
      _othersController,
      _processingController,
    ]) {
      c.addListener(() => setState(() {}));
    }
  }

  String _num(double v) =>
      v == v.truncateToDouble() ? v.toStringAsFixed(0) : v.toString();

  @override
  void dispose() {
    _basicController.dispose();
    _otRateController.dispose();
    _workingDaysController.dispose();
    _stdHoursController.dispose();
    _othersController.dispose();
    _processingController.dispose();
    super.dispose();
  }

  double get _basic => CurrencyFormatter.parse(_basicController.text) ?? 0;
  double get _otRate => CurrencyFormatter.parse(_otRateController.text) ?? 0;
  int get _workingDays =>
      int.tryParse(_workingDaysController.text.replaceAll(',', '')) ?? 0;
  double get _stdHours => CurrencyFormatter.parse(_stdHoursController.text) ?? 0;
  double get _others => CurrencyFormatter.parse(_othersController.text) ?? 0;
  double get _processing => CurrencyFormatter.parse(_processingController.text) ?? 0;

  Future<void> _save() async {
    setState(() => _isSaving = true);
    await context.read<OtnProvider>().saveSettings(OtnSettings(
          basicSalary: _basic,
          overtimeRatePerHour: _otRate,
          workingDaysPerMonth: _workingDays,
          standardHoursPerDay: _stdHours,
          others: _others,
          processing: _processing,
        ));
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final symbol = context.watch<SettingsProvider>().currencySymbol;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              size: 20,
              color: Theme.of(context).textTheme.titleLarge?.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'OTN Setup',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).textTheme.titleLarge?.color,
          ),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel('Pay rate'),
                const SizedBox(height: 8),
                _AmountField(
                  controller: _basicController,
                  symbol: symbol,
                  hintText: 'e.g. 45000',
                ),
                const SizedBox(height: 14),
                _AmountField(
                  controller: _otRateController,
                  symbol: symbol,
                  hintText: 'Per OT hour, e.g. 250',
                ),

                const SizedBox(height: 24),
                _SectionLabel('Work schedule'),
                const SizedBox(height: 8),
                _NumberField(
                  controller: _workingDaysController,
                  hintText: 'e.g. 26',
                  suffix: 'days / month',
                ),
                const SizedBox(height: 14),
                _NumberField(
                  controller: _stdHoursController,
                  hintText: 'e.g. 8',
                  suffix: 'hrs / day',
                ),

                const SizedBox(height: 24),
                _SectionLabel('Pay add-ons'),
                const SizedBox(height: 8),
                _AmountField(
                  controller: _othersController,
                  symbol: symbol,
                  hintText: 'Allowances, bonus (optional)',
                ),
                const SizedBox(height: 14),
                _AmountField(
                  controller: _processingController,
                  symbol: symbol,
                  hintText: 'Processing fee (deducted)',
                ),

                const SizedBox(height: 24),
                _InfoCard(
                  isDark: isDark,
                  title: 'How your pay is previewed',
                  lines: [
                    'Net = Basic + Overtime + Others − Processing − EBF1 − ETF',
                    'Overtime is auto-calculated as OT hours × OT rate per hour.',
                    'EBF1 (8%) and ETF (3%) are deducted from your basic salary.',
                  ],
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
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
                    backgroundColor: AppColors.income,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    'Save Setup',
                    style: GoogleFonts.poppins(
                        fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ),
          ),
        ],
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

class _AmountField extends StatelessWidget {
  final TextEditingController controller;
  final String symbol;
  final String hintText;

  const _AmountField({
    required this.controller,
    required this.symbol,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
      style: GoogleFonts.poppins(fontSize: 15),
      decoration: InputDecoration(
        prefixText: '$symbol  ',
        prefixStyle: GoogleFonts.poppins(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
        hintText: hintText,
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

class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final String suffix;

  const _NumberField({
    required this.controller,
    required this.hintText,
    required this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
      style: GoogleFonts.poppins(fontSize: 15),
      decoration: InputDecoration(
        suffixText: suffix,
        suffixStyle: GoogleFonts.poppins(
          fontSize: 13,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
        ),
        hintText: hintText,
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

class _InfoCard extends StatelessWidget {
  final bool isDark;
  final String title;
  final List<String> lines;

  const _InfoCard({
    required this.isDark,
    required this.title,
    required this.lines,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkPrimarySurface : AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.primary.withOpacity(0.2)
              : AppColors.primary.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.titleLarge?.color,
            ),
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '•  $line',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
