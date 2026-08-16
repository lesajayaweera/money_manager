import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/transaction_model.dart';
import '../providers/budget_provider.dart';
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
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: textPrimary,
            size: 26,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: GoogleFonts.poppins(
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
                // Theme Color picker
                _ThemeColorRow(
                  currentColor: settings.themeColor,
                  onTap: () => _showThemeColorSheet(context, settings),
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

  // Preset theme colors
  static const List<Map<String, dynamic>> _themeColors = [
    {'color': Color(0xFF6C5CE7), 'name': 'Purple'},
    {'color': Color(0xFF2196F3), 'name': 'Blue'},
    {'color': Color(0xFF009688), 'name': 'Teal'},
    {'color': Color(0xFF3F51B5), 'name': 'Indigo'},
    {'color': Color(0xFFE91E63), 'name': 'Pink'},
    {'color': Color(0xFFFF9800), 'name': 'Orange'},
    {'color': Color(0xFFF44336), 'name': 'Red'},
    {'color': Color(0xFF4CAF50), 'name': 'Green'},
  ];

  Future<void> _showThemeColorSheet(
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
              'Theme Color',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Choose an accent color for the app',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 20),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemCount: _themeColors.length,
              itemBuilder: (context, index) {
                final item = _themeColors[index];
                final color = item['color'] as Color;
                final name = item['name'] as String;
                final isSelected = settings.themeColor.toARGB32() == color.toARGB32();

                return GestureDetector(
                  onTap: () async {
                    await settings.setThemeColor(color);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(
                                  color: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.color ??
                                      Colors.white,
                                  width: 3,
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: isSelected ? 12 : 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 22)
                            : null,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        name,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight:
                              isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected
                              ? color
                              : Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

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
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).textTheme.titleLarge?.color,
              ),
            ),
            const SizedBox(height: 16),
            ..._currencies.map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c['name']!,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      )),
                  trailing: settings.currencySymbol == c['symbol']
                      ? Icon(Icons.check_rounded, color: AppColors.primary)
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
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w700,
              color: Theme.of(context).textTheme.titleLarge?.color,
            )),
        content: Text(
          'This will permanently delete all your transactions. This action cannot be undone.',
          style: GoogleFonts.poppins(
            color: Theme.of(context).textTheme.bodyMedium?.color,
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.poppins(
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
                style: GoogleFonts.poppins(
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
      if (!context.mounted) return;
      await context.read<BudgetProvider>().clearAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('All data cleared',
                style: GoogleFonts.poppins(fontSize: 14)),
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
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // App Icon / Logo area
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.35),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Moneygrow',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Version 1.0.0',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage your money smartly and easily.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
              ),
              const SizedBox(height: 20),
              Divider(
                height: 1,
                color: Theme.of(context).dividerTheme.color ?? const Color(0xFFF0F0F0),
              ),
              const SizedBox(height: 16),
              // Seed Data Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await _seedDemoData(context);
                  },
                  icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                  label: Text(
                    'Seed Demo Data',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Close',
                    style: GoogleFonts.poppins(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '© 2024 Moneygrow. All rights reserved.',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _seedDemoData(BuildContext context) async {
    final provider = context.read<TransactionProvider>();
    final now = DateTime.now();

    // Helper to build a date relative to today
    DateTime d(int monthsBack, int day) {
      final m = now.month - monthsBack;
      final y = now.year + (m <= 0 ? -1 : 0);
      final month = m <= 0 ? 12 + m : m;
      final clamped = day.clamp(1, DateUtils.getDaysInMonth(y, month));
      return DateTime(y, month, clamped, 9, 0);
    }

    final seedTransactions = <TransactionModel>[
      // ── This month ──────────────────────────────────────────────────────
      TransactionModel(title: 'Monthly Salary', amount: 85000, type: TransactionType.income, category: 'Salary', date: d(0, 1), walletName: 'Bank'),
      TransactionModel(title: 'Freelance Project', amount: 18000, type: TransactionType.income, category: 'Freelance', date: d(0, 5), walletName: 'Bank'),
      TransactionModel(title: 'Grocery Shopping', amount: 3200, type: TransactionType.expense, category: 'Food', date: d(0, 3), walletName: 'Cash'),
      TransactionModel(title: 'Electricity Bill', amount: 2800, type: TransactionType.expense, category: 'Bills', date: d(0, 4), walletName: 'Bank'),
      TransactionModel(title: 'Petrol', amount: 1500, type: TransactionType.expense, category: 'Transport', date: d(0, 6), walletName: 'Cash'),
      TransactionModel(title: 'Lunch at Restaurant', amount: 850, type: TransactionType.expense, category: 'Food', date: d(0, 7), walletName: 'Cash'),
      TransactionModel(title: 'New Sneakers', amount: 4500, type: TransactionType.expense, category: 'Shopping', date: d(0, 9), walletName: 'Bank'),
      TransactionModel(title: 'Mobile Bill', amount: 1200, type: TransactionType.expense, category: 'Bills', date: d(0, 10), walletName: 'Bank'),
      TransactionModel(title: 'Gym Membership', amount: 1800, type: TransactionType.expense, category: 'Health', date: d(0, 11), walletName: 'Bank'),
      TransactionModel(title: 'Netflix', amount: 700, type: TransactionType.expense, category: 'Entertainment', date: d(0, 12), walletName: 'Bank'),
      TransactionModel(title: 'Coffee & Snacks', amount: 320, type: TransactionType.expense, category: 'Food', date: d(0, 13), walletName: 'Cash'),
      TransactionModel(title: 'Online Course', amount: 2500, type: TransactionType.expense, category: 'Education', date: d(0, 14), walletName: 'Bank'),
      TransactionModel(title: 'Uber Rides', amount: 680, type: TransactionType.expense, category: 'Transport', date: d(0, 15), walletName: 'Cash'),
      TransactionModel(title: 'Gift — Birthday', amount: 2000, type: TransactionType.income, category: 'Gift', date: d(0, 16), walletName: 'Cash'),
      TransactionModel(title: 'Medical Checkup', amount: 1100, type: TransactionType.expense, category: 'Health', date: d(0, 17), walletName: 'Bank'),
      TransactionModel(title: 'Dinner Out', amount: 1400, type: TransactionType.expense, category: 'Food', date: d(0, 19), walletName: 'Cash'),
      TransactionModel(title: 'Laptop Accessories', amount: 3200, type: TransactionType.expense, category: 'Shopping', date: d(0, 20), walletName: 'Bank'),
      TransactionModel(title: 'Internet Bill', amount: 1500, type: TransactionType.expense, category: 'Bills', date: d(0, 21), walletName: 'Bank'),
      TransactionModel(title: 'Savings Deposit', amount: 10000, type: TransactionType.income, category: 'Savings', date: d(0, 22), walletName: 'Bank'),
      TransactionModel(title: 'Movie Tickets', amount: 900, type: TransactionType.expense, category: 'Entertainment', date: d(0, 23), walletName: 'Cash'),

      // ── Last month ──────────────────────────────────────────────────────
      TransactionModel(title: 'Monthly Salary', amount: 85000, type: TransactionType.income, category: 'Salary', date: d(1, 1), walletName: 'Bank'),
      TransactionModel(title: 'Freelance — Logo Design', amount: 8500, type: TransactionType.income, category: 'Freelance', date: d(1, 8), walletName: 'Bank'),
      TransactionModel(title: 'Supermarket Run', amount: 4100, type: TransactionType.expense, category: 'Food', date: d(1, 3), walletName: 'Cash'),
      TransactionModel(title: 'Water Bill', amount: 450, type: TransactionType.expense, category: 'Bills', date: d(1, 5), walletName: 'Bank'),
      TransactionModel(title: 'Bus Pass', amount: 1200, type: TransactionType.expense, category: 'Transport', date: d(1, 6), walletName: 'Cash'),
      TransactionModel(title: 'Pharmacy', amount: 760, type: TransactionType.expense, category: 'Health', date: d(1, 7), walletName: 'Cash'),
      TransactionModel(title: 'Spotify Premium', amount: 550, type: TransactionType.expense, category: 'Entertainment', date: d(1, 9), walletName: 'Bank'),
      TransactionModel(title: 'Clothing Purchase', amount: 5500, type: TransactionType.expense, category: 'Shopping', date: d(1, 11), walletName: 'Bank'),
      TransactionModel(title: 'Lunch — Office', amount: 620, type: TransactionType.expense, category: 'Food', date: d(1, 13), walletName: 'Cash'),
      TransactionModel(title: 'Book Purchase', amount: 980, type: TransactionType.expense, category: 'Education', date: d(1, 15), walletName: 'Cash'),
      TransactionModel(title: 'House Rent', amount: 25000, type: TransactionType.expense, category: 'Bills', date: d(1, 2), walletName: 'Bank'),
      TransactionModel(title: 'Investment Return', amount: 5200, type: TransactionType.income, category: 'Investment', date: d(1, 18), walletName: 'Bank'),
      TransactionModel(title: 'Petrol Fill-up', amount: 2200, type: TransactionType.expense, category: 'Transport', date: d(1, 20), walletName: 'Cash'),
      TransactionModel(title: 'Takeaway Dinner', amount: 1050, type: TransactionType.expense, category: 'Food', date: d(1, 22), walletName: 'Cash'),
      TransactionModel(title: 'Apple Music', amount: 350, type: TransactionType.expense, category: 'Entertainment', date: d(1, 24), walletName: 'Bank'),
      TransactionModel(title: 'Weekend Trip', amount: 8000, type: TransactionType.expense, category: 'Entertainment', date: d(1, 26), walletName: 'Bank'),
      TransactionModel(title: 'Dental Visit', amount: 2200, type: TransactionType.expense, category: 'Health', date: d(1, 28), walletName: 'Bank'),
      TransactionModel(title: 'Snacks & Coffee', amount: 410, type: TransactionType.expense, category: 'Food', date: d(1, 29), walletName: 'Cash'),

      // ── Two months ago ──────────────────────────────────────────────────
      TransactionModel(title: 'Monthly Salary', amount: 80000, type: TransactionType.income, category: 'Salary', date: d(2, 1), walletName: 'Bank'),
      TransactionModel(title: 'Side Project Payment', amount: 12000, type: TransactionType.income, category: 'Freelance', date: d(2, 10), walletName: 'Bank'),
      TransactionModel(title: 'Grocery — Bulk Buy', amount: 5500, type: TransactionType.expense, category: 'Food', date: d(2, 4), walletName: 'Cash'),
      TransactionModel(title: 'House Rent', amount: 25000, type: TransactionType.expense, category: 'Bills', date: d(2, 2), walletName: 'Bank'),
      TransactionModel(title: 'Electricity Bill', amount: 3100, type: TransactionType.expense, category: 'Bills', date: d(2, 5), walletName: 'Bank'),
      TransactionModel(title: 'Eye Doctor', amount: 1500, type: TransactionType.expense, category: 'Health', date: d(2, 7), walletName: 'Bank'),
      TransactionModel(title: 'Cab Rides', amount: 890, type: TransactionType.expense, category: 'Transport', date: d(2, 9), walletName: 'Cash'),
      TransactionModel(title: 'Udemy Course', amount: 1800, type: TransactionType.expense, category: 'Education', date: d(2, 12), walletName: 'Bank'),
      TransactionModel(title: 'New Headphones', amount: 6500, type: TransactionType.expense, category: 'Shopping', date: d(2, 14), walletName: 'Bank'),
      TransactionModel(title: 'Restaurant — Date Night', amount: 3200, type: TransactionType.expense, category: 'Food', date: d(2, 16), walletName: 'Cash'),
      TransactionModel(title: 'Mobile Bill', amount: 1200, type: TransactionType.expense, category: 'Bills', date: d(2, 18), walletName: 'Bank'),
      TransactionModel(title: 'Gaming Purchase', amount: 2800, type: TransactionType.expense, category: 'Entertainment', date: d(2, 20), walletName: 'Bank'),
      TransactionModel(title: 'Gift Received', amount: 3000, type: TransactionType.income, category: 'Gift', date: d(2, 21), walletName: 'Cash'),
      TransactionModel(title: 'Petrol', amount: 1800, type: TransactionType.expense, category: 'Transport', date: d(2, 23), walletName: 'Cash'),
      TransactionModel(title: 'Savings Deposit', amount: 8000, type: TransactionType.income, category: 'Savings', date: d(2, 25), walletName: 'Bank'),
      TransactionModel(title: 'Stationery', amount: 480, type: TransactionType.expense, category: 'Shopping', date: d(2, 27), walletName: 'Cash'),
    ];

    // Show loading indicator
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            const SizedBox(width: 14),
            Text('Seeding demo data…', style: GoogleFonts.poppins(fontSize: 14)),
          ],
        ),
        duration: const Duration(seconds: 10),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    try {
      for (final tx in seedTransactions) {
        await provider.addTransaction(tx);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                '${seedTransactions.length} demo transactions added!',
                style: GoogleFonts.poppins(fontSize: 14),
              ),
            ],
          ),
          backgroundColor: AppColors.income,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error seeding data: $e', style: GoogleFonts.poppins(fontSize: 14)),
          backgroundColor: AppColors.expense,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Coming soon!', style: GoogleFonts.poppins(fontSize: 14)),
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
      style: GoogleFonts.poppins(
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
              style: GoogleFonts.poppins(
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
                Theme.of(context).dividerTheme.color ?? Theme.of(context).dividerColor,
          ),
        ],
      ),
    );
  }
}

/// Theme color picker row (shows a color swatch with the current color).
class _ThemeColorRow extends StatelessWidget {
  final Color currentColor;
  final VoidCallback onTap;
  const _ThemeColorRow({required this.currentColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textPrimary =
        Theme.of(context).textTheme.titleLarge?.color ?? AppColors.textPrimary;
    final dividerColor =
        Theme.of(context).dividerTheme.color ?? const Color(0xFFF0F0F0);
    final textHint =
        Theme.of(context).textTheme.bodySmall?.color ?? AppColors.textHint;

    return Column(
      children: [
        Divider(height: 1, indent: 66, endIndent: 0, color: dividerColor),
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: currentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.palette_rounded,
                    color: currentColor,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 14),
                // Label
                Expanded(
                  child: Text(
                    'Theme Color',
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: textPrimary,
                    ),
                  ),
                ),
                // Color swatch preview
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: currentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: currentColor.withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.chevron_right_rounded, color: textHint, size: 20),
              ],
            ),
          ),
        ),
      ],
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
                    style: GoogleFonts.poppins(
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
                    style: GoogleFonts.poppins(
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
