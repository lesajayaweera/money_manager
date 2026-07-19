import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../providers/goal_provider.dart';
import '../providers/lend_borrow_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Currencies
  static const List<Map<String, String>> _currencies = [
    {'symbol': 'Rs.', 'name': 'LKR (Rs.)'},
    {'symbol': '₹', 'name': 'INR (₹)'},
    {'symbol': '\$', 'name': 'USD (\$)'},
    {'symbol': '€', 'name': 'EUR (€)'},
    {'symbol': '£', 'name': 'GBP (£)'},
    {'symbol': '¥', 'name': 'JPY (¥)'},
    {'symbol': 'AED', 'name': 'AED'},
  ];

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final settings = context.watch<SettingsProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          children: [
            _SettingsList(
              children: [

                // Currency
                _SettingsRow(
                  icon: Icons.attach_money_rounded,
                  iconColor: const Color(0xFF2ECC71),
                  label: 'Currency',
                  value: _currencies.firstWhere(
                    (c) => c['symbol'] == settings.currencySymbol,
                    orElse: () => _currencies.first,
                  )['name']!,
                  onTap: () => _showCurrencySheet(context, settings),
                ),
                // PIN Lock
                _SettingsRow(
                  icon: Icons.lock_outline_rounded,
                  iconColor: const Color(0xFFE74C3C),
                  label: 'PIN Lock',
                  value: 'Enabled',
                  onTap: () => _showComingSoon(context),
                ),
                // Change PIN
                _SettingsRow(
                  icon: Icons.edit_outlined,
                  iconColor: AppColors.primary,
                  label: 'Change PIN',
                  value: '',
                  onTap: () => _showComingSoon(context),
                ),
                // Clear All Data
                _SettingsRow(
                  icon: Icons.delete_outline_rounded,
                  iconColor: const Color(0xFFE74C3C),
                  label: 'Clear All Data',
                  value: '',
                  labelColor: const Color(0xFFE74C3C),
                  onTap: () => _showClearDataDialog(context),
                ),
                // About App
                _SettingsRow(
                  icon: Icons.info_outline_rounded,
                  iconColor: const Color(0xFF4A6CF7),
                  label: 'About App',
                  value: 'Version 1.0.0',
                  isLast: true,
                  onTap: () => _showAbout(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Dialogs ─────────────────────────────────────────────────────────────


  Future<void> _showCurrencySheet(
      BuildContext context, SettingsProvider settings) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Currency',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 16),
            ..._currencies.map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title:
                      Text(c['name']!, style: GoogleFonts.inter(fontSize: 15)),
                  trailing: settings.currencySymbol == c['symbol']
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.primary)
                      : null,
                  onTap: () async {
                    await settings.setCurrencySymbol(c['symbol']!);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                )),
          ],
        ),
      ),
    );
  }

  Future<void> _showClearDataDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear All Data',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete all your transactions. This action cannot be undone.',
          style:
              GoogleFonts.inter(color: AppColors.textSecondary, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE74C3C),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            child: Text('Clear',
                style: GoogleFonts.inter(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await context.read<TransactionProvider>().clearAllData();
      if (!context.mounted) return;
      await context.read<LendBorrowProvider>().clearAllData();
      if (!context.mounted) return;
      await context.read<GoalProvider>().clearAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All data cleared',
                style: GoogleFonts.inter(fontSize: 14)),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'Money Manager',
      applicationVersion: '1.0.0',
      applicationLegalese: '© 2024 Money Manager. All rights reserved.',
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coming soon!', style: GoogleFonts.inter(fontSize: 14)),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ─── UI Components ────────────────────────────────────────────────────────────

class _SettingsList extends StatelessWidget {
  final List<Widget> children;
  const _SettingsList({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: children,
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String valuePrefix;
  final Color? labelColor;
  final bool isLast;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valuePrefix = '',
    this.labelColor,
    this.isLast = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isLast ? const Radius.circular(16) : Radius.zero,
            bottomRight: isLast ? const Radius.circular(16) : Radius.zero,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                // Icon in circle
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 18),
                ),
                const SizedBox(width: 14),
                // Label
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: labelColor ?? AppColors.textPrimary,
                    ),
                  ),
                ),
                // Value
                if (value.isNotEmpty)
                  Text(
                    '$valuePrefix$value',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right_rounded,
                    color: AppColors.textHint, size: 20),
              ],
            ),
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: 66,
            endIndent: 0,
            color: Color(0xFFF5F5F5),
          ),
      ],
    );
  }
}
