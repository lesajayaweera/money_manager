import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../providers/goal_provider.dart';
import '../providers/lend_borrow_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/transaction_provider.dart';
import '../providers/wallet_provider.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = Theme.of(context).textTheme.titleLarge?.color ?? AppColors.textPrimary;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.inter(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: textPrimary,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Appearance ────────────────────────────────────────────────
            _SectionLabel('Appearance'),
            const SizedBox(height: 8),
            _SettingsList(
              children: [
                // Dark Mode toggle
                _DarkModeRow(
                  isDark: isDark,
                  value: settings.isDarkMode,
                  onChanged: (_) => settings.toggleDarkMode(),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── General ───────────────────────────────────────────────────
            _SectionLabel('General'),
            const SizedBox(height: 8),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 16),
            ..._currencies.map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c['name']!,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      )),
                  trailing: settings.currencySymbol == c['symbol']
                      ? const Icon(Icons.check_rounded, color: AppColors.primary)
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
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text('Clear All Data',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.titleLarge?.color,
            )),
        content: Text(
          'This will permanently delete all your transactions. This action cannot be undone.',
          style: GoogleFonts.inter(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.inter(
                    color: Theme.of(context).textTheme.bodyMedium?.color)),
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
      if (!context.mounted) return;
      await context.read<WalletProvider>().clearAllData();
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

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(context).textTheme.bodySmall?.color,
      ),
    );
  }
}

class _SettingsList extends StatelessWidget {
  final List<Widget> children;
  const _SettingsList({required this.children});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
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

/// Dark mode toggle row (uses a Switch instead of chevron).
class _DarkModeRow extends StatelessWidget {
  final bool isDark;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _DarkModeRow(
      {required this.isDark, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        Theme.of(context).textTheme.titleLarge?.color ?? AppColors.textPrimary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: (isDark ? AppColors.primaryLight : AppColors.primary)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: isDark ? AppColors.primaryLight : AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          // Label
          Expanded(
            child: Text(
              'Dark Mode',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: textPrimary,
              ),
            ),
          ),
          // Toggle switch
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.primary,
            inactiveThumbColor: Theme.of(context).textTheme.bodySmall?.color,
            inactiveTrackColor:
                Theme.of(context).dividerTheme.color ?? const Color(0xFFE0E0E0),
          ),
        ],
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
    final textPrimary =
        Theme.of(context).textTheme.titleLarge?.color ?? AppColors.textPrimary;
    final textSecondary =
        Theme.of(context).textTheme.bodyMedium?.color ?? AppColors.textSecondary;
    final textHint =
        Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textHint;
    final dividerColor =
        Theme.of(context).dividerTheme.color ?? const Color(0xFFF5F5F5);

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
                      color: labelColor ?? textPrimary,
                    ),
                  ),
                ),
                // Value
                if (value.isNotEmpty)
                  Text(
                    '$valuePrefix$value',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: textSecondary,
                    ),
                  ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, color: textHint, size: 20),
              ],
            ),
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 66,
            endIndent: 0,
            color: dividerColor,
          ),
      ],
    );
  }
}
